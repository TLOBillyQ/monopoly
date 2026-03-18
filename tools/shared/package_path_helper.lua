local package_path_helper = {}

local function _normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function _join(base, child)
  local normalized_base = _normalize_path(base):gsub("/+$", "")
  local normalized_child = _normalize_path(child):gsub("^/+", "")
  if normalized_base == "" then
    return normalized_child
  end
  if normalized_child == "" then
    return normalized_base
  end
  return normalized_base .. "/" .. normalized_child
end

local function _contains_path(path_pattern)
  return tostring(package.path):find(path_pattern, 1, true) ~= nil
end

local function _prepend_path(path_pattern)
  if not _contains_path(path_pattern) then
    package.path = path_pattern .. ";" .. package.path
  end
end

local function _append_path(path_pattern)
  if not _contains_path(path_pattern) then
    package.path = package.path .. ";" .. path_pattern
  end
end

function package_path_helper.install_monopoly_package_paths(opts)
  opts = opts or {}
  local repo_root = _normalize_path(opts.repo_root or ".")
  local arch_view_root = _normalize_path(opts.arch_view_root or _join(repo_root, "vendor/arch_view"))

  local canonical_patterns = {
    _join(repo_root, "tools/?.lua"),
    _join(repo_root, "tools/?/init.lua"),
    _join(repo_root, "tools/bridge/?.lua"),
    _join(repo_root, "tools/bridge/?/init.lua"),
    _join(repo_root, "tests/?.lua"),
    _join(repo_root, "tests/?/init.lua"),
    _join(repo_root, "tests/suites/?.lua"),
    _join(repo_root, "tests/fixtures/?.lua"),
    _join(repo_root, "?.lua"),
    _join(repo_root, "?/init.lua"),
  }

  for index = #canonical_patterns, 1, -1 do
    _prepend_path(canonical_patterns[index])
  end

  local compatibility_patterns = {
    _join(arch_view_root, "?.lua"),
    _join(arch_view_root, "?/?.lua"),
  }

  for _, pattern in ipairs(compatibility_patterns) do
    _append_path(pattern)
  end
end

return package_path_helper
