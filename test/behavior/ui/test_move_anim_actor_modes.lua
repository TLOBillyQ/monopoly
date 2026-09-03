--- 原生 LuaUnit 迁移(busted → luaunit):describe 拍平为文件级 Test* 类,
--- 断言词汇切到 lu.assertXxx,用例数与改写前一一对应(5 例)。
local lu = require("luaunit")

local logger = require("src.foundation.log")
local move_anim = require("src.ui.render.move_anim")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local support = require("test.support.move_anim_support")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local function _capture_print(fn)
  local captured = {}
  local original_print = _G.print
  rawset(_G, "print", function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[#parts + 1] = tostring(select(i, ...))
    end
    captured[#captured + 1] = table.concat(parts, " ")
  end)
  local ok, err = pcall(fn)
  rawset(_G, "print", original_print)
  if not ok then
    error(err)
  end
  return table.concat(captured, "\n")
end

TestMoveAnimActorModes = {}

function TestMoveAnimActorModes:test_local_player_prefers_forced_move_stop_and_model_stop()
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
  lu.assertEvalToTrue(finish_callback ~= nil, "move sequence should provide a finish callback")
  finish_callback.fn()
  _assert_eq(calls[2], "stop_forced_move", "finish callback should stop forced movement before ai fallback")
  _assert_eq(calls[3], "interrupt_multi_animation", "finish callback should interrupt multi animation first")
  _assert_eq(calls[4], "stop_anim", "finish callback should stop display anim")
  _assert_eq(calls[5], "stop_play_body_anim", "finish callback should stop body anim layers")
  _assert_eq(calls[6], "stop_play_upper_anim", "finish callback should stop upper anim layers")
  _assert_eq(calls[7], "model_stop_animation", "finish callback should also stop model anim")
  _assert_eq(calls[8], nil, "finish callback should not fall through to ai stop when forced stop exists")
end

function TestMoveAnimActorModes:test_synthetic_actor_uses_unified_move_start_and_stop()
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
    { target = runtime_ports, key = "is_synthetic_player", value = function(player_id)
      return player_id == -2
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
  lu.assertEvalToTrue(finish_callback ~= nil, "synthetic move should provide a finish callback")
  finish_callback.fn()
  _assert_eq(calls[1], "start_move_by_direction", "synthetic actor should start moving via start_move_by_direction")
  _assert_eq(calls[2], "stop_move", "synthetic actor should stop via stop_move")
  lu.assertEvalToTrue(calls[3] == "ai_command_stop_move" or calls[3] == "stop_anim",
    "synthetic actor should either clear host movement state or stop anim next")
  lu.assertEvalToTrue(calls[#calls] == "stop_anim", "synthetic actor should still stop anim")
end

function TestMoveAnimActorModes:test_non_synthetic_actor_uses_regular_move_start()
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
    { target = runtime_ports, key = "is_synthetic_player", value = function() return false end },
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
  lu.assertEvalToTrue(finish_callback ~= nil, "non-synthetic move should provide a finish callback")
  finish_callback.fn()
  _assert_eq(calls[1], "start_move_by_direction", "non-synthetic actor should keep regular move start")
  _assert_eq(calls[2], "stop_move", "non-synthetic actor should go straight to motion stop")
  _assert_eq(calls[3], "stop_anim", "non-synthetic actor should still stop anim")
  _assert_eq(calls[4], nil, "non-synthetic actor should not add extra stop calls")
end

function TestMoveAnimActorModes:test_move_anim_debug_log_writes_when_enabled()
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function() end,
        force_stop_move = function() end,
        stop_anim = function() end,
      },
    },
  })

  local text = _capture_print(function()
    _with_patches({
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
  end)

  lu.assertEvalToTrue(string.find(text, "[Eggy] consume per-turn info budget", 1, true) ~= nil, "regular info log should still be present")
  lu.assertEvalToTrue(string.find(text, "[MoveAnim] play_sequence_start", 1, true) ~= nil, "debug log should include sequence start")
  lu.assertEvalToTrue(string.find(text, "step_execute player_id=1 seq=31", 1, true) ~= nil, "debug log should include step execute seq")
  lu.assertEvalToTrue(string.find(text, "[MoveAnim] finish_stop", 1, true) ~= nil, "debug log should include finish stop")
end

function TestMoveAnimActorModes:test_move_anim_debug_step_execute_logs_nil_seq_when_missing()
  local scene = support.new_scene_with_linear_tiles(2, {
    units_by_player_id = {
      [1] = {
        start_move_by_direction = function() end,
        force_stop_move = function() end,
        stop_anim = function() end,
      },
    },
  })

  local text = _capture_print(function()
    _with_patches({
      { target = logger, key = "anim_debug_enabled_provider", value = function() return true end },
      { target = logger, key = "info_per_turn_limit", value = 1 },
      { target = logger, key = "info_turn_provider", value = function() return 7 end },
      { target = runtime_ports, key = "schedule", value = function(_, fn) fn() end },
    }, function()
      move_anim.play_sequence(scene, {
        player_id = 1,
        from_index = 1,
        to_index = 2,
        direction = { x = 1, y = 0, z = 0 },
      })
    end)
  end)

  lu.assertEvalToTrue(string.find(text, "step_execute player_id=1 seq=nil", 1, true) ~= nil,
    "debug log should render missing step seq as nil")
end


return TestMoveAnimActorModes
