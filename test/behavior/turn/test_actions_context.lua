local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local context = require("src.turn.actions.context")
local defaults = require("src.turn.actions.defaults")

-- 原生 LuaUnit 迁移:两个无钩子同级 describe 合并为单个 Test* 类,describe 级的
-- local 辅助函数(_game)上提到文件级,has_error 翻成 lu.assertError,用例数与
-- 改写前一一对应(5 + 4 = 9 例)。

TestActionsContext = {}

function TestActionsContext:test_uses_the_clock_port_diff_when_it_returns_a_numeric_value()
  local ctx = {
    clock_ports = {
      wall_diff_seconds = function(a, b)
        return (a - b) * 2
      end,
    },
  }
  _assert_eq(context.resolve_timestamp_diff_seconds(ctx, 9, 7), 4,
    "a numeric clock-port diff should be returned directly")
end

function TestActionsContext:test_falls_back_to_subtraction_when_the_clock_port_returns_a_non_numeric_value()
  local ctx = {
    clock_ports = {
      wall_diff_seconds = function()
        return "not-a-number"
      end,
    },
  }
  _assert_eq(context.resolve_timestamp_diff_seconds(ctx, 9, 7), 2,
    "a non-numeric clock-port diff should fall back to arithmetic")
end

function TestActionsContext:test_falls_back_to_subtraction_when_the_clock_port_errors()
  local ctx = {
    clock_ports = {
      wall_diff_seconds = function()
        error("clock boom")
      end,
    },
  }
  _assert_eq(context.resolve_timestamp_diff_seconds(ctx, 9, 7), 2,
    "a throwing clock port should fall back to arithmetic")
end

function TestActionsContext:test_subtracts_directly_when_no_clock_port_is_available()
  _assert_eq(context.resolve_timestamp_diff_seconds(nil, 9, 7), 2,
    "a missing dispatch context should fall back to arithmetic")
  _assert_eq(context.resolve_timestamp_diff_seconds({}, 9, 7), 2,
    "a context without clock ports should fall back to arithmetic")
end

function TestActionsContext:test_returns_zero_when_either_timestamp_is_non_numeric()
  _assert_eq(context.resolve_timestamp_diff_seconds(nil, "x", 7), 0,
    "a non-numeric first timestamp should yield 0")
  _assert_eq(context.resolve_timestamp_diff_seconds(nil, 9, nil), 0,
    "a missing second timestamp should yield 0")
end

local function _game(players)
  return {
    players = players,
    find_player_by_id = function(_, id)
      for _, player in ipairs(players) do
        if player.id == id then
          return player
        end
      end
      return nil
    end,
  }
end

function TestActionsContext:test_returns_the_player_the_actions_actor_role_id_maps_to()
  local target = { id = 1002 }
  local game = _game({ { id = 1001 }, target })
  _assert_eq(context.resolve_actor_player(game, { id = "next", actor_role_id = 1002 }), target,
    "a mapped actor_role_id should resolve to that player")
end

function TestActionsContext:test_returns_nil_when_the_action_carries_no_actor_role_id()
  local game = _game({ { id = 1001 } })
  _assert_eq(context.resolve_actor_player(game, { id = "next" }), nil,
    "an action without actor_role_id has no resolvable actor")
end

function TestActionsContext:test_returns_nil_when_the_actor_role_id_maps_to_no_player()
  local game = _game({ { id = 1001 } })
  _assert_eq(context.resolve_actor_player(game, { id = "next", actor_role_id = 4242 }), nil,
    "an actor_role_id absent from game.players should not resolve")
end

function TestActionsContext:test_asserts_when_game_players_is_missing()
  -- 按错误消息断言：杀掉 and→or 突变（会越界到 find_player_by_id 报不同错误）与
  -- 断言消息→nil 突变。
  lu.assertErrorMsgMatches(".*missing game%.players", function()
    context.resolve_actor_player({}, { id = "next", actor_role_id = 1001 })
  end)
end

-- resolve_dispatch_context 覆盖（杀掉 require→nil 幸存者：nil context 走 fallback 装配路径）

function TestActionsContext:test_resolve_dispatch_context_assembles_fallback_when_context_nil()
  local result = context.resolve_dispatch_context({}, nil)
  _assert_eq(type(result), "table", "nil context should yield a table")
  _assert_eq(result.output_ports ~= nil, true, "should resolve output_ports from fallback")
  _assert_eq(result.ui_sync_ports ~= nil, true, "should resolve ui_sync_ports from fallback")
  _assert_eq(result.clock_ports ~= nil, true, "should resolve clock_ports from fallback")
end

-- resolve_timestamp_now 覆盖（杀掉 _safe_wall_now and→or + 默认值 0→1 幸存者）

function TestActionsContext:test_resolve_timestamp_now_defaults_to_zero()
  _assert_eq(context.resolve_timestamp_now(nil), 0,
    "missing dispatch_ctx should default to 0")
  _assert_eq(context.resolve_timestamp_now({}), 0,
    "dispatch_ctx without clock_ports should default to 0")
end

function TestActionsContext:test_resolve_timestamp_now_filters_non_numeric_clock_result()
  local ctx = {
    clock_ports = {
      wall_now_seconds = function()
        return "not-a-number"
      end,
    },
  }
  _assert_eq(context.resolve_timestamp_now(ctx), 0,
    "non-numeric clock result should fall back to 0")
end

function TestActionsContext:test_resolve_timestamp_now_uses_clock_value()
  local ctx = {
    clock_ports = {
      wall_now_seconds = function()
        return 42
      end,
    },
  }
  _assert_eq(context.resolve_timestamp_now(ctx), 42,
    "numeric clock result should be returned")
end

-- default_clock_ports 覆盖（杀掉 wall_now_seconds 默认值 0→1 幸存者）

function TestActionsContext:test_default_clock_ports_wall_now_returns_zero()
  _assert_eq(defaults.default_clock_ports.wall_now_seconds(), 0,
    "default wall_now_seconds should return 0")
end

return TestActionsContext
