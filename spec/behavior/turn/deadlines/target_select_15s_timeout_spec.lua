-- 验证：道具目标选择 (target_select) 的 timeout 为 15s（来自 timing.scope_timeouts.target_select）。
-- 与 market_buy_60s / non_market_15s 对齐补齐超时三元组的最后一档：另两档已硬钉字面值，
-- target_select 此前只有行为测试（推进 16s），而 _resolve_target_select_timeout 带 `return 15`
-- 回退 → 配置被删/调小时行为测试仍绿（回退也是 15）。这里钉死字面值并证明解析走配置而非回退。
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

describe("target_select 15s timeout", function()
  it("scope_timeouts.target_select is 15", function()
    assert.is_table(timing.scope_timeouts)
    assert.equals(15, timing.scope_timeouts.target_select)
  end)

  it("registers the target_select deadline at the configured 15s", function()
    local state = _active_state()
    target_select_timer.step(_game(), state, 0.1)
    local entry = DeadlineService.peek(state, "target_select")
    assert.is_table(entry)
    assert.equals(15, entry.timeout_seconds)
  end)

  it("resolves the timeout from config, not the hardcoded fallback", function()
    -- Drive the resolver off the fallback value: if it ignored config and always
    -- returned 15, this would fail. Proves a real config drift would propagate.
    local original = timing.scope_timeouts.target_select
    timing.scope_timeouts.target_select = 25
    local ok, err = pcall(function()
      local state = _active_state()
      target_select_timer.step(_game(), state, 0.1)
      local entry = DeadlineService.peek(state, "target_select")
      assert.equals(25, entry.timeout_seconds)
    end)
    timing.scope_timeouts.target_select = original
    assert.is_true(ok, tostring(err))
  end)
end)
