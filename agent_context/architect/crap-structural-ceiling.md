# CRAP≤6 已触结构性天花板（complexity-floor，非覆盖债）

来源：refactorer CRAP-coverage cycle（merged `a17be806`）。已闭两个 cx≤6 覆盖 holdout（init `_ui_warn_sink` 10.75→4；player_units `resolve_role` 回退 10.5→6，同时把 player_units 变异 kill 率 60.0%→70.0%）。

## 现状

CRAP≤6 现由 **50+ 个 cx≥8 函数**封顶，这些函数已 100% 覆盖 → crap = cx（覆盖项归零，crap 退化为纯复杂度）。**加测无法再降这些函数的 CRAP**；唯一杠杆是**降复杂度的拆分重构**。

## 已裁定并落地（450ffdc5）

用户裁定：低复杂度保持现状 7 基线（只放宽高 cx），棘轮执行只挡新增回归。已实现复杂度感知门
`max(crap_threshold=7, cx+1)`：cx≤6 沿用旧 <7 门，cx≥7 接受 crap 复杂度本征下限（满覆盖即过），
仅覆盖缺口顶到下限上一整分才失败。当前 28 文件 30 违规冻结为棘轮基线
（`tools/quality/crap/crap_gate_baseline.lua`），verify_full 加 `crap_gate` 步只挡新增。
纯逻辑在 `tools/quality/crap/gate.lua`（可单测，crap_tooling_contract +5）。
真正降这批 CRAP 仍需降复杂度拆分（下方岔路依旧成立，按需逐个判）。合法复杂度变更后跑
`lua tools/quality/crap_gate.lua --in tmp/crap_collect.json --update-baseline` 刷新基线。

## 决策岔路（拆分仍待按需裁定）

降这批 CRAP 需把 cx≥8 函数拆小 → 触及 50+ manifest-bearing src 文件 → 必然 desync 内嵌 mutate4lua 清单（见 feedback_refactorer_manifest_blocks_src_restructure），属 coder lane 重构 + architect 后续 --mutate-all 刷新。

权衡：这些函数**已 100% 覆盖、无正确性/覆盖收益**，纯为压 CRAP 指标而拆 50 个函数 = 大量 manifest churn。是否值得需价值判断：
- 若某些 cx≥8 函数确实混合无关职责/可读性差 → 拆分有真实内聚收益，值得 routing 给 coder（按文件分批，避免一次 desync 50 清单）。
- 若只是算法本征复杂（如 dispatch/装配表）→ 拆分是为指标而拆，不值,建议 CRAP tier 接受 cx 本征下限而非强压≤6。

下一步：需要时跑 `lua tools/quality/crap.lua report --top N` 枚举 cx≥8 floor 函数，逐个判「真混职责」vs「本征复杂」，只对前者分批 routing。
