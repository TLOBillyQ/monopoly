local handlers = require("src.ui.render.anim.handlers")
local board_feedback = require("src.ui.render.board_feedback.service")
local move_anim = require("src.ui.render.move_anim")
local unit_position = require("src.ui.render.unit_position")
local timing = require("src.config.gameplay.timing")
local support = require("spec.support.ui_action_anim_support")

local _with_patches = support.with_patches

describe("mine_trigger_crap_coverage", function()
  it("scheduled mine trigger prefers unit position and defers snap", function()
    local state = support.build_min_state()
    local scheduled = {}
    local player_calls = {}
    local tile_calls = 0
    local clear_calls = {}
    local snap_calls = 0

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
          snap_calls = snap_calls + 100
        end,
      },
      {
        target = move_anim,
        key = "snap_player_to_index",
        value = function(_, player_id, to_index, anim, reason)
          snap_calls = snap_calls + 1
          assert(player_id == 1, "scheduled mine trigger should preserve player id")
          assert(to_index == 7, "scheduled mine trigger should preserve destination index")
          assert(anim.tile_index == 3, "scheduled mine trigger should preserve animation payload")
          assert(reason == "play_sequence_mine_trigger", "scheduled mine trigger should keep snap reason")
          return 0.2
        end,
      },
    }, function()
      local duration = handlers.play_mine_trigger(state, {
        player_id = 1,
        tile_index = 3,
        to_index = 7,
        cue_name = "mine_blast",
      }, 0.1, {
        clear_overlay = function(_, kind, tile_index)
          clear_calls[#clear_calls + 1] = kind .. ":" .. tostring(tile_index)
        end,
        schedule = function(delay, callback)
          scheduled[#scheduled + 1] = {
            delay = delay,
            callback = callback,
          }
        end,
      })

      assert(duration == timing.mine_trigger_snap_delay_seconds,
        "scheduled mine trigger should return scheduler snap delay when above minimum duration")
      assert(#scheduled == 1, "scheduled mine trigger should enqueue exactly one delayed snap")
      assert(scheduled[1].delay == timing.mine_trigger_snap_delay_seconds,
        "scheduled mine trigger should use configured snap delay")
      assert(snap_calls == 0, "scheduled mine trigger should defer snap work until scheduled callback runs")

      scheduled[1].callback()

      assert(snap_calls == 101, "scheduled mine trigger callback should prepare and snap exactly once")
    end)

    assert(#player_calls == 1, "scheduled mine trigger should emit one player cue when unit position exists")
    assert(player_calls[1].cue_name == "mine_blast", "scheduled mine trigger should preserve cue name")
    assert(player_calls[1].player_id == 1, "scheduled mine trigger should preserve player id in cue")
    assert(player_calls[1].payload.pos.x == 1, "scheduled mine trigger should prefer unit position over tile position")
    assert(tile_calls == 0, "scheduled mine trigger should not fall back to tile cue when unit position exists")
    assert(clear_calls[1] == "mine:3", "scheduled mine trigger should clear mine overlay immediately")
  end)

  it("mine trigger falls back to tile position for player cue", function()
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

    assert(#player_calls == 1, "mine trigger should keep player cue when tile position fallback exists")
    assert(player_calls[1].cue_name == "mine_blast", "mine trigger should use default cue name")
    assert(player_calls[1].player_id == 1, "mine trigger should preserve player id for fallback cue")
    assert(player_calls[1].payload.pos.x == 4, "mine trigger should fall back to tile position when unit position is missing")
    assert(tile_calls == 0, "mine trigger should avoid tile cue when tile position fallback exists")
  end)

  it("mine trigger without any position uses tile cue and normalizes duration", function()
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

      assert(duration == 0.2, "mine trigger should clamp negative snap delay to the provided minimum duration")
    end)

    assert(steps[1] == "prepare", "mine trigger should prepare the player before fallback feedback without scheduler")
    assert(steps[2] == "mine_blast:5", "mine trigger should emit tile cue when no hit position exists")
    assert(steps[3] == "mine:5", "mine trigger should clear mine overlay after fallback feedback")
    assert(steps[4] == "snap", "mine trigger should snap after fallback feedback")
    assert(steps[5] == nil, "mine trigger should not emit player cue when no hit position exists")
  end)

  it("mine trigger normalizes negative duration without scheduler", function()
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

      assert(duration == 0, "mine trigger should normalize negative minimum duration to zero")
    end)
  end)
end)
