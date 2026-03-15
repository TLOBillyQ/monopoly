local bootstrap = {}

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
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

  require("scripts.shared.package_path_helper").install_monopoly_package_paths({
    repo_root = repo_root,
    arch_view_root = _normalize_path(repo_root .. "/vendor/arch_view"),
  })

  return {
    script_dir = _normalize_path(script_dir),
    repo_root = _normalize_path(repo_root),
    scripts_dir = scripts_dir,
  }
end

return bootstrap
