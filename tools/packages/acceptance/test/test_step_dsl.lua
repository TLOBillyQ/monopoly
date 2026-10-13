require("test.bootstrap").install_package_paths()
local check = require("luassert")
local dsl = require("packages.acceptance.step_dsl")

describe("acceptance step DSL", function()

it("passes plain sentence as exact key", function()
  local handlers = dsl.steps({
    ["项目验收步骤已加载"] = function() return true end,
  })
  check.is_function(handlers["项目验收步骤已加载"])
  check.is_nil(handlers.__patterns)
end)

it("keeps placeholder sentence verbatim", function()
  local seen
  local handlers = dsl.steps({
    ["玩家有<数量>个金币"] = function(_, example)
      seen = example["数量"]
      return true
    end,
  })
  -- The runtime binds <数量> from the example; the DSL only registers the key.
  local ok = handlers["玩家有<数量>个金币"]({}, { ["数量"] = "7" })
  check.is_true(ok)
  check.equal("7", seen)
end)

it("strips int annotation and coerces column", function()
  local seen
  local handlers = dsl.steps({
    ["玩家有<数量:int>个金币"] = function(_, example)
      seen = example["数量"]
      return true
    end,
  })
  check.is_function(handlers["玩家有<数量>个金币"])
  check.is_nil(handlers["玩家有<数量:int>个金币"])

  local ok = handlers["玩家有<数量>个金币"]({}, { ["数量"] = "42" })
  check.is_true(ok)
  check.equal(42, seen)
end)

it("passes non annotated columns untouched", function()
  local other
  local handlers = dsl.steps({
    ["玩家<玩家名>有<数量:int>个金币"] = function(_, example)
      other = example["玩家名"]
      return true
    end,
  })
  local ok = handlers["玩家<玩家名>有<数量>个金币"]({}, { ["玩家名"] = "小明", ["数量"] = "3" })
  check.is_true(ok)
  check.equal("小明", other)
end)

it("reports uniform failure for non integer column", function()
  local handlers = dsl.steps({
    ["玩家有<数量:int>个金币"] = function() return true end,
  })
  local ok, err = handlers["玩家有<数量>个金币"]({}, { ["数量"] = "abc" })
  check.is_nil(ok)
  check.truthy(err:find("invalid <数量>", 1, true), err)
  check.truthy(err:find("abc", 1, true), err)
end)

it("compiles anchored integer capture pattern", function()
  local handlers = dsl.steps({
    ["玩家掷出 {点数:int} 点"] = function() return true end,
  })
  check.is_table(handlers.__patterns)
  check.equal(1, #handlers.__patterns)
  local entry = handlers.__patterns[1]
  check.same({ "点数" }, entry.names)
  check.equal("int", entry.types["点数"])
  check.truthy(("玩家掷出 5 点"):match(entry.pattern))
  check.is_nil(("玩家掷出  点"):match(entry.pattern))
end)

it("captures non empty text run", function()
  local handlers = dsl.steps({
    ["当前玩家是 {名字}"] = function() return true end,
  })
  local entry = handlers.__patterns[1]
  check.equal("text", entry.types["名字"])
  -- Non-empty: an empty run does not match.
  check.is_nil(("当前玩家是 "):match(entry.pattern))
  check.equal("小红", ("当前玩家是 小红"):match(entry.pattern))
end)

it("escapes Lua magic literals", function()
  local handlers = dsl.steps({
    ["余额 (元) 为 {金额:int}"] = function() return true end,
  })
  local entry = handlers.__patterns[1]
  check.equal("9", ("余额 (元) 为 9"):match(entry.pattern))
end)

it("errors on ordinary key collision", function()
  local base = dsl.steps({ ["步骤甲"] = function() return true end })
  local extra = dsl.steps({ ["步骤甲"] = function() return true end })
  check.has_error(function()
    dsl.merge(base, extra, "mod_b")
  end)
end)

it("concatenates pattern arrays", function()
  local base = dsl.steps({ ["掷出 {点数:int} 点"] = function() return true end })
  local extra = dsl.steps({ ["移动 {格数:int} 格"] = function() return true end })
  dsl.merge(base, extra, "mod_b")
  check.equal(2, #base.__patterns)
end)

it("merges ordinary keys without collision", function()
  local base = dsl.steps({ ["步骤甲"] = function() return true end })
  local extra = dsl.steps({ ["步骤乙"] = function() return true end })
  dsl.merge(base, extra, "mod_b")
  check.is_function(base["步骤甲"])
  check.is_function(base["步骤乙"])
end)

it("eq reports label expected and actual on failure", function()
  check.is_true(dsl.eq(3, 3, "金币"))
  local ok, err = dsl.eq(2, 3, "金币")
  check.is_nil(ok)
  check.truthy(err:find("金币", 1, true), err)
  check.truthy(err:find("期望 3", 1, true), err)
  check.truthy(err:find("实际 2", 1, true), err)
end)

it("ne passes on inequality", function()
  check.is_true(dsl.ne(2, 3, "金币"))
  check.is_nil((dsl.ne(3, 3, "金币")))
end)

it("range includes both bounds", function()
  check.is_true(dsl.range(1, 1, 6, "点数"))
  check.is_true(dsl.range(6, 1, 6, "点数"))
  check.is_nil((dsl.range(7, 1, 6, "点数")))
  check.is_nil((dsl.range(0, 1, 6, "点数")))
end)

it("contains matches substring or list element", function()
  check.is_true(dsl.contains("玩家小明破产", "破产", "消息"))
  check.is_true(dsl.contains({ "a", "b", "c" }, "b", "列表"))
  check.is_nil((dsl.contains("玩家小明破产", "胜利", "消息")))
  check.is_nil((dsl.contains({ "a", "b" }, "z", "列表")))
end)

it("truthy accepts any truthy value", function()
  check.is_true(dsl.truthy(0, "值"))
  check.is_true(dsl.truthy("", "值"))
  check.is_nil((dsl.truthy(nil, "值")))
  check.is_nil((dsl.truthy(false, "值")))
end)

it("all runs checks in order and returns first failure", function()
  check.is_true(dsl.all(
    function() return dsl.eq(1, 1, "一") end,
    function() return dsl.eq(2, 2, "二") end
  ))
  local ok, err = dsl.all(
    function() return dsl.eq(1, 1, "一") end,
    function() return dsl.eq(2, 3, "二") end,
    function() return dsl.eq(9, 9, "三") end
  )
  check.is_nil(ok)
  check.truthy(err:find("二", 1, true), err)
end)
end)
