-- presentation.board_feedback 与 board_feedback.catalog 的行为规约。
--
-- 原生 LuaUnit(busted → LuaUnit 迁移):两个 describe 均无钩子,合并拍平为
-- TestBoardFeedback 单类,裸 assert(cond, msg) 机械映射为 lu.assertEvalToTrue,
-- 用例数与改写前一一对应(21 + 1 = 22 例)。
local lu = require("luaunit")
local host_sfx = require("src.ui.seams.host_sfx")
local ui_host_runtime = require("src.ui.seams.host_runtime")

local board_feedback = require("src.ui.render.board_feedback.service")
local runtime_refs = require("src.config.content.runtime_refs")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local effect_track = require("src.ui.render.support.effect_track")
local logger = require("src.foundation.log")
local tip_queue = require("src.foundation.tips")
local runtime_context = require("src.host.context")

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed")
    .. " expected=" .. tostring(expected)
    .. " actual=" .. tostring(actual))
end

local function _reload_with(module_name, overrides, fn)
  local original_module = package.loaded[module_name]
  local originals = {}
  for key, value in pairs(overrides or {}) do
    originals[key] = package.loaded[key]
    package.loaded[key] = value
  end
  package.loaded[module_name] = nil

  local ok, result = pcall(function()
    return fn(require(module_name))
  end)

  package.loaded[module_name] = original_module
  for key, value in pairs(originals) do
    package.loaded[key] = value
  end
  if not ok then
    error(result)
  end
  return result
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

TestBoardFeedback = {}

function TestBoardFeedback:test_board_feedback_effect_id_ref_routes_integer_sfx_key()
  local effect_calls = {}

  _with_patches({
    {
      target = host_sfx,
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
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {})
    lu.assertEvalToTrue(played == true, "configured effect cue should play")
  end)

  lu.assertEvalToTrue(#effect_calls == 1, "effect cue should call engine once")
  lu.assertEvalToTrue(effect_calls[1].sfx_key == runtime_refs.effects.upgrade_land_smoke, "effect id ref should resolve to integer sfx key")
  lu.assertEvalToTrue(effect_calls[1].scale == 3.0, "upgrade_land_smoke should use scalar scale")
end

function TestBoardFeedback:test_board_feedback_tile_cue_uses_building_position_when_requested()
  local effect_calls = {}

  _with_patches({
    {
      target = host_sfx,
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
      target = host_sfx,
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
    lu.assertEvalToTrue(played == true, "configured effect cue should play from building position")
  end)

  lu.assertEvalToTrue(#effect_calls == 1, "building-position tile cue should call engine once")
  lu.assertEvalToTrue(effect_calls[1].pos.x == 10.0, "building-position tile cue should use building x")
  lu.assertEvalToTrue(effect_calls[1].pos.y == 0.0, "building-position tile cue should use building y")
  lu.assertEvalToTrue(effect_calls[1].pos.z == 0.0, "building-position tile cue should use building z")
end

function TestBoardFeedback:test_board_feedback_tile_cue_falls_back_to_tile_position_when_building_missing()
  local effect_calls = {}

  _with_patches({
    {
      target = host_sfx,
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
      target = host_sfx,
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
    lu.assertEvalToTrue(played == true, "tile cue should fall back to tile position when building is missing")
  end)

  lu.assertEvalToTrue(#effect_calls == 1, "fallback tile cue should call engine once")
  lu.assertEvalToTrue(effect_calls[1].pos.x == 0.0, "fallback tile cue should use tile x")
  lu.assertEvalToTrue(effect_calls[1].pos.y == 0.0, "fallback tile cue should use tile y")
  lu.assertEvalToTrue(effect_calls[1].pos.z == 0.0, "fallback tile cue should use tile z")
end

function TestBoardFeedback:test_board_feedback_tile_cue_reads_host_unit_position()
  local effect_calls = {}
  local state = _build_state()
  state.board_scene.tiles[1] = _make_host_unit(21.0, 22.0, 23.0)

  _with_patches({
    {
      target = host_sfx,
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
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {})
    lu.assertEvalToTrue(played == true, "board feedback should play on host unit position")
  end)

  lu.assertEvalToTrue(#effect_calls == 1, "board feedback should call engine once for host unit position")
  lu.assertEvalToTrue(effect_calls[1].pos.x == 21.0, "board feedback should use host unit x")
  lu.assertEvalToTrue(effect_calls[1].pos.y == 22.0, "board feedback should use host unit y")
  lu.assertEvalToTrue(effect_calls[1].pos.z == 23.0, "board feedback should use host unit z")
end

function TestBoardFeedback:test_board_feedback_effect_params_keep_payload_overrides_and_defaults()
  local effect_calls = {}
  local spawn_calls = {}
  local scaled_inputs = {}
  local payload_rot = { id = "payload-rot" }

  _with_patches({
    {
      target = effect_track,
      key = "scaled_duration",
      value = function(raw_duration)
        scaled_inputs[#scaled_inputs + 1] = raw_duration
        return raw_duration + 10.0
      end,
    },
    {
      target = effect_track,
      key = "spawn",
      value = function(cue_name, kind, duration)
        spawn_calls[#spawn_calls + 1] = {
          cue_name = cue_name,
          kind = kind,
          duration = duration,
        }
        return { cue_name = cue_name }
      end,
    },
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos, rot, scale, duration, rate, with_sound)
        effect_calls[#effect_calls + 1] = {
          sfx_key = sfx_key,
          rot = rot,
          scale = scale,
          duration = duration,
          rate = rate,
          with_sound = with_sound,
        }
        return 650
      end,
    },
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {
      duration = 2.0,
      scale = 2.5,
      rot = payload_rot,
      rate = 0.75,
      with_sound = true,
      followup_sounds = {},
    })
    lu.assertEvalToTrue(played == true, "payload effect params should play")

    played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {
      followup_sounds = {},
    })
    lu.assertEvalToTrue(played == true, "default effect params should play")
  end)

  lu.assertEvalToTrue(#effect_calls == 2, "effect params test should call engine twice")
  lu.assertEvalToTrue(scaled_inputs[1] == 2.0, "payload duration should be scaled from raw payload duration")
  lu.assertEvalToTrue(effect_calls[1].duration == 12.0, "payload duration should use scaled duration")
  lu.assertEvalToTrue(effect_calls[1].scale == 2.5, "payload scale should override cue scale")
  lu.assertEvalToTrue(effect_calls[1].rot == payload_rot, "payload rotation should override default rotation")
  lu.assertEvalToTrue(effect_calls[1].rate == 0.75, "payload rate should override default rate")
  lu.assertEvalToTrue(effect_calls[1].with_sound == true, "payload with_sound should override default")
  lu.assertEvalToTrue(spawn_calls[1].duration == 12.0, "effect track should receive scaled payload duration")

  lu.assertEvalToTrue(scaled_inputs[2] == 1.0, "cue duration should be scaled when payload duration is absent")
  lu.assertEvalToTrue(effect_calls[2].rot == runtime_constants.q_zero, "missing rotation should use default rotation")
  lu.assertEvalToTrue(effect_calls[2].rate == 1.0, "missing rate should use default rate")
  lu.assertEvalToTrue(effect_calls[2].with_sound == false, "missing with_sound should use default")
  lu.assertEvalToTrue(spawn_calls[2].duration == 11.0, "effect track should receive scaled default duration")
end

function TestBoardFeedback:test_board_feedback_effect_returns_false_when_host_runtime_cannot_play_sfx()
  local state = _build_state()
  local played = board_feedback.play_tile_cue(state, "item_stop_highlight", 1, {
    followup_sounds = {},
  }, {
    host_runtime = {},
  })

  lu.assertEvalToTrue(played == false, "effect-only cue should fail without a playable host runtime")
end

function TestBoardFeedback:test_board_feedback_does_not_bind_unbound_cue_to_player_unit()
  local bind_calls = 0
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
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function()
        return 651
      end,
    },
    {
      target = host_sfx,
      key = "bind_sfx_to_unit",
      value = function()
        bind_calls = bind_calls + 1
      end,
    },
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {
      player_id = 1,
      followup_sounds = {},
    })
    lu.assertEvalToTrue(played == true, "unbound cue should still play")
  end)

  lu.assertEvalToTrue(bind_calls == 0, "cue without bind_to_player should not bind to the player unit")
end

function TestBoardFeedback:test_board_feedback_effect_only_failures_return_false()
  local play_calls = 0

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function()
        play_calls = play_calls + 1
        return nil
      end,
    },
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_tile_cue(state, "item_stop_highlight", 1, {
      effect_id_ref = "missing_effect_ref_for_test",
      followup_sounds = {},
    })
    lu.assertEvalToTrue(played == false, "missing effect id on effect-only cue should return false")

    played = board_feedback.play_tile_cue(state, "item_stop_highlight", 1, {
      followup_sounds = {},
    })
    lu.assertEvalToTrue(played == false, "nil runtime sfx id on effect-only cue should return false")
  end)

  lu.assertEvalToTrue(play_calls == 1, "missing effect id should skip engine call before nil sfx handle case")
end

function TestBoardFeedback:test_board_feedback_player_effect_binding_keeps_bind_call()
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
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos, rot, scale)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key, scale = scale }
        return 777
      end,
    },
    {
      target = host_sfx,
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
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local played = board_feedback.play_player_cue(state, "rich_deity", 1, {})
    lu.assertEvalToTrue(played == true, "bound player effect should play")
  end)

  lu.assertEvalToTrue(#effect_calls == 1, "player effect should call engine once")
  lu.assertEvalToTrue(effect_calls[1].sfx_key == runtime_refs.effects.rich_deity, "player effect should resolve configured integer sfx key")
  lu.assertEvalToTrue(effect_calls[1].scale == 1.4, "player effect should use scalar scale")
  lu.assertEvalToTrue(#bind_calls == 1, "player effect should still bind to unit")
  lu.assertEvalToTrue(bind_calls[1].sfx_id == 777, "bind call should receive runtime sfx handle")
end

function TestBoardFeedback:test_board_feedback_cash_burst_routes_scalar_scale()
  local effect_calls = {}

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos, rot, scale)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key, scale = scale }
        return 888
      end,
    },
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_player_cue(state, "cash_burst", 1, {})
    lu.assertEvalToTrue(played == true, "cash_burst should play")
  end)

  lu.assertEvalToTrue(#effect_calls == 1, "cash_burst should call engine once")
  lu.assertEvalToTrue(effect_calls[1].sfx_key == runtime_refs.effects.cash_burst, "cash_burst should resolve configured integer sfx key")
  lu.assertEvalToTrue(effect_calls[1].scale == 1.6, "cash_burst should use scalar scale")
end

function TestBoardFeedback:test_board_feedback_player_cue_prefers_explicit_payload_position()
  local effect_calls = {}
  local explicit_pos = math.Vector3(9.0, 8.0, 7.0)

  _with_patches({
    {
      target = host_sfx,
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
      target = host_sfx,
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
    lu.assertEvalToTrue(played == true, "player cue should play when explicit position is provided")
  end)

  lu.assertEvalToTrue(#effect_calls == 1, "explicit player cue should call engine once")
  lu.assertEvalToTrue(effect_calls[1].pos == explicit_pos, "explicit payload position should override resolved player position")
end

function TestBoardFeedback:test_board_feedback_bankruptcy_routes_scalar_scale()
  local effect_calls = {}

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos, rot, scale)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key, scale = scale }
        return 999
      end,
    },
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_player_cue(state, "bankruptcy_slam", 1, {})
    lu.assertEvalToTrue(played == true, "bankruptcy_slam should play")
  end)

  lu.assertEvalToTrue(#effect_calls == 1, "bankruptcy_slam should call engine once")
  lu.assertEvalToTrue(effect_calls[1].sfx_key == runtime_refs.effects.bankruptcy_slam, "bankruptcy should resolve configured integer sfx key")
  lu.assertEvalToTrue(effect_calls[1].scale == 1.0, "bankruptcy should fallback to scalar scale 1.0")
end

function TestBoardFeedback:test_board_feedback_followup_sound_defaults_are_numeric()
  local sound_calls = {}

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function()
        return nil
      end,
    },
    {
      target = ui_host_runtime,
      key = "schedule",
      value = function(delay, fn)
        sound_calls[#sound_calls + 1] = { scheduled_delay = delay }
        fn()
      end,
    },
    {
      target = host_sfx,
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
    lu.assertEvalToTrue(played == true, "followup sound should count as played")
  end)

  lu.assertEvalToTrue(#sound_calls == 3, "followup sound path should include one main sound, one schedule, and one followup sound")
  lu.assertEvalToTrue(sound_calls[1].sound_id == runtime_refs.audio.cash_receive, "main cue sound should play first")
  lu.assertEvalToTrue(sound_calls[2].scheduled_delay == 0, "missing followup delay should default to zero")
  lu.assertEvalToTrue(sound_calls[3].sound_id == runtime_refs.audio.turn_started, "followup sound should resolve configured integer sound id")
  lu.assertEvalToTrue(sound_calls[3].duration == 1.0, "missing followup duration should default to 1.0")
  lu.assertEvalToTrue(sound_calls[3].volume == 1.0, "missing followup volume should default to 1.0")
end

function TestBoardFeedback:test_board_feedback_unconfigured_effect_id_ref_skips_without_error()
  local play_calls = 0

  _with_patches({
    {
      target = host_sfx,
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
    lu.assertEvalToTrue(played == true, "followup sound scheduling may still keep cue successful")
  end)

  lu.assertEvalToTrue(play_calls == 0, "missing effect ref should not call engine")
end

function TestBoardFeedback:test_board_feedback_play_cue_with_nil_cue_name_returns_false()
  local effect_calls = {}

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function()
        effect_calls[#effect_calls + 1] = {}
        return 1
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_tile_cue(state, nil, 1, {})
    lu.assertEvalToTrue(played == false, "nil cue name should return false")
    played = board_feedback.play_tile_cue(state, "", 1, {})
    lu.assertEvalToTrue(played == false, "empty cue name should return false")
  end)

  lu.assertEvalToTrue(#effect_calls == 0, "invalid cue name should not call engine")
end

function TestBoardFeedback:test_board_feedback_play_cue_with_nil_pos_uses_default()
  local effect_calls = {}

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key, pos = pos }
        return 601
      end,
    },
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local state = _build_state()
    -- Use player_cue which may have nil pos resolved
    local played = board_feedback.play_player_cue(state, "cash_burst", 999, {})
    lu.assertEvalToTrue(played == true, "cue should play with fallback position")
  end)

  lu.assertEvalToTrue(#effect_calls >= 1, "cue with fallback pos should call engine")
end

function TestBoardFeedback:test_board_feedback_play_cue_both_effect_and_sound()
  local effect_calls = {}
  local sound_calls = {}

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key }
        return 701
      end,
    },
    {
      target = host_sfx,
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
    lu.assertEvalToTrue(played == true, "cue with both effect and sound should play")
  end)

  lu.assertEvalToTrue(#effect_calls >= 1, "cue should trigger effect")
end

function TestBoardFeedback:test_board_feedback_play_cue_only_sound_no_effect()
  local effect_calls = {}
  local sound_calls = {}

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function()
        effect_calls[#effect_calls + 1] = {}
        return nil
      end,
    },
    {
      target = host_sfx,
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
    lu.assertEvalToTrue(played == true, "sound-only cue should play")
  end)

  lu.assertEvalToTrue(#sound_calls >= 1, "sound-only cue should trigger sound")
end

function TestBoardFeedback:test_board_feedback_play_cue_effect_only_returns_true()
  local effect_calls = {}

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function(sfx_key, pos, rot, scale)
        effect_calls[#effect_calls + 1] = { sfx_key = sfx_key, scale = scale }
        return 901
      end,
    },
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, {})
    lu.assertEvalToTrue(played == true, "effect-only cue should return true")
  end)

  lu.assertEvalToTrue(#effect_calls == 1, "effect-only cue should call play_sfx_by_key once")
end

function TestBoardFeedback:test_board_feedback_play_cue_followup_sound_with_delay()
  local sound_calls = {}
  local scheduled_calls = {}

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function()
        return 1
      end,
    },
    {
      target = ui_host_runtime,
      key = "schedule",
      value = function(delay, fn)
        scheduled_calls[#scheduled_calls + 1] = { delay = delay }
        fn()
      end,
    },
    {
      target = host_sfx,
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
    lu.assertEvalToTrue(played == true, "cue with followup sound should play")
  end)

  lu.assertEvalToTrue(#scheduled_calls == 1, "followup sound should be scheduled")
  lu.assertEvalToTrue(scheduled_calls[1].delay == 0.5, "followup delay should be preserved")
  lu.assertEvalToTrue(#sound_calls >= 1, "followup sound should trigger play_3d_sound")
end

function TestBoardFeedback:test_board_feedback_play_cue_nil_payload_uses_defaults()
  local effect_calls = {}

  _with_patches({
    {
      target = host_sfx,
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
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_tile_cue(state, "upgrade_land_smoke", 1, nil)
    lu.assertEvalToTrue(played == true, "cue with nil payload should use defaults")
  end)

  lu.assertEvalToTrue(#effect_calls == 1, "nil payload should still call play_sfx_by_key")
end

function TestBoardFeedback:test_resolves_numeric_cue_fields_and_rejects_non_numeric_ones()
  local warns = 0
  _reload_with("src.ui.render.board_feedback.catalog", {
    ["src.config.content.runtime_refs"] = {
      board_feedback = {
        my_cue = {
          scale = 2,
          rate = { x = 1 },          -- vector-like: rejected with a warning
          duration = "abc",          -- non-numeric: rejected with a warning
          volume = nil,              -- absent: stays nil, no warning
          delay = 3,
          followup_sounds = { { delay = "nope" } }, -- nested non-numeric: warns
        },
      },
    },
    ["src.foundation.log"] = {
      warn = function() warns = warns + 1 end,
      info = function() end,
      error = function() end,
    },
  }, function(reloaded_catalog)
    _assert_eq(reloaded_catalog.get(nil), nil, "nil cue name resolves to nil")
    _assert_eq(reloaded_catalog.get("unknown"), nil, "an unknown cue resolves to nil")

    local cue = reloaded_catalog.get("my_cue")
    _assert_eq(cue.scale, 2, "numeric field passes through")
    _assert_eq(cue.delay, 3, "numeric field passes through")
    _assert_eq(cue.rate, nil, "vector-like field is rejected")
    _assert_eq(cue.duration, nil, "non-numeric string field is rejected")
  end)
  lu.assertEvalToTrue(warns >= 3, "vector, non-numeric, and nested non-numeric fields should warn (got " .. warns .. ")")
end

function TestBoardFeedback:test_board_feedback_resolves_player_unit_from_state_player_units()
  -- kills _resolve_player_unit 的 player_units 回落换 nil:units_by_player_id
  -- 缺失但 state.player_units 提供 unit 时必须能绑定到该 unit。
  local bind_calls = 0
  local state = _build_state()
  state.player_units = {
    [1] = {
      get_position = function()
        return math.Vector3(1.0, 2.0, 3.0)
      end,
    },
  }

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function()
        return 651
      end,
    },
    {
      target = host_sfx,
      key = "bind_sfx_to_unit",
      value = function()
        bind_calls = bind_calls + 1
      end,
    },
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local played = board_feedback.play_player_cue(state, "cash_burst", 1, {})
    lu.assertEvalToTrue(played == true, "player cue should play with unit resolved from state.player_units")
  end)

  lu.assertEvalToTrue(bind_calls == 1, "cash_burst should bind to the unit resolved from player_units")
end

function TestBoardFeedback:test_board_feedback_tile_cue_resolves_unit_from_payload_player_id()
  -- kills _cue_player_unit 的 _resolve_player_unit 换 nil:play_tile_cue 带
  -- payload.player_id 时必须解析出 unit 供绑定。
  local bind_calls = 0
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
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function()
        return 651
      end,
    },
    {
      target = host_sfx,
      key = "bind_sfx_to_unit",
      value = function()
        bind_calls = bind_calls + 1
      end,
    },
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local played = board_feedback.play_tile_cue(state, "cash_burst", 1, { player_id = 1 })
    lu.assertEvalToTrue(played == true, "tile cue with payload player_id should play")
  end)

  lu.assertEvalToTrue(bind_calls == 1, "tile cue with payload player_id should bind to the player unit")
end

function TestBoardFeedback:test_board_feedback_play_sound_only_resolves_player_unit_position()
  -- kills play_sound_only pos 链的玩家段:无 payload.pos 但有 player_id 时,
  -- 位置必须解析自玩家 unit(_resolve_player_position 换 nil / 链上
  -- _player_pos_or_nil 换 nil / 链上 or->and 都会退化成 v3_zero)。
  local sound_pos = nil
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
      target = host_sfx,
      key = "play_3d_sound",
      value = function(pos)
        sound_pos = pos
        return 802
      end,
    },
  }, function()
    local played = board_feedback.play_sound_only(state, "turn_started", { player_id = 1 })
    lu.assertEvalToTrue(played == true, "sound-only cue with player_id should play")
  end)

  lu.assertEvalToTrue(sound_pos.x == 1.0, "sound-only cue should use the player unit position x")
  lu.assertEvalToTrue(sound_pos.y == 2.0, "sound-only cue should use the player unit position y")
  lu.assertEvalToTrue(sound_pos.z == 3.0, "sound-only cue should use the player unit position z")
end

function TestBoardFeedback:test_board_feedback_play_sound_only_resolves_tile_position()
  -- kills play_sound_only pos 链的 tile 段:无 pos/player_id 但有 tile_index 时,
  -- 位置必须解析自场景 tile(_resolve_tile_position 换 nil / 链上
  -- _tile_pos_or_nil 换 nil 都会退化成 v3_zero)。
  local sound_pos = nil
  local state = _build_state()
  state.board_scene.tiles[1] = {
    get_position = function()
      return math.Vector3(5.0, 6.0, 7.0)
    end,
  }

  _with_patches({
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function(pos)
        sound_pos = pos
        return 803
      end,
    },
  }, function()
    local played = board_feedback.play_sound_only(state, "turn_started", { tile_index = 1 })
    lu.assertEvalToTrue(played == true, "sound-only cue with tile_index should play")
  end)

  lu.assertEvalToTrue(sound_pos.x == 5.0, "sound-only cue should use the tile position x")
  lu.assertEvalToTrue(sound_pos.y == 6.0, "sound-only cue should use the tile position y")
  lu.assertEvalToTrue(sound_pos.z == 7.0, "sound-only cue should use the tile position z")
end

function TestBoardFeedback:test_board_feedback_tile_cue_binds_resolved_unit_not_player_id()
  -- kills _cue_player_unit 的 and->or:payload.player_id 存在时必须返回解析出的
  -- unit 表(变异体短路返回 player_id 本身,绑定目标变成裸 id)。
  local bound_unit = nil
  local state = _build_state()
  local unit = {
    get_position = function()
      return math.Vector3(1.0, 2.0, 3.0)
    end,
  }
  state.board_scene.units_by_player_id = {
    [1] = unit,
  }

  _with_patches({
    {
      target = host_sfx,
      key = "play_sfx_by_key",
      value = function()
        return 651
      end,
    },
    {
      target = host_sfx,
      key = "bind_sfx_to_unit",
      value = function(sfx_id, bound)
        bound_unit = bound
        return true
      end,
    },
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function()
        return nil
      end,
    },
  }, function()
    local played = board_feedback.play_tile_cue(state, "cash_burst", 1, { player_id = 1 })
    lu.assertEvalToTrue(played == true, "tile cue with payload player_id should play")
  end)

  lu.assertEvalToTrue(bound_unit == unit, "bind should target the resolved player unit, not the bare player id")
end

function TestBoardFeedback:test_board_feedback_play_step_tile_sound_forwards_pounce_cue()
  -- kills play_step_tile_sound 的 "move_step_pounce" 换 nil 与整调用换 nil:
  -- 必须转发 pounce cue 名并携带 player_id/tile_index,返回透传。
  local forwarded = nil
  local returned = nil

  _with_patches({
    {
      target = board_feedback,
      key = "play_sound_only",
      value = function(state_arg, cue_name, payload, deps)
        forwarded = {
          cue_name = cue_name,
          player_id = payload.player_id,
          tile_index = payload.tile_index,
        }
        return true
      end,
    },
  }, function()
    returned = board_feedback.play_step_tile_sound({}, 3, 5, {})
  end)

  lu.assertEvalToTrue(returned == true, "play_step_tile_sound should pass through the play result")
  lu.assertEvalToTrue(forwarded ~= nil, "play_step_tile_sound should forward to play_sound_only")
  lu.assertEvalToTrue(forwarded.cue_name == "move_step_pounce", "play_step_tile_sound should use the pounce cue")
  lu.assertEvalToTrue(forwarded.player_id == 3, "play_step_tile_sound should forward the player id")
  lu.assertEvalToTrue(forwarded.tile_index == 5, "play_step_tile_sound should forward the tile index")
end

function TestBoardFeedback:test_board_feedback_play_sound_only_prefers_explicit_payload_position()
  -- kills play_sound_only pos 链第一段 or->and:payload.pos 显式时必须原样
  -- 传给 play_3d_sound(变异体把链压成 nil)。
  local sound_pos = nil
  local explicit_pos = math.Vector3(9.0, 8.0, 7.0)

  _with_patches({
    {
      target = host_sfx,
      key = "play_3d_sound",
      value = function(pos)
        sound_pos = pos
        return 801
      end,
    },
  }, function()
    local state = _build_state()
    local played = board_feedback.play_sound_only(state, "turn_started", { pos = explicit_pos })
    lu.assertEvalToTrue(played == true, "sound-only cue with explicit pos should play")
  end)

  lu.assertEvalToTrue(sound_pos == explicit_pos, "explicit payload position should reach play_3d_sound")
end

function TestBoardFeedback:test_empty_cue_name_skips_catalog_lookup()
  -- 杀 L73 两个位点(and->or 与 ""->nil):空串 cue_name 不得进 catalog 查询。
  local catalog = require("src.ui.render.board_feedback.catalog")
  local lookups = 0
  _with_patches({
    { target = catalog, key = "get", value = function()
      lookups = lookups + 1
      return nil
    end },
  }, function()
    local state = {
      board_scene = {
        tiles = {
          { get_position = function() return { x = 0, y = 0, z = 0 } end },
        },
      },
    }
    local played = board_feedback.play_tile_cue(state, "", 1, {})
    lu.assertEvalToTrue(played == false, "empty cue name should not play anything")
  end)
  lu.assertEvalToTrue(lookups == 0, "empty cue name must not reach the catalog")
end


return TestBoardFeedback
