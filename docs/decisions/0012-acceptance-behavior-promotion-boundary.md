---
kind: adr
status: stable
owner: quality
last_verified: 2026-05-23
---
# ADR 0012 — Acceptance 与 Behavior 测试提升边界

## 背景

`spec/behavior/` 按架构层覆盖 rules、turn、state、host、foundation、ui 和 scenarios，是本仓库的主要实现回归网。`features/` 与 `tools/acceptance/` 则承担中文 Gherkin 验收规格，面向外显玩法和 UI 行为。

把 `spec/behavior` 整体迁到 acceptance 会把内部端口、mock、module reload、错误消息和分支定位测试伪装成业务规格，降低两个测试面的信号质量。因此本仓库采用“提升外显行为”，不做“测试搬家”。

## 决策

### D1 — Acceptance 是外显行为真源

写进 `features/*.feature` 的场景必须满足至少一条：

- 策划或 QA 能用产品语言读懂。
- 玩家可观察到结果，例如金币、位置、道具、神灵、回合、面板状态。
- 能通过真实 `game_driver`、UI facade 或明确的产品级 mock 观察，不依赖模块私有状态。

Acceptance 不按架构分层；按玩法主题组织，例如 `deities.feature`、`items.feature`、`turn_flow.feature`。

### D2 — Behavior 保留为实现回归网

以下测试继续留在 `spec/behavior/`：

- foundation、host、app、state 的端口 fallback 和装配契约。
- `package.loaded` patch、stub、module reload、错误消息、异常分支。
- UI sync、render、coord、input dispatch 等内部协作细节。
- 能快速定位单个模块分支的窄断言。

这些测试可以补充 acceptance，但不应被 Gherkin 逐条翻译。

### D3 — 提升标签

评估 behavior case 时只使用四类结论：

- `promote`：外显行为缺失，补到 `features/`。
- `keep`：内部契约或定位价值高，留在 behavior。
- `split`：主路径提升到 acceptance，边界和异常留在 behavior。
- `drop-duplicate`：acceptance 已用真实路径覆盖，behavior 没有额外定位价值时才删除。

默认不删除 behavior；只有明确 `drop-duplicate` 才删。

### D4 — Step handler 不平行实现业务规则

新增 acceptance step 时优先调用真实域逻辑或现有 driver/facade。只在规格工具自身测试或纯展示 mock 场景中维护 world-only 小模型。

如果 step handler 重写了一套与 `src/` 平行的规则，它只能作为临时过渡，后续必须收敛到真实 driver/facade。

## 首个提升样例

`spec/behavior/rules/item_transfer_atomicity_spec.lua` 中：

- 请神卡 happy path 提升到 `features/game/deities.feature`。
- 送神卡 happy path 提升到 `features/game/deities.feature`。
- 空神灵占位、无神灵、非穷神使用者、过期穷神等异常和边界留在 behavior。

这个样例采用 `split`：acceptance 守“神灵从谁转到谁”，behavior 守“哪些目标/使用者不合法以及错误契约”。

## 验证

每次提升至少运行：

```sh
lua tools/acceptance/cli/parser.lua features/game/<feature>.feature ./tmp/<feature>.json
lua tools/acceptance/cli/generator.lua ./tmp/<feature>.json tools/acceptance/generated/<feature>_acceptance_spec.lua
busted --helper=spec/helper.lua tools/acceptance/generated/<feature>_acceptance_spec.lua
busted --helper=spec/helper.lua spec/behavior/<original>_spec.lua
```

如果全量 acceptance 已有历史红灯，提升提交必须在结果里明确区分新增失败与既有失败。
