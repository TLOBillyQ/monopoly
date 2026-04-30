local logger = require("src.foundation.log.logger")
local move_anim = require("src.ui.render.move_anim")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local support = require("support.move_anim_support")
local gameplay_rules = require("src.config.gameplay.debug_flags")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local function _test_move_anim_prefers_forced_move_stop_and_model_stop_for_local_player_units()
  local calls = {}
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function() calls[#calls + 1] = "start_move_by_direction" end,
        stop_forced_move = function() calls[#calls + 1] = "stop_forced_move" end,
        ai_command_stop_move = function() calls[#calls + 1] = "ai_command_stop_move" end,
        stop_anim = function() calls[#calls + 1] = "stop_anim" end,
        interrupt_multi_animation = function() calls[#calls + 1] = "interrupt_multi_animation" end,
        stop_play_body_anim = function() calls[#calls + 1] = "stop_play_body_anim" end,
        stop_play_upper_anim = function() calls[#calls + 1] = "stop_play_upper_anim" end,
        model_stop_animation = function() calls[#calls + 1] = "model_stop_animation" end,
      },
    },
  })

  local scheduled = nil
  _with_patches({
    { key = "Enums", value = { BuffState = { BUFF_FORBID_CONTROL = 32 } } },
  }, function()
    scheduled = support.capture_scheduled_callbacks(function()
      move_anim.play_sequence(scene, {
        player_id = 1,
        seq = 41,
        from_index = 1,
        to_index = 2,
        direction = { x = 1, y = 0, z = 0 },
      })
    end)
  end)

  _assert_eq(#scheduled, 1, "move sequence should schedule a finish callback for local-player stop fallback")
  local finish_callback = (scheduled or {})[1]
  assert(finish_callback ~= nil, "move sequence should provide a finish callback")
  finish_callback.fn()
  _assert_eq(calls[2], "stop_forced_move", "finish callback should stop forced movement before ai fallback")
  _assert_eq(calls[3], "interrupt_multi_animation", "finish callback should interrupt multi animation first")
  _assert_eq(calls[4], "stop_anim", "finish callback should stop display anim")
  _assert_eq(calls[5], "stop_play_body_anim", "finish callback should stop body anim layers")
  _assert_eq(calls[6], "stop_play_upper_anim", "finish callback should stop upper anim layers")
  _assert_eq(calls[7], "model_stop_animation", "finish callback should also stop model anim")
  _assert_eq(calls[8], nil, "finish callback should not fall through to ai stop when forced stop exists")
end

local function _test_move_anim_synthetic_actor_uses_unified_move_start_and_stop()
  local calls = {}
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = {
      [-2] = {
        start_move_by_direction = function() calls[#calls + 1] = "start_move_by_direction" end,
        stop_move = function() calls[#calls + 1] = "stop_move" end,
        ai_command_stop_move = function() calls[#calls + 1] = "ai_command_stop_move" end,
        stop_anim = function() calls[#calls + 1] = "stop_anim" end,
      },
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
        seq = 82,
        from_index = 1,
        to_index = 2,
        direction = { x = 1, y = 0, z = 0 },
      })
    end)
  end)

  _assert_eq(#scheduled, 1, "synthetic move should schedule one finish callback")
  local finish_callback = (scheduled or {})[1]
  assert(finish_callback ~= nil, "synthetic move should provide a finish callback")
  finish_callback.fn()
  _assert_eq(calls[1], "start_move_by_direction", "synthetic actor should start moving via start_move_by_direction")
  _assert_eq(calls[2], "stop_move", "synthetic actor should stop via stop_move")
  assert(calls[3] == "ai_command_stop_move" or calls[3] == "stop_anim",
    "synthetic actor should either clear host movement state or stop anim next")
  assert(calls[#calls] == "stop_anim", "synthetic actor should still stop anim")
end

local function _test_move_anim_non_synthetic_actor_uses_regular_move_start()
  local calls = {}
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = {
      [-2] = {
        start_move_by_direction = function() calls[#calls + 1] = "start_move_by_direction" end,
        stop_move = function() calls[#calls + 1] = "stop_move" end,
        stop_anim = function() calls[#calls + 1] = "stop_anim" end,
      },
    },
  })

  local scheduled = nil
  _with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return { is_synthetic_actor = false } end },
  }, function()
    scheduled = support.capture_scheduled_callbacks(function()
      move_anim.play_sequence(scene, {
        player_id = -2,
        seq = 83,
        from_index = 1,
        to_index = 2,
        direction = { x = 1, y = 0, z = 0 },
      })
    end)
  end)

  _assert_eq(#scheduled, 1, "non-synthetic move should schedule one finish callback")
  local finish_callback = (scheduled or {})[1]
  assert(finish_callback ~= nil, "non-synthetic move should provide a finish callback")
  finish_callback.fn()
  _assert_eq(calls[1], "start_move_by_direction", "non-synthetic actor should keep regular move start")
  _assert_eq(calls[2], "stop_move", "non-synthetic actor should go straight to motion stop")
  _assert_eq(calls[3], "stop_anim", "non-synthetic actor should still stop anim")
  _assert_eq(calls[4], nil, "non-synthetic actor should not add extra stop calls")
end

local function _test_move_anim_debug_log_writes_when_enabled()
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function() end,
        force_stop_move = function() end,
        stop_anim = function() end,
      },
    },
  })

  logger.clear()
  _with_patches({
    { target = gameplay_rules, key = "move_anim_debug_log_enabled", value = false },
    { target = logger, key = "anim_debug_enabled_provider", value = function() return true end },
    { target = logger, key = "info_per_turn_limit", value = 1 },
    { target = logger, key = "info_turn_provider", value = function() return 7 end },
    { target = runtime_ports, key = "schedule", value = function(_, fn) fn() end },
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

  local text = logger.get_text()
  assert(string.find(text, "[Eggy] consume per-turn info budget", 1, true) ~= nil, "regular info log should still be present")
  assert(string.find(text, "[MoveAnim] play_sequence_start", 1, true) ~= nil, "debug log should include sequence start")
  assert(string.find(text, "[MoveAnim] finish_stop", 1, true) ~= nil, "debug log should include finish stop")
end

return {
  name = "presentation.move_anim_actor_modes",
  tests = {
    { name = "local_player_prefers_forced_move_stop_and_model_stop", run = _test_move_anim_prefers_forced_move_stop_and_model_stop_for_local_player_units },
    { name = "synthetic_actor_uses_unified_move_start_and_stop", run = _test_move_anim_synthetic_actor_uses_unified_move_start_and_stop },
    { name = "non_synthetic_actor_uses_regular_move_start", run = _test_move_anim_non_synthetic_actor_uses_regular_move_start },
    { name = "move_anim_debug_log_writes_when_enabled", run = _test_move_anim_debug_log_writes_when_enabled },
  },
}
