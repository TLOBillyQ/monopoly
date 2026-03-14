local package_path_helper = {}

local function _append_path(path_pattern)
  if not tostring(package.path):find(path_pattern, 1, true) then
    package.path = package.path .. ";" .. path_pattern
  end
end

function package_path_helper.install_monopoly_package_paths(opts)
  opts = opts or {}
  local arch_view_root = tostring(opts.arch_view_root or "./vendor/arch_view")

  local patterns = {
    "./?/init.lua",
    "./tests/?.lua",
    "./tests/?/init.lua",
    "./tests/suites/?.lua",
    "./tests/fixtures/?.lua",
    "./scripts/?.lua",
    "./scripts/?/?.lua",
    "./scripts/arch/?.lua",
    "./scripts/arch/?/?.lua",
    "./scripts/quality/?.lua",
    "./scripts/quality/?/?.lua",
    arch_view_root .. "/?.lua",
    arch_view_root .. "/?/?.lua",
  }

  for _, pattern in ipairs(patterns) do
    _append_path(pattern)
  end
end

return package_path_helper
