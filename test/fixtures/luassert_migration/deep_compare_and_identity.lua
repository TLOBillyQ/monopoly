--- 反例 fixture:深比较与身份(#74 断言层迁移试点)。
---
--- 本目录是试点反例集,故意失败,由
--- test/support/luassert_migration/test/test_luassert_assertion_contract.lua
--- 交给真实 busted runner 子进程执行。test/fixtures/ 不是任何车道的 spec root,所以
--- 这些红不会漏进车道计数。
---
--- 每个 fixture 的契约(契约 spec 逐文件核对):
---   1. 同文件控制用例必须为绿——证明文件的断言接线本身是通的,反例的红不是
---      「加载即失败」的假红;
---   2. 断言反例必须落在真实 busted 的 failed 桶，并让 runner 退出码非零。
require("test.bootstrap").install_package_paths()

local luassert = assert

describe("TestLuassertFixtureDeepCompareAndIdentity", function()

-- 控制:is.same 是深比较(内容相同即通过);is_not 证明两张表仍是不同引用。
it("test_control_deep_compare_passes_and_identity_still_differs", function()
  local expected = { hp = 10, tags = { "a", "b" } }
  local actual = { hp = 10, tags = { "a", "b" } }
  luassert.is.same(expected, actual)
  luassert.is_not(expected, actual)
end)

-- 反例:is.equal 走 `==`,内容相同的两张表必须红。这正是迁移的头号陷阱——
-- LuaUnit 的 lu.assertEquals 对表是深比较,把名字直译成 is.equal 会静默放松断言。
it("test_counterexample_identity_equal_on_equal_content_tables_fails", function()
  local expected = { hp = 10 }
  local actual = { hp = 10 }
  luassert.is.equal(expected, actual)
end)

end)
