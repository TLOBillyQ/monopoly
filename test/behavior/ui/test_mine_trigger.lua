-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
local handlers = require("src.ui.render.anim.handlers")
local board_feedback = require("src.ui.render.board_feedback.service")
local host_sfx = require("src.ui.seams.host_sfx")
local runtime_refs = require("src.config.content.runtime_refs")
local move_anim = require("src.ui.render.move_anim")
local unit_position = require("src.ui.render.support.unit_position")
local support = require("test.support.ui_action_anim_support")

local _with_patches = support.with_patches

describe("TestMineTrigger", function()

  it("test_scheduled_mine_trigger_prefers_unit_position_and_defers_snap", function()
    local state = support.build_min_state()
    local scheduled = {}
    local effect_calls = {}
    local sound_calls = {}
    local steps = {}
    state.board_scene.units_by_player_id[1] = {
      get_position = function()
        return math.Vector3(1.0, 2.0, 3.0)
      end,
    }
    state.board_scene.tiles[3] = {
      get_position = function()
        return math.Vector3(9.0, 9.0, 9.0)
      end,
    }

    _with_patches({
      {
        target = host_sfx,
        key = "play_sfx_by_key",
        value = function(sfx_key, pos, _rot, _scale, _duration, _rate, _with_sound, opts)
          effect_calls[#effect_calls + 1] = {
            sfx_key = sfx_key,
            pos = pos,
            cue_name = opts and opts.cue_name or nil,
          }
          return 901
        end,
      },
      {
        target = host_sfx,
        key = "play_3d_sound",
        value = function(pos, sound_id)
          sound_calls[#sound_calls + 1] = { pos = pos, sound_id = sound_id }
          return 902
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
          luassert.truthy(player_id == 1, "scheduled mine trigger should preserve player id")
          luassert.truthy(to_index == 7, "scheduled mine trigger should preserve destination index")
          luassert.truthy(anim.tile_index == 3, "scheduled mine trigger should preserve animation payload")
          luassert.truthy(reason == "play_sequence_mine_trigger", "scheduled mine trigger should keep snap reason")
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

      luassert.truthy(duration == 0.1, "scheduled mine trigger should return the anim duration as the performance length")
      luassert.truthy(#scheduled == 1, "scheduled mine trigger should enqueue exactly one delayed snap")
      luassert.truthy(scheduled[1].delay == 0.1, "scheduled mine trigger should schedule the snap at the anim duration")
      luassert.truthy(#steps == 0, "handler start should zero-destroy the mine overlay and defer snap work until the callback")

      scheduled[1].callback()

      -- 回调内同帧:先销毁雷,再 prepare+snap 人
      luassert.truthy(steps[1] == "mine:3", "scheduled callback should clear the mine overlay first")
      luassert.truthy(steps[2] == "prepare", "scheduled callback should prepare after clearing the mine")
      luassert.truthy(steps[3] == "snap", "scheduled callback should snap after clearing the mine")
      luassert.truthy(steps[4] == nil, "scheduled callback should run clear+snap exactly once")
    end)

    luassert.truthy(#effect_calls == 1, "scheduled mine trigger should emit exactly one host effect without a tile fallback")
    luassert.truthy(effect_calls[1].sfx_key == runtime_refs.effects.mine_blast, "scheduled mine trigger should play the configured mine effect")
    luassert.truthy(effect_calls[1].cue_name == "mine_blast", "scheduled mine trigger should preserve cue name at the host boundary")
    luassert.truthy(effect_calls[1].pos.x == 1 and effect_calls[1].pos.y == 2 and effect_calls[1].pos.z == 3,
      "scheduled mine trigger should play the host effect at the unit position")
    luassert.truthy(#sound_calls == 1, "scheduled mine trigger should emit exactly one host sound without a tile fallback")
    luassert.truthy(sound_calls[1].sound_id == runtime_refs.audio.mine_blast, "scheduled mine trigger should play the configured mine sound")
    luassert.truthy(sound_calls[1].pos.x == 1 and sound_calls[1].pos.y == 2 and sound_calls[1].pos.z == 3,
      "scheduled mine trigger should play the host sound at the unit position")
  end)

  it("test_mine_trigger_falls_back_to_tile_position_for_player_cue", function()
    local state = support.build_min_state()
    local effect_calls = {}
    local sound_calls = {}
    local bindings = {}
    local player_unit = {}
    state.board_scene.units_by_player_id[1] = player_unit
    state.board_scene.tiles[3] = {
      get_position = function()
        return math.Vector3(4.0, 5.0, 6.0)
      end,
    }

    _with_patches({
      {
        target = host_sfx,
        key = "play_sfx_by_key",
        value = function(sfx_key, pos)
          effect_calls[#effect_calls + 1] = { sfx_key = sfx_key, pos = pos }
          return 903
        end,
      },
      {
        target = host_sfx,
        key = "play_3d_sound",
        value = function(pos, sound_id)
          sound_calls[#sound_calls + 1] = { pos = pos, sound_id = sound_id }
          return 904
        end,
      },
      {
        target = host_sfx,
        key = "bind_sfx_to_unit",
        value = function(sfx_id, unit)
          bindings[#bindings + 1] = { sfx_id = sfx_id, unit = unit }
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
      -- cash_burst 会绑定玩家单位:player cue 在宿主产生绑定,tile cue 的空 payload 不会。
      handlers.play_mine_trigger(state, {
        player_id = 1,
        tile_index = 3,
        to_index = 7,
        cue_name = "cash_burst",
      }, 0, {
        clear_overlay = function() end,
      })
    end)

    luassert.truthy(#effect_calls == 1, "mine trigger should emit one player effect without an additional tile cue")
    luassert.truthy(effect_calls[1].sfx_key == runtime_refs.effects.cash_burst, "mine trigger should preserve the selected player cue")
    luassert.truthy(effect_calls[1].pos.x == 4 and effect_calls[1].pos.y == 5 and effect_calls[1].pos.z == 6,
      "mine trigger should play the player effect at the tile-position fallback")
    luassert.truthy(#sound_calls == 1 and sound_calls[1].sound_id == runtime_refs.audio.cash_receive,
      "mine trigger should play the selected player cue sound once")
    luassert.truthy(sound_calls[1].pos.x == 4 and sound_calls[1].pos.y == 5 and sound_calls[1].pos.z == 6,
      "mine trigger should play the player sound at the tile-position fallback")
    luassert.truthy(#bindings == 1 and bindings[1].sfx_id == 903 and bindings[1].unit == player_unit,
      "player cue routing should bind the effect to player 1; tile cue routing cannot produce this host binding")
  end)

  it("test_mine_trigger_without_any_position_uses_tile_cue_and_normalizes_duration", function()
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

      luassert.truthy(duration == 0.2, "mine trigger should clamp negative snap delay to the provided minimum duration")
    end)

    -- #550:无调度器兜底与回调同序——反馈立即播,销毁雷先于瞬移人(同帧)
    luassert.truthy(steps[1] == "mine_blast:5", "mine trigger should emit tile cue when no hit position exists")
    luassert.truthy(steps[2] == "mine:5", "mine trigger should clear the mine overlay before snapping")
    luassert.truthy(steps[3] == "prepare", "mine trigger should prepare the player after clearing the mine")
    luassert.truthy(steps[4] == "snap", "mine trigger should snap after clearing the mine")
    luassert.truthy(steps[5] == nil, "mine trigger should not emit player cue when no hit position exists")
  end)

  it("test_mine_trigger_normalizes_negative_duration_without_scheduler", function()
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

      luassert.truthy(duration == 0, "mine trigger should normalize negative minimum duration to zero")
    end)
  end)


end)
