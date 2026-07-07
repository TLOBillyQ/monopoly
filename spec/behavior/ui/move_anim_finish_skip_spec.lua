local move_anim = require("src.ui.render.move_anim")
local rt = require("src.ui.render.move_anim.runtime")
local debug_alias = require("src.ui.render.move_anim.debug")
local support = require("spec.support.move_anim_support")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local function _play_and_capture(scene)
  local scheduled = support.capture_scheduled_callbacks(function()
    move_anim.play_sequence(scene, {
      player_id = 1,
      seq = 21,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
  end)
  return scheduled
end

describe("presentation.move_anim_finish_skip", function()
  it("finish_callback_skips_stop_when_token_is_stale", function()
    local unit, calls = support.new_unit_spy()
    local scene = support.new_scene_with_linear_tiles(2, {
      units_by_player_id = { [1] = unit },
    })
    local scheduled = _play_and_capture(scene)
    _assert_eq(#scheduled, 1, "move sequence should schedule one finish callback")

    rt.set_active_token(scene, 1, "stale_token_override")
    scheduled[1].fn()
    _assert_eq(#calls, 1, "stale token should skip stop; only the initial move call remains")
    _assert_eq(calls[1], "start_move_by_direction", "initial move call should be untouched")
  end)

  it("finish_skip_logs_when_debug_enabled", function()
    local unit, _ = support.new_unit_spy()
    local scene = support.new_scene_with_linear_tiles(2, {
      units_by_player_id = { [1] = unit },
    })
    local logged = {}
    local scheduled
    _with_patches({
      { target = debug_alias, key = "enabled", value = function() return true end },
      { target = debug_alias, key = "debug_log", value = function(tag)
        logged[#logged + 1] = tag
      end },
    }, function()
      scheduled = _play_and_capture(scene)
      rt.set_active_token(scene, 1, "stale_token_override")
      scheduled[1].fn()
    end)
    local saw_skip = false
    for _, tag in ipairs(logged) do
      if tag == "finish_skip_stale_token" then saw_skip = true end
    end
    _assert_eq(saw_skip, true, "debug mode should log the stale-token finish skip")
  end)
end)
