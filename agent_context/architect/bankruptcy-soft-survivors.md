# bankruptcy.feature soft Gherkin — 6 survivor【全 benign，关闭】

测量：HEAD（bankruptcy-src-closure 合并后）。`./acceptance-mutate --feature features/game/bankruptcy.feature --level soft` → `total=9 killed=3 survived=6 errors=0`。

## survivor（全在 scenarios[0] 租金破产判定）
6 个均为 `余额`/`租金` 输入单元小扰动：
- ex0（余额100/租金200→破产）：余额 100→102、租金 200→193 — 仍 <0 → 破产
- ex1（余额500/租金200→存活）：余额 500→497、租金 200→209 — 仍 >0 → 存活
- ex2（余额0/租金100→破产）：余额 0→-1、租金 100→101 — 仍 <0 → 破产

## 判定：benign（非闭环缺口）
- 该场景断言 `结算后玩家<结果>`=**二元**（破产/存活），这正是 bankruptcy feature 的契约（淘汰判定），不是精确算术。
- 6 个突变都是不跨越破产阈值的小扰动 → 二元结果不变 → 天然存活。**跨阈值**已被测（大突变翻转会被杀）。
- 精确租金算术属 economy.feature 域（Tier A，game_driver 真闭环已覆盖）。给存活例加「剩余余额=300」断言会重复 economy 且过度规约淘汰契约 → 不补。

闭环本体真实（handler 经 game_driver 驱真 `src.rules.land.actions`/`chance.resolver`，断言读真 `player.eliminated`，ADR 0017 D1.2）。soft survivor 与闭环无关。

参考：[[project_contract_features_gherkin_mutation_resistant]]（gameplay 例外按二元契约判）、ADR 0017 D1.2。
