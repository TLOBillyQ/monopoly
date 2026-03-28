local host_runtime = require("src.host")
local board_feedback = require("src.ui.render.board_feedback_service")
local runtime_refs = require("src.config.content.runtime_refs")
local logger = require("src.core.utils.logger")
local tip_queue = require("src.core.utils.tip_queue")
local runtime_context = require("src.host.context")

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

local function _with_patches(patches, fn)
  local function _refresh_runtime_ctx()
    local lua_api = {}
    if type(LuaAPI) == "table" then
      for key, value in pairs(LuaAPI) do
        lua_api[key] = value
      end
    end
    if type(SetTimeOut) == "function" then
      lua_api.call_delay_time = function(delay, cb)
        return SetTimeOut(delay, cb)
      end
    elseif type(lua_api.call_delay_time) ~= "function" then
      lua_api.call_delay_time = function(_, cb)
        if cb then
          cb()
          return true
        end
        return false
      end
    end
    runtime_context.set_current(runtime_context.new({
      GameAPI = GameAPI,
      LuaAPI = lua_api,
    }))
    tip_queue.configure_runtime({
      presenter = function(text, duration)
        if GlobalAPI and type(GlobalAPI.show_tips) == "function" then
          return GlobalAPI.show_tips(text, duration)
        end
        return false
      end,
      scheduler = function(delay, cb)
        return lua_api.call_delay_time(delay, cb)
      end,
      test_mode = logger.is_test_mode(),
    })
  end

  local originals = {}
  for i, patch in ipairs(patches) do
    local target = patch.target or _G
    originals[i] = { target = target, key = patch.key, value = target[patch.key] }
    target[patch.key] = patch.value
  end
  _refresh_runtime_ctx()
  local ok, err = xpcall(fn, debug.traceback)
  for i = #originals, 1, -1 do
    local patch = originals[i]
    patch.target[patch.key] = patch.value
  end
  _refresh_runtime_ctx()
  if not ok then
    error(err)
  end
end

local function _build_state()
  return {
    ui = {},
    board_scene = {
      tiles = {
        [1] = {
          get_position = function()
            return math.Vector3(0.0, 0.0, 0.0)
          end,
        },
      },
      buildings = {
        [1] = {
          get_position = function()
            return math.Vector3(10.0, 0.0, 0.0)
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
end

local function _make_host_unit(x, y, z)
  if type(newproxy) == "function" then
    local unit = newproxy(true)
    getmetatable(unit).__index = {
      get_position = function()
        return math.Vector3(x, y, z)
      end,
    }
    return unit
  end
  return {
    get_position = function()
      return math.Vector3(x, y, z)
    end,
  }
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

local function _test_board_feedback_tile_cue_uses_building_position_when_requested()
  local effect_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos)
        effect_calls[#effect_calls + 1] = {
          sfx_key = sfx_key,
          pos = pos,
        }
        return 502
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
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {
      use_building_tile_position = true,
    })
    assert(played == true, "configured effect cue should play from building position")
  end)

  assert(#effect_calls == 1, "building-position tile cue should call engine once")
  assert(effect_calls[1].pos.x == 10.0, "building-position tile cue should use building x")
  assert(effect_calls[1].pos.y == 0.0, "building-position tile cue should use building y")
  assert(effect_calls[1].pos.z == 0.0, "building-position tile cue should use building z")
end

local function _test_board_feedback_tile_cue_falls_back_to_tile_position_when_building_missing()
  local effect_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos)
        effect_calls[#effect_calls + 1] = {
          sfx_key = sfx_key,
          pos = pos,
        }
        return 503
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
    state.board_scene.buildings = {}
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {
      use_building_tile_position = true,
    })
    assert(played == true, "tile cue should fall back to tile position when building is missing")
  end)

  assert(#effect_calls == 1, "fallback tile cue should call engine once")
  assert(effect_calls[1].pos.x == 0.0, "fallback tile cue should use tile x")
  assert(effect_calls[1].pos.y == 0.0, "fallback tile cue should use tile y")
  assert(effect_calls[1].pos.z == 0.0, "fallback tile cue should use tile z")
end

local function _test_board_feedback_tile_cue_reads_host_unit_position()
  local effect_calls = {}
  local state = _build_state()
  state.board_scene.tiles[1] = _make_host_unit(21.0, 22.0, 23.0)

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos)
        effect_calls[#effect_calls + 1] = {
          sfx_key = sfx_key,
          pos = pos,
        }
        return 504
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
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {})
    assert(played == true, "board feedback should play on host unit position")
  end)

  assert(#effect_calls == 1, "board feedback should call engine once for host unit position")
  assert(effect_calls[1].pos.x == 21.0, "board feedback should use host unit x")
  assert(effect_calls[1].pos.y == 22.0, "board feedback should use host unit y")
  assert(effect_calls[1].pos.z == 23.0, "board feedback should use host unit z")
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
      value = function(sfx_key, pos, rot, scale)
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
      value = function(sfx_key, pos, rot, scale)
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

local function _test_board_feedback_player_cue_prefers_explicit_payload_position()
  local effect_calls = {}
  local explicit_pos = math.Vector3(9.0, 8.0, 7.0)

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos)
        effect_calls[#effect_calls + 1] = {
          sfx_key = sfx_key,
          pos = pos,
        }
        return 889
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
    local played = board_feedback.play_player_cue(state, "cash_burst", 1, {
      pos = explicit_pos,
    })
    assert(played == true, "player cue should play when explicit position is provided")
  end)

  assert(#effect_calls == 1, "explicit player cue should call engine once")
  assert(effect_calls[1].pos == explicit_pos, "explicit payload position should override resolved player position")
end

local function _test_board_feedback_bankruptcy_routes_scalar_scale()
  local effect_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos, rot, scale)
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

local function _test_board_feedback_followup_sound_defaults_are_numeric()
  local sound_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function()
        return nil
      end,
    },
    {
      target = host_runtime,
      key = "schedule",
      value = function(delay, fn)
        sound_calls[#sound_calls + 1] = { scheduled_delay = delay }
        fn()
      end,
    },
    {
      target = host_runtime,
      key = "play_3d_sound",
      value = function(pos, sound_id, duration, volume)
        sound_calls[#sound_calls + 1] = {
          sound_id = sound_id,
          duration = duration,
          volume = volume,
        }
        return 303
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {
      followup_sounds = {
        { sound_id_ref = "turn_started" },
      },
    })
    assert(played == true, "followup sound should count as played")
  end)

  assert(#sound_calls == 3, "followup sound path should include one main sound, one schedule, and one followup sound")
  assert(sound_calls[1].sound_id == runtime_refs.audio.cash_receive, "main cue sound should play first")
  assert(sound_calls[2].scheduled_delay == 0, "missing followup delay should default to zero")
  assert(sound_calls[3].sound_id == runtime_refs.audio.turn_started, "followup sound should resolve configured integer sound id")
  assert(sound_calls[3].duration == 1.0, "missing followup duration should default to 1.0")
  assert(sound_calls[3].volume == 1.0, "missing followup volume should default to 1.0")
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

local function _test_board_feedback_play_cue_with_nil_cue_name_returns_false()
  local effect_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function()
        effect_calls[#effect_calls + 1] = {}
        return 1
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_tile_cue(state, nil, 1, {})
    assert(played == false, "nil cue name should return false")
    played = board_feedback.play_tile_cue(state, "", 1, {})
    assert(played == false, "empty cue name should return false")
  end)

  assert(#effect_calls == 0, "invalid cue name should not call engine")
end

local function _test_board_feedback_play_cue_with_nil_pos_uses_default()
  local effect_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key, pos = pos }
        return 601
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
    -- Use player_cue which may have nil pos resolved
    local played = board_feedback.play_player_cue(state, "cash_burst", 999, {})
    assert(played == true, "cue should play with fallback position")
  end)

  assert(#effect_calls >= 1, "cue with fallback pos should call engine")
end

local function _test_board_feedback_play_cue_both_effect_and_sound()
  local effect_calls = {}
  local sound_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key }
        return 701
      end,
    },
    {
      target = host_runtime,
      key = "play_3d_sound",
      value = function(pos, sound_id)
        sound_calls[#sound_calls + 1] = { sound_id = sound_id }
        return 702
      end,
    },
  }, function()
    local state = _build_state()
    -- Use a cue that has both effect and sound configured
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {})
    assert(played == true, "cue with both effect and sound should play")
  end)

  assert(#effect_calls >= 1, "cue should trigger effect")
end

local function _test_board_feedback_play_cue_only_sound_no_effect()
  local effect_calls = {}
  local sound_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function()
        effect_calls[#effect_calls + 1] = {}
        return nil
      end,
    },
    {
      target = host_runtime,
      key = "play_3d_sound",
      value = function(pos, sound_id)
        sound_calls[#sound_calls + 1] = { sound_id = sound_id }
        return 801
      end,
    },
  }, function()
    local state = _build_state()
    -- Use a cue that may only have sound
    local played = board_feedback.play_sound_only(state, "turn_started", {})
    assert(played == true, "sound-only cue should play")
  end)

  assert(#sound_calls >= 1, "sound-only cue should trigger sound")
end

local function _test_board_feedback_play_cue_effect_only_returns_true()
  local effect_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos, rot, scale)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key, scale = scale }
        return 901
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
    assert(played == true, "effect-only cue should return true")
  end)

  assert(#effect_calls == 1, "effect-only cue should call play_sfx_by_key once")
end

local function _test_board_feedback_play_cue_followup_sound_with_delay()
  local sound_calls = {}
  local scheduled_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "play_sfx_by_key",
      value = function()
        return 1
      end,
    },
    {
      target = host_runtime,
      key = "schedule",
      value = function(delay, fn)
        scheduled_calls[#scheduled_calls + 1] = { delay = delay }
        fn()
      end,
    },
    {
      target = host_runtime,
      key = "play_3d_sound",
      value = function(pos, sound_id, duration, volume)
        sound_calls[#sound_calls + 1] = { sound_id = sound_id, duration = duration, volume = volume }
        return 1
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {
      followup_sounds = {
        { sound_id_ref = "turn_started", delay = 0.5, duration = 2.0, volume = 0.8 },
      },
    })
    assert(played == true, "cue with followup sound should play")
  end)

  assert(#scheduled_calls == 1, "followup sound should be scheduled")
  assert(scheduled_calls[1].delay == 0.5, "followup delay should be preserved")
  assert(#sound_calls >= 1, "followup sound should trigger play_3d_sound")
end

local function _test_board_feedback_play_cue_nil_payload_uses_defaults()
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
          with_sound = with_sound,
        }
        return 1001
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
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, nil)
    assert(played == true, "cue with nil payload should use defaults")
  end)

  assert(#effect_calls == 1, "nil payload should still call play_sfx_by_key")
end

return {
  name = "presentation.board_feedback",
  tests = {
    { name = "board_feedback_effect_id_ref_routes_integer_sfx_key", run = _test_board_feedback_effect_id_ref_routes_integer_sfx_key },
    { name = "board_feedback_tile_cue_uses_building_position_when_requested", run = _test_board_feedback_tile_cue_uses_building_position_when_requested },
    { name = "board_feedback_tile_cue_falls_back_to_tile_position_when_building_missing", run = _test_board_feedback_tile_cue_falls_back_to_tile_position_when_building_missing },
    { name = "board_feedback_tile_cue_reads_host_unit_position", run = _test_board_feedback_tile_cue_reads_host_unit_position },
    { name = "board_feedback_player_effect_binding_keeps_bind_call", run = _test_board_feedback_player_effect_binding_keeps_bind_call },
    { name = "board_feedback_cash_burst_routes_scalar_scale", run = _test_board_feedback_cash_burst_routes_scalar_scale },
    { name = "board_feedback_player_cue_prefers_explicit_payload_position", run = _test_board_feedback_player_cue_prefers_explicit_payload_position },
    { name = "board_feedback_bankruptcy_routes_scalar_scale", run = _test_board_feedback_bankruptcy_routes_scalar_scale },
    { name = "board_feedback_followup_sound_defaults_are_numeric", run = _test_board_feedback_followup_sound_defaults_are_numeric },
    { name = "board_feedback_unconfigured_effect_id_ref_skips_without_error", run = _test_board_feedback_unconfigured_effect_id_ref_skips_without_error },
    { name = "board_feedback_play_cue_with_nil_cue_name_returns_false", run = _test_board_feedback_play_cue_with_nil_cue_name_returns_false },
    { name = "board_feedback_play_cue_with_nil_pos_uses_default", run = _test_board_feedback_play_cue_with_nil_pos_uses_default },
    { name = "board_feedback_play_cue_both_effect_and_sound", run = _test_board_feedback_play_cue_both_effect_and_sound },
    { name = "board_feedback_play_cue_only_sound_no_effect", run = _test_board_feedback_play_cue_only_sound_no_effect },
    { name = "board_feedback_play_cue_effect_only_returns_true", run = _test_board_feedback_play_cue_effect_only_returns_true },
    { name = "board_feedback_play_cue_followup_sound_with_delay", run = _test_board_feedback_play_cue_followup_sound_with_delay },
    { name = "board_feedback_play_cue_nil_payload_uses_defaults", run = _test_board_feedback_play_cue_nil_payload_uses_defaults },
  },
}
