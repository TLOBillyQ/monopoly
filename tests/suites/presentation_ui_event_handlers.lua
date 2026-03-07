local support = require("TestSupport")
local _with_patches = support.with_patches
local number_utils = require("src.core.utils.number_utils")
local monopoly_event = require("src.core.events.monopoly_events")
local host_runtime = require("src.presentation.adapter.host_runtime_port")
local board_feedback = require("src.presentation.render.board_feedback_service")

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

local function _load_fresh_handlers()
  package.loaded["src.presentation.adapter.ui_event_handlers"] = nil
  return require("src.presentation.adapter.ui_event_handlers")
end

local function _test_market_buy_failed_shows_tip_for_three_seconds_without_popup()
  local handlers = {}
  local tips = {}

  _with_patches({
    {
      target = host_runtime,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = host_runtime,
      key = "show_tips",
      value = function(text, duration)
        tips[#tips + 1] = { text = text, duration = duration }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {})
    local handler = handlers[monopoly_event.market.buy_failed]
    assert(type(handler) == "function", "buy_failed handler should be registered")
    handler(nil, nil, {
      popup = {
        title = "黑市",
        body = "余额不足",
      },
    })
  end)

  assert(#tips == 1, "buy_failed should emit exactly one tip")
  assert(tips[1].text == "余额不足", "tip text should use popup body when available")
  assert(number_utils.is_numeric(tips[1].duration), "tip duration should be numeric")
  assert(tips[1].duration == 3.0, "tip duration should be exactly 3 seconds")
end

local function _test_market_buy_failed_without_popup_body_uses_fallback_tip()
  local handlers = {}
  local tips = {}

  _with_patches({
    {
      target = host_runtime,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = host_runtime,
      key = "show_tips",
      value = function(text, duration)
        tips[#tips + 1] = { text = text, duration = duration }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {})
    local handler = handlers[monopoly_event.market.buy_failed]
    assert(type(handler) == "function", "buy_failed handler should be registered")
    handler(nil, nil, {
      reason = "charge_failed",
    })
  end)

  assert(#tips == 1, "fallback buy_failed should still emit tip")
  assert(tips[1].text == "黑市购买失败", "fallback tip should use default text")
  assert(number_utils.is_numeric(tips[1].duration), "fallback duration should be numeric")
  assert(tips[1].duration == 3.0, "fallback tip duration should be exactly 3 seconds")
end

local function _test_turn_started_feedback_routes_to_player_cue()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id, payload)
        calls[#calls + 1] = {
          cue_name = cue_name,
          player_id = player_id,
        }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, { game = {} })
    local handler = handlers[monopoly_event.feedback.turn_started]
    assert(type(handler) == "function", "turn_started handler should be registered")
    handler(nil, nil, { player_id = 2 })
  end)

  assert(#calls == 1, "turn_started should route one player cue")
  assert(calls[1].cue_name == "turn_started", "turn_started cue name mismatch")
  assert(calls[1].player_id == 2, "turn_started should target payload player id")
end

local function _test_turn_started_feedback_routes_configured_audio_without_error()
  local handlers = {}
  local play_3d_sound_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = host_runtime,
      key = "play_3d_sound",
      value = function(pos, sound_id, duration, volume)
        play_3d_sound_calls[#play_3d_sound_calls + 1] = {
          sound_id = sound_id,
          duration = duration,
          volume = volume,
        }
        return 123
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {
      game = {
        find_player_by_id = function(_, player_id)
          return { id = player_id, position = 1, name = "测试玩家" }
        end,
      },
      board_scene = {
        units_by_player_id = {
          [2] = {
            get_position = function()
              return math.Vector3(0.0, 0.0, 0.0)
            end,
          },
        },
      },
    })
    local handler = handlers[monopoly_event.feedback.turn_started]
    assert(type(handler) == "function", "turn_started handler should be registered")
    handler(nil, nil, { player_id = 2 })
  end)

  assert(#play_3d_sound_calls == 1, "configured turn_started audio should call engine once")
  assert(play_3d_sound_calls[1].sound_id == 4233, "turn_started should resolve configured integer sound id")
end

local function _test_status_applied_feedback_prefers_tile_cue()
  local handlers = {}
  local tile_calls = {}
  local player_calls = 0

  _with_patches({
    {
      target = host_runtime,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = board_feedback,
      key = "play_tile_cue",
      value = function(_, cue_name, tile_index, payload)
        tile_calls[#tile_calls + 1] = {
          cue_name = cue_name,
          tile_index = tile_index,
        }
        return true
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function()
        player_calls = player_calls + 1
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, { game = {} })
    local handler = handlers[monopoly_event.feedback.status_applied]
    assert(type(handler) == "function", "status_applied handler should be registered")
    handler(nil, nil, {
      cue_name = "hospital_shock",
      player_id = 1,
      tile_index = 7,
    })
  end)

  assert(#tile_calls == 1, "status_applied should prefer tile cue when tile_index exists")
  assert(tile_calls[1].cue_name == "hospital_shock", "status_applied cue mismatch")
  assert(tile_calls[1].tile_index == 7, "status_applied tile index mismatch")
  assert(player_calls == 0, "status_applied should not fallback to player cue when tile cue is used")
end

local function _test_deity_applied_feedback_routes_specific_cue()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id, payload)
        calls[#calls + 1] = {
          cue_name = cue_name,
          player_id = player_id,
        }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, { game = {} })
    local handler = handlers[monopoly_event.feedback.deity_applied]
    assert(type(handler) == "function", "deity_applied handler should be registered")
    handler(nil, nil, {
      player_id = 3,
      deity_type = "angel",
    })
  end)

  assert(#calls == 1, "deity_applied should route one player cue")
  assert(calls[1].cue_name == "angel_deity", "deity cue name mismatch")
  assert(calls[1].player_id == 3, "deity cue should target payload player id")
end

local function _test_negative_chance_routes_generic_negative_cue()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function(_, cue_name, player_id, payload)
        calls[#calls + 1] = {
          cue_name = cue_name,
          player_id = player_id,
        }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, { game = {} })
    local handler = handlers[monopoly_event.chance.applied]
    assert(type(handler) == "function", "chance.applied handler should be registered")
    handler(nil, nil, {
      player = { id = 4 },
      card = { negative = true },
    })
  end)

  assert(#calls == 1, "negative chance should route one player cue")
  assert(calls[1].cue_name == "generic_negative", "negative chance cue mismatch")
  assert(calls[1].player_id == 4, "negative chance should target payload player id")
end

return {
  name = "presentation_ui.event_handlers",
  tests = {
    {
      name = "market_buy_failed_shows_tip_for_three_seconds_without_popup",
      run = _test_market_buy_failed_shows_tip_for_three_seconds_without_popup,
    },
    {
      name = "market_buy_failed_without_popup_body_uses_fallback_tip",
      run = _test_market_buy_failed_without_popup_body_uses_fallback_tip,
    },
    {
      name = "turn_started_feedback_routes_to_player_cue",
      run = _test_turn_started_feedback_routes_to_player_cue,
    },
    {
      name = "turn_started_feedback_routes_configured_audio_without_error",
      run = _test_turn_started_feedback_routes_configured_audio_without_error,
    },
    {
      name = "status_applied_feedback_prefers_tile_cue",
      run = _test_status_applied_feedback_prefers_tile_cue,
    },
    {
      name = "deity_applied_feedback_routes_specific_cue",
      run = _test_deity_applied_feedback_routes_specific_cue,
    },
    {
      name = "negative_chance_routes_generic_negative_cue",
      run = _test_negative_chance_routes_generic_negative_cue,
    },
  },
}
