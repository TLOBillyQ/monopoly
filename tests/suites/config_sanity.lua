local support = require("TestSupport")
local with_patches = support.with_patches
local config_sanity = require("src.core.config.ConfigSanity")
local vehicle_catalog = require("src.core.config.VehicleCatalog")
local market_cfg = require("Config.Generated.Market")
local chance_cfg = require("Config.Generated.ChanceCards")

local function _test_config_sanity_validate_passes_current_generated_data()
  config_sanity.reset_for_tests()
  assert(config_sanity.validate() == true, "current generated config should pass sanity checks")
end

local function _test_config_sanity_fails_when_vehicle_reference_is_invalid()
  config_sanity.reset_for_tests()
  with_patches({
    {
      target = vehicle_catalog,
      key = "has",
      value = function(id)
        if id == 4001 then
          return false
        end
        return true
      end,
    },
  }, function()
    local ok, err = pcall(config_sanity.validate)
    assert(ok == false, "sanity validate should fail on invalid vehicle reference")
    assert(
      tostring(err):find("unknown vehicle", 1, true) ~= nil,
      "sanity error should include unknown vehicle hint"
    )
  end)
end

local function _replace_table_rows(target, rows)
  for i = #target, 1, -1 do
    target[i] = nil
  end
  for i, row in ipairs(rows or {}) do
    target[i] = row
  end
end

local function _with_release_tables(chance_rows, market_rows, fn)
  local chance_backup = {}
  local market_backup = {}
  for i, row in ipairs(chance_cfg) do
    chance_backup[i] = row
  end
  for i, row in ipairs(market_cfg) do
    market_backup[i] = row
  end

  local function restore()
    _replace_table_rows(chance_cfg, chance_backup)
    _replace_table_rows(market_cfg, market_backup)
  end

  _replace_table_rows(chance_cfg, chance_rows)
  _replace_table_rows(market_cfg, market_rows)
  local ok, err = pcall(fn)
  restore()
  if not ok then
    error(err)
  end
end

local function _test_config_sanity_release_fails_when_vehicle_market_entry_exists()
  config_sanity.reset_for_tests()
  with_patches({ { key = "RELEASE_BUILD", value = true } }, function()
    _with_release_tables({}, {
      { product_id = 4999, kind = "vehicle" },
    }, function()
      local ok, err = pcall(config_sanity.validate)
      assert(ok == false, "release sanity validate should fail when vehicle market entry exists")
      assert(
        tostring(err):find("must not include vehicle market entries", 1, true) ~= nil,
        "release sanity error should include vehicle market hint"
      )
    end)
  end)
end

local function _test_config_sanity_release_fails_when_set_vehicle_card_exists()
  config_sanity.reset_for_tests()
  with_patches({ { key = "RELEASE_BUILD", value = true } }, function()
    _with_release_tables({
      {
        id = 8888,
        effect = "set_vehicle",
        vehicle_id = 4999,
      },
    }, {}, function()
      local ok, err = pcall(config_sanity.validate)
      assert(ok == false, "release sanity validate should fail when set_vehicle chance exists")
      assert(
        tostring(err):find("must not include chance set_vehicle cards", 1, true) ~= nil,
        "release sanity error should include set_vehicle hint"
      )
    end)
  end)
end

return {
  name = "config_sanity",
  tests = {
    { name = "config_sanity_validate_passes_current_generated_data", run = _test_config_sanity_validate_passes_current_generated_data },
    { name = "config_sanity_fails_when_vehicle_reference_is_invalid", run = _test_config_sanity_fails_when_vehicle_reference_is_invalid },
    {
      name = "config_sanity_release_fails_when_vehicle_market_entry_exists",
      run = _test_config_sanity_release_fails_when_vehicle_market_entry_exists,
    },
    {
      name = "config_sanity_release_fails_when_set_vehicle_card_exists",
      run = _test_config_sanity_release_fails_when_set_vehicle_card_exists,
    },
  },
}
