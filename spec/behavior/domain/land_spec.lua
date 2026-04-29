require("spec.behavior._shim").bind(_ENV, "suites.domain.land", {
  reset = true,
  skip = {
    ["total_invested_caps_and_skips_sparse_upgrade_costs"] = "sparse table {10,nil,40}: busted Lua 5.4 reports #t=3, tests/ harness Lua 5.4 reports #t=1; ambiguous Lua border",
  },
})
