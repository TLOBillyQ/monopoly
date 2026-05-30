# items-survivors 重测裁定 — trail 可关闭

coder handoff `items-survivors` 申请关闭 · architect branch `swarmforge-architect` @ aff28541 · 2026-05-29
items.feature baseline 90/90 green。

## 重测结果（gherkin-mutator `--level full`, current HEAD）

**features/game/items.feature: total=155, killed=155, survived=0, errors=0 → 100%**

## 裁定：APPROVED，trail 无工作，关闭

coder 的代码级分析全部成立，实测确认：
- backlog 旧测量（9 survivor / 4 closable / L87·L172·L227）**陈旧**——跑在更短的旧 feature 上（现 source_line 差 ≈100；现 feature 1072 行 / 155 mutation vs 旧 30 mutation）。
- 4 个曾标 closable 的 survivor 现已全 killed：CJK 单元格（神灵类型 / 道具名）经 `_dither_string` 字节污染必成非法 UTF-8，两个 setup 步过 `_require_allowed` 白名单（83380ce3 "harden steal mutation coverage", 2026-05-25）→ setup 失败 → killed；目标初始道具数 1→6 被 `目标剩余0张道具` 断言杀。
- 5 个曾标 structural residue 也已随 feature 加固消失。

coder 不写 验证 列是对的（不为已 killed 的 mutation 造重言式断言）。

## 方法论

dispatch gherkin closure 前必须在 current HEAD 重测——survivor 测量跨 feature 编辑会陈旧（行号漂、mutation 数变）。CJK example cell 在 `_require_allowed` 白名单后天然抗 byte-garble（setup-fail 即 kill）。见 [[project_gherkin_survivor_measurement_staleness]]、[[project_gherkin_validation_column]]。
