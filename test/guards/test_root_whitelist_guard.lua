require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local guard = require("test.guards.lib.root_whitelist_guard")

-- #490 放行条目退役钉：dependency-checker.edn 与
-- implementation-order.md 是 squad analyst 的根级产物,随 squad 范式退场——白名单
-- 恢复报违规,重引入放行即破此钉。guard 只跑在「已经合规的真实仓库」上时测不出
-- 放行是否生效,所以一律用 M.check 喂合成输入。

TestRootWhitelistGuard = {}

function TestRootWhitelistGuard:test_dependency_checker_edn_retired()
  local violations = guard.check({ "dependency-checker.edn" })
  lu.assertIs(#violations, 1)
  lu.assertEquals(violations[1], "dependency-checker.edn")
end

function TestRootWhitelistGuard:test_implementation_order_md_retired()
  local violations = guard.check({ "implementation-order.md" })
  lu.assertIs(#violations, 1)
  lu.assertEquals(violations[1], "implementation-order.md")
end

function TestRootWhitelistGuard:test_root_readme_is_retired()
  local violations = guard.check({ "README.md" })
  lu.assertEquals(violations, { "README.md" })
end

-- 上游 four-pack launcher 退役钉（2026-08-30 迁入本地 swarm-forge）：启停走
-- forge dashboard，根部不该再有 swarm / close-swarm；重引入即破此钉。
function TestRootWhitelistGuard:test_upstream_launchers_are_retired()
  lu.assertEquals(guard.check({ "swarm", "close-swarm" }), { "swarm", "close-swarm" })
end

-- 运营方任务书 tasks/<task-name>.md 是版本化的意图真源（master 随任务首次
-- git 工作提交），常驻白名单；把它降级为忽略项即破此钉。
function TestRootWhitelistGuard:test_tasks_doc_dir_stays_whitelisted()
  lu.assertEquals(guard.check({ "tasks" }), {})
end

-- 常规根级条目不受影响。
function TestRootWhitelistGuard:test_regular_entries_stay_whitelisted()
  local violations = guard.check({
    "src",
    "test",
    "swarmforge",
    "AGENTS.md",
    "CODING_STANDARDS.md",
  })
  lu.assertIs(#violations, 0)
end

-- 防回归:白名单不是摆设,未知根级条目必须仍被报违规。
function TestRootWhitelistGuard:test_still_flags_unknown_root_entry()
  local violations = guard.check({ "mystery-root-file.txt" })
  lu.assertIs(#violations, 1)
  lu.assertEquals(violations[1], "mystery-root-file.txt")
end

function TestRootWhitelistGuard:test_deduplicates_repeated_names()
  local violations = guard.check({ "mystery.txt", "mystery.txt" })
  lu.assertIs(#violations, 1)
end

return TestRootWhitelistGuard
