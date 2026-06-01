return {
  project_name = "Monopoly",
  project_root = "../../..",
  source_roots = { "src" },
  coverage = {
    adapter = "adapter.lua",
    lanes = {
      behavior = "adapter.lua",
      contract = "busted_adapter.lua",
    },
  },
  -- CRAP 质量门禁基线阈值。
  -- crap_gate.lua 用复杂度感知上限 max(crap_threshold, cx+1)：
  --   cx<=6 → 上限 = crap_threshold（沿用旧 <7 门），靠补覆盖压低；
  --   cx>=7 → 上限 = cx+1，接受 crap 的复杂度本征下限（满覆盖即过），
  --            仅当覆盖缺口把 crap 顶到下限之上一整分时才失败。
  -- 门以棘轮方式执行（见 crap/crap_gate_baseline.lua）：只挡新增回归。
  crap_threshold = 7,
}
