# skin_shop.feature soft Gherkin 变异 — example-value survivor【全 benign，关闭】

## 当前测量：HEAD `32667666`（skin-unequip-route 合并后）

`./acceptance-mutate --feature features/v102/skin_shop.feature --level soft`
→ `killed=309 survived=12 errors=0`（feature 因新增脱下场景增长；survivor 由 5 增至 12，新增 7 个全为 Examples 单元残留）。

## survivor 清单（scenario 索引 + 字段）

| 字段 | 突变 | 场景 | 判定 |
|------|------|------|------|
| 槽位 | 1→5 / 3→6 | [14] 点击已装备槽位触发脱下（新） | lockstep：own/equip/click/断言同走 `槽位`，落购买类任意槽位皆真 |
| 皮肤数 | 6→4 | [14] 同上 | slot3 仍有效、pages 不变（≤6）→ benign |
| 角色ID | 1→2 | [25][36] | input==expected 锁步 / role-agnostic setup |
| 验证槽位 | 6→1 | [27] 购买类按钮显示价格可点 | 1 也是购买类槽位（3/4 为赠礼）→ 价格+可点仍真 |
| 皮肤数 | 6→5 / 6→2 | [28][38][39] | 不跨页边界、不失效被引槽位 → benign |
| 槽位 | 5→6 / 6→4 / 1→5 | [31][32] | 购买类槽位 lockstep 迁移 |

## 结论：全部 benign，无可分离 assert-only 缺口

判据同既有定性（读 `tools/acceptance/steps/skin_shop.lua`）：
- `槽位`/`验证槽位` 落购买类满足集，输入与断言锁步迁移；
- `角色ID` input==expected 锁步，跨角色覆盖由兄弟 example 钉死；
- `皮肤数` 在 `≤ page_size 6` 内不改页数、不失效被引槽位。

新增脱下场景 [14] **真闭环到 src**（click→`canvas_route.skin_panel`→`view_command.dispatch`→unequip，差分变异 canvas_route 16/16 killed 佐证）；其 Examples 残留与闭环无关。

按 [[project_contract_features_gherkin_mutation_resistant]] 判为 UI feature 例值残留：不补 change-detector、不路由 specifier。后续 skin_shop.feature/step handler 有 delta 时复跑 soft 复核。

参考：[[project_gherkin_validation_column]]、[[project_gherkin_survivor_measurement_staleness]]、ADR 0017。
