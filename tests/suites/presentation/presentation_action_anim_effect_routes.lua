local action_anim = require("src.ui.render.action_anim")
local handlers = require("src.ui.render.anim_handlers")
local board_feedback = require("src.ui.render.board_feedback_service")
local gameplay_rules = require("src.config.gameplay.rules")
local logger = require("src.core.utils.logger")
local host_runtime = require("src.host.eggy")
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

return {
  name = "presentation.action_anim_effect_routes",
  tests = {
    { name = "action_anim_overlay_handler_returns_duration", run = _test_action_anim_overlay_handler_returns_duration },
    { name = "action_anim_move_effect_uses_real_handler_duration", run = _test_action_anim_move_effect_uses_real_handler_duration },
    { name = "action_anim_teleport_effect_uses_real_handler_duration_without_direction_patch", run = _test_action_anim_teleport_effect_uses_real_handler_duration_without_direction_patch },
    { name = "action_anim_forced_relocation_uses_real_handler_duration_without_direction_patch", run = _test_action_anim_forced_relocation_uses_real_handler_duration_without_direction_patch },
    { name = "action_anim_mine_trigger_uses_real_handler_duration_without_direction_patch", run = _test_action_anim_mine_trigger_uses_real_handler_duration_without_direction_patch },
    { name = "action_anim_roadblock_trigger_routes_clear_overlay", run = _test_action_anim_roadblock_trigger_routes_clear_overlay },
    { name = "action_anim_upgrade_land_does_not_call_overlay_handler", run = _test_action_anim_upgrade_land_does_not_call_overlay_handler },
    { name = "action_anim_is_silent_by_default", run = _test_action_anim_is_silent_by_default },
    { name = "action_anim_user_tip_policy_forces_tip", run = _test_action_anim_user_tip_policy_forces_tip },
    { name = "action_anim_debug_log_uses_info_without_tip", run = _test_action_anim_debug_log_uses_info_without_tip },
    { name = "host_runtime_sfx_port_skips_missing_keys_and_routes_valid_calls", run = _test_host_runtime_sfx_port_skips_missing_keys_and_routes_valid_calls },
    { name = "action_anim_upgrade_land_routes_board_feedback", run = _test_action_anim_upgrade_land_routes_board_feedback },
    { name = "action_anim_cash_receive_routes_board_feedback", run = _test_action_anim_cash_receive_routes_board_feedback },
  },
}
