-- 验证：DeadlineService 的 5s/3s 警告按顺序触发，level 从 normal -> warn_5s -> warn_3s -> expired
local DeadlineService = require("src.turn.deadlines")
local runtime_state = require("src.state.runtime")

local function _build_state()
  local state = {}
  runtime_state.ensure_all(state)
  return state
end

describe("fake clock warning levels", function()
  it("levels transition through normal -> warn_5s -> warn_3s -> expired", function()
    local state = _build_state()
    local warns = {}
    DeadlineService.start(state, "choice", {
      timeout_seconds = 15,
      on_warn = function(level)
        warns[#warns + 1] = level
      end,
    })
    -- 推进 1s -> remaining 14, normal
    DeadlineService.tick(state, 1.0)
    assert.equals("normal", DeadlineService.peek(state, "choice").level)
    -- 推进至 elapsed=10.5（remaining=4.5），应该触发 warn_5s
    DeadlineService.tick(state, 9.5)
    assert.equals("warn_5s", DeadlineService.peek(state, "choice").level)
    assert.is_true(warns[1] == "warn_5s")
    -- 推进至 elapsed=12.5（remaining=2.5），应该触发 warn_3s
    DeadlineService.tick(state, 2.0)
    assert.equals("warn_3s", DeadlineService.peek(state, "choice").level)
    assert.is_true(warns[2] == "warn_3s")
    -- 推进到过期
    local fired_timeout = false
    DeadlineService.cancel(state, "choice")
    DeadlineService.start(state, "choice", {
      timeout_seconds = 1.0,
      on_timeout = function() fired_timeout = true end,
    })
    DeadlineService.tick(state, 1.5)
    assert.is_true(fired_timeout)
  end)

  it("warns fire only once each", function()
    local state = _build_state()
    local count_5s, count_3s = 0, 0
    DeadlineService.start(state, "choice", {
      timeout_seconds = 15,
      on_warn = function(level)
        if level == "warn_5s" then count_5s = count_5s + 1 end
        if level == "warn_3s" then count_3s = count_3s + 1 end
      end,
    })
    -- 多次小步推进越过 5s 阈值
    DeadlineService.tick(state, 11.0)  -- remaining=4 -> warn_5s
    DeadlineService.tick(state, 0.5)   -- remaining=3.5 still warn_5s scope
    DeadlineService.tick(state, 0.6)   -- remaining=2.9 -> warn_3s
    DeadlineService.tick(state, 0.5)
    assert.equals(1, count_5s)
    assert.equals(1, count_3s)
  end)

  it("expires entries at exact timeout and treats missing elapsed as zero", function()
    local state = _build_state()
    local active = runtime_state.ensure_deadlines(state).active
    local fired_scope = nil
    local entry = {
      scope = "choice",
      timeout = 1,
      on_timeout = function(scope)
        fired_scope = scope
      end,
      fired_warn_5s = false,
      fired_warn_3s = false,
      fired_timeout = false,
    }

    active.choice = entry

    DeadlineService.tick(state, 0.25)

    assert.is_nil(fired_scope)
    assert.equals(0.25, entry.elapsed)
    assert.equals(0.75, DeadlineService.peek(state, "choice").remaining_seconds)

    DeadlineService.tick(state, 0.75)

    assert.equals("choice", fired_scope)
    assert.is_true(entry.fired_timeout == true)
    assert.is_nil(DeadlineService.peek(state, "choice"))
  end)
end)
