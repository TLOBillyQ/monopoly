local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _repo_root()
  local source = debug.getinfo(1, "S").source or "@scripts/crap4lua/_internal/json_writer.lua"
  local normalized = _normalize_path(source):gsub("^@", "")
  local repo_root = normalized:match("^(.*)/scripts/crap4lua/_internal/[^/]+$")
  return repo_root or "."
end

local repo_root = _repo_root()
dofile(repo_root .. "/scripts/shared/package_path_helper.lua").install_monopoly_package_paths({
  repo_root = repo_root,
  arch_view_root = repo_root .. "/vendor/arch_view",
})

return require("shared.lib.json_writer")
