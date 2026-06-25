local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/vendor_submodules.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)

local common = require("shared.lib.common")
local tool_cache = require("shared.tool_cache")

local vendor_submodules = {}

local function _trim(text)
  return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _short(hash)
  local text = tostring(hash or "")
  if text == "" then
    return "-"
  end
  return text:sub(1, 10)
end

local function _git(args)
  local command = { "git" }
  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end
  return common.run_command(command)
end

local function _append_issue(issues, row, message)
  issues[#issues + 1] = {
    tool = row.tool,
    path = row.path,
    message = message,
    expected = row.expected,
    actual = row.actual,
  }
end

function vendor_submodules.repo_root(cwd)
  local result = common.run_command({ "git", "-C", cwd or common.current_dir(), "rev-parse", "--show-toplevel" })
  if result.ok ~= true then
    return nil, result.output
  end
  return _trim(result.output)
end

function vendor_submodules.inspect_tool(root, name, entry)
  local row = {
    tool = name,
    path = tool_cache.tool_dir({ repo_root = root }, name, entry.commit),
    expected = entry.commit,
    actual = nil,
    cached = false,
  }
  local issues = {}

  if common.is_dir(row.path) ~= true then
    _append_issue(issues, row, "tool cache missing")
    return row, issues
  end
  row.cached = true

  local rev = _git({ "-C", row.path, "rev-parse", "HEAD" })
  if rev.ok ~= true then
    _append_issue(issues, row, "cannot read cached tool HEAD: " .. _trim(rev.output))
    return row, issues
  end
  row.actual = _trim(rev.output)

  if row.actual ~= row.expected then
    _append_issue(issues, row, "cached tool HEAD differs from tools.lock")
  end

  return row, issues
end

function vendor_submodules.check(opts)
  opts = opts or {}
  local root = opts.root
  if root == nil or root == "" then
    local root_err
    root, root_err = vendor_submodules.repo_root(common.current_dir())
    if root == nil then
      return {
        ok = false,
        issues = { { message = "cannot resolve repo root: " .. tostring(root_err) } },
        rows = {},
      }
    end
  end
  root = common.normalize_path(root)
  local env = { repo_root = root }

  local lock, lock_err = tool_cache.read_lock(env)
  if lock == nil then
    return {
      ok = false,
      issues = { { message = "cannot read tools.lock: " .. tostring(lock_err) } },
      rows = {},
    }
  end

  if opts.ensure == true or opts.fetch == true then
    for _, name in ipairs(lock.ordered or {}) do
      local _, err = bootstrap.ensure_tool(name, env)
      if err ~= nil then
        return {
          ok = false,
          issues = { { tool = name, message = "cannot bootstrap tool: " .. tostring(err) } },
          rows = {},
        }
      end
    end
  end

  local rows = {}
  local issues = {}
  for _, name in ipairs(lock.ordered or {}) do
    local row, row_issues = vendor_submodules.inspect_tool(root, name, lock.tools[name])
    rows[#rows + 1] = row
    for _, issue in ipairs(row_issues) do
      issues[#issues + 1] = issue
    end
  end

  return {
    ok = #issues == 0,
    root = root,
    rows = rows,
    issues = issues,
    tool_count = #rows,
  }
end

local function _usage()
  return table.concat({
    "usage: lua tools/quality/vendor_submodules.lua [--root <path>] [--ensure]",
    "Checks swarm quality tool lockfile/cache health.",
    "--fetch is accepted as a compatibility alias for --ensure.",
  }, "\n")
end

local function _parse_args(args)
  local opts = {}
  local index = 1
  while index <= #(args or {}) do
    local value = args[index]
    if value == "--root" then
      opts.root = args[index + 1]
      if opts.root == nil then
        return nil, "missing value for --root"
      end
      index = index + 2
    elseif value == "--ensure" or value == "--fetch" then
      opts.ensure = true
      index = index + 1
    elseif value == "--help" or value == "-h" then
      opts.help = true
      index = index + 1
    else
      return nil, "unknown option: " .. tostring(value)
    end
  end
  return opts
end

function vendor_submodules.main(args)
  local opts, err = _parse_args(args or {})
  if opts == nil then
    io.stderr:write(_usage() .. "\n" .. tostring(err) .. "\n")
    return 2
  end
  if opts.help then
    io.write(_usage() .. "\n")
    return 0
  end

  local result = vendor_submodules.check(opts)
  if result.ok then
    io.write(string.format("tool cache clean: %d tools\n", result.tool_count or 0))
    return 0
  end

  for _, issue in ipairs(result.issues or {}) do
    io.stderr:write(string.format(
      "tool cache issue: tool=%s path=%s expected=%s actual=%s message=%s\n",
      tostring(issue.tool or "-"),
      tostring(issue.path or "-"),
      _short(issue.expected),
      _short(issue.actual),
      tostring(issue.message or "unknown")
    ))
  end
  return 1
end

if arg ~= nil and tostring(arg[0] or ""):match("vendor_submodules%.lua$") then
  os.exit(vendor_submodules.main(arg))
end

return vendor_submodules
