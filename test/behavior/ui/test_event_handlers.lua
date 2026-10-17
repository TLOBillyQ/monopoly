-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
-- luacheck: ignore 211
local support = require("test.support.shared_support")
local _with_patches = support.with_patches
local number_utils = require("src.foundation.number")
local monopoly_event = require("src.foundation.events")
local tip_queue = require("src.foundation.tips")
local host_events = require("src.ui.seams.host_events")
local host_sfx = require("src.ui.seams.host_sfx")
local board_feedback = require("src.ui.render.board_feedback.service")
local panel_interrupt = require("src.ui.state.panel_interrupt")
local landing_visual_hold = require("src.state.visual_hold")

local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

local function _load_fresh_handlers()
  -- event_handlers 拆分后子模块在加载期捕获 tip_queue.enqueue 等桩,须一并清缓存。
  package.loaded["src.ui.coord.event_handlers"] = nil
  package.loaded["src.ui.coord.market_tip_handlers"] = nil
  package.loaded["src.ui.coord.board_feedback_handlers"] = nil
  package.loaded["src.ui.coord.endgame_result_panels"] = nil
  package.loaded["src.ui.coord.tile_index_handlers"] = nil
  return require("src.ui.coord.event_handlers")
end


describe("TestEventHandlers", function()
  local loaded_before_case
  before_each(function()
    loaded_before_case = {}
    for name, object in pairs(package.loaded) do
      if name:match("^src%.") then loaded_before_case[name] = object end
    end
  end)
  after_each(function()
    for name in pairs(package.loaded) do
      if name:match("^src%.") and loaded_before_case[name] == nil then package.loaded[name] = nil end
    end
    for name, object in pairs(loaded_before_case) do package.loaded[name] = object end
  end)


it("test_market_buy_failed_shows_tip_for_three_seconds_without_popup", function()
  local handlers = {}
  local tips = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = tip_queue,
      key = "enqueue",
      value = function(intent)
        tips[#tips + 1] = { text = intent.text, duration = intent.duration }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {})
    local handler = handlers[monopoly_event.market.buy_failed]
    luassert.truthy(type(handler) == "function", "buy_failed handler should be registered")
    handler(nil, nil, {
      popup = {
        title = "黑市",
        body = "余额不足",
      },
    })
  end)

  luassert.truthy(#tips == 1, "buy_failed should emit exactly one tip")
  luassert.truthy(tips[1].text == "余额不足", "tip text should use popup body when available")
  luassert.truthy(number_utils.is_numeric(tips[1].duration), "tip duration should be numeric")
  luassert.truthy(tips[1].duration == 3.0, "tip duration should be exactly 3 seconds")
end)

it("test_market_buy_failed_without_popup_body_uses_fallback_tip", function()
  local handlers = {}
  local tips = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = tip_queue,
      key = "enqueue",
      value = function(intent)
        tips[#tips + 1] = { text = intent.text, duration = intent.duration }
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {})
    local handler = handlers[monopoly_event.market.buy_failed]
    luassert.truthy(type(handler) == "function", "buy_failed handler should be registered")
    handler(nil, nil, {
      reason = "charge_failed",
    })
  end)

  luassert.truthy(#tips == 1, "fallback buy_failed should still emit tip")
  luassert.truthy(tips[1].text == "黑市购买失败", "fallback tip should use default text")
  luassert.truthy(number_utils.is_numeric(tips[1].duration), "fallback duration should be numeric")
  luassert.truthy(tips[1].duration == 3.0, "fallback tip duration should be exactly 3 seconds")
end)

it("test_roadblock_hit_no_longer_drives_visual_feedback", function()
  local handlers = {}
  local cleared = 0
  local looked_up_tile_id = nil

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = require("src.ui.render.anim"),
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
            looked_up_tile_id = tile_id
            if tile_id == 12 then
              return 7
            end
            return nil
          end,
        },
      },
    })
    local handler = handlers[monopoly_event.movement.roadblock_hit]
    luassert.truthy(type(handler) == "function", "roadblock_hit handler should be registered")
    handler(nil, nil, { tile_id = 12 })
  end)

  -- lint-allow: call-count 存量:桩在内部协作者上,只能经调用次数观察路由;迁到宿主边界观察待另开单
  luassert.truthy(cleared == 0, "roadblock_hit should no longer clear overlay directly")
  luassert.truthy(looked_up_tile_id == 12, "roadblock_hit should still resolve payload tile ids through board lookup")
end)

it("test_roadblock_hit_returns_explicit_tile_index_without_lookup", function()
  local handlers = {}
  local looked_up_tile_id = nil

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {
      game = {
        board = {
          index_of_tile_id = function(_, tile_id)
            looked_up_tile_id = tile_id
            return 99
          end,
        },
      },
    })
    local handler = handlers[monopoly_event.movement.roadblock_hit]
    luassert.truthy(type(handler) == "function", "roadblock_hit handler should be registered")
    local resolved = handler(nil, nil, {
      tile_index = 7,
      tile_id = 12,
    })
    luassert.truthy(resolved == 7, "roadblock_hit should return the explicit tile_index")
  end)

  luassert.truthy(looked_up_tile_id == nil, "roadblock_hit should not consult board lookup when tile_index exists")
end)

it("test_mine_hit_no_longer_drives_visual_feedback", function()
  local handlers = {}
  local cleared = 0
  local cues = 0
  local looked_up_tile_id = nil

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = require("src.ui.render.anim"),
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
            looked_up_tile_id = tile_id
            if tile_id == 20 then
              return 11
            end
            return nil
          end,
        },
      },
    })
    local handler = handlers[monopoly_event.land.mine_hit]
    luassert.truthy(type(handler) == "function", "mine_hit handler should be registered")
    handler(nil, nil, {
      tile = { id = 20 },
      player = { id = 3 },
    })
  end)

  -- lint-allow: call-count 存量:桩在内部协作者上,只能经调用次数观察路由;迁到宿主边界观察待另开单
  luassert.truthy(cleared == 0, "mine_hit should no longer clear overlay directly")
  -- lint-allow: call-count 存量:桩在内部协作者上,只能经调用次数观察路由;迁到宿主边界观察待另开单
  luassert.truthy(cues == 0, "mine_hit should no longer emit direct cue playback")
  luassert.truthy(looked_up_tile_id == 20, "mine_hit should still resolve nested payload tile ids through board lookup")
end)

it("test_mine_hit_returns_board_lookup_index_for_nested_tile_id", function()
  local handlers = {}
  local looked_up_tile_id = nil

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {
      game = {
        board = {
          index_of_tile_id = function(_, tile_id)
            looked_up_tile_id = tile_id
            return 11
          end,
        },
      },
    })
    local handler = handlers[monopoly_event.land.mine_hit]
    luassert.truthy(type(handler) == "function", "mine_hit handler should be registered")
    local resolved = handler(nil, nil, {
      tile = { id = 20 },
      player = { id = 3 },
    })
    luassert.truthy(resolved == 11, "mine_hit should return the board lookup index")
  end)

  luassert.truthy(looked_up_tile_id == 20, "mine_hit should resolve nested payload tile ids through board lookup")
end)

it("test_mine_hit_tolerates_missing_state_and_lookup_api", function()
  local handlers = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {})
    local handler = handlers[monopoly_event.land.mine_hit]
    luassert.truthy(type(handler) == "function", "mine_hit handler should be registered")
    handler(nil, nil, { tile_id = 77 })

    package.loaded["src.ui.coord.event_handlers"] = nil
    handlers = {}
    event_handlers = require("src.ui.coord.event_handlers")
    event_handlers.install(nil, nil, {
      game = {
        board = {},
      },
    })
    handler = handlers[monopoly_event.land.mine_hit]
    luassert.truthy(type(handler) == "function", "mine_hit handler should stay registered without lookup api")
    handler(nil, nil, { tile_id = 88 })
  end)
end)

it("test_turn_started_feedback_routes_to_player_cue", function()
  local handlers = {}
  local calls = {}
  local action_roles = {}

  _with_patches({
    {
      target = host_events,
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
    {
      target = panel_interrupt,
      key = "begin_player_action",
      value = function(_, role_id)
        action_roles[#action_roles + 1] = role_id
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, { game = {} })
    local handler = handlers[monopoly_event.feedback.turn_started]
    luassert.truthy(type(handler) == "function", "turn_started handler should be registered")
    handler(nil, nil, { player_id = 2 })
  end)

  luassert.truthy(#calls == 1, "turn_started should route one player cue")
  luassert.truthy(calls[1].cue_name == "turn_started", "turn_started cue name mismatch")
  luassert.truthy(calls[1].player_id == 2, "turn_started should target payload player id")
  luassert.truthy(#action_roles == 1, "turn_started should begin player action once")
  luassert.truthy(action_roles[1] == 2, "turn_started should begin action for payload player id")
end)

it("test_market_bought_item_plays_immediate_cash_burst", function()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_events,
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
    luassert.truthy(type(handler) == "function", "bought_item handler should be registered")
    handler(nil, nil, {
      player = { id = 3, name = "测试玩家" },
      entry = { product_id = 2003, kind = "item" },
      price = 500,
      currency = "金币",
      text = "测试玩家 在黑市购买 路障卡 花费 500 金币",
    })
  end)

  luassert.truthy(#calls >= 1, "bought_item should play at least one player cue")
  local found_cash_burst = false
  for _, call in ipairs(calls) do
    if call.cue_name == "cash_burst" and call.player_id == 3 then
      found_cash_burst = true
    end
  end
  luassert.truthy(found_cash_burst, "bought_item should play immediate cash_burst on buyer")
end)

it("test_turn_started_feedback_routes_configured_audio_without_error", function()
  local handlers = {}
  local play_3d_sound_calls = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = host_sfx,
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
    luassert.truthy(type(handler) == "function", "turn_started handler should be registered")
    handler(nil, nil, { player_id = 2 })
  end)

  luassert.truthy(#play_3d_sound_calls == 1, "configured turn_started audio should call engine once")
  luassert.truthy(play_3d_sound_calls[1].sound_id == 4233, "turn_started should resolve configured integer sound id")
end)

it("test_status_applied_feedback_prefers_tile_cue", function()
  local handlers = {}
  local tile_calls = {}
  local player_calls = 0

  _with_patches({
    {
      target = host_events,
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
    luassert.truthy(type(handler) == "function", "status_applied handler should be registered")
    handler(nil, nil, {
      cue_name = "hospital_shock",
      player_id = 1,
      tile_index = 7,
    })
  end)

  luassert.truthy(#tile_calls == 1, "status_applied should prefer tile cue when tile_index exists")
  luassert.truthy(tile_calls[1].cue_name == "hospital_shock", "status_applied cue mismatch")
  luassert.truthy(tile_calls[1].tile_index == 7, "status_applied tile index mismatch")
  -- lint-allow: call-count 存量:桩在内部协作者上,只能经调用次数观察路由;迁到宿主边界观察待另开单
  luassert.truthy(player_calls == 0, "status_applied should not fallback to player cue when tile cue is used")
end)

it("test_deity_applied_feedback_routes_specific_cue", function()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_events,
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
    luassert.truthy(type(handler) == "function", "deity_applied handler should be registered")
    handler(nil, nil, {
      player_id = 3,
      deity_type = "angel",
    })
  end)

  luassert.truthy(#calls == 1, "deity_applied should route one player cue")
  luassert.truthy(calls[1].cue_name == "angel_deity", "deity cue name mismatch")
  luassert.truthy(calls[1].player_id == 3, "deity cue should target payload player id")
end)

it("test_negative_chance_routes_generic_negative_cue", function()
  local handlers = {}
  local calls = {}

  _with_patches({
    {
      target = host_events,
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
    luassert.truthy(type(handler) == "function", "chance.applied handler should be registered")
    handler(nil, nil, {
      player = { id = 4 },
      card = { negative = true },
    })
  end)

  luassert.truthy(#calls == 1, "negative chance should route one player cue")
  luassert.truthy(calls[1].cue_name == "generic_negative", "negative chance cue mismatch")
  luassert.truthy(calls[1].player_id == 4, "negative chance should target payload player id")
end)

it("test_turn_started_feedback_defers_during_landing_hold", function()
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
      target = host_events,
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
    state.game.landing_visual_hold_state = state
    landing_visual_hold.start(state.game)
    landing_visual_hold.mark_release_pending(state.game)
    state.game.turn.landing_visual_hold_active = false
    state.game.turn.landing_visual_release_pending = false
    local handler = handlers[monopoly_event.feedback.turn_started]
    luassert.truthy(type(handler) == "function", "turn_started handler should be registered")
    handler(nil, nil, { player_id = 5 })
    luassert.truthy(#calls == 0, "landing hold should defer turn_started cue")

      local hold = state.turn_runtime and state.turn_runtime.landing_visual_hold or nil
      luassert.truthy(hold and #hold.release_callbacks == 1, "landing hold should queue deferred runtime event")
      luassert.truthy(hold.release_callbacks[1].key == "runtime_event", "landing hold should register runtime_event callback")

    state.game.turn.landing_visual_release_pending = true
    landing_visual_hold.release(state, state.game)
  end)

  luassert.truthy(#calls == 1, "releasing landing hold should replay deferred runtime event")
  luassert.truthy(calls[1].cue_name == "turn_started", "replayed turn_started cue mismatch")
  luassert.truthy(calls[1].player_id == 5, "replayed turn_started player mismatch")
end)

it("test_game_result_feedback_routes_winner_and_loser_panels", function()
  local handlers = {}
  local role_calls = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = require("src.foundation.ports.runtime_ports"),
      key = "resolve_role",
      value = function(player_id)
        role_calls[player_id] = role_calls[player_id] or { wins = 0, loses = 0, lose_calls = 0 }
        return {
          game_win_and_show_result_panel = function()
            role_calls[player_id].wins = role_calls[player_id].wins + 1
          end,
          game_lose_and_show_result_panel = function()
            role_calls[player_id].loses = role_calls[player_id].loses + 1
          end,
          lose = function()
            role_calls[player_id].lose_calls = role_calls[player_id].lose_calls + 1
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
    luassert.truthy(type(handler) == "function", "game_finished handler should be registered")
    handler(nil, nil, {
      winner_ids = {
        [2] = true,
      },
    })
  end)

  luassert.truthy(role_calls[1].wins == 0 and role_calls[1].loses == 1,
    "loser should open the defeat panel once")
  luassert.truthy(role_calls[2].wins == 1 and role_calls[2].loses == 0,
    "winner should show result panel once")
  luassert.truthy(role_calls[3].wins == 0 and role_calls[3].loses == 1,
    "other loser should open the defeat panel once")
  luassert.truthy(role_calls[1].lose_calls == 0 and role_calls[2].lose_calls == 0 and role_calls[3].lose_calls == 0,
    "the result panels must never call the plain lose marker (#334)")
end)

-- gm.finished 终局链共享脚手架(#609 审查收口:两新测试近乎逐字重复的补丁组):
-- 捕获注册表 + resolve_role 双面板桩 + end_game 桩,调用顺序记录进 calls。
-- role_factory 覆写 resolve_role 桩(如面板抛错形态),避免数字下标改产物。
local function _result_panel_patches(handlers, calls, role_factory)
  local runtime_ports = require("src.foundation.ports.runtime_ports")
  return {
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = runtime_ports,
      key = "resolve_role",
      value = role_factory or function(player_id)
        return {
          game_win_and_show_result_panel = function()
            calls[#calls + 1] = "win_panel:" .. player_id
          end,
          game_lose_and_show_result_panel = function()
            calls[#calls + 1] = "lose_panel:" .. player_id
          end,
        }
      end,
    },
    {
      target = runtime_ports,
      key = "end_game",
      value = function()
        calls[#calls + 1] = "end_game"
        return true
      end,
    },
  }
end

-- 存量面板路由测试的 end_game 哑桩:不断言收尾,只隔离终局新增的收尾副作用。
local function _end_game_ok_patch()
  return {
    target = require("src.foundation.ports.runtime_ports"),
    key = "end_game",
    value = function()
      return true
    end,
  }
end

it("test_game_result_ends_game_after_result_panels", function()
  -- 宿主文档语义:逐玩家标记胜负(带面板)之后必须显式结束游戏,玩家才会离开
  -- 对局(「胜利并不代表玩家将离开游戏,还需要设置游戏结束才会离开」)。
  -- 顺序敏感:game_end 先于胜负标记时宿主不采纳胜负,必须最后调用。
  local handlers = {}
  local sequence = {}

  _with_patches(_result_panel_patches(handlers, sequence), function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {
      game = {
        players = {
          { id = 1, name = "P1" },
          { id = 2, name = "P2" },
        },
      },
    })
    local handler = handlers[monopoly_event.game.finished]
    luassert.truthy(type(handler) == "function", "game_finished handler should be registered")
    handler(nil, nil, { winner_ids = { [2] = true } })
  end)

  _assert_eq(#sequence, 3, "two result panels then exactly one end_game")
  _assert_eq(sequence[3], "end_game", "game must end only after every result panel")
end)

it("test_game_result_dispatches_immediately_during_landing_hold", function()
  -- 终局是终态事件:landing hold 激活时不得 defer。finished 后 advance_turn
  -- 直接返回(game_state.lua:26-28),回合脚本永不恢复,release_pending 永不
  -- 置位,deferred 的终局处理器永久滞留——面板不弹、对局不结束。
  local handlers = {}
  local calls = {}

  _with_patches(_result_panel_patches(handlers, calls), function()
    local state = {
      game = {
        players = {
          { id = 1, name = "P1" },
          { id = 2, name = "P2" },
        },
      },
    }
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, state)
    require("src.state.runtime").set_landing_visual_hold_active(state, true)
    local handler = handlers[monopoly_event.game.finished]
    luassert.truthy(type(handler) == "function", "game_finished handler should be registered")
    handler(nil, nil, { winner_ids = { [2] = true } })
  end)

  _assert_eq(#calls, 3, "terminal game.finished must dispatch immediately even during landing hold")
  _assert_eq(calls[3], "end_game", "end_game must run during landing hold, not deferred with panels")
end)

it("test_game_result_panel_raise_still_ends_game_and_warns", function()
  -- #609 审查收口:面板宿主方法抛错属硬断裂,必须吞成 warn 且不阻塞 end_game
  -- 收尾——上抛会让会话悬挂不退出。
  local handlers = {}
  local calls = {}
  local warns = {}
  local patches = _result_panel_patches(handlers, calls, function(player_id)
    return {
      game_win_and_show_result_panel = function()
        error("host panel exploded")
      end,
      game_lose_and_show_result_panel = function()
        calls[#calls + 1] = "lose_panel:" .. player_id
      end,
    }
  end)

  _with_patches(patches, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, { warn = function(...)
      warns[#warns + 1] = table.concat({ ... }, " ")
    end }, {
      game = {
        players = {
          { id = 1, name = "P1" },
          { id = 2, name = "P2" },
        },
      },
    })
    local handler = handlers[monopoly_event.game.finished]
    luassert.truthy(type(handler) == "function", "game_finished handler should be registered")
    local ok = pcall(handler, nil, nil, { winner_ids = { [2] = true } })
    luassert.truthy(ok, "raising panel must not escape the handler")
  end)

  _assert_eq(calls[#calls], "end_game", "end_game must run even when a result panel raises")
  luassert.truthy(#warns == 1 and warns[1]:find("panel raised", 1, true) ~= nil,
    "raised panel should leave exactly one warn; got " .. tostring(warns[1]))
end)

it("test_game_result_resolve_raise_still_ends_game_and_warns", function()
  -- #609 复审收口:resolve_role 经 port 触达宿主适配层,抛错与返回 nil 同判——
  -- 吞成 warn、跳过该玩家面板,不阻塞其余玩家面板与 end_game 收尾;
  -- 上抛会沿事件回调冒泡跳过收尾,会话悬挂不退出。
  local handlers = {}
  local calls = {}
  local warns = {}
  local patches = _result_panel_patches(handlers, calls, function(player_id)
    if player_id == 1 then
      error("host resolve exploded")
    end
    return {
      game_win_and_show_result_panel = function()
        calls[#calls + 1] = "win_panel:" .. player_id
      end,
      game_lose_and_show_result_panel = function()
        calls[#calls + 1] = "lose_panel:" .. player_id
      end,
    }
  end)

  _with_patches(patches, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, { warn = function(...)
      warns[#warns + 1] = table.concat({ ... }, " ")
    end }, {
      game = {
        players = {
          { id = 1, name = "P1" },
          { id = 2, name = "P2" },
        },
      },
    })
    local handler = handlers[monopoly_event.game.finished]
    luassert.truthy(type(handler) == "function", "game_finished handler should be registered")
    local ok = pcall(handler, nil, nil, { winner_ids = { [2] = true } })
    luassert.truthy(ok, "raising resolve_role must not escape the handler")
  end)

  _assert_eq(calls[1], "win_panel:2", "other players' panels must survive one player's resolve raise")
  _assert_eq(calls[#calls], "end_game", "end_game must run even when resolve_role raises")
  luassert.truthy(#warns == 1 and warns[1]:find("resolve_role raised", 1, true) ~= nil,
    "raised resolve_role should leave exactly one warn; got " .. tostring(warns[1]))
end)

it("test_game_result_without_players_skips_panels", function()
  local handlers = {}
  local role_calls = 0

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = require("src.foundation.ports.runtime_ports"),
      key = "resolve_role",
      value = function()
        role_calls = role_calls + 1
        return nil
      end,
    },
    _end_game_ok_patch(),
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, nil, {})
    local handler = handlers[monopoly_event.game.finished]
    luassert.truthy(type(handler) == "function", "game_finished handler should be registered")
    handler(nil, nil, { winner_ids = { [1] = true } })
  end)

  -- lint-allow: call-count runtime_ports.resolve_role 是宿主角色解析 port,零调用=未向宿主解析角色
  luassert.truthy(role_calls == 0, "no players should mean no role resolution")
end)

it("test_game_result_with_players_but_no_roles_skips_panels_and_warns", function()
  -- #327:players 存在但 resolve_role 返回 nil 时必须跳过面板且每条跳过留痕
  -- (warn 带 player 上下文),不得静默、也不得在 nil role 上索引方法报错。
  local handlers = {}
  local resolve_calls = 0
  local warns = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = require("src.foundation.ports.runtime_ports"),
      key = "resolve_role",
      value = function()
        resolve_calls = resolve_calls + 1
        return nil
      end,
    },
    _end_game_ok_patch(),
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, { warn = function(...)
      warns[#warns + 1] = table.concat({ ... }, " ")
    end }, {
      game = {
        players = {
          { id = 1, name = "P1" },
          { id = 2, name = "P2" },
        },
      },
    })
    local handler = handlers[monopoly_event.game.finished]
    luassert.truthy(type(handler) == "function", "game_finished handler should be registered")
    local ok = pcall(handler, nil, nil, { winner_ids = { [1] = true } })
    luassert.truthy(ok, "missing role should not raise while routing result panels")
  end)

  -- lint-allow: call-count runtime_ports.resolve_role 是宿主角色解析 port,调用次数=向宿主解析角色的次数
  luassert.truthy(resolve_calls == 2, "both players should attempt role resolution")
  luassert.truthy(#warns == 2, "each unresolved role should leave one warn (#327)")
  luassert.truthy(warns[1]:find("player 1", 1, true) ~= nil and warns[2]:find("player 2", 1, true) ~= nil,
    "warns should carry the player context; got " .. tostring(warns[1]) .. " / " .. tostring(warns[2]))
end)

it("test_game_result_without_players_skips_panels_and_warns", function()
  -- #327 guard ①:_current_players() 返回 nil 时必须留痕,不得静默 return。
  local handlers = {}
  local warns = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = require("src.foundation.ports.runtime_ports"),
      key = "resolve_role",
      value = function()
        error("resolve_role must not be consulted without players")
      end,
    },
    _end_game_ok_patch(),
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, { warn = function(...)
      warns[#warns + 1] = table.concat({ ... }, " ")
    end }, {})
    local handler = handlers[monopoly_event.game.finished]
    luassert.truthy(type(handler) == "function", "game_finished handler should be registered")
    local ok = pcall(handler, nil, nil, { winner_ids = { [1] = true } })
    luassert.truthy(ok, "missing players should not raise while routing result panels")
  end)

  luassert.truthy(#warns == 1, "no players should leave exactly one warn (#327)")
  luassert.truthy(warns[1]:find("no current players", 1, true) ~= nil,
    "no-players warn should carry the skip reason; got " .. tostring(warns[1]))
end)

it("test_game_result_winner_method_missing_warns", function()
  -- #327 guard ③:胜者方法缺失时跳过且留痕,不静默。
  local handlers = {}
  local warns = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = require("src.foundation.ports.runtime_ports"),
      key = "resolve_role",
      value = function()
        return {}
      end,
    },
    _end_game_ok_patch(),
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, { warn = function(...)
      warns[#warns + 1] = table.concat({ ... }, " ")
    end }, {
      game = {
        players = {
          { id = 9, name = "P9" },
        },
      },
    })
    local handler = handlers[monopoly_event.game.finished]
    luassert.truthy(type(handler) == "function", "game_finished handler should be registered")
    local ok = pcall(handler, nil, nil, { winner_ids = { [9] = true } })
    luassert.truthy(ok, "missing winner method should not raise while routing result panels")
  end)

  luassert.truthy(#warns == 1, "missing winner method should leave exactly one warn (#327)")
  luassert.truthy(warns[1]:find("game_win_and_show_result_panel", 1, true) ~= nil,
    "warn should name the missing winner method; got " .. tostring(warns[1]))
end)

it("test_game_result_loser_method_missing_warns", function()
  -- #327 guard ④:败者方法缺失时跳过且留痕,不静默。
  local handlers = {}
  local warns = {}

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = require("src.foundation.ports.runtime_ports"),
      key = "resolve_role",
      value = function()
        return {}
      end,
    },
    _end_game_ok_patch(),
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, { warn = function(...)
      warns[#warns + 1] = table.concat({ ... }, " ")
    end }, {
      game = {
        players = {
          { id = 9, name = "P9" },
        },
      },
    })
    local handler = handlers[monopoly_event.game.finished]
    luassert.truthy(type(handler) == "function", "game_finished handler should be registered")
    local ok = pcall(handler, nil, nil, { winner_ids = {} })
    luassert.truthy(ok, "missing loser method should not raise while routing result panels")
  end)

  luassert.truthy(#warns == 1, "missing loser method should leave exactly one warn (#327)")
  luassert.truthy(warns[1]:find("game_lose_and_show_result_panel", 1, true) ~= nil,
    "warn should name the missing loser method; got " .. tostring(warns[1]))
end)

it("test_game_result_skips_synthetic_players_without_warn", function()
  -- #611:合成 AI 没有客户端,结算面板无处显示——终局路由必须在 resolve_role
  -- 之前静默跳过它们,不留 warn。覆盖两种情形:已退役(die/lose 已把自己从
  -- 合成角色注册表删除,resolve_role 恒 nil)与在场(适配器无败者面板方法)。
  local handlers = {}
  local calls = {}
  local warns = {}
  local infos = {}
  local resolved = {}
  local runtime_ports = require("src.foundation.ports.runtime_ports")

  _with_patches({
    {
      target = host_events,
      key = "register_custom_event",
      value = function(event_name, handler)
        handlers[event_name] = handler
        return true
      end,
    },
    {
      target = runtime_ports,
      key = "is_synthetic_player",
      value = function(player_id)
        return player_id == -2 or player_id == -3
      end,
    },
    {
      target = runtime_ports,
      key = "resolve_role",
      value = function(player_id)
        resolved[#resolved + 1] = player_id
        if player_id == -2 then
          return nil
        end
        if player_id == -3 then
          return { game_win_and_show_result_panel = function() end }
        end
        return {
          game_win_and_show_result_panel = function()
            calls[#calls + 1] = "win_panel:" .. player_id
          end,
          game_lose_and_show_result_panel = function()
            calls[#calls + 1] = "lose_panel:" .. player_id
          end,
        }
      end,
    },
    {
      target = runtime_ports,
      key = "end_game",
      value = function()
        calls[#calls + 1] = "end_game"
        return true
      end,
    },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, {
      warn = function(...)
        warns[#warns + 1] = table.concat({ ... }, " ")
      end,
      -- 生产 logger 的 info 受每回合节流(debug_flags.info_log_per_turn_limit=1),
      -- 终局回合额度常已用尽:只桩不限流通道,若实现改用 logger.info 本例即红。
      info_unlimited = function(...)
        infos[#infos + 1] = table.concat({ ... }, " ")
      end,
      info = function()
        error("synthetic skip trace must not use the throttled info channel")
      end,
    }, {
      game = {
        players = {
          { id = 1, name = "P1" },
          { id = -2, name = "AI-2" },
          { id = -3, name = "AI-3" },
        },
      },
    })
    local handler = handlers[monopoly_event.game.finished]
    luassert.truthy(type(handler) == "function", "game_finished handler should be registered")
    local ok = pcall(handler, nil, nil, { winner_ids = { [1] = true } })
    luassert.truthy(ok, "synthetic players should not raise while routing result panels")
  end)

  _assert_eq(#warns, 0, "synthetic players must not warn; got " .. tostring(warns[1]))
  _assert_eq(#resolved, 1, "synthetic players must not even reach resolve_role")
  _assert_eq(resolved[1], 1, "only the host player should be resolved")
  _assert_eq(calls[1], "win_panel:1", "host winner should still get its panel")
  _assert_eq(#calls, 2, "one host panel then exactly one end_game")
  _assert_eq(calls[2], "end_game", "end_game must still run exactly once after routing")
  -- 跳过必留痕(ADR 0046):降级为 info,不是静默。
  _assert_eq(#infos, 2, "both synthetic skips should leave an info trace")
  luassert.truthy(infos[1]:find("player -2", 1, true) ~= nil and infos[2]:find("player -3", 1, true) ~= nil,
    "synthetic skip traces should carry the player context; got "
      .. tostring(infos[1]) .. " / " .. tostring(infos[2]))
end)

it("test_angel_immune_blocked_routes_tile_and_player_cues", function()
  local captured = {}
  local tile_calls = {}
  local player_calls = {}
  local state = { game = {} }

  _with_patches({
    { target = host_events, key = "register_custom_event", value = function(event_name, handler)
      captured[event_name] = handler
    end },
    { target = landing_visual_hold, key = "run_or_defer", value = function(_, _, _, fn)
      return fn()
    end },
    { target = board_feedback, key = "play_tile_cue", value = function(_, cue_name, tile_index)
      tile_calls[#tile_calls + 1] = cue_name .. ":" .. tostring(tile_index)
    end },
    { target = board_feedback, key = "play_player_cue", value = function(_, cue_name, player_id)
      player_calls[#player_calls + 1] = cue_name .. ":" .. tostring(player_id)
    end },
  }, function()
    local event_handlers = _load_fresh_handlers()
    event_handlers.install(nil, {}, state)
    local handler = assert(captured[monopoly_event.feedback.angel_immune_blocked])
    handler(nil, nil, { tile_index = 3, player_id = 4 })
    handler(nil, nil, { player_id = 4 })
  end)

  _assert_eq(tile_calls[1], "angel_deity:3", "tile event should prefer tile cue")
  _assert_eq(player_calls[1], "angel_deity:4", "player event should fall back to player cue")
end)

do
  -- 共享驱动:装一次 handlers,捕获 player/tile cue 与 tip,触发一个事件。
  local function _drive(event_name, state, data)
    local handlers = {}
    local captured = { player_cues = {}, tile_cues = {}, tips = {} }
    _with_patches({
      { target = host_events, key = "register_custom_event", value = function(name, handler)
        handlers[name] = handler
        return true
      end },
      { target = board_feedback, key = "play_player_cue", value = function(_, cue, pid)
        captured.player_cues[#captured.player_cues + 1] = { cue_name = cue, player_id = pid }
        return true
      end },
      { target = board_feedback, key = "play_tile_cue", value = function(_, cue, idx)
        captured.tile_cues[#captured.tile_cues + 1] = { cue_name = cue, tile_index = idx }
        return true
      end },
      { target = tip_queue, key = "enqueue", value = function(intent)
        captured.tips[#captured.tips + 1] = intent
        return true
      end },
    }, function()
      local event_handlers = _load_fresh_handlers()
      event_handlers.install(nil, nil, state)
      local handler = assert(handlers[event_name], "handler should be registered")
      captured.result = handler(nil, nil, data)
    end)
    return captured
  end

  local STATE = { game = {} }

  it("test_buy_failed_with_an_empty_popup_body_falls_back_to_the_default_tip_text", function()
    -- kills _resolve_market_buy_failed_tip's `body ~= ""` "" -> nil.
    local c = _drive(monopoly_event.market.buy_failed, STATE, { popup = { body = "" } })
    _assert_eq(c.tips[1].text, "黑市购买失败", "empty body falls back to the default")
  end)

  it("test_buy_failed_tip_pins_blocks_inter_turn_and_source", function()
    -- kills the tip literal's blocks_inter_turn false -> true and source -> nil.
    local c = _drive(monopoly_event.market.buy_failed, STATE, { popup = { body = "余额不足" } })
    _assert_eq(c.tips[1].blocks_inter_turn, false, "buy_failed tip must not block inter-turn")
    _assert_eq(c.tips[1].source, "market.buy_failed", "buy_failed tip source pinned")
  end)

  it("test_inventory_full_tip_carries_body_text_and_full_field_set", function()
    -- kills _event_data call -> nil, the body fallback chain's and/or mutants,
    -- and the dedupe_key/blocks_inter_turn/source literals.
    local c = _drive(monopoly_event.market.inventory_full, STATE, { body = "背包不够用了" })
    local tip = c.tips[1]
    _assert_eq(tip.text, "背包不够用了", "explicit body wins over the default")
    _assert_eq(tip.dedupe_key, "market_inventory_full", "dedupe key pinned")
    _assert_eq(tip.blocks_inter_turn, false, "inventory_full tip must not block inter-turn")
    _assert_eq(tip.source, "market.inventory_full", "inventory_full tip source pinned")
  end)

  it("test_inventory_full_without_a_body_uses_the_default_tip_text", function()
    -- kills the fallback chain's "卡槽已满，无法继续购买" -> nil.
    local c = _drive(monopoly_event.market.inventory_full, STATE, {})
    _assert_eq(c.tips[1].text, "卡槽已满，无法继续购买", "missing body falls back to the default")
  end)

  it("test_install_is_idempotent_a_second_install_does_not_re_register", function()
    -- kills `context.installed = true` true -> false.
    local registrations = 0
    _with_patches({
      { target = host_events, key = "register_custom_event", value = function()
        registrations = registrations + 1
        return true
      end },
    }, function()
      local event_handlers = _load_fresh_handlers()
      event_handlers.install(nil, nil, STATE)
      local first = registrations
      luassert.truthy(first > 0, "first install registers handlers")
      event_handlers.install(nil, nil, STATE)
      _assert_eq(registrations, first, "second install must not re-register")
    end)
  end)

  it("test_install_loads_the_anim_module_for_its_registration_side_effects", function()
    -- kills pcall(require, "src.ui.render.anim")'s module-name -> nil.
    local saved = package.loaded["src.ui.render.anim"]
    package.loaded["src.ui.render.anim"] = nil
    _with_patches({
      { target = host_events, key = "register_custom_event", value = function() return true end },
    }, function()
      _load_fresh_handlers().install(nil, nil, STATE)
    end)
    local loaded = package.loaded["src.ui.render.anim"] ~= nil
    package.loaded["src.ui.render.anim"] = package.loaded["src.ui.render.anim"] or saved
    luassert.truthy(loaded, "install must require src.ui.render.anim")
  end)

  it("test_roadblock_hit_without_state_returns_the_handler_result_directly", function()
    -- kills _dispatch_or_defer's `return handler(data)` call -> nil.
    local c = _drive(monopoly_event.movement.roadblock_hit, nil, { tile_index = 7 })
    _assert_eq(c.result, 7, "state-less dispatch returns the handler result")
  end)

  it("test_chance_applied_guard_matrix_every_missing_piece_suppresses_the_cue", function()
    -- kills the guard's four `and` -> `or` mutants.
    local data = { player = { id = 4 }, card = { negative = true } }
    local c1 = _drive(monopoly_event.chance.applied, nil, data)
    _assert_eq(#c1.player_cues, 0, "nil state suppresses the cue")
    local c2 = _drive(monopoly_event.chance.applied, STATE, { card = { negative = true } })
    _assert_eq(#c2.player_cues, 0, "missing player suppresses the cue")
    local c3 = _drive(monopoly_event.chance.applied, STATE, { player = {}, card = { negative = true } })
    _assert_eq(#c3.player_cues, 0, "missing player id suppresses the cue")
    local c4 = _drive(monopoly_event.chance.applied, STATE, { player = { id = 4 } })
    _assert_eq(#c4.player_cues, 0, "missing card suppresses the cue")
    local c5 = _drive(monopoly_event.chance.applied, STATE, { player = { id = 4 }, card = { negative = false } })
    _assert_eq(#c5.player_cues, 0, "a non-negative card suppresses the cue")
  end)

  it("test_turn_started_without_state_fires_no_cue", function()
    -- kills the turn_started guard's `and` -> `or`.
    local c = _drive(monopoly_event.feedback.turn_started, nil, { player_id = 2 })
    _assert_eq(#c.player_cues, 0, "nil state suppresses the turn_started cue")
  end)

  it("test_bankruptcy_without_state_fires_no_cue", function()
    -- kills _player_cue_from_player_id's guard `and` -> `or`.
    local c = _drive(monopoly_event.feedback.bankruptcy, nil, { player_id = 3 })
    _assert_eq(#c.player_cues, 0, "nil state suppresses the bankruptcy cue")
  end)

  it("test_status_applied_falls_back_to_a_player_cue_when_no_tile_index", function()
    -- kills the fallback's _event_player_id call -> nil, `player_id ~= nil`
    -- ~= -> ==, and the guard `and` -> `or` pair.
    local c = _drive(monopoly_event.feedback.status_applied, STATE, { cue_name = "zap", player_id = 5 })
    _assert_eq(#c.player_cues, 1, "player fallback fires exactly once")
    _assert_eq(c.player_cues[1].cue_name, "zap", "fallback cue name passes through")
    _assert_eq(c.player_cues[1].player_id, 5, "fallback player id resolved")
    local no_state = _drive(monopoly_event.feedback.status_applied, nil, { cue_name = "zap", player_id = 5 })
    _assert_eq(#no_state.player_cues, 0, "nil state suppresses the fallback")
    local no_cue = _drive(monopoly_event.feedback.status_applied, STATE, { player_id = 5 })
    _assert_eq(#no_cue.player_cues, 0, "missing cue_name suppresses the fallback")
  end)

  it("test_status_applied_tile_path_needs_state_cue_name_and_tile_index_together", function()
    -- kills the tile guard's `and` -> `or` pair.
    local no_state = _drive(monopoly_event.feedback.status_applied, nil, { cue_name = "zap", tile_index = 9 })
    _assert_eq(#no_state.tile_cues, 0, "nil state suppresses the tile cue")
    local no_name = _drive(monopoly_event.feedback.status_applied, STATE, { tile_index = 9 })
    _assert_eq(#no_name.tile_cues, 0, "missing cue_name suppresses the tile cue")
  end)

  it("test_deity_applied_routes_rich_to_the_rich_deity_cue", function()
    -- kills the "rich" / "rich_deity" literal mutants.
    local c = _drive(monopoly_event.feedback.deity_applied, STATE, { deity_type = "rich", player_id = 6 })
    _assert_eq(#c.player_cues, 1, "rich deity fires one cue")
    _assert_eq(c.player_cues[1].cue_name, "rich_deity", "rich maps to rich_deity")
  end)

  it("test_deity_applied_without_state_or_with_an_unmapped_deity_fires_no_cue", function()
    -- kills the deity guard's `and` -> `or` pair.
    local no_state = _drive(monopoly_event.feedback.deity_applied, nil, { deity_type = "rich", player_id = 6 })
    _assert_eq(#no_state.player_cues, 0, "nil state suppresses the deity cue")
    local poor = _drive(monopoly_event.feedback.deity_applied, STATE, { deity_type = "poor", player_id = 6 })
    _assert_eq(#poor.player_cues, 0, "an unmapped deity fires no cue")
  end)

  it("test_angel_immune_blocked_falls_back_to_a_player_cue_and_needs_state", function()
    -- kills the player fallback guard's `and` -> `or`.
    local c = _drive(monopoly_event.feedback.angel_immune_blocked, STATE, { player_id = 8 })
    _assert_eq(#c.player_cues, 1, "angel immune player fallback fires")
    _assert_eq(c.player_cues[1].cue_name, "angel_deity", "fallback cue is angel_deity")
    local no_state = _drive(monopoly_event.feedback.angel_immune_blocked, nil, { player_id = 8 })
    _assert_eq(#no_state.player_cues, 0, "nil state suppresses the angel cue")
  end)
end


end)
