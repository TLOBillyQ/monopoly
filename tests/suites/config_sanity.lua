local support = require("TestSupport")
local with_patches = support.with_patches
local config_sanity = require("src.core.config.ConfigSanity")
local vehicle_catalog = require("src.core.config.VehicleCatalog")

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

return {
  name = "config_sanity",
  tests = {
    { name = "config_sanity_validate_passes_current_generated_data", run = _test_config_sanity_validate_passes_current_generated_data },
    { name = "config_sanity_fails_when_vehicle_reference_is_invalid", run = _test_config_sanity_fails_when_vehicle_reference_is_invalid },
  },
}
