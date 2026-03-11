local bootstrap = {}

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _append_path(path_pattern)
  if not tostring(package.path):find(path_pattern, 1, true) then
    package.path = path_pattern .. ";" .. package.path
  end
end

local function _script_dir(script_path)
  local normalized = _normalize_path(script_path)
  return normalized:match("^(.*)/[^/]+$") or "scripts"
end

local function _repo_root(script_path)
  local normalized = _normalize_path(script_path)
  local repo_root = normalized:match("^(.*)/scripts/.*$")
  if repo_root ~= nil and repo_root ~= "" then
    return repo_root
  end
  local script_dir = _script_dir(script_path)
  return _normalize_path(script_dir .. "/..")
end

function bootstrap.install(script_path)
  local resolved_script_path = script_path or (arg and arg[0]) or "scripts"
  local script_dir = _script_dir(resolved_script_path)
  local repo_root = _repo_root(resolved_script_path)
  local scripts_dir = _normalize_path(repo_root .. "/scripts")

  _append_path(scripts_dir .. "/?.lua")
  _append_path(scripts_dir .. "/?/?.lua")
  _append_path(repo_root .. "/?.lua")
  _append_path(repo_root .. "/?/init.lua")
  _append_path(repo_root .. "/tests/?.lua")
  _append_path(repo_root .. "/tests/?/init.lua")

  return {
    script_dir = _normalize_path(script_dir),
    repo_root = _normalize_path(repo_root),
    scripts_dir = scripts_dir,
  }
end

return bootstrap
