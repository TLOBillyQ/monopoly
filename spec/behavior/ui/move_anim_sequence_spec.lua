local move_anim = require("src.ui.render.move_anim")
local runtime_state = require("src.ui.state.runtime")
local anim_ports = require("src.ui.ports.anim")
local ui_view = require("src.ui.coord.ui_runtime")
local support = require("spec.support.move_anim_support")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

describe("presentation.move_anim_sequence", function()
  it("sequence_stops_unit_when_duration_finishes", function()
    local unit, calls = support.new_unit_spy()
    local scene = support.new_scene_with_linear_tiles(2, {
      units_by_player_id = { [1] = unit },
    })

    local total = nil
    local scheduled = support.capture_scheduled_callbacks(function()
      total = move_anim.play_sequence(scene, {
        player_id = 1,
        seq = 11,
        from_index = 1,
        to_index = 2,
        direction = { x = 1, y = 0, z = 0 },
      })
    end)

    assert(total and total > 0, "move sequence should report positive duration")
    _assert_eq(calls[1], "start_move_by_direction", "move sequence should start unit move immediately")
    _assert_eq(#scheduled, 1, "move sequence should schedule one explicit finish-stop callback")
    scheduled[1].fn()
    _assert_eq(calls[2], "stop_move", "finish callback should stop movement via stop_move")
    _assert_eq(calls[3], "stop_anim", "finish callback should stop looping anim")
  end)

  it("sequence_updates_follow_target_runtime", function()
    local unit, _ = support.new_unit_spy()
    local state = {}
    local scene = support.new_scene_with_linear_tiles(2, {
      units_by_player_id = { [1] = unit },
    })

    support.capture_scheduled_callbacks(function()
      move_anim.play_sequence(scene, {
        state = state,
        player_id = 1,
        seq = 91,
        from_index = 1,
        to_index = 2,
        direction = { x = 1, y = 0, z = 0 },
      })
    end)

    local pos = runtime_state.get_follow_target_position(state, 1)
    assert(pos ~= nil, "move sequence should publish follow target position")
    _assert_eq(pos.x, 10, "move sequence follow target should point at destination tile x")
  end)

  it("sequence_stale_finish_callback_does_not_stop_new_sequence", function()
    local unit, calls = support.new_unit_spy()
    local scene = support.new_scene_with_linear_tiles(3, {
      units_by_player_id = { [1] = unit },
    })

    local scheduled = support.capture_scheduled_callbacks(function()
      move_anim.play_sequence(scene, {
        player_id = 1,
        seq = 21,
        from_index = 1,
        to_index = 2,
        direction = { x = 1, y = 0, z = 0 },
      })
      move_anim.play_sequence(scene, {
        player_id = 1,
        seq = 22,
        from_index = 2,
        to_index = 3,
        direction = { x = 1, y = 0, z = 0 },
      })
    end)

    _assert_eq(#scheduled, 2, "overlapping sequences should schedule two finish callbacks")
    scheduled[0 + 1].fn()
    _assert_eq(#calls, 2, "stale finish callback should not stop the new active sequence")
    scheduled[2].fn()
    _assert_eq(calls[3], "stop_move", "active finish callback should stop movement via stop_move")
    _assert_eq(calls[4], "stop_anim", "active finish callback should stop anim")
  end)

  it("sequence_lock_lifecycle_single_step", function()
    local scene = support.new_scene_with_linear_tiles(2, {
      units_by_player_id = {
        [1] = {
          start_move_by_direction = function() end,
          stop_move = function() end,
          stop_anim = function() end,
        },
      },
    })
    local sequence_calls = {}
    local step_calls = {}

    local scheduled = support.capture_scheduled_callbacks(function()
      move_anim.play_sequence(scene, {
        player_id = 1,
        seq = 51,
        from_index = 1,
        to_index = 2,
        direction = { x = 1, y = 0, z = 0 },
        on_step_lock = function(enabled, _, meta)
          step_calls[#step_calls + 1] = tostring(enabled) .. ":" .. tostring(meta and meta.player_id)
        end,
        on_sequence_lock = function(enabled, _, meta)
          sequence_calls[#sequence_calls + 1] = tostring(enabled) .. ":" .. tostring(meta and meta.seq) .. ":" .. tostring(meta and meta.reason)
        end,
      })
    end)

    _assert_eq(sequence_calls[1], "false:51:nil", "sequence should unlock once at sequence start")
    _assert_eq(step_calls[1], "false:1", "step lock should still unlock immediately")
    _assert_eq(#scheduled, 2, "single-step move should schedule step relock and finish stop")
    scheduled[1].fn()
    _assert_eq(step_calls[2], "true:1", "step lock should relock when the step ends")
    scheduled[2].fn()
    _assert_eq(sequence_calls[2], "true:51:sequence_finished", "sequence should relock once when finish stop runs")
  end)

  it("sequence_lock_releases_previous_sequence_only_once", function()
    local scene = support.new_scene_with_linear_tiles(3, {
      units_by_player_id = {
        [1] = {
          start_move_by_direction = function() end,
          stop_move = function() end,
          stop_anim = function() end,
        },
      },
    })
    local sequence_calls = {}

    local scheduled = support.capture_scheduled_callbacks(function()
      move_anim.play_sequence(scene, {
        player_id = 1,
        seq = 61,
        from_index = 1,
        to_index = 2,
        direction = { x = 1, y = 0, z = 0 },
        on_sequence_lock = function(enabled, _, meta)
          sequence_calls[#sequence_calls + 1] = tostring(meta and meta.seq) .. ":" .. tostring(enabled) .. ":" .. tostring(meta and meta.reason)
        end,
      })
      move_anim.play_sequence(scene, {
        player_id = 1,
        seq = 62,
        from_index = 2,
        to_index = 3,
        direction = { x = 1, y = 0, z = 0 },
        on_sequence_lock = function(enabled, _, meta)
          sequence_calls[#sequence_calls + 1] = tostring(meta and meta.seq) .. ":" .. tostring(enabled) .. ":" .. tostring(meta and meta.reason)
        end,
      })
    end)

    _assert_eq(sequence_calls[1], "61:false:nil", "old sequence should unlock at start")
    _assert_eq(sequence_calls[2], "61:true:sequence_replaced", "new sequence should release the old sequence lock first")
    _assert_eq(sequence_calls[3], "62:false:nil", "new sequence should unlock after replacing the old one")
    scheduled[1].fn()
    scheduled[2].fn()
    _assert_eq(sequence_calls[4], "62:true:sequence_finished", "only the active finish callback should relock the new sequence")
    _assert_eq(sequence_calls[5], nil, "stale finish callback should not relock again")
  end)

  it("anim_ports_role_control_exempt_stays_until_sequence_finish", function()
    local state = {
      board_scene = support.new_scene_with_linear_tiles(2, {
        units_by_player_id = {
          [1] = {
            start_move_by_direction = function() end,
             stop_move = function() end,
            stop_anim = function() end,
          },
        },
      }),
      role_control_lock_exempt_by_role = {},
      role_control_lock_exempt_count_by_role = {},
      role_control_lock_active = true,
    }
    local apply_calls = {}

    local scheduled = nil
    _with_patches({
      {
        target = ui_view,
        key = "apply_role_control_lock",
        value = function(_, enabled)
          apply_calls[#apply_calls + 1] = enabled
        end,
      },
    }, function()
      scheduled = support.capture_scheduled_callbacks(function()
        anim_ports.build().play_move_anim(state, {
          player_id = 1,
          seq = 71,
          from_index = 1,
          to_index = 2,
          direction = { x = 1, y = 0, z = 0 },
        })
      end)
      _assert_eq(state.role_control_lock_exempt_by_role[1], true, "sequence start should mark the local role exempt")
      _assert_eq(state.role_control_lock_exempt_count_by_role[1], 1, "sequence start should hold one exempt count")
      _assert_eq(apply_calls[1], true, "sequence start should reapply current lock policy")
      scheduled[1].fn()
      _assert_eq(state.role_control_lock_exempt_by_role[1], true, "step relock should not clear sequence exemption")
      scheduled[2].fn()
      _assert_eq(state.role_control_lock_exempt_by_role[1], nil, "finish should clear sequence exemption")
      assert(#apply_calls >= 1, "sequence should apply lock state during lifecycle")
    end)
  end)

  it("anim_ports_role_control_exempt_rebuilds_tables_and_preserves_existing_count", function()
    local state = {
      board_scene = support.new_scene_with_linear_tiles(2, {
        units_by_player_id = {
          [1] = {
            start_move_by_direction = function() end,
            stop_move = function() end,
            stop_anim = function() end,
          },
        },
      }),
      role_control_lock_exempt_by_role = "invalid",
      role_control_lock_exempt_count_by_role = "invalid",
      role_control_lock_active = true,
    }
    local scheduled = nil

    _with_patches({
      {
        target = ui_view,
        key = "apply_role_control_lock",
        value = function() end,
      },
    }, function()
      scheduled = support.capture_scheduled_callbacks(function()
        anim_ports.build().play_move_anim(state, {
          player_id = 1,
          seq = 72,
          from_index = 1,
          to_index = 2,
          direction = { x = 1, y = 0, z = 0 },
        })
      end)

      assert(type(state.role_control_lock_exempt_by_role) == "table", "invalid exempt map should be rebuilt")
      assert(type(state.role_control_lock_exempt_count_by_role) == "table", "invalid exempt count map should be rebuilt")
      _assert_eq(state.role_control_lock_exempt_count_by_role[1], 1, "sequence start should create one count")

      state.role_control_lock_exempt_count_by_role[1] = 3
      scheduled[2].fn()

      _assert_eq(state.role_control_lock_exempt_count_by_role[1], 2, "finish should decrement existing count")
      _assert_eq(state.role_control_lock_exempt_by_role[1], true, "remaining count should keep role exempt")
    end)
  end)

  it("anim_ports_role_control_exempt_keeps_valid_existing_tables", function()
    local exempt_by_role = {}
    local exempt_counts = {}
    local state = {
      board_scene = support.new_scene_with_linear_tiles(2, {
        units_by_player_id = {
          [1] = {
            start_move_by_direction = function() end,
            stop_move = function() end,
            stop_anim = function() end,
          },
        },
      }),
      role_control_lock_exempt_by_role = exempt_by_role,
      role_control_lock_exempt_count_by_role = exempt_counts,
      role_control_lock_active = true,
    }

    _with_patches({
      {
        target = ui_view,
        key = "apply_role_control_lock",
        value = function() end,
      },
    }, function()
      support.capture_scheduled_callbacks(function()
        anim_ports.build().play_move_anim(state, {
          player_id = 1,
          seq = 73,
          from_index = 1,
          to_index = 2,
          direction = { x = 1, y = 0, z = 0 },
        })
      end)
    end)

    assert(state.role_control_lock_exempt_by_role == exempt_by_role, "valid exempt map should be reused")
    assert(state.role_control_lock_exempt_count_by_role == exempt_counts, "valid count map should be reused")
    _assert_eq(exempt_counts[1], 1, "sequence start should write into existing count map")
  end)
end)
