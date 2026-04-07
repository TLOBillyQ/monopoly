local action_anim = require("src.ui.render.action_anim")
local handlers = require("src.ui.render.anim_handlers")
local anim_units = require("src.ui.render.anim_units")
local board_feedback = require("src.ui.render.board_feedback.service")
local timing = require("src.config.gameplay.timing")
local logger = require("src.core.utils.logger")
local host_runtime = require("src.host")
local move_anim = require("src.ui.render.move_anim")
local unit_position = require("src.ui.render.unit_position")
local runtime_port = require("src.ui.render.runtime_ui")
local support = require("support.presentation_action_anim_support")

local _with_patches = support.with_patches

local function _test_action_anim_overlay_handler_returns_duration()
  local state = support.build_min_state()
  local duration = action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 })
  assert(duration == 0.2, "roadblock duration should be used")
end

local function _test_action_anim_move_effect_uses_real_handler_duration()
  local state = support.build_min_state()
  local probe = support.capture_handler_duration("play_move_effect")
  probe.set_duration(0.75)

  _with_patches(probe.patches, function()
    local duration = action_anim.play(state, {
      kind = "move_effect",
      player_id = 1,
      from_index = 1,
      to_index = 1,
      duration = 2.0,
    })
    assert(duration == 0.75, "move_effect should use handler duration instead of default wait")
  end)

  local captured_anim = probe.captured_anim()
  assert(captured_anim ~= nil, "move_effect handler should receive animation payload")
  assert(captured_anim.direction ~= nil, "move_effect handler should receive a fallback direction")
end

local function _test_action_anim_teleport_effect_uses_real_handler_duration_without_direction_patch()
  local state = support.build_min_state()
  local probe = support.capture_handler_duration("play_teleport_effect")
  probe.set_duration(0)

  _with_patches(probe.patches, function()
    local duration = action_anim.play(state, {
      kind = "teleport_effect",
      player_id = 1,
      from_index = 1,
      to_index = 1,
      duration = 2.0,
    })
    assert(duration == 0, "teleport_effect should use handler duration instead of default wait")
  end)

  local captured_anim = probe.captured_anim()
  assert(captured_anim ~= nil, "teleport_effect handler should receive animation payload")
  assert(captured_anim.direction == nil, "teleport_effect should not receive move direction fallback")
end

local function _test_action_anim_forced_relocation_uses_real_handler_duration_without_direction_patch()
  local state = support.build_min_state()
  local probe = support.capture_handler_duration("play_forced_relocation")
  probe.set_duration(0)

  _with_patches(probe.patches, function()
    local duration = action_anim.play(state, {
      kind = "forced_relocation",
      player_id = 1,
      from_index = 1,
      to_index = 1,
      duration = 2.0,
    })
    assert(duration == 0, "forced_relocation should use handler duration instead of default wait")
  end)

  local captured_anim = probe.captured_anim()
  assert(captured_anim ~= nil, "forced_relocation handler should receive animation payload")
  assert(captured_anim.direction == nil, "forced_relocation should not receive move direction fallback")
end

local function _test_action_anim_mine_trigger_uses_real_handler_duration_without_direction_patch()
  local state = support.build_min_state()
  local probe = support.capture_handler_duration("play_mine_trigger")
  probe.set_duration(0)

  _with_patches(probe.patches, function()
    local duration = action_anim.play(state, {
      kind = "mine_trigger",
      player_id = 1,
      tile_index = 1,
      from_index = 1,
      to_index = 1,
      cue_name = "mine_blast",
      duration = 2.0,
    })
    assert(duration == 0, "mine_trigger should use handler duration instead of default wait")
  end)

  local captured_anim = probe.captured_anim()
  assert(captured_anim ~= nil, "mine_trigger handler should receive animation payload")
  assert(captured_anim.direction == nil, "mine_trigger should not receive move direction fallback")
end

local function _test_action_anim_missile_waits_before_starting_handler()
  local state = support.build_min_state()
  local scheduled_delay = nil
  local scheduled_fn = nil
  local handler_calls = 0
  local expected_delay = timing.demolish_effect_start_delay_seconds or 0.2

  _with_patches({
    {
      target = handlers,
      key = "play_missile",
      value = function()
        handler_calls = handler_calls + 1
      end,
    },
    {
      target = host_runtime,
      key = "schedule",
      value = function(delay, fn)
        scheduled_delay = delay
        scheduled_fn = fn
      end,
    },
  }, function()
    local duration = action_anim.play(state, {
      kind = "missile",
      tile_index = 1,
      duration = 0.6,
    })
    assert(duration == 0.6 + expected_delay, "missile should add startup delay to total duration")
    assert(scheduled_delay == expected_delay, "missile should schedule handler after startup delay")
    assert(handler_calls == 0, "missile handler should not run immediately before ui closes")
    assert(type(scheduled_fn) == "function", "missile should enqueue delayed handler callback")
    scheduled_fn()
    assert(handler_calls == 1, "missile handler should run after delayed callback")
  end)
end

local function _test_action_anim_monster_waits_before_starting_handler()
  local state = support.build_min_state()
  local scheduled_delay = nil
  local scheduled_fn = nil
  local handler_calls = 0
  local expected_delay = timing.demolish_effect_start_delay_seconds or 0.2

  _with_patches({
    {
      target = handlers,
      key = "play_monster",
      value = function()
        handler_calls = handler_calls + 1
      end,
    },
    {
      target = host_runtime,
      key = "schedule",
      value = function(delay, fn)
        scheduled_delay = delay
        scheduled_fn = fn
      end,
    },
  }, function()
    local duration = action_anim.play(state, {
      kind = "monster",
      tile_index = 1,
      duration = 0.6,
    })
    assert(duration == 0.6 + expected_delay, "monster should add startup delay to total duration")
    assert(scheduled_delay == expected_delay, "monster should schedule handler after startup delay")
    assert(handler_calls == 0, "monster handler should not run immediately before ui closes")
    assert(type(scheduled_fn) == "function", "monster should enqueue delayed handler callback")
    scheduled_fn()
    assert(handler_calls == 1, "monster handler should run after delayed callback")
  end)
end

local function _test_action_anim_roadblock_trigger_routes_clear_overlay()
  local state = support.build_min_state()
  local cleared = {}

  _with_patches({
    {
      target = handlers,
      key = "clear_overlay",
      value = function(_, kind, tile_index)
        cleared[#cleared + 1] = kind .. ":" .. tostring(tile_index)
      end,
    },
  }, function()
    action_anim.play(state, { kind = "roadblock_trigger", tile_index = 1, duration = 0.2 })
  end)

  assert(cleared[1] == "roadblock:1", "roadblock_trigger should clear the roadblock overlay")
end

local function _test_action_anim_upgrade_land_does_not_call_overlay_handler()
  local state = support.build_min_state()
  local called = 0

  _with_patches({
    {
      target = handlers,
      key = "play_overlay",
      value = function()
        called = called + 1
      end,
    },
  }, function()
    local out_duration = action_anim.play(state, {
      kind = "upgrade_land",
      tile_index = 1,
      level = 1,
      duration = 0.6,
    })
    assert(out_duration == 0.6, "upgrade_land should keep configured duration")
    assert(called == 0, "upgrade_land should not call overlay handler")
  end)
end

local function _test_action_anim_is_silent_by_default()
  local state = support.build_min_state()
  local tip_calls = 0

  _with_patches({
    {
      target = host_runtime,
      key = "enqueue_tip",
      value = function()
        tip_calls = tip_calls + 1
        return true
      end,
    },
  }, function()
    local duration = action_anim.play(state, {
      kind = "item_use",
      player_id = 1,
      item_id = 2001,
      duration = 0.6,
    })
    assert(duration == 0.6, "silent action anim should still return duration")
  end)

  assert(tip_calls == 0, "action anim should not emit user tips by default")
end

local function _test_action_anim_user_tip_policy_forces_tip()
  local state = support.build_min_state()
  local tips = {}

  _with_patches({
    {
      target = host_runtime,
      key = "enqueue_tip",
      value = function(intent)
        tips[#tips + 1] = intent
        return true
      end,
    },
  }, function()
    action_anim.play(state, {
      kind = "item_use",
      player_id = 1,
      item_id = 2001,
      item_name = "免费卡",
      duration = 0.6,
      tip_policy = "user",
    })
  end)

  assert(#tips == 1, "tip_policy=user should force exactly one tip")
  assert(tips[1].text ~= nil and tips[1].text ~= "", "forced tip should contain text")
end

local function _test_action_anim_debug_log_uses_info_without_tip()
  local state = support.build_min_state()
  local tip_calls = 0
  local info_calls = {}

  _with_patches({
    { target = gameplay_rules, key = "action_anim_debug_log_enabled", value = false },
    {
      target = logger,
      key = "anim_debug_enabled_provider",
      value = function()
        return true
      end,
    },
    {
      target = host_runtime,
      key = "enqueue_tip",
      value = function()
        tip_calls = tip_calls + 1
        return true
      end,
    },
    {
      target = logger,
      key = "info_unlimited",
      value = function(...)
        info_calls[#info_calls + 1] = table.concat({ ... }, " ")
      end,
    },
    {
      target = handlers,
      key = "play_move_effect",
      value = function()
        return 0.6
      end,
    },
  }, function()
    action_anim.play(state, {
      kind = "move_effect",
      player_id = 1,
      from_index = 1,
      to_index = 1,
      duration = 0.6,
    })
  end)

  assert(tip_calls == 0, "debug action anim log should not consume tip channel")
  assert(#info_calls == 1, "debug action anim log should emit one info log")
end

local function _test_host_runtime_sfx_port_skips_missing_keys_and_routes_valid_calls()
  local sfx_calls = {}
  local sound_calls = {}

  _with_patches({
    {
      key = "GameAPI",
      value = {
        play_sfx_by_key = function(sfx_key, pos, rot, scale, duration, rate, with_sound)
          sfx_calls[#sfx_calls + 1] = {
            sfx_key = sfx_key,
            pos = pos,
            rot = rot,
            scale = scale,
            duration = duration,
            rate = rate,
            with_sound = with_sound,
          }
          return 101
        end,
        play_3d_sound = function(pos, sound_id, duration, volume)
          sound_calls[#sound_calls + 1] = {
            pos = pos,
            sound_id = sound_id,
            duration = duration,
            volume = volume,
          }
          return 202
        end,
      },
    },
  }, function()
    local pos = math.Vector3(1.0, 2.0, 3.0)
    local sfx_id = host_runtime.play_sfx_by_key(4286, pos, nil, 1.0, 1.0, nil, false)
    local missing_id = host_runtime.play_sfx_by_key(nil, pos, nil, nil, 1.0, nil, false)
    local zero_sfx_id = host_runtime.play_sfx_by_key(0, pos, nil, nil, 1.0, nil, false)
    local string_sfx_id = host_runtime.play_sfx_by_key("fx.valid", pos, nil, nil, 1.0, nil, false)
    local vector_scale_id = host_runtime.play_sfx_by_key(4286, pos, nil, math.Vector3(1.0, 1.0, 1.0), 1.0, nil, false)
    local sound_id = host_runtime.play_3d_sound(pos, 301, 0.8, 1.0)
    local missing_sound_id = host_runtime.play_3d_sound(pos, nil, 0.8, 1.0)
    local zero_sound_id = host_runtime.play_3d_sound(pos, 0, 0.8, 1.0)
    local string_sound_id = host_runtime.play_3d_sound(pos, "snd.valid", 0.8, 1.0)

    assert(sfx_id == 101, "valid sfx call should return engine id")
    assert(missing_id == nil, "missing sfx key should skip safely")
    assert(zero_sfx_id == nil, "zero sfx key should skip safely")
    assert(string_sfx_id == nil, "string sfx key should skip safely")
    assert(vector_scale_id == nil, "vector scale should skip safely")
    assert(sound_id == 202, "valid sound call should return engine id")
    assert(missing_sound_id == nil, "missing sound id should skip safely")
    assert(zero_sound_id == nil, "zero sound id should skip safely")
    assert(string_sound_id == nil, "string sound id should skip safely")
  end)

  assert(#sfx_calls == 1, "invalid sfx keys should not call engine")
  assert(sfx_calls[1].sfx_key == 4286, "sfx key should route unchanged as integer")
  assert(sfx_calls[1].scale == 1.0, "direct sfx port should pass caller-provided scalar scale")
  assert(sfx_calls[1].rate == 1.0, "direct sfx port should default missing rate to 1.0")
  assert(sfx_calls[1].with_sound == false, "direct sfx port should default with_sound to false")
  assert(sfx_calls[1].rot ~= nil, "direct sfx port should default missing rot")
  assert(#sound_calls == 1, "sound call should route once")
  assert(sound_calls[1].sound_id == 301, "sound id should route unchanged")
end

local function _test_action_anim_upgrade_land_routes_board_feedback()
  local state = support.build_min_state()
  local calls = {}

  _with_patches({
    {
      target = board_feedback,
      key = "play_tile_cue",
      value = function(_, cue_name, tile_index, payload)
        calls[#calls + 1] = {
          cue_name = cue_name,
          tile_index = tile_index,
          player_id = payload and payload.player_id or nil,
          use_building_tile_position = payload and payload.use_building_tile_position or nil,
        }
        return true
      end,
    },
  }, function()
    local out_duration = action_anim.play(state, {
      kind = "upgrade_land",
      player_id = 1,
      tile_index = 1,
      level = 2,
      duration = 0.6,
    })
    assert(out_duration == 0.6, "upgrade_land should keep configured duration")
  end)

  assert(#calls == 1, "upgrade_land should route exactly one board feedback cue")
  assert(calls[1].cue_name == "upgrade_land_smoke", "upgrade cue name mismatch")
  assert(calls[1].tile_index == 1, "upgrade cue should target tile index")
  assert(calls[1].player_id == 1, "upgrade cue should preserve player id")
  assert(calls[1].use_building_tile_position == true, "upgrade cue should request building tile position")
end

local function _test_action_anim_cash_receive_routes_board_feedback()
  local state = support.build_min_state()
  local calls = {}

  _with_patches({
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id, payload)
        calls[#calls + 1] = {
          cue_name = cue_name,
          player_id = player_id,
          amount = payload and payload.amount or nil,
        }
        return true
      end,
    },
  }, function()
    local out_duration = action_anim.play(state, {
      kind = "cash_receive",
      player_id = 1,
      amount = 500,
      duration = 0.7,
    })
    assert(out_duration == 0.7, "cash_receive should keep configured duration")
  end)

  assert(#calls == 1, "cash_receive should route exactly one board feedback cue")
  assert(calls[1].cue_name == "cash_burst", "cash cue name mismatch")
  assert(calls[1].player_id == 1, "cash cue should preserve player id")
  assert(calls[1].amount == 500, "cash cue should preserve amount")
end

local function _test_play_mine_trigger_prefers_player_cue_with_unit_position()
  local state = support.build_min_state()
  local player_calls = {}
  local tile_calls = 0
  local cleared = {}

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
      value = function() end,
    },
    {
      target = move_anim,
      key = "snap_player_to_index",
      value = function()
        return 0.4
      end,
    },
  }, function()
    local duration = anim_units.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 1,
      to_index = 2,
      cue_name = "mine_blast",
    }, 0.1, {
      clear_overlay = function(_, kind, tile_index)
        cleared[#cleared + 1] = kind .. ":" .. tostring(tile_index)
      end,
    })

    assert(duration == 0.4, "play_mine_trigger should keep positive snap delay when above minimum duration")
  end)

  assert(#player_calls == 1, "play_mine_trigger should route one player cue when unit position exists")
  assert(player_calls[1].payload.pos.x == 1, "play_mine_trigger should prefer unit position over tile position")
  assert(tile_calls == 0, "play_mine_trigger should not emit tile cue when player cue is available")
  assert(cleared[1] == "mine:1", "play_mine_trigger should clear mine overlay after feedback")
end

local function _test_play_mine_trigger_falls_back_to_tile_position_for_player_cue()
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
      value = function(_, _, _, payload)
        player_calls[#player_calls + 1] = payload
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
    anim_units.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 1,
      to_index = 2,
    }, 0, {
      clear_overlay = function() end,
    })
  end)

  assert(#player_calls == 1, "play_mine_trigger should keep player cue when tile position exists")
  assert(player_calls[1].pos.x == 4, "play_mine_trigger should fall back to tile position")
  assert(tile_calls == 0, "play_mine_trigger should avoid tile cue when tile position fallback exists")
end

local function _test_play_mine_trigger_uses_tile_cue_without_any_position_and_normalizes_minimum_delay()
  local state = support.build_min_state()
  local player_calls = 0
  local tile_calls = {}

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
        player_calls = player_calls + 1
      end,
    },
    {
      target = board_feedback,
      key = "play_tile_cue",
      value = function(_, cue_name, tile_index)
        tile_calls[#tile_calls + 1] = cue_name .. ":" .. tostring(tile_index)
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
        return -1
      end,
    },
  }, function()
    local duration = anim_units.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 3,
      to_index = 2,
    }, 0.2, {
      clear_overlay = function() end,
    })

    assert(duration == 0.2, "play_mine_trigger should clamp negative snap delay to minimum duration")
  end)

  assert(player_calls == 0, "play_mine_trigger should skip player cue when no hit position exists")
  assert(tile_calls[1] == "mine_blast:3", "play_mine_trigger should fall back to tile cue when position lookup fails")
end

local function _test_play_mine_trigger_uses_prepare_before_feedback_without_scheduler()
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
    local duration = anim_units.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 3,
      to_index = 2,
      cue_name = "mine_blast",
    }, -0.5, {
      clear_overlay = function(_, kind, tile_index)
        steps[#steps + 1] = kind .. ":" .. tostring(tile_index)
      end,
    })

    assert(duration == 0, "play_mine_trigger should normalize negative fallback duration to zero")
  end)

  assert(steps[1] == "prepare", "play_mine_trigger should prepare the player before fallback feedback")
  assert(steps[2] == "mine_blast:3", "play_mine_trigger should emit tile cue after prepare when no hit position exists")
  assert(steps[3] == "mine:3", "play_mine_trigger should clear the mine overlay after feedback")
  assert(steps[4] == "snap", "play_mine_trigger should snap after fallback feedback")
end

local function _new_roll_nodes()
  local nodes = {}
  local node_names = {
    "骰子屏",
    "骰子_旋转中",
    "骰子_点数1",
    "骰子_点数2",
    "骰子_点数3",
    "骰子_点数4",
    "骰子_点数5",
    "骰子_点数6",
  }
  for _, name in ipairs(node_names) do
    nodes[name] = { visible = false, name = name }
  end
  return nodes
end

local function _run_timers_until(timers, limit)
  table.sort(timers, function(left, right)
    return left.delay < right.delay
  end)
  for _, entry in ipairs(timers) do
    if not entry.done and entry.delay <= limit then
      entry.done = true
      entry.cb()
    end
  end
end

local function _with_roll_runtime(nodes, fn)
  local timers = {}
  _with_patches({
    {
      key = "SetTimeOut",
      value = function(delay, cb)
        timers[#timers + 1] = {
          delay = delay,
          cb = cb,
          done = false,
        }
      end,
    },
    {
      target = runtime_port,
      key = "for_each_role_or_global",
      value = function(cb)
        cb(nil)
      end,
    },
    {
      target = runtime_port,
      key = "query_node",
      value = function(name)
        return assert(nodes[name], "missing test node: " .. tostring(name))
      end,
    },
  }, function()
    fn(timers)
  end)
end

local function _test_action_anim_roll_screen_two_stage_timeline()
  local state = support.build_min_state()
  local nodes = _new_roll_nodes()

  _with_roll_runtime(nodes, function(timers)
    local total_duration = action_anim.play(state, {
      kind = "roll",
      duration = 3.0,
      rolls = { 1, 5 },
      total = 6,
    })

    assert(total_duration == 2.0, "roll action duration should use 1.0s spin + 1.0s hold")
    assert(nodes["骰子屏"].visible == true, "dice screen should be visible at start")
    assert(nodes["骰子_旋转中"].visible == true, "spin node should be visible at start")
    for i = 1, 6 do
      assert(nodes["骰子_点数" .. i].visible == false, "face should be hidden while spinning")
    end

    _run_timers_until(timers, 1.0)
    assert(nodes["骰子_旋转中"].visible == false, "spin node should hide at 1.0s")
    assert(nodes["骰子_点数1"].visible == true, "first roll face should be shown")

    _run_timers_until(timers, 1.6)
    assert(nodes["骰子屏"].visible == true, "dice screen should stay visible during hold")
    assert(nodes["骰子_点数1"].visible == true, "face should remain visible during hold")

    _run_timers_until(timers, 2.0)
    assert(nodes["骰子屏"].visible == false, "dice screen should hide after hold")
    for i = 1, 6 do
      assert(nodes["骰子_点数" .. i].visible == false, "all faces should hide after hold")
    end
  end)
end

local function _test_action_anim_roll_screen_fallback_face_when_invalid()
  local state = support.build_min_state()
  local nodes = _new_roll_nodes()

  _with_roll_runtime(nodes, function(timers)
    action_anim.play(state, {
      kind = "roll",
      duration = 3.0,
      rolls = {
        setmetatable({}, {
          __tostring = function()
            return "bad"
          end,
        }),
      },
      total = "bad",
    })

    _run_timers_until(timers, 1.0)
    assert(nodes["骰子_旋转中"].visible == false, "spin node should hide at 1.0s")
    assert(nodes["骰子_点数1"].visible == true, "fallback face should show 1 when parsed face is invalid")
    for i = 2, 6 do
      assert(nodes["骰子_点数" .. i].visible == false, "other faces should remain hidden on fallback")
    end
  end)
end

local function _test_play_missile_plays_blast_and_delays_upgrade_smoke()
  local state = support.build_min_state()
  local cue_calls = {}
  local scheduled_delay = nil
  local scheduled_fn = nil
  local expected_delay = timing.demolish_effect_followup_delay_seconds or 0.35

  _with_patches({
    {
      target = board_feedback,
      key = "play_tile_cue",
      value = function(_, cue_name, tile_index, payload)
        cue_calls[#cue_calls + 1] = {
          cue_name = cue_name,
          tile_index = tile_index,
          use_building_tile_position = payload and payload.use_building_tile_position,
        }
        return true
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
    {
      target = require("src.ui.render.anim_unit_overlay"),
      key = "play_missile",
      value = function() end,
    },
  }, function()
    anim_units.play_missile(state, {
      tile_index = 3,
      target_player_ids = { 2 },
      to_index = 4,
    }, 0.5, {
      schedule = function(delay, fn)
        scheduled_delay = delay
        scheduled_fn = fn
      end,
      clear_overlay = function() end,
    })

    assert(#cue_calls == 1, "play_missile should emit mine blast immediately")
    assert(cue_calls[1].cue_name == "mine_blast", "play_missile should reuse mine blast cue")
    assert(cue_calls[1].tile_index == 3, "play_missile should target the demolished tile")
    assert(cue_calls[1].use_building_tile_position == false, "play_missile blast should use tile position")
    assert(scheduled_delay == expected_delay, "play_missile should delay upgrade smoke cue")
    assert(type(scheduled_fn) == "function", "play_missile should schedule followup upgrade smoke cue")

    scheduled_fn()

    assert(#cue_calls == 2, "play_missile should emit delayed upgrade smoke cue")
    assert(cue_calls[2].cue_name == "upgrade_land_smoke", "play_missile should reuse upgrade smoke cue")
    assert(cue_calls[2].tile_index == 3, "play_missile delayed smoke should target the demolished tile")
    assert(cue_calls[2].use_building_tile_position == false, "play_missile delayed smoke should use tile position")
  end)
end

local function _test_play_monster_plays_blast_and_delays_upgrade_smoke()
  local state = support.build_min_state()
  local cue_calls = {}
  local scheduled_delay = nil
  local scheduled_fn = nil
  local expected_delay = timing.demolish_effect_followup_delay_seconds or 0.35

  _with_patches({
    {
      target = board_feedback,
      key = "play_tile_cue",
      value = function(_, cue_name, tile_index, payload)
        cue_calls[#cue_calls + 1] = {
          cue_name = cue_name,
          tile_index = tile_index,
          use_building_tile_position = payload and payload.use_building_tile_position,
        }
        return true
      end,
    },
    {
      target = require("src.ui.render.anim_unit_overlay"),
      key = "play_monster",
      value = function() end,
    },
  }, function()
    anim_units.play_monster(state, {
      tile_index = 5,
    }, 0.5, {
      schedule = function(delay, fn)
        scheduled_delay = delay
        scheduled_fn = fn
      end,
    })

    assert(#cue_calls == 1, "play_monster should emit mine blast immediately")
    assert(cue_calls[1].cue_name == "mine_blast", "play_monster should reuse mine blast cue")
    assert(cue_calls[1].tile_index == 5, "play_monster should target the demolished tile")
    assert(cue_calls[1].use_building_tile_position == true, "play_monster blast should use building position")
    assert(scheduled_delay == expected_delay, "play_monster should delay upgrade smoke cue")
    assert(type(scheduled_fn) == "function", "play_monster should schedule followup upgrade smoke cue")

    scheduled_fn()

    assert(#cue_calls == 2, "play_monster should emit delayed upgrade smoke cue")
    assert(cue_calls[2].cue_name == "upgrade_land_smoke", "play_monster should reuse upgrade smoke cue")
    assert(cue_calls[2].tile_index == 5, "play_monster delayed smoke should target the demolished tile")
    assert(cue_calls[2].use_building_tile_position == true, "play_monster delayed smoke should use building position")
  end)
end

local function _test_play_mine_trigger_delays_snap_when_schedule_available()
  local state = support.build_min_state()
  local scheduled_delay = nil
  local scheduled_fn = nil
  local steps = {}
  local expected_delay = timing.mine_trigger_snap_delay_seconds or 0.6

  _with_patches({
    {
      target = unit_position,
      key = "read_unit_position",
      value = function()
        return { x = 1, y = 2, z = 3 }
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function()
        steps[#steps + 1] = "cue"
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
        return 0
      end,
    },
  }, function()
    local duration = anim_units.play_mine_trigger(state, {
      player_id = 1,
      tile_index = 1,
      to_index = 2,
    }, 0, {
      clear_overlay = function()
        steps[#steps + 1] = "clear"
      end,
      schedule = function(delay, fn)
        scheduled_delay = delay
        scheduled_fn = fn
      end,
    })

    assert(duration == expected_delay, "play_mine_trigger should return configured delayed snap duration")
    assert(scheduled_delay == expected_delay, "play_mine_trigger should schedule snap with configured delay")
    assert(type(scheduled_fn) == "function", "play_mine_trigger should enqueue delayed snap callback")
    assert(steps[1] == "cue", "mine feedback cue should emit immediately")
    assert(steps[2] == "clear", "mine overlay should clear before delayed snap")
    assert(steps[3] == nil, "snap should not run before scheduled callback executes")

    scheduled_fn()
    assert(steps[3] == "prepare", "scheduled callback should prepare player for snap")
    assert(steps[4] == "snap", "scheduled callback should snap player to hospital")
  end)
end

return {
  name = "presentation.action_anim_effect_routes",
  tests = {
    { name = "action_anim_overlay_handler_returns_duration", run = _test_action_anim_overlay_handler_returns_duration },
    { name = "action_anim_move_effect_uses_real_handler_duration", run = _test_action_anim_move_effect_uses_real_handler_duration },
    { name = "action_anim_teleport_effect_uses_real_handler_duration_without_direction_patch", run = _test_action_anim_teleport_effect_uses_real_handler_duration_without_direction_patch },
    { name = "action_anim_forced_relocation_uses_real_handler_duration_without_direction_patch", run = _test_action_anim_forced_relocation_uses_real_handler_duration_without_direction_patch },
    { name = "action_anim_mine_trigger_uses_real_handler_duration_without_direction_patch", run = _test_action_anim_mine_trigger_uses_real_handler_duration_without_direction_patch },
    { name = "action_anim_missile_waits_before_starting_handler", run = _test_action_anim_missile_waits_before_starting_handler },
    { name = "action_anim_monster_waits_before_starting_handler", run = _test_action_anim_monster_waits_before_starting_handler },
    { name = "action_anim_roadblock_trigger_routes_clear_overlay", run = _test_action_anim_roadblock_trigger_routes_clear_overlay },
    { name = "action_anim_upgrade_land_does_not_call_overlay_handler", run = _test_action_anim_upgrade_land_does_not_call_overlay_handler },
    { name = "action_anim_is_silent_by_default", run = _test_action_anim_is_silent_by_default },
    { name = "action_anim_user_tip_policy_forces_tip", run = _test_action_anim_user_tip_policy_forces_tip },
    { name = "action_anim_debug_log_uses_info_without_tip", run = _test_action_anim_debug_log_uses_info_without_tip },
    { name = "host_runtime_sfx_port_skips_missing_keys_and_routes_valid_calls", run = _test_host_runtime_sfx_port_skips_missing_keys_and_routes_valid_calls },
    { name = "action_anim_upgrade_land_routes_board_feedback", run = _test_action_anim_upgrade_land_routes_board_feedback },
    { name = "action_anim_cash_receive_routes_board_feedback", run = _test_action_anim_cash_receive_routes_board_feedback },
    { name = "play_mine_trigger_prefers_player_cue_with_unit_position", run = _test_play_mine_trigger_prefers_player_cue_with_unit_position },
    { name = "play_mine_trigger_falls_back_to_tile_position_for_player_cue", run = _test_play_mine_trigger_falls_back_to_tile_position_for_player_cue },
    { name = "play_mine_trigger_uses_tile_cue_without_any_position_and_normalizes_minimum_delay", run = _test_play_mine_trigger_uses_tile_cue_without_any_position_and_normalizes_minimum_delay },
    { name = "play_mine_trigger_uses_prepare_before_feedback_without_scheduler", run = _test_play_mine_trigger_uses_prepare_before_feedback_without_scheduler },
    { name = "play_missile_plays_blast_and_delays_upgrade_smoke", run = _test_play_missile_plays_blast_and_delays_upgrade_smoke },
    { name = "play_monster_plays_blast_and_delays_upgrade_smoke", run = _test_play_monster_plays_blast_and_delays_upgrade_smoke },
    { name = "play_mine_trigger_delays_snap_when_schedule_available", run = _test_play_mine_trigger_delays_snap_when_schedule_available },
    { name = "action_anim_roll_screen_two_stage_timeline", run = _test_action_anim_roll_screen_two_stage_timeline },
    { name = "action_anim_roll_screen_fallback_face_when_invalid", run = _test_action_anim_roll_screen_fallback_face_when_invalid },
  },
}
