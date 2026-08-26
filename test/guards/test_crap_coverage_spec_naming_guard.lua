require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local guard = require("test.guards.lib.crap_coverage_spec_naming_guard")

-- 门禁的价值全在能变红。每一条都喂合成路径,断言 guard 对「刷分 spec 命名」真的会红,
-- 且对正牌 spec 放行——否则一个不可能变红的 guard 等于没有 guard（#139）。
--
-- 原生 LuaUnit 试点(推翻自研 busted 兼容运行器决策的迁移):describe/it 拍平为文件级 Test* 类,
-- 断言词汇从 luassert 兼容层切到 lu.assertXxx,用例数与改写前一一对应(5 例)。

TestCrapCoverageSpecNamingGuard = {}

function TestCrapCoverageSpecNamingGuard:test_passes_a_repo_with_no_crap_coverage_spec_files()
  local violations = guard.check({
    "test/behavior/ui/test_board_slice.lua",
    "test/behavior/host/test_sound.lua",
    "test/behavior/rules/test_items_phase.lua",
  })
  lu.assertEquals(#violations, 0)
end

function TestCrapCoverageSpecNamingGuard:test_flags_a_refactorer_style_crap_coverage_spec_anywhere_under_spec()
  local violations = guard.check({ "test/behavior/ui/test_refactorer_crap_coverage.lua" })
  lu.assertEquals(#violations, 1)
  lu.assertEvalToTrue(violations[1]:find("test_refactorer_crap_coverage.lua", 1, true))
  lu.assertEvalToTrue(violations[1]:find("#139", 1, true))
end

function TestCrapCoverageSpecNamingGuard:test_flags_the_status3d_style_crap_coverage_spec_too()
  local violations = guard.check({ "test/behavior/ui/test_status3d_resolve_crap_coverage.lua" })
  lu.assertEquals(#violations, 1)
end

function TestCrapCoverageSpecNamingGuard:test_does_not_flag_a_spec_that_merely_mentions_crap_elsewhere()
  -- 只拦 _crap_coverage 结尾的刷分命名(旧 *_crap_coverage_spec.lua 与新 test_*_crap_coverage.lua);正常的 crap 工具测试(如 test_crap_gate)不受影响。
  local violations = guard.check({
    "test/behavior/tooling/test_crap_gate.lua",
    "test/behavior/ui/test_coverage_report.lua",
  })
  lu.assertEquals(#violations, 0)
end

function TestCrapCoverageSpecNamingGuard:test_flags_every_offender_when_several_coexist()
  local violations = guard.check({
    "test/behavior/ui/test_a_crap_coverage.lua",
    "test/behavior/ui/test_legit.lua",
    "test/behavior/rules/test_b_crap_coverage.lua",
  })
  lu.assertEquals(#violations, 2)
end


return TestCrapCoverageSpecNamingGuard
