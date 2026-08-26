local lu = require("luaunit")
local support = require("test.support.shared_support")
local event_feed = require("src.rules.ports.event_feed")
local phase_registry = require("src.turn.phases.registry")
local landing_visual_hold = require("src.state.visual_hold")

local _assert_eq = support.assert_eq

local function _make_game(player, board)
  return {
    board = board,
    turn = {
      market_prompt = nil,
      post_action = nil,
      item_phase = {},
      used_effect_groups = {},
      item_phase_active = "",
      inter_turn_wait_active = false,
      inter_turn_wait_elapsed = 0,
    },
    dirty = {},
    current_player = function()
      return player
    end,
    tick_player_deity = function() end,
    clear_player_temporal_flags = function() end,
    stop_all_players_movement = function() end,
    next_player = function() end,
  }
end

local function _make_turn_mgr(game)
  return {
    game = game,
    next_player = function() end,
  }
end

TestPhaseRegistry = {}

function TestPhaseRegistry:test_end_turn_publishes_tile_name_and_arms_inter_turn_wait()
  -- kills _phase_end 的 _positioned/_landing_tile 调用换 nil、inter_turn_wait_seconds
  -- 的 or->and(恒 1.0)、inter_turn_wait_elapsed 的 0->1:落位玩家必须带 tile 名,
  -- 等待时长必须用配置值(0.5),elapsed 必须从 0 起算。
  local published = {}
  local player = { name = "P1", position = 2 }
  local game = _make_game(player, {
    get_tile = function(_, index)
      if index == 2 then
        return { name = "测试大道" }
      end
      return nil
    end,
  })

  support.with_patches({
    {
      target = event_feed,
      key = "publish",
      value = function(_, evt)
        published[#published + 1] = evt
      end,
    },
  }, function()
    local phases = phase_registry.build_default_phases()
    local next_state, next_args = phases.end_turn(_make_turn_mgr(game), { player = player })
    _assert_eq(next_state, "inter_turn_wait", "end_turn should enter the inter-turn wait")
    lu.assertEvalToTrue(type(next_args) == "table" and next(next_args) == nil,
      "inter-turn wait carries no args")
  end)

  lu.assertEvalToTrue(#published == 1, "end_turn should publish the turn_end event")
  lu.assertEvalToTrue(published[1].text:find("测试大道", 1, true) ~= nil,
    "turn_end text should carry the landing tile name: " .. tostring(published[1].text))
  lu.assertEvalToTrue(published[1].tip == false, "turn_end should not surface a tip")
  _assert_eq(game.turn.inter_turn_wait_seconds, 0.5, "inter-turn wait should use the configured seconds")
  _assert_eq(game.turn.inter_turn_wait_elapsed, 0, "inter-turn wait elapsed should start at zero")
  _assert_eq(game.turn.inter_turn_wait_active, true, "inter-turn wait should be armed")
end

function TestPhaseRegistry:test_end_turn_falls_back_to_unknown_tile_when_not_positioned()
  -- kills _tile_name_or_unknown 的 `tile and tile.name` and->or 与 "未知地块"
  -- 换 nil:玩家无落位时必须显示未知地块占位而不是报错。
  local published = {}
  local player = { name = "P2", position = 99 }
  local game = _make_game(player, {
    get_tile = function()
      return nil
    end,
  })

  support.with_patches({
    {
      target = event_feed,
      key = "publish",
      value = function(_, evt)
        published[#published + 1] = evt
      end,
    },
  }, function()
    local phases = phase_registry.build_default_phases()
    local ok = pcall(phases.end_turn, _make_turn_mgr(game), { player = player })
    lu.assertEvalToTrue(ok, "end_turn should not raise for an unpositioned player")
  end)

  lu.assertEvalToTrue(#published == 1, "end_turn should still publish the turn_end event")
  lu.assertEvalToTrue(published[1].text:find("未知地块", 1, true) ~= nil,
    "unpositioned player should fall back to the unknown tile label: " .. tostring(published[1].text))
end

function TestPhaseRegistry:test_end_turn_replays_pending_landing_visual_release_before_clearing()
  -- #440 回归: 真实 _phase_end 在「置 release_pending」与「tick release」之间
  -- 执行时,hold 期间 defer 的回调不得被静默丢弃。
  local player = { name = "P1", position = 2 }
  local game = _make_game(player, nil)
  local state = {}
  game.landing_visual_hold_state = state

  local replayed = {}
  landing_visual_hold.start(game)
  landing_visual_hold.mark_release_pending(game)
  landing_visual_hold.register_release_callback(state, "runtime_event", function()
    replayed[#replayed + 1] = "release"
  end)

  local phases = phase_registry.build_default_phases()
  phases.end_turn(_make_turn_mgr(game), { player = player })

  _assert_eq(#replayed, 1, "end_turn should replay deferred callbacks from the pending landing visual release")
  _assert_eq(landing_visual_hold.is_active_game(game), false, "end_turn should still clear the landing visual hold")
  _assert_eq(landing_visual_hold.is_release_pending_game(game), false, "end_turn should still clear the pending flag")
end


return TestPhaseRegistry
