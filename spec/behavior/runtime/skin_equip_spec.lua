local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local runtime_ports = require("src.foundation.ports.runtime_ports")
local skin_equip = require("src.rules.cosmetics.skin_equip")

describe("skin_equip runtime integration", function()
  it("applies creature key to resolved role unit", function()
    local calls = {}

    _with_patches({
      {
        target = runtime_ports,
        key = "resolve_role",
        value = function(role_id)
          _assert_eq(role_id, 11, "skin equip should resolve target role")
          return {
            get_ctrl_unit = function()
              return {
                set_model_by_creature_key = function(...)
                  calls[#calls + 1] = { ... }
                  return true
                end,
              }
            end,
          }
        end,
      },
    }, function()
      _assert_eq(skin_equip.equip(11, "skin_key"), true, "skin equip should report model change success")
    end)

    _assert_eq(#calls, 1, "skin equip should call unit model setter")
    _assert_eq(calls[1][1], "skin_key", "skin equip should pass creature key")
  end)
end)
