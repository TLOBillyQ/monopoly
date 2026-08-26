local lu = require("luaunit")
local handlers = require("src.ui.render.anim.handlers")
local board_feedback = require("src.ui.render.board_feedback.service")
local move_anim = require("src.ui.render.move_anim")
local unit_position = require("src.ui.render.support.unit_position")
local support = require("test.support.ui_action_anim_support")

local _with_patches = support.with_patches

TestMineTrigger = {}

function TestMineTrigger:test_scheduled_mine_trigger_prefers_unit_position_and_defers_snap()
  local state = support.build_min_state()
  local scheduled = {}
  local player_calls = {}
  local tile_calls = 0
  local steps = {}

  _with_patches({
    {
      target = unit_position,
      key = "read_unit_position",
      value = function()
        return { x = 1, y = 2, z = 3 }
      end,
    },
    {
      target = unit_position,
      key = "read_scene_tile_position",
      value = function()
        return { x = 9, y = 9, z = 9 }
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id, payload)
        player_calls[#player_calls + 1] = {
          cue_name = cue_name,
          player_id = player_id,
          payload = payload,
        }
      end,
    },
    {
      target = board_feedback,
      key = "play_tile_cue",
      value = function()
        tile_calls = tile_calls + 1
      end,
    },
    {
      target = move_anim,
      key = "prepare_player_for_snap",
      value = function()
        steps[#steps + 1] = "prepare"
      end,
    },
    {
      target = move_anim,
      key = "snap_player_to_index",
      value = function(_, player_id, to_index, anim, reason)
        steps[#steps + 1] = "snap"
        lu.assertEvalToTrue(player_id == 1, "scheduled mine trigger should preserve player id")
        lu.assertEvalToTrue(to_index == 7, "scheduled mine trigger should preserve destination index")
        lu.assertEvalToTrue(anim.tile_index == 3, "scheduled mine trigger should preserve animation payload")
        lu.assertEvalToTrue(reason == "play_sequence_mine_trigger", "scheduled mine trigger should keep snap reason")
        return 0.2
      end,
    },
  }, function()
    -- #550:演出时长由 anim duration 承担,mine_trigger_snap_delay_seconds 已退役
    local duration = handlers.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 3,
      to_index = 7,
      cue_name = "mine_blast",
    }, 0.1, {
      clear_overlay = function(_, kind, tile_index)
        steps[#steps + 1] = kind .. ":" .. tostring(tile_index)
      end,
      schedule = function(delay, callback)
        scheduled[#scheduled + 1] = {
          delay = delay,
          callback = callback,
        }
      end,
    })

    lu.assertEvalToTrue(duration == 0.1,
      "scheduled mine trigger should return the anim duration as the performance length")
    lu.assertEvalToTrue(#scheduled == 1, "scheduled mine trigger should enqueue exactly one delayed snap")
    lu.assertEvalToTrue(scheduled[1].delay == 0.1,
      "scheduled mine trigger should schedule the snap at the anim duration")
    lu.assertEvalToTrue(#steps == 0,
      "handler start should zero-destroy the mine overlay and defer snap work until the callback")

    scheduled[1].callback()

    -- 回调内同帧:先销毁雷,再 prepare+snap 人
    lu.assertEvalToTrue(steps[1] == "mine:3", "scheduled callback should clear the mine overlay first")
    lu.assertEvalToTrue(steps[2] == "prepare", "scheduled callback should prepare after clearing the mine")
    lu.assertEvalToTrue(steps[3] == "snap", "scheduled callback should snap after clearing the mine")
    lu.assertEvalToTrue(steps[4] == nil, "scheduled callback should run clear+snap exactly once")
  end)

  lu.assertEvalToTrue(#player_calls == 1, "scheduled mine trigger should emit one player cue when unit position exists")
  lu.assertEvalToTrue(player_calls[1].cue_name == "mine_blast", "scheduled mine trigger should preserve cue name")
  lu.assertEvalToTrue(player_calls[1].player_id == 1, "scheduled mine trigger should preserve player id in cue")
  lu.assertEvalToTrue(player_calls[1].payload.pos.x == 1, "scheduled mine trigger should prefer unit position over tile position")
  lu.assertEvalToTrue(tile_calls == 0, "scheduled mine trigger should not fall back to tile cue when unit position exists")
end

function TestMineTrigger:test_mine_trigger_falls_back_to_tile_position_for_player_cue()
  local state = support.build_min_state()
  local player_calls = {}
  local tile_calls = 0

  _with_patches({
    {
      target = unit_position,
      key = "read_unit_position",
      value = function()
        return nil
      end,
    },
    {
      target = unit_position,
      key = "read_scene_tile_position",
      value = function()
        return { x = 4, y = 5, z = 6 }
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id, payload)
        player_calls[#player_calls + 1] = {
          cue_name = cue_name,
          player_id = player_id,
          payload = payload,
        }
      end,
    },
    {
      target = board_feedback,
      key = "play_tile_cue",
      value = function()
        tile_calls = tile_calls + 1
      end,
    },
    {
      target = move_anim,
      key = "prepare_player_for_snap",
      value = function() end,
    },
    {
      target = move_anim,
      key = "snap_player_to_index",
      value = function()
        return 0
      end,
    },
  }, function()
    handlers.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 3,
      to_index = 7,
    }, 0, {
      clear_overlay = function() end,
    })
  end)

  lu.assertEvalToTrue(#player_calls == 1, "mine trigger should keep player cue when tile position fallback exists")
  lu.assertEvalToTrue(player_calls[1].cue_name == "mine_blast", "mine trigger should use default cue name")
  lu.assertEvalToTrue(player_calls[1].player_id == 1, "mine trigger should preserve player id for fallback cue")
  lu.assertEvalToTrue(player_calls[1].payload.pos.x == 4, "mine trigger should fall back to tile position when unit position is missing")
  lu.assertEvalToTrue(tile_calls == 0, "mine trigger should avoid tile cue when tile position fallback exists")
end

function TestMineTrigger:test_mine_trigger_without_any_position_uses_tile_cue_and_normalizes_duration()
  local state = support.build_min_state()
  local steps = {}

  _with_patches({
    {
      target = unit_position,
      key = "read_unit_position",
      value = function()
        return nil
      end,
    },
    {
      target = unit_position,
      key = "read_scene_tile_position",
      value = function()
        return nil
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function()
        steps[#steps + 1] = "player_cue"
      end,
    },
    {
      target = board_feedback,
      key = "play_tile_cue",
      value = function(_, cue_name, tile_index)
        steps[#steps + 1] = cue_name .. ":" .. tostring(tile_index)
      end,
    },
    {
      target = move_anim,
      key = "prepare_player_for_snap",
      value = function()
        steps[#steps + 1] = "prepare"
      end,
    },
    {
      target = move_anim,
      key = "snap_player_to_index",
      value = function()
        steps[#steps + 1] = "snap"
        return -1
      end,
    },
  }, function()
    local duration = handlers.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 5,
      to_index = 7,
    }, 0.2, {
      clear_overlay = function(_, kind, tile_index)
        steps[#steps + 1] = kind .. ":" .. tostring(tile_index)
      end,
    })

    lu.assertEvalToTrue(duration == 0.2, "mine trigger should clamp negative snap delay to the provided minimum duration")
  end)

  -- #550:无调度器兜底与回调同序——反馈立即播,销毁雷先于瞬移人(同帧)
  lu.assertEvalToTrue(steps[1] == "mine_blast:5", "mine trigger should emit tile cue when no hit position exists")
  lu.assertEvalToTrue(steps[2] == "mine:5", "mine trigger should clear the mine overlay before snapping")
  lu.assertEvalToTrue(steps[3] == "prepare", "mine trigger should prepare the player after clearing the mine")
  lu.assertEvalToTrue(steps[4] == "snap", "mine trigger should snap after clearing the mine")
  lu.assertEvalToTrue(steps[5] == nil, "mine trigger should not emit player cue when no hit position exists")
end

function TestMineTrigger:test_mine_trigger_normalizes_negative_duration_without_scheduler()
  local state = support.build_min_state()

  _with_patches({
    {
      target = unit_position,
      key = "read_unit_position",
      value = function()
        return nil
      end,
    },
    {
      target = unit_position,
      key = "read_scene_tile_position",
      value = function()
        return nil
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function() end,
    },
    {
      target = board_feedback,
      key = "play_tile_cue",
      value = function() end,
    },
    {
      target = move_anim,
      key = "prepare_player_for_snap",
      value = function() end,
    },
    {
      target = move_anim,
      key = "snap_player_to_index",
      value = function()
        return -1
      end,
    },
  }, function()
    local duration = handlers.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 5,
      to_index = 7,
    }, -0.5, {
      clear_overlay = function() end,
    })

    lu.assertEvalToTrue(duration == 0, "mine trigger should normalize negative minimum duration to zero")
  end)
end


return TestMineTrigger
