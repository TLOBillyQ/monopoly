local support = require("support.presentation_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local logger = require("src.core.utils.logger")
local gameplay_rules = require("src.core.config.gameplay_rules")
local move_anim = require("src.presentation.view.render.move_anim")
local runtime_ports = require("src.core.ports.runtime_ports")
local anim_ports = require("src.presentation.runtime.ports.anim_ports")
local ui_view = require("src.presentation.runtime.view")
local vec3 = require("fixtures.vec3")

local function _test_move_anim_sequence_stops_unit_when_duration_finishes()
  local _vec3 = vec3.with_sub_length
  local scheduled = {}
  local calls = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function()
          calls[#calls + 1] = "start_move_by_direction"
        end,
        force_stop_move = function()
          calls[#calls + 1] = "force_stop_move"
        end,
        stop_anim = function()
          calls[#calls + 1] = "stop_anim"
        end,
      },
    },
  }

  local total = nil
  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
  }, function()
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
  _assert_eq(calls[2], "force_stop_move", "finish callback should stop movement")
  _assert_eq(calls[3], "stop_anim", "finish callback should stop looping anim")
end

local function _test_move_anim_stale_finish_callback_does_not_stop_new_sequence()
  local _vec3 = vec3.with_sub_length
  local scheduled = {}
  local calls = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
      [3] = { get_position = function() return _vec3(20, 0, 0) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function()
          calls[#calls + 1] = "start_move_by_direction"
        end,
        force_stop_move = function()
          calls[#calls + 1] = "force_stop_move"
        end,
        stop_anim = function()
          calls[#calls + 1] = "stop_anim"
        end,
      },
    },
  }

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
  }, function()
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
  scheduled[1].fn()
  _assert_eq(#calls, 2, "stale finish callback should not stop the new active sequence")
  scheduled[2].fn()
  _assert_eq(calls[3], "force_stop_move", "active finish callback should stop movement")
  _assert_eq(calls[4], "stop_anim", "active finish callback should stop anim")
end

local function _test_move_anim_sequence_lock_lifecycle_single_step()
  local _vec3 = vec3.with_sub_length
  local scheduled = {}
  local sequence_calls = {}
  local step_calls = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function() end,
        force_stop_move = function() end,
        stop_anim = function() end,
      },
    },
  }

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
  }, function()
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
  _assert_eq(sequence_calls[2], nil, "sequence lock should not relock at step end")
  scheduled[2].fn()
  _assert_eq(sequence_calls[2], "true:51:sequence_finished", "sequence should relock once when finish stop runs")
  _assert_eq(sequence_calls[3], nil, "sequence relock should only run once")
end

local function _test_move_anim_sequence_lock_releases_previous_sequence_only_once()
  local _vec3 = vec3.with_sub_length
  local scheduled = {}
  local sequence_calls = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
      [3] = { get_position = function() return _vec3(20, 0, 0) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function() end,
        force_stop_move = function() end,
        stop_anim = function() end,
      },
    },
  }

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
  }, function()
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
end

local function _test_move_anim_prefers_forced_move_stop_and_model_stop_for_local_player_units()
  local _vec3 = vec3.with_sub_length
  local scheduled = {}
  local calls = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function()
          calls[#calls + 1] = "start_move_by_direction"
        end,
        stop_forced_move = function()
          calls[#calls + 1] = "stop_forced_move"
        end,
        ai_command_stop_move = function()
          calls[#calls + 1] = "ai_command_stop_move"
        end,
        stop_anim = function()
          calls[#calls + 1] = "stop_anim"
        end,
        interrupt_multi_animation = function()
          calls[#calls + 1] = "interrupt_multi_animation"
        end,
        stop_play_body_anim = function()
          calls[#calls + 1] = "stop_play_body_anim"
        end,
        stop_play_upper_anim = function()
          calls[#calls + 1] = "stop_play_upper_anim"
        end,
        model_stop_animation = function()
          calls[#calls + 1] = "model_stop_animation"
        end,
      },
    },
  }

  _with_patches({
    { key = "Enums", value = { BuffState = { BUFF_FORBID_CONTROL = 32 } } },
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = 1,
      seq = 41,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
  end)

  _assert_eq(#scheduled, 1, "move sequence should schedule a finish callback for local-player stop fallback")
  scheduled[1].fn()
  _assert_eq(calls[2], "stop_forced_move", "finish callback should stop forced movement before ai fallback")
  _assert_eq(calls[3], "interrupt_multi_animation", "finish callback should interrupt multi animation first")
  _assert_eq(calls[4], "stop_anim", "finish callback should stop display anim")
  _assert_eq(calls[5], "stop_play_body_anim", "finish callback should stop body anim layers")
  _assert_eq(calls[6], "stop_play_upper_anim", "finish callback should stop upper anim layers")
  _assert_eq(calls[7], "model_stop_animation", "finish callback should also stop model anim")
  _assert_eq(calls[8], nil, "finish callback should not fall through to ai stop when forced stop exists")
end

local function _test_move_anim_synthetic_actor_stops_ai_before_motion_stop()
  local _vec3 = vec3.with_sub_length
  local scheduled = {}
  local calls = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = {
      [-2] = {
        start_move_by_direction = function()
          calls[#calls + 1] = "start_move_by_direction"
        end,
        stop_ai = function()
          calls[#calls + 1] = "stop_ai"
        end,
        force_stop_move = function()
          calls[#calls + 1] = "force_stop_move"
        end,
        stop_anim = function()
          calls[#calls + 1] = "stop_anim"
        end,
      },
    },
  }

  _with_patches({
    { target = runtime_ports, key = "resolve_role", value = function(player_id)
      if player_id == -2 then
        return { is_synthetic_actor = true }
      end
      return nil
    end },
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = -2,
      seq = 82,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
    _assert_eq(#scheduled, 1, "synthetic move should schedule one finish callback")
    scheduled[1].fn()
    _assert_eq(calls[2], "stop_ai", "synthetic actor should stop ai before motion stop")
    _assert_eq(calls[3], "force_stop_move", "synthetic actor should still stop motion")
    _assert_eq(calls[4], "stop_anim", "synthetic actor should still stop anim")
    _assert_eq(move_anim.peek_pending_synthetic_ai_stop(scene, -2), true,
      "synthetic finish should leave a pending board-sync ai stop marker")
  end)
end

local function _test_move_anim_non_synthetic_actor_does_not_stop_ai()
  local _vec3 = vec3.with_sub_length
  local scheduled = {}
  local calls = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = {
      [-2] = {
        start_move_by_direction = function()
          calls[#calls + 1] = "start_move_by_direction"
        end,
        stop_ai = function()
          calls[#calls + 1] = "stop_ai"
        end,
        force_stop_move = function()
          calls[#calls + 1] = "force_stop_move"
        end,
        stop_anim = function()
          calls[#calls + 1] = "stop_anim"
        end,
      },
    },
  }

  _with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return { is_synthetic_actor = false } end },
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = -2,
      seq = 83,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
    _assert_eq(#scheduled, 1, "non-synthetic move should schedule one finish callback")
    scheduled[1].fn()
    _assert_eq(calls[2], "force_stop_move", "non-synthetic actor should go straight to motion stop")
    _assert_eq(calls[3], "stop_anim", "non-synthetic actor should still stop anim")
    _assert_eq(calls[4], nil, "non-synthetic actor should not call stop_ai")
    _assert_eq(move_anim.peek_pending_synthetic_ai_stop(scene, -2), false,
      "non-synthetic finish should not mark pending board-sync ai stop")
  end)
end

local function _test_move_anim_synthetic_stop_ai_failure_falls_through_to_motion_stop()
  local _vec3 = vec3.with_sub_length
  local scheduled = {}
  local calls = {}
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = {
      [-2] = {
        start_move_by_direction = function()
          calls[#calls + 1] = "start_move_by_direction"
        end,
        stop_ai = function()
          calls[#calls + 1] = "stop_ai"
          error("stop_ai_failed")
        end,
        force_stop_move = function()
          calls[#calls + 1] = "force_stop_move"
        end,
        stop_anim = function()
          calls[#calls + 1] = "stop_anim"
        end,
      },
    },
  }

  _with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return { is_synthetic_actor = true } end },
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
  }, function()
    move_anim.play_sequence(scene, {
      player_id = -2,
      seq = 84,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
    local ok, err = pcall(scheduled[1].fn)
    assert(ok == true, tostring(err))
    _assert_eq(calls[2], "stop_ai", "synthetic actor should still attempt stop_ai first")
    _assert_eq(calls[3], "force_stop_move", "stop_ai failure should not block motion stop")
    _assert_eq(calls[4], "stop_anim", "stop_ai failure should not block anim stop")
    _assert_eq(move_anim.peek_pending_synthetic_ai_stop(scene, -2), true,
      "stop_ai failure should still leave a pending board-sync ai stop marker")
  end)
end

local function _test_anim_ports_role_control_exempt_stays_until_sequence_finish()
  local _vec3 = vec3.with_sub_length
  local scheduled = {}
  local apply_calls = {}
  local state = {
    board_scene = {
      tiles = {
        [1] = { get_position = function() return _vec3(0, 0, 0) end },
        [2] = { get_position = function() return _vec3(10, 0, 0) end },
      },
      units_by_player_id = {
        [1] = {
          start_move_by_direction = function() end,
          force_stop_move = function() end,
          stop_anim = function() end,
        },
      },
    },
    role_control_lock_exempt_by_role = {},
    role_control_lock_exempt_count_by_role = {},
    role_control_lock_active = true,
  }

  _with_patches({
    { target = runtime_ports, key = "schedule", value = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end },
    { target = ui_view, key = "apply_role_control_lock", value = function(_, enabled)
      apply_calls[#apply_calls + 1] = enabled
    end },
  }, function()
    anim_ports.build().play_move_anim(state, {
      player_id = 1,
      seq = 71,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
    _assert_eq(state.role_control_lock_exempt_by_role[1], true, "sequence start should mark the local role exempt")
    _assert_eq(state.role_control_lock_exempt_count_by_role[1], 1, "sequence start should hold one exempt count")
    _assert_eq(apply_calls[1], true, "sequence start should reapply current lock policy")
    scheduled[1].fn()
    _assert_eq(state.role_control_lock_exempt_by_role[1], true, "step relock should not clear sequence exemption")
    _assert_eq(state.role_control_lock_exempt_count_by_role[1], 1, "step relock should not decrement sequence exemption")
    scheduled[2].fn()
    _assert_eq(state.role_control_lock_exempt_by_role[1], nil, "finish should clear sequence exemption")
    _assert_eq(state.role_control_lock_exempt_count_by_role[1], nil, "finish should release the exempt count")
    _assert_eq(apply_calls[2], true, "finish should reapply current lock policy after exemption release")
  end)
end

local function _test_move_anim_debug_log_writes_when_enabled()
  local _vec3 = vec3.with_sub_length
  local scene = {
    tiles = {
      [1] = { get_position = function() return _vec3(0, 0, 0) end },
      [2] = { get_position = function() return _vec3(10, 0, 0) end },
    },
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function() end,
        force_stop_move = function() end,
        stop_anim = function() end,
      },
    },
  }

  logger.clear()
  _with_patches({
    { target = gameplay_rules, key = "move_anim_debug_log_enabled", value = false },
    { target = logger, key = "anim_debug_enabled_provider", value = function() return true end },
    { target = logger, key = "info_per_turn_limit", value = 1 },
    { target = logger, key = "info_turn_provider", value = function() return 7 end },
    { target = runtime_ports, key = "schedule", value = function(_, fn)
      fn()
    end },
  }, function()
    logger.info("[Eggy]", "consume per-turn info budget")
    move_anim.play_sequence(scene, {
      player_id = 1,
      seq = 31,
      from_index = 1,
      to_index = 2,
      direction = { x = 1, y = 0, z = 0 },
    })
  end)

  local text = logger.get_text_by_level("info")
  assert(string.find(text, "[Eggy] consume per-turn info budget", 1, true) ~= nil, "regular info log should still be present")
  assert(string.find(text, "[MoveAnim] play_sequence_start", 1, true) ~= nil, "debug log should include sequence start")
  assert(string.find(text, "[MoveAnim] finish_stop", 1, true) ~= nil, "debug log should include finish stop")
end

return {
  name = "presentation.move_anim",
  tests = {
    {
      name = "_test_move_anim_sequence_stops_unit_when_duration_finishes",
      run = _test_move_anim_sequence_stops_unit_when_duration_finishes,
    },
    {
      name = "_test_move_anim_stale_finish_callback_does_not_stop_new_sequence",
      run = _test_move_anim_stale_finish_callback_does_not_stop_new_sequence,
    },
    {
      name = "_test_move_anim_sequence_lock_lifecycle_single_step",
      run = _test_move_anim_sequence_lock_lifecycle_single_step,
    },
    {
      name = "_test_move_anim_sequence_lock_releases_previous_sequence_only_once",
      run = _test_move_anim_sequence_lock_releases_previous_sequence_only_once,
    },
    {
      name = "_test_move_anim_prefers_forced_move_stop_and_model_stop_for_local_player_units",
      run = _test_move_anim_prefers_forced_move_stop_and_model_stop_for_local_player_units,
    },
    {
      name = "_test_anim_ports_role_control_exempt_stays_until_sequence_finish",
      run = _test_anim_ports_role_control_exempt_stays_until_sequence_finish,
    },
    {
      name = "_test_move_anim_synthetic_actor_stops_ai_before_motion_stop",
      run = _test_move_anim_synthetic_actor_stops_ai_before_motion_stop,
    },
    {
      name = "_test_move_anim_non_synthetic_actor_does_not_stop_ai",
      run = _test_move_anim_non_synthetic_actor_does_not_stop_ai,
    },
    {
      name = "_test_move_anim_synthetic_stop_ai_failure_falls_through_to_motion_stop",
      run = _test_move_anim_synthetic_stop_ai_failure_falls_through_to_motion_stop,
    },
    {
      name = "_test_move_anim_debug_log_writes_when_enabled",
      run = _test_move_anim_debug_log_writes_when_enabled,
    },
  },
}
