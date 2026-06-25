local common = require("shared.lib.common")
local cache_lock = require("shared.tool_cache_lock")

local tool_cache_fetch = {}

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

function tool_cache_fetch.cache_valid(path, commit, def, opts)
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

function tool_cache_fetch.with_lock(path, fn)
  return cache_lock.with_lock(path, fn)
end

function tool_cache_fetch.populate(root, tmp, name, entry, opts)
  common.remove_path(tmp)
  common.remove_path(root)

  local clone = _git({ "clone", "--quiet", entry.repo, tmp }, opts)
  if clone.ok ~= true then
    common.remove_path(tmp)
    return nil, "clone failed for " .. tostring(name) .. ": " .. tostring(clone.output)
  end

  local checkout = _git({ "-C", tmp, "checkout", "--quiet", entry.commit }, opts)
  if checkout.ok ~= true then
    common.remove_path(tmp)
    return nil, "checkout failed for " .. tostring(name) .. "@" .. _short(entry.commit) .. ": " .. tostring(checkout.output)
  end

  local submodules = _git({ "-C", tmp, "submodule", "update", "--init", "--recursive" }, opts)
  if submodules.ok ~= true then
    common.remove_path(tmp)
    return nil, "submodule update failed for " .. tostring(name) .. ": " .. tostring(submodules.output)
  end

  local ok, err = common.copy_tree(tmp, root)
  common.remove_path(tmp)
  if not ok then
    return nil, err
  end
  return true
end

return tool_cache_fetch
