local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/shared/bootstrap.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  return normalized:match("^(.*)/[^/]+$") or "tools/shared"
end

local runtime_paths = dofile(_module_dir() .. "/runtime_paths.lua")

local bootstrap = {}

function bootstrap.resolve(script_path, opts)
  opts = opts or {}
  return runtime_paths.resolve({
    source_path = script_path or opts.source_path or (debug.getinfo(2, "S") and debug.getinfo(2, "S").source) or "",
    cwd = opts.cwd or runtime_paths.current_dir(),
  })
end

function bootstrap.install(script_path, opts)
  local env = bootstrap.resolve(script_path, opts)
  dofile(runtime_paths.join_path(env.scripts_dir, "shared/package_path_helper.lua")).install_monopoly_package_paths({
    repo_root = env.repo_root,
    arch_view_root = runtime_paths.join_path(env.vendor_dir, "arch_view"),
  })
  require("shared.lib.common").ensure_windows_utf8_console()
  return env
end

return bootstrap
