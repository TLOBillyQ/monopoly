--- 反例 fixture:LuaUnit failures 桶的另一半聚合口径(#74 断言层迁移试点)。
---
--- 前六个 fixture 钉的是 luassert 侧:luassert 抛普通字符串 error,不带
--- `LuaUnit test FAILURE: ` 前缀,旧 runner 归 **errors** 桶。本 fixture 钉另一半
--- 口径——lu.fail 带前缀,归 **failures** 桶。两桶各自都能把 runner 退出码顶成
--- 非零,所以迁移前后「红」既不会被吞,也不会因为换了桶而被当成新错误。
---
--- 契约见同目录 deep_compare_and_identity.lua 的文件头。
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local luassert = assert(require("test.support.luassert_loader").load())

TestLuassertFixtureLuaunitFailureBucket = {}

-- 控制:与 lu.fail 同处一文件,luassert 的绿照常为绿。
function TestLuassertFixtureLuaunitFailureBucket:test_control_luassert_green_beside_a_luaunit_failure()
  luassert.is.equal(1, 1)
end

-- 反例:lu.fail 的消息带 FAILURE_PREFIX,必须落 failures 桶。
function TestLuassertFixtureLuaunitFailureBucket:test_counterexample_lu_fail_lands_in_the_failures_bucket()
  lu.fail("断言层迁移试点:lu.fail 的 FAILURE_PREFIX 必须落 failures 桶,不能被吞")
end

return TestLuassertFixtureLuaunitFailureBucket
