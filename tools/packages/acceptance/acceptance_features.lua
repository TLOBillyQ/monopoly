-- Acceptance suite registry: the canonical feature -> generated-spec mapping.
--
-- This is the source of truth for *which* features compose the acceptance
-- suite and what each one's generated spec is named (see
-- tools/packages/acceptance/regenerate.lua and the `lua tools/cli.lua acceptance` entrypoint).
-- The set is corpus-specific, so it is supplied by the consuming project at the
-- repo-root path `features/manifest.lua`, which returns
-- `{ entries = {...}, generated_dir? }`. The template skeleton has no such
-- file, so the registry is simply empty there. The repo root is derived from
-- this file's own path, not the current working directory.

local DEFAULT_GENERATED_DIR = "tools/packages/acceptance/generated"

local function _repo_root()
  local src_path = debug.getinfo(1, "S").source or "@tools/packages/acceptance/acceptance_features.lua"
  local normalized = tostring(src_path):gsub("^@", ""):gsub("\\", "/")
  local tools_dir = normalized:match("^(.*)/packages/acceptance/[^/]+%.lua$")
  if tools_dir == nil then
    return "."
  end
  return tools_dir:match("^(.*)/tools$") or "."
end

local function _load_manifest()
  local path = _repo_root() .. "/features/manifest.lua"
  local probe = io.open(path, "r")
  if probe == nil then
    return {}
  end
  probe:close()

  local loaded = dofile(path)
  if type(loaded) ~= "table" then
    return {}
  end
  return loaded
end

local manifest = _load_manifest()

return {
  generated_dir = manifest.generated_dir or DEFAULT_GENERATED_DIR,
  entries = manifest.entries or {},
}
