# 属性测试覆盖：land/pricing（2026-06-01 refactorer）

规则层变异闭合 arc 收尾后，refactorer 行使 property-test 所有权评估属性覆盖，
发现 `src/rules/land/pricing.lua` 的不变量此前**无直接 property 覆盖**：
`asset_total_spec` 仅把 `pricing.total_invested` 当 **oracle** 验 asset_total，
`land_spec`/`land_rent_spec` 是行为 spec（点值用例），`rent_for_level` /
`upgrade_cost` / `max_level` 的数学不变量完全没生成式覆盖。

新增 `spec/property/pricing_spec.lua`（11 properties，property lane 50 → **61 ok**）：

- `total_invested`：level 0 / 非正 level = 购价；level 单调非减；≥max_level 平台；
  每级步进 == `upgrade_cost(tile, k-1)`（绑定两函数）；无 ladder 恒为购价。
- `rent_for_level`：level 单调非减；level≥1 相邻翻倍（闭式 `price*2^(L-1)`，0.5 抵消
  2 的幂无余数）；≥max_level 平台；无 price 回退 rents ladder（越界→0）。
- `upgrade_cost`/`max_level`：max_level == ladder 长度（无 ladder→0）；in-range 读
  ladder 项，越界 / 负 level → 0。

生成器只造非负 price/cost（单调性前提）。property lane 走 `busted --run property`，
按宪法**不进** normal verify / coverage / 语言变异 lane。verify 9/0、property 61 ok。
