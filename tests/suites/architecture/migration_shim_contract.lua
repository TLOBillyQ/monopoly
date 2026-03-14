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

return {
  name = "migration_shim_contract",
  tests = tests,
}
