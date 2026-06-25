local common = require("shared.lib.common")

local tool_cache = {}

local _TOOL_DEFS = {
  acceptance4lua = { required = "lib/acceptance4lua/init.lua" },
  arch_view = { required = "lib/arch_view/init.lua" },
  crap4lua = { required = "lib/crap4lua/cli.lua" },
  dry4lua = { required = "lib/dry4lua/cli.lua" },
  mutate4lua = { required = "lib/mutate4lua/cli.lua" },
}

local function _trim(text)
  return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _split_fields(line)
  local fields = {}
  for field in tostring(line or ""):gmatch("%S+") do
    fields[#fields + 1] = field
  end
  return fields
end

local function _short(hash)
  local text = tostring(hash or "")
  if text == "" then
    return "-"
  end
  return text:sub(1, 10)
end

local function _prepend_package_path(pattern)
  if tostring(package.path):find(pattern, 1, true) == nil then
    package.path = pattern .. ";" .. package.path
  end
end

local function _run(command, opts)
  local runner = opts and opts.run_command or common.run_command
  return runner(command, opts and opts.command_options or nil)
end

local function _git(args, opts)
  local command = { "git" }
  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end
  return _run(command, opts)
end

local function _execute_success(ok, _, code)
  if type(ok) == "number" then
    return ok == 0
  end
  return ok == true and (code == nil or code == 0)
end

local function _powershell_literal(value)
  return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function _mkdir_once(path)
  local command
  if common.is_windows() then
    command = table.concat({
      "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ",
      [["try { New-Item -ItemType Directory -Path ]],
      _powershell_literal(path),
      [[ -ErrorAction Stop | Out-Null; exit 0 } catch { exit 1 }" > nul 2> nul]],
    })
  else
    command = "mkdir " .. common.shell_quote(path) .. " >/dev/null 2>&1"
  end
  return _execute_success(os.execute(command))
end

local function _sleep_briefly()
  if common.is_windows() then
    os.execute([[powershell -NoProfile -NonInteractive -Command "Start-Sleep -Milliseconds 100" > nul 2> nul]])
  else
    os.execute("sleep 0.1 >/dev/null 2>&1")
  end
end

local function _acquire_lock(path)
  local started = os.time()
  while true do
    if _mkdir_once(path) then
      return function()
        common.remove_path(path)
      end
    end
    if os.time() - started > 300 then
      return nil, "timed out waiting for tool cache lock: " .. tostring(path)
    end
    _sleep_briefly()
  end
end

local function _cache_valid(path, commit, def, opts)
  if common.is_dir(path) ~= true then
    return false, "cache directory missing"
  end
  if common.path_exists(common.join_path(path, def.required)) ~= true then
    return false, "required tool file missing: " .. tostring(def.required)
  end
  local result = _git({ "-C", path, "rev-parse", "HEAD" }, opts)
  if result.ok ~= true then
    return false, "cannot read cached commit: " .. tostring(result.output)
  end
  local actual = _trim(result.output)
  if actual ~= commit then
    return false, "cached commit " .. _short(actual) .. " != lock " .. _short(commit)
  end
  return true
end

function tool_cache.parse_lock_contents(content)
  local tools = {}
  local ordered = {}
  local errors = {}

  local line_no = 0
  for raw_line in (tostring(content or "") .. "\n"):gmatch("(.-)\n") do
    line_no = line_no + 1
    local line = _trim(raw_line:gsub("#.*$", ""))
    if line ~= "" then
      local fields = _split_fields(line)
      local name, repo, commit = fields[1], fields[2], fields[3]
      if #fields < 3 then
        errors[#errors + 1] = "line " .. tostring(line_no) .. ": expected <name> <repo> <commit>"
      elseif _TOOL_DEFS[name] == nil then
        errors[#errors + 1] = "line " .. tostring(line_no) .. ": unknown tool " .. tostring(name)
      elseif tools[name] ~= nil then
        errors[#errors + 1] = "line " .. tostring(line_no) .. ": duplicate tool " .. tostring(name)
      elseif not tostring(commit):match("^[0-9a-fA-F]+$") or #tostring(commit) < 10 then
        errors[#errors + 1] = "line " .. tostring(line_no) .. ": invalid commit for " .. tostring(name)
      else
        tools[name] = {
          name = name,
          repo = repo,
          commit = commit,
          checksum = fields[4],
        }
        ordered[#ordered + 1] = name
      end
    end
  end

  if #errors > 0 then
    return nil, table.concat(errors, "\n")
  end
  return { tools = tools, ordered = ordered }
end

function tool_cache.lock_path(env)
  return common.join_path((env or {}).repo_root or ".", "swarmforge/tools.lock")
end

function tool_cache.cache_root(env)
  return common.join_path((env or {}).repo_root or ".", ".swarmforge/tools")
end

function tool_cache.read_lock(env)
  local path = tool_cache.lock_path(env)
  local content, err = common.read_file(path)
  if content == nil then
    return nil, err
  end
  return tool_cache.parse_lock_contents(content)
end

function tool_cache.tool_dir(env, name, commit)
  return common.join_path(tool_cache.cache_root(env), tostring(name) .. "@" .. tostring(commit))
end

function tool_cache.add_lua_paths(tool_root)
  local lib_root = common.join_path(tool_root, "lib")
  _prepend_package_path(common.join_path(lib_root, "?.lua"))
  _prepend_package_path(common.join_path(lib_root, "?/init.lua"))
end

function tool_cache.install_locked_tool_paths(env)
  local lock, err = tool_cache.read_lock(env)
  if lock == nil then
    return nil, err
  end
  for _, name in ipairs(lock.ordered or {}) do
    local entry = lock.tools[name]
    tool_cache.add_lua_paths(tool_cache.tool_dir(env, name, entry.commit))
  end
  return true
end

function tool_cache.ensure_tool(name, env, opts)
  opts = opts or {}
  local def = _TOOL_DEFS[name]
  if def == nil then
    return nil, "unknown tool: " .. tostring(name)
  end

  local lock, err = tool_cache.read_lock(env)
  if lock == nil then
    return nil, err
  end
  local entry = lock.tools[name]
  if entry == nil then
    return nil, "tool missing from lockfile: " .. tostring(name)
  end

  local cache_root = tool_cache.cache_root(env)
  local ok, ensure_err = common.ensure_dir(cache_root)
  if not ok then
    return nil, ensure_err
  end

  local release_lock, lock_err = _acquire_lock(common.join_path(cache_root, tostring(name) .. ".lock"))
  if release_lock == nil then
    return nil, lock_err
  end

  local function _finish(value, finish_err)
    release_lock()
    return value, finish_err
  end

  local root = tool_cache.tool_dir(env, name, entry.commit)
  local valid = _cache_valid(root, entry.commit, def, opts)
  if not valid then
    local tmp = common.join_path(cache_root, "." .. tostring(name) .. "@" .. tostring(entry.commit) .. ".tmp")
    common.remove_path(tmp)
    common.remove_path(root)

    local clone = _git({ "clone", "--quiet", entry.repo, tmp }, opts)
    if clone.ok ~= true then
      common.remove_path(tmp)
      return _finish(nil, "clone failed for " .. tostring(name) .. ": " .. tostring(clone.output))
    end

    local checkout = _git({ "-C", tmp, "checkout", "--quiet", entry.commit }, opts)
    if checkout.ok ~= true then
      common.remove_path(tmp)
      return _finish(nil, "checkout failed for " .. tostring(name) .. "@" .. _short(entry.commit) .. ": " .. tostring(checkout.output))
    end

    local submodules = _git({ "-C", tmp, "submodule", "update", "--init", "--recursive" }, opts)
    if submodules.ok ~= true then
      common.remove_path(tmp)
      return _finish(nil, "submodule update failed for " .. tostring(name) .. ": " .. tostring(submodules.output))
    end

    ok, err = common.copy_tree(tmp, root)
    common.remove_path(tmp)
    if not ok then
      return _finish(nil, err)
    end

    valid, err = _cache_valid(root, entry.commit, def, opts)
    if not valid then
      return _finish(nil, "cached tool invalid after clone: " .. tostring(err))
    end
  end

  tool_cache.add_lua_paths(root)
  return _finish({
    name = name,
    root = root,
    repo = entry.repo,
    commit = entry.commit,
  })
end

return tool_cache
