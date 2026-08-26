-- roster 装配层注册的 choice 取消兜底:fallback_registry 解析出
-- choice_cancel 动作,choice id 缺省时字段为 nil。
local lu = require("luaunit")

local fallback_registry = require("src.rules.choice.fallback_registry")

TestRosterFallback = {}

function TestRosterFallback:setUp()
  fallback_registry.reset()
  package.loaded["src.app.roster"] = nil
  require("src.app.roster")
end

function TestRosterFallback:test_cancel_fallback_action()
  local action = fallback_registry.resolve("market_buy", {}, { id = "c1" })
  lu.assertEquals(action.type, "choice_cancel")
  lu.assertEquals(action.choice_id, "c1")
end

function TestRosterFallback:test_cancel_fallback_without_choice_id()
  local action = fallback_registry.resolve("market_buy", {}, nil)
  lu.assertEquals(action.type, "choice_cancel")
  lu.assertEquals(action.choice_id, nil)
end

return TestRosterFallback
