local support = require("support.presentation_support")
local _with_patches = support.with_patches
local number_utils = require("src.core.utils.number_utils")
local monopoly_event = require("src.core.events.monopoly_events")
local host_runtime = require("src.host.eggy")
local board_feedback = require("src.ui.render.board_feedback_service")
local landing_visual_hold = require("src.state.state_access.landing_visual_hold")

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

local function _load_fresh_handlers()
  package.loaded["src.ui.ctl.event_handlers"] = nil
  return require("src.ui.ctl.event_handlers")
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

local function _test_market_bought_item_plays_immediate_cash_burst()
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
    local handler = handlers[monopoly_event.market.bought_item]
    assert(type(handler) == "function", "bought_item handler should be registered")
    handler(nil, nil, {
      player = { id = 3, name = "测试玩家" },
      entry = { product_id = 2003, kind = "item" },
      price = 500,
      currency = "金币",
      text = "测试玩家 在黑市购买 路障卡 花费 500 金币",
    })
  end)

  assert(#calls >= 1, "bought_item should play at least one player cue")
  local found_cash_burst = false
  for _, call in ipairs(calls) do
    if call.cue_name == "cash_burst" and call.player_id == 3 then
      found_cash_burst = true
    end
  end
  assert(found_cash_burst, "bought_item should play immediate cash_burst on buyer")
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

local function _test_roadblock_hit_no_longer_drives_visual_feedback()
  local handlers = {}
  local cleared = 0

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
      target = require("src.ui.render.action_anim"),
      key = "clear_overlay",
      value = function()
        cleared = cleared + 1
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {
      game = {
        board = {
          index_of_tile_id = function(_, tile_id)
            if tile_id == 12 then
              return 7
            end
            return nil
          end,
        },
      },
    })
    local handler = handlers[monopoly_event.movement.roadblock_hit]
    assert(type(handler) == "function", "roadblock_hit handler should be registered")
    handler(nil, nil, { tile_id = 12 })
  end)

  assert(cleared == 0, "roadblock_hit should no longer clear overlay directly")
end

local function _test_mine_hit_no_longer_drives_visual_feedback()
  local handlers = {}
  local cleared = 0
  local cues = 0

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
      target = require("src.ui.render.action_anim"),
      key = "clear_overlay",
      value = function()
        cleared = cleared + 1
      end,
    },
    {
      target = board_feedback,
      key = "play_player_cue",
      value = function()
        cues = cues + 1
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {
      game = {
        board = {
          index_of_tile_id = function(_, tile_id)
            if tile_id == 20 then
              return 11
            end
            return nil
          end,
        },
      },
    })
    local handler = handlers[monopoly_event.land.mine_hit]
    assert(type(handler) == "function", "mine_hit handler should be registered")
    handler(nil, nil, {
      tile = { id = 20 },
      player = { id = 3 },
    })
  end)

  assert(cleared == 0, "mine_hit should no longer clear overlay directly")
  assert(cues == 0, "mine_hit should no longer emit direct cue playback")
end

local function _test_turn_started_feedback_defers_during_landing_hold()
  local handlers = {}
  local calls = {}
  local state = {
      game = {
        turn = {
          landing_visual_hold_active = true,
          landing_visual_release_pending = false,
        },
        dirty = {
          any = false,
        turn = false,
      },
    },
  }

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
      value = function(_, cue_name, player_id)
        calls[#calls + 1] = { cue_name = cue_name, player_id = player_id }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, state)
    local handler = handlers[monopoly_event.feedback.turn_started]
    assert(type(handler) == "function", "turn_started handler should be registered")
    handler(nil, nil, { player_id = 5 })
    assert(#calls == 0, "landing hold should defer turn_started cue")

      local hold = state.turn_runtime and state.turn_runtime.landing_visual_hold or nil
      assert(hold and #hold.release_callbacks == 1, "landing hold should queue deferred runtime event")
      assert(hold.release_callbacks[1].key == "runtime_event", "landing hold should register runtime_event callback")

    state.game.turn.landing_visual_release_pending = true
    landing_visual_hold.release(state, state.game)
  end)

  assert(#calls == 1, "releasing landing hold should replay deferred runtime event")
  assert(calls[1].cue_name == "turn_started", "replayed turn_started cue mismatch")
  assert(calls[1].player_id == 5, "replayed turn_started player mismatch")
end

local function _test_game_result_feedback_routes_winner_and_loser_panels()
  local handlers = {}
  local role_calls = {}

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
      target = require("src.core.ports.runtime_ports"),
      key = "resolve_role",
      value = function(player_id)
        role_calls[player_id] = role_calls[player_id] or { wins = 0, loses = 0 }
        return {
          game_win_and_show_result_panel = function()
            role_calls[player_id].wins = role_calls[player_id].wins + 1
          end,
          lose = function()
            role_calls[player_id].loses = role_calls[player_id].loses + 1
          end,
        }
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {
      game = {
        players = {
          { id = 1, name = "P1" },
          { id = 2, name = "P2" },
          { id = 3, name = "P3" },
        },
      },
    })
    local handler = handlers[monopoly_event.game.finished]
    assert(type(handler) == "function", "game_finished handler should be registered")
    handler(nil, nil, {
      winner_ids = {
        [2] = true,
      },
    })
  end)

  assert(role_calls[1].wins == 0 and role_calls[1].loses == 1, "loser should call lose once")
  assert(role_calls[2].wins == 1 and role_calls[2].loses == 0, "winner should show result panel once")
  assert(role_calls[3].wins == 0 and role_calls[3].loses == 1, "other loser should call lose once")
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
      name = "roadblock_hit_no_longer_drives_visual_feedback",
      run = _test_roadblock_hit_no_longer_drives_visual_feedback,
    },
    {
      name = "mine_hit_no_longer_drives_visual_feedback",
      run = _test_mine_hit_no_longer_drives_visual_feedback,
    },
    {
      name = "turn_started_feedback_routes_to_player_cue",
      run = _test_turn_started_feedback_routes_to_player_cue,
    },
    {
      name = "market_bought_item_plays_immediate_cash_burst",
      run = _test_market_bought_item_plays_immediate_cash_burst,
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
    {
      name = "turn_started_feedback_defers_during_landing_hold",
      run = _test_turn_started_feedback_defers_during_landing_hold,
    },
    {
      name = "game_result_feedback_routes_winner_and_loser_panels",
      run = _test_game_result_feedback_routes_winner_and_loser_panels,
    },
  },
}
