local support = require("support.runtime_support")
local migration_pairs = require("support.migration_pairs")

local _assert_eq = support.assert_eq
local tests = {}

for _, pair in ipairs(migration_pairs.iter_pairs()) do
  if migration_pairs.file_exists(pair.old_path) and migration_pairs.file_exists(pair.new_path) then
    tests[#tests + 1] = {
      name = "compat_" .. pair.old_module:gsub("%.", "_"),
      run = function()
        local old_mod = require(pair.old_module)
        local new_mod = require(pair.new_module)
        _assert_eq(old_mod, new_mod, pair.old_module .. " should resolve to the same module as " .. pair.new_module)
      end,
    }
  end
end

local retired_require_cases = {
  "Config.generated.market",
  "src.core.config.gameplay_rules",
}

local function _assert_retired_require_fails(module_name)
  local previous = package.loaded[module_name]
  package.loaded[module_name] = nil
  local ok = pcall(require, module_name)
  package.loaded[module_name] = previous
  assert(ok == false, module_name .. " should fail to require after retirement")
end

for _, module_name in ipairs(retired_require_cases) do
  tests[#tests + 1] = {
    name = "retired_" .. module_name:gsub("%.", "_") .. "_must_not_resolve",
    run = function()
      _assert_retired_require_fails(module_name)
    end,
  }
end

return {
  name = "migration_shim_contract",
  tests = tests,
}
