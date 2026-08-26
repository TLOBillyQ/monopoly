require("test.bootstrap").install_package_paths()

local git_query = require("test.guards.lib.git_query")

local M = {}

-- CRAP「刷分 spec」命名门禁(issue #139)。
--
-- 病灶:CRAP 门禁是平坦阈值 6、无豁免,于是「把覆盖率数字压到 6 以下」比「把行为钉住」
-- 更省事。曾长出两个以此为唯一目的的堆场——refactorer_crap_coverage_spec(1427 行)与
-- status3d_resolve_crap_coverage_spec(84 行):git 史显示它们每次增重都精确落在一次 CRAP
-- 战役里,基线报告里有 5 个模块的最差分数恰好卡在 6.00(门槛就是 6)——测试是加到数字够格
-- 就停手,不是加到行为钉住。#123 已把它们的 it 按目标模块归位、两个文件删除。
--
-- 这条 guard 防复发:刷分堆场重新出现即违规——旧 BDD 命名 `*_crap_coverage_spec.lua`
-- 与新 xUnit 命名 `test_*_crap_coverage.lua` 同禁。名字里带 "crap_coverage" 就暴露了
-- 动机是刷分而非钉行为——真测试按目标 src 模块命名,进正牌 test。
-- 这不拦「补覆盖」,只拦「为凑 CRAP 分单开一个以覆盖率命名的堆场」。
local _FORBIDDEN_PATTERNS = {
  "_crap_coverage_spec%.lua$",
  "test_[^/]*_crap_coverage%.lua$",
}

-- 纯策略核:给定路径表,返回违规列表。不碰 git、不碰文件系统——判定逻辑必须能拿合成的
-- 「违规输入」喂进来验证它真的会红；焊死 IO 的门禁
-- 永远见不到违规输入,可能被整个掏空而车道照样全绿)。
function M.check(paths)
  local violations = {}
  for _, path in ipairs(paths) do
    for _, pattern in ipairs(_FORBIDDEN_PATTERNS) do
      if path:match(pattern) then
        violations[#violations + 1] = "crap_coverage_spec_naming_guard: " .. path
          .. "(issue #139:别为凑 CRAP 分单开以覆盖率命名的刷分测试;真测试按目标 src 模块命名、进正牌 test)"
        break
      end
    end
  end
  return violations
end

-- IO 壳:取 tracked test 路径,交给纯核。
function M.run()
  return git_query.run_tracked_guard("crap_coverage_spec_naming_guard", "test", M.check)
end

return M
