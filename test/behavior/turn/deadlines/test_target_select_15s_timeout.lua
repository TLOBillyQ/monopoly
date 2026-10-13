-- 验证：道具目标选择 (target_select) 的 timeout 为 15s（来自 timing.scope_timeouts.target_select）。
-- 与 market_buy_60s / non_market_15s 对齐补齐超时三元组的最后一档：另两档已硬钉字面值，
-- target_select 此前只有行为测试（推进 16s），而 _resolve_target_select_timeout 带 `return 15`
-- 回退 → 配置被删/调小时行为测试仍绿（回退也是 15）。这里钉死字面值并证明解析走配置而非回退。
-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
local function _assert_same(actual, expected, message)
  luassert.is.same(expected, actual, message)
end
local timing = require("src.config.gameplay.timing")
local target_select_timer = require("src.turn.waits.target_select_timer")
local pending_confirmation = require("src.state.pending_confirmation")
local DeadlineService = require("src.turn.deadlines")
local runtime_state = require("src.state.runtime")

local function _active_state()
  local state = {}
  runtime_state.ensure_all(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  return state
end

local function _game()
  return { turn = { pending_choice = { id = "tc1", kind = "item_target_tile" } } }
end

describe("TestTargetSelect15sTimeout", function()

it("test_scope_timeouts_target_select_is_15", function()
  luassert.is_table(timing.scope_timeouts)
  _assert_same(timing.scope_timeouts.target_select, 15)
end)

it("test_registers_the_target_select_deadline_at_the_configured_15s", function()
  local state = _active_state()
  target_select_timer.step(_game(), state, 0.1)
  local entry = DeadlineService.peek(state, "target_select")
  luassert.is_table(entry)
  _assert_same(entry.timeout_seconds, 15)
end)

it("test_resolves_the_timeout_from_config_not_the_hardcoded_fallback", function()
  -- Drive the resolver off the fallback value: if it ignored config and always
  -- returned 15, this would fail. Proves a real config drift would propagate.
  local original = timing.scope_timeouts.target_select
  timing.scope_timeouts.target_select = 25
  local ok, err = pcall(function()
    local state = _active_state()
    target_select_timer.step(_game(), state, 0.1)
    local entry = DeadlineService.peek(state, "target_select")
    _assert_same(entry.timeout_seconds, 25)
  end)
  timing.scope_timeouts.target_select = original
  luassert.is_true(ok, tostring(err))
end)


it("test_step_ignores_non_table_state", function()
  target_select_timer.step(_game(), nil, 0.1)
  target_select_timer.step(_game(), "not-a-state", 0.1)
  luassert.truthy(true, "target_select_timer.step should tolerate non-table states")
end)

it("test_timeout_of_one_second_uses_config_value", function()
  -- L13 兜底 `> 0` 的 0->1:配置 1s 必须生效(1>0 为真),不能被 1>1 误判回退 15。
  local original = timing.scope_timeouts.target_select
  timing.scope_timeouts.target_select = 1
  local ok, err = pcall(function()
    local state = _active_state()
    target_select_timer.step(_game(), state, 0.1)
    _assert_same(DeadlineService.peek(state, "target_select").timeout_seconds, 1)
  end)
  timing.scope_timeouts.target_select = original
  luassert.is_true(ok, tostring(err))
end)

it("test_zero_timeout_falls_back_to_15", function()
  -- L13 `> 0` 的 >->=:0s 配置必须回退 15,不能返回 0。
  local original = timing.scope_timeouts.target_select
  timing.scope_timeouts.target_select = 0
  local ok, err = pcall(function()
    local state = _active_state()
    target_select_timer.step(_game(), state, 0.1)
    _assert_same(DeadlineService.peek(state, "target_select").timeout_seconds, 15)
  end)
  timing.scope_timeouts.target_select = original
  luassert.is_true(ok, tostring(err))
end)

it("test_non_numeric_timeout_falls_back_to_15", function()
  -- L13 第二个 and->or:非数值 target_select 不得进入比较运算,必须回退 15。
  local original = timing.scope_timeouts.target_select
  timing.scope_timeouts.target_select = "abc"
  local ok, err = pcall(function()
    local state = _active_state()
    target_select_timer.step(_game(), state, 0.1)
    _assert_same(DeadlineService.peek(state, "target_select").timeout_seconds, 15)
  end)
  timing.scope_timeouts.target_select = original
  luassert.is_true(ok, tostring(err))
end)

it("test_non_table_scope_timeouts_falls_back_to_15", function()
  -- L13 第一个 and->or:scope_timeouts 非表时必须回退 15,不能索引 nil。
  local original = timing.scope_timeouts
  timing.scope_timeouts = nil
  local ok, err = pcall(function()
    local state = _active_state()
    target_select_timer.step(_game(), state, 0.1)
    _assert_same(DeadlineService.peek(state, "target_select").timeout_seconds, 15)
  end)
  timing.scope_timeouts = original
  luassert.is_true(ok, tostring(err))
end)

it("test_does_not_restart_an_already_active_deadline", function()
  -- L33 两连(is_active 调用换 nil / scope 名换 nil):活跃 deadline 不得被再次 start。
  local state = _active_state()
  local start_calls = 0
  local real_start = DeadlineService.start
  DeadlineService.start = function(s, scope, cfg)
    start_calls = start_calls + 1
    return real_start(s, scope, cfg)
  end
  local ok, err = pcall(function()
    target_select_timer.step(_game(), state, 0.1)
    target_select_timer.step(_game(), state, 0.1)
    _assert_same(start_calls, 1)
  end)
  DeadlineService.start = real_start
  luassert.is_true(ok, tostring(err))
end)

it("test_timeout_resolves_with_pending_choice_and_tick_reason", function()
  -- L38 or->and(choice 恒 nil)与 L39 reason 换 nil:超时必须带真实 pending_choice 与 tick_timeout。
  local captured = nil
  local real_resolve = DeadlineService.resolve_target_select
  DeadlineService.resolve_target_select = function(game, state, args, reason)
    captured = { choice = args and args.choice or nil, reason = reason }
  end
  local ok, err = pcall(function()
    local state = _active_state()
    local game = _game()
    target_select_timer.step(game, state, 0.1)
    DeadlineService.tick(state, 16.0)
    luassert.is_not_nil(captured, "resolve_target_select must be invoked")
    luassert.truthy(captured.choice == game.turn.pending_choice,
      "timeout must resolve with the pending choice")
    _assert_same(captured.reason, "tick_timeout")
  end)
  DeadlineService.resolve_target_select = real_resolve
  luassert.is_true(ok, tostring(err))
end)

it("test_timeout_tolerates_game_without_turn", function()
  -- L38 两处 and->or:game.turn 缺失时 choice 解析必须安全回退 nil 并正常超时。
  local captured = nil
  local real_resolve = DeadlineService.resolve_target_select
  DeadlineService.resolve_target_select = function(game, state, args, reason)
    captured = { choice = args and args.choice or nil, reason = reason }
  end
  local ok, err = pcall(function()
    local state = _active_state()
    target_select_timer.step({}, state, 0.1)
    DeadlineService.tick(state, 16.0)
    luassert.is_not_nil(captured, "resolve_target_select must still fire")
    _assert_same(captured.reason, "tick_timeout")
    luassert.is_nil(captured.choice, "missing turn must yield nil choice")
  end)
  DeadlineService.resolve_target_select = real_resolve
  luassert.is_true(ok, tostring(err))
end)


end)
