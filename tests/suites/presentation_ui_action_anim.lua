local action_anim = require("src.presentation.render.ActionAnim")
local runtime_port = require("src.presentation.api.UIRuntimePort")
local handlers = require("src.presentation.render.ActionAnimHandlers")
local host_runtime = require("src.presentation.api.HostRuntimePort")
local board_feedback = require("src.presentation.render.BoardFeedbackService")
local runtime_refs = require("Config.RuntimeRefs")

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

local function _with_patches(patches, fn)
  local originals = {}
  for i, patch in ipairs(patches) do
    local target = patch.target or _G
    originals[i] = { target = target, key = patch.key, value = target[patch.key] }
    target[patch.key] = patch.value
  end
  local ok, err = xpcall(fn, debug.traceback)
  for i = #originals, 1, -1 do
    local patch = originals[i]
    patch.target[patch.key] = patch.value
  end
  if not ok then
    error(err)
  end
end

local function _build_state()
  local state = {
    ui = {},
    board_scene = {
      tiles = {
        [1] = {
          get_position = function()
            if math and math.Vector3 then
              return math.Vector3(0.0, 0.0, 0.0)
            end
            return { x = 0.0, y = 0.0, z = 0.0 }
          end,
        },
      },
    },
    game = {
      board = {
        get_tile = function()
          return { name = "测试地块" }
        end,
      },
      find_player_by_id = function()
        return { position = 1, name = "测试玩家" }
      end,
    },
  }
  return state
end

local function _test_action_anim_overlay_handler_returns_duration()
  local state = _build_state()
  local duration = action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 })
  assert(duration == 0.2, "roadblock duration should be used")
end

local function _test_action_anim_roadblock_overlay_uses_4x_scale()
  local state = _build_state()
  local unit_calls = 0
  local group_calls = 0
  local captured_scale = nil

  _with_patches({
    {
      target = host_runtime,
      key = "create_unit_with_scale",
      value = function(_, _, _, scale)
        unit_calls = unit_calls + 1
        captured_scale = scale
        return { _unit_id = 1 }
      end,
    },
    {
      target = host_runtime,
      key = "create_unit_group",
      value = function()
        group_calls = group_calls + 1
        return { _group_id = 1 }
      end,
    },
  }, function()
    action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 })
  end)

  assert(unit_calls == 1, "roadblock should spawn via unit path")
  assert(group_calls == 0, "roadblock should not spawn via group path")
  assert(captured_scale ~= nil, "roadblock should pass explicit scale")
  assert(captured_scale.x == 4.0 and captured_scale.y == 4.0 and captured_scale.z == 4.0, "roadblock should use 4x scale")
end

local function _test_action_anim_roll_screen_two_stage_timeline()
  local state = _build_state()
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

  local timers = {}
  local function run_timers_until(limit)
    table.sort(timers, function(a, b)
      return a.delay < b.delay
    end)
    for _, entry in ipairs(timers) do
      if not entry.done and entry.delay <= limit then
        entry.done = true
        entry.cb()
      end
    end
  end

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
      value = function(fn)
        fn(nil)
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

    run_timers_until(1.0)
    assert(nodes["骰子_旋转中"].visible == false, "spin node should hide at 1.0s")
    assert(nodes["骰子_点数1"].visible == true, "first roll face should be shown")
    for i = 2, 6 do
      assert(nodes["骰子_点数" .. i].visible == false, "other faces should remain hidden")
    end

    run_timers_until(1.6)
    assert(nodes["骰子屏"].visible == true, "dice screen should stay visible during hold")
    assert(nodes["骰子_点数1"].visible == true, "face should remain visible during hold")

    run_timers_until(2.0)
    assert(nodes["骰子屏"].visible == false, "dice screen should hide after hold")
    for i = 1, 6 do
      assert(nodes["骰子_点数" .. i].visible == false, "all faces should hide after hold")
    end
  end)
end

local function _test_action_anim_roll_screen_fallback_face_when_invalid()
  local state = _build_state()
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

  local timers = {}
  local function run_timers_until(limit)
    table.sort(timers, function(a, b)
      return a.delay < b.delay
    end)
    for _, entry in ipairs(timers) do
      if not entry.done and entry.delay <= limit then
        entry.done = true
        entry.cb()
      end
    end
  end

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
      value = function(fn)
        fn(nil)
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

    run_timers_until(1.0)
    assert(nodes["骰子_旋转中"].visible == false, "spin node should hide at 1.0s")
    assert(nodes["骰子_点数1"].visible == true, "fallback face should show 1 when parsed face is invalid")
    for i = 2, 6 do
      assert(nodes["骰子_点数" .. i].visible == false, "other faces should remain hidden on fallback")
    end
  end)
end

local function _test_action_anim_upgrade_land_does_not_call_overlay_handler()
  local state = _build_state()
  local called = 0
  _with_patches({
    {
      target = handlers,
      key = "play_overlay",
      value = function(_, anim, duration)
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
            scale = scale,
            duration = duration,
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
    local sound_id = host_runtime.play_3d_sound(pos, 301, 0.8, 1.0)
    local missing_sound_id = host_runtime.play_3d_sound(pos, nil, 0.8, 1.0)
    local zero_sound_id = host_runtime.play_3d_sound(pos, 0, 0.8, 1.0)
    local string_sound_id = host_runtime.play_3d_sound(pos, "snd.valid", 0.8, 1.0)

    assert(sfx_id == 101, "valid sfx call should return engine id")
    assert(missing_id == nil, "missing sfx key should skip safely")
    assert(zero_sfx_id == nil, "zero sfx key should skip safely")
    assert(string_sfx_id == nil, "string sfx key should skip safely")
    assert(sound_id == 202, "valid sound call should return engine id")
    assert(missing_sound_id == nil, "missing sound id should skip safely")
    assert(zero_sound_id == nil, "zero sound id should skip safely")
    assert(string_sound_id == nil, "string sound id should skip safely")
  end)

  assert(#sfx_calls == 1, "invalid sfx keys should not call engine")
  assert(sfx_calls[1].sfx_key == 4286, "sfx key should route unchanged as integer")
  assert(sfx_calls[1].scale == 1.0, "direct sfx port should pass caller-provided scalar scale")
  assert(#sound_calls == 1, "sound call should route once")
  assert(sound_calls[1].sound_id == 301, "sound id should route unchanged")
end

local function _test_board_feedback_effect_id_ref_routes_integer_sfx_key()
  local effect_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos, rot, scale, duration, rate, with_sound)
        effect_calls[#effect_calls + 1] = {
          sfx_key = sfx_key,
          scale = scale,
          duration = duration,
        }
        return 501
      end,
    },
    {
      target = host_runtime,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {})
    assert(played == true, "configured effect cue should play")
  end)

  assert(#effect_calls == 1, "effect cue should call engine once")
  assert(effect_calls[1].sfx_key == runtime_refs.effects.upgrade_land_smoke, "effect id ref should resolve to integer sfx key")
  assert(effect_calls[1].scale == 3.0, "upgrade_land_smoke should use scalar scale")
end

local function _test_board_feedback_player_effect_binding_keeps_bind_call()
  local effect_calls = {}
  local bind_calls = {}
  local state = _build_state()
  state.board_scene.units_by_player_id = {
    [1] = {
      get_position = function()
        return math.Vector3(1.0, 2.0, 3.0)
      end,
    },
  }

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos, rot, scale, duration, rate, with_sound)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key, scale = scale }
        return 777
      end,
    },
    {
      target = host_runtime,
      key = "bind_sfx_to_unit",
      value = function(sfx_id, unit, socket_name, pos, bind_type)
        bind_calls[#bind_calls + 1] = {
          sfx_id = sfx_id,
          socket_name = socket_name,
          pos = pos,
        }
        return true
      end,
    },
    {
      target = host_runtime,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local played = board_feedback.play_player_cue(state, "rich_deity", 1, {})
    assert(played == true, "bound player effect should play")
  end)

  assert(#effect_calls == 1, "player effect should call engine once")
  assert(effect_calls[1].sfx_key == runtime_refs.effects.rich_deity, "player effect should resolve configured integer sfx key")
  assert(effect_calls[1].scale == 1.4, "player effect should use scalar scale")
  assert(#bind_calls == 1, "player effect should still bind to unit")
  assert(bind_calls[1].sfx_id == 777, "bind call should receive runtime sfx handle")
end

local function _test_board_feedback_cash_burst_routes_scalar_scale()
  local effect_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos, rot, scale, duration, rate, with_sound)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key, scale = scale }
        return 888
      end,
    },
    {
      target = host_runtime,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_player_cue(state, "cash_burst", 1, {})
    assert(played == true, "cash_burst should play")
  end)

  assert(#effect_calls == 1, "cash_burst should call engine once")
  assert(effect_calls[1].sfx_key == runtime_refs.effects.cash_burst, "cash_burst should resolve configured integer sfx key")
  assert(effect_calls[1].scale == 1.6, "cash_burst should use scalar scale")
end

local function _test_board_feedback_bankruptcy_routes_scalar_scale()
  local effect_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos, rot, scale, duration, rate, with_sound)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key, scale = scale }
        return 999
      end,
    },
    {
      target = host_runtime,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_player_cue(state, "bankruptcy_slam", 1, {})
    assert(played == true, "bankruptcy_slam should play")
  end)

  assert(#effect_calls == 1, "bankruptcy_slam should call engine once")
  assert(effect_calls[1].sfx_key == runtime_refs.effects.bankruptcy_slam, "bankruptcy should resolve configured integer sfx key")
  assert(effect_calls[1].scale == 1.0, "bankruptcy should fallback to scalar scale 1.0")
end

local function _test_board_feedback_unconfigured_effect_id_ref_skips_without_error()
  local play_calls = 0

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function()
        play_calls = play_calls + 1
        return 1
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {
      effect_id_ref = "missing_effect_ref_for_test",
      sound_id_ref = "missing_sound_ref_for_test",
    })
    assert(played == true, "followup sound scheduling may still keep cue successful")
  end)

  assert(play_calls == 0, "missing effect ref should not call engine")
end

local function _test_action_anim_upgrade_land_routes_board_feedback()
  local state = _build_state()
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
          duration = payload and payload.duration or nil,
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
end

local function _test_action_anim_cash_receive_routes_board_feedback()
  local state = _build_state()
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
  name = "presentation_ui_action_anim",
  tests = {
    { name = "action_anim_overlay_handler_returns_duration", run = _test_action_anim_overlay_handler_returns_duration },
    { name = "action_anim_roadblock_overlay_uses_4x_scale", run = _test_action_anim_roadblock_overlay_uses_4x_scale },
    { name = "action_anim_upgrade_land_does_not_call_overlay_handler", run = _test_action_anim_upgrade_land_does_not_call_overlay_handler },
    {
      name = "host_runtime_sfx_port_skips_missing_keys_and_routes_valid_calls",
      run = _test_host_runtime_sfx_port_skips_missing_keys_and_routes_valid_calls,
    },
    {
      name = "board_feedback_effect_id_ref_routes_integer_sfx_key",
      run = _test_board_feedback_effect_id_ref_routes_integer_sfx_key,
    },
    {
      name = "board_feedback_player_effect_binding_keeps_bind_call",
      run = _test_board_feedback_player_effect_binding_keeps_bind_call,
    },
    {
      name = "board_feedback_cash_burst_routes_scalar_scale",
      run = _test_board_feedback_cash_burst_routes_scalar_scale,
    },
    {
      name = "board_feedback_bankruptcy_routes_scalar_scale",
      run = _test_board_feedback_bankruptcy_routes_scalar_scale,
    },
    {
      name = "board_feedback_unconfigured_effect_id_ref_skips_without_error",
      run = _test_board_feedback_unconfigured_effect_id_ref_skips_without_error,
    },
    { name = "action_anim_upgrade_land_routes_board_feedback", run = _test_action_anim_upgrade_land_routes_board_feedback },
    { name = "action_anim_cash_receive_routes_board_feedback", run = _test_action_anim_cash_receive_routes_board_feedback },
    { name = "action_anim_roll_screen_two_stage_timeline", run = _test_action_anim_roll_screen_two_stage_timeline },
    { name = "action_anim_roll_screen_fallback_face_when_invalid", run = _test_action_anim_roll_screen_fallback_face_when_invalid },
  },
}
