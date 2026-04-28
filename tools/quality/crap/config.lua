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
  -- CRAP 质量门禁阈值：函数 CRAP 分数必须 < 7
  -- 超过此阈值的函数需要拆分或补充测试覆盖
  crap_threshold = 7,
}
