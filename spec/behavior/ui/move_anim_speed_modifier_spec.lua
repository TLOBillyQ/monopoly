local move_anim = require("src.ui.render.move_anim")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local support = require("spec.support.move_anim_support")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

describe("presentation.move_anim_speed_modifier_synthetic", function()
  it("synthetic_actor_receives_speed_modifier", function()
    local modifier_key_received = nil
    local duration_received = nil

    local mock_modifier = {
      set_remain_duration = function(d)
        duration_received = d
      end,
    }

    local unit, _ = support.new_unit_spy({
      add_modifier_by_key = function(key, _opts)
        modifier_key_received = key
        return mock_modifier
      end,
    })

    local scene = support.new_scene_with_linear_tiles(3, {
      units_by_player_id = {
        [-2] = unit,
      },
    })

    local scheduled = nil
    _with_patches({
      { target = runtime_ports, key = "resolve_role", value = function(player_id)
        if player_id == -2 then
          return { is_synthetic_actor = true }
        end
        return nil
      end },
    }, function()
      scheduled = support.capture_scheduled_callbacks(function()
        move_anim.play_sequence(scene, {
          player_id = -2,
          seq = 91,
          from_index = 1,
          to_index = 3,
          direction = { x = 1, y = 0, z = 0 },
        })
      end)
    end)

    assert(#scheduled >= 1, "move sequence should schedule at least one callback")
    _assert_eq(
      modifier_key_received,
      runtime_constants.speed_boost_modifier_key,
      "add_modifier_by_key should be called with speed_boost_modifier_key (100000) for synthetic actor"
    )
    assert(duration_received ~= nil, "set_remain_duration should be called on the modifier")
    assert(duration_received > 0, "set_remain_duration should receive a positive duration")
  end)
end)
