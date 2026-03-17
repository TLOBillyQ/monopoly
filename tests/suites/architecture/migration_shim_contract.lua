local support = require("support.runtime_support")
local migration_pairs = require("support.migration_pairs")

local _assert_eq = support.assert_eq
local tests = {}

local function has_existing_pair(pair)
  return migration_pairs.file_exists(pair.old_path) and migration_pairs.file_exists(pair.new_path)
end

local function assert_aliases_point_to_same_module(expected, alias_modules, message_prefix)
  for _, alias in ipairs(alias_modules or {}) do
    local loaded = package.loaded[alias]
    if loaded ~= nil then
      _assert_eq(loaded, expected, message_prefix .. " package.loaded[" .. alias .. "] should match canonical module")
    end
  end
end

for _, pair in ipairs(migration_pairs.iter_pairs()) do
  if has_existing_pair(pair) then
    tests[#tests + 1] = {
      name = "compat_" .. pair.old_module:gsub("%.", "_"),
      run = function()
        package.loaded[pair.old_module] = nil
        package.loaded[pair.new_module] = nil

        local old_mod = require(pair.old_module)
        local new_mod = require(pair.new_module)
        _assert_eq(old_mod, new_mod, pair.old_module .. " should resolve to the same module as " .. pair.new_module)
        assert_aliases_point_to_same_module(new_mod, pair.alias_modules, pair.old_module)
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
