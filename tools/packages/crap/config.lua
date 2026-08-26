return {
  project_name = "Monopoly",
  project_root = "../../..",
  source_roots = { "src" },
  coverage = {
    -- luacov adapter：spec 在 luacov.runner 下跑，report.out 由
    -- luacov 原生 reporter 产出,crap4lua 只解析标准产物。自研 debug hook
    -- 适配器(adapter.lua)与加载期回放(load_coverage.lua)已删除。
    adapter = function()
      return require("packages.crap.luacov_adapter")
    end,
    lanes = {
      behavior = function()
        return require("packages.crap.luacov_adapter")
      end,
    },
    -- 相对 project_root(仓根)解析;build/ 是 gitignored 生成物区,报告不落根目录。
    report = "build/luacov.crap.report.out",
  },
  -- CRAP 质量门禁阈值对齐上游 v0.1.0（6 -> 5.0）。crap_gate.lua 用平坦
  -- 上限:任何函数 crap > 5.0 即失败;覆盖率缺失(N/A)同样计违例(#275-③)。
  -- 无白名单、无 per-file 基线、无复杂度豁免。满覆盖时 crap == 复杂度,
  -- 故复杂度 > 5 的函数只能靠拆分达标。
  crap_threshold = 5.0,
}
