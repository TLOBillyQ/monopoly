---
name: verify
description: 质量车道编排器。模式：--smoke（~9s，behavior-smoke 窄反馈）、default（~5s slim，七层 + foundation 行为 spec 全跑）、--full（~50s，恢复 coverage + crap）。终序：verify → mutate → dry → acceptance soft。提供选项不指挥调用者：swarm-forge 角色按各自 prompt 的 flag 权限自取。触发：src/** 迭代、handoff、PR、commit 前。不用于：单工具诊断（mutate / dry / crap viewer / arch viewer 各自有 skill）；tooling profile 单测走 `lua tools/quality/busted_lane.lua --profile tooling`（压缩输出）。
---

# Verify

质量车道编排器。给调用方提供模式选项；角色边界由 `swarmforge/roles/*.prompt` 决定，本 skill 只说明选项与当前车队行为。

## 模式

```bash
# 迭代信心扫：behavior-smoke + contract + guards + arch + lint + encoding，~13s
lua tools/quality/verify_full.lua --smoke

# 默认 slim（无 flag）：contract + guards + arch + behavior(全) + lint + encoding，~6s
lua tools/quality/verify_full.lua

# 完整车道：默认 slim + coverage + crap，~70s；恢复旧默认
lua tools/quality/verify_full.lua --full

# 分别加 opt-in 车道
lua tools/quality/verify_full.lua --coverage       # 加 coverage 并行 lane
lua tools/quality/verify_full.lua --crap           # 加 crap_collect → crap → crap_gate
lua tools/quality/verify_full.lua --coverage --crap # 等价 --full

# 向后兼容：静默 no-op
lua tools/quality/verify_full.lua --no-coverage
```

## 车道集

| 模式 | 车道 | 典型 wall |
|---|---|---|
| `--smoke` | arch, contract, behavior-smoke（turn+foundation+host+state+rules+ui+scenarios{turn_flow,startup}）, encoding, guards, lint | ~13s |
| default（无 flag） | contract, guards, arch, behavior（全跑）, lint, encoding | ~6s |
| `--coverage` | default + coverage 并行 lane | ~60s |
| `--crap` | default + crap_collect 并行 lane → crap_analyze → crap_gate sequential | ~14s |
| `--full` | default + coverage + crap | ~70s |
| `--tooling` | 与上述模式正交叠加，加 tooling 并行 lane | +~30s |

`--smoke --no-coverage` 静默（smoke 本就不含 coverage）。
`lint` 在 luacheck 缺失或 lua5.4 缺失时 skipped；`coverage` 在 lua5.4 缺失且未显式请求时 skipped，显式 `--coverage` 不可用时 emit warning。

verify 不跑 `tooling profile`（混合工具契约 + 模块单测，不是验收材料）；`tools/{quality,acceptance,shared,ops}/**` 改动直接 `lua tools/quality/busted_lane.lua --profile tooling` 单跑（等价 `busted --run tooling`，但压缩 TAP 成汇总）。

## 角色权限

| flag | 允许 | 禁止 |
|---|---|---|
| `--coverage` / `--crap` / `--full` | refactorer, architect | coder, specifier |
| 默认无 flag / `--smoke` | 全部角色 | — |
| `--tooling` | 改工具链时任何人 | — |

角色 prompt 是权限真源；本表仅摘要。

## 选项画像

| 选项 | 覆盖 | 跳过 | 适合 |
|---|---|---|---|
| `lua tools/acceptance/run_acceptance.lua` | Gherkin 验收 | 整条 `verify` 管线 | 只验规约可执行性 |
| `verify --smoke` | behavior-smoke + contract + guards + arch + lint + encoding | coverage, crap, mutation, Gherkin mutation | 高频迭代窄反馈 |
| `verify`（无 flag） | contract + guards + arch + behavior(全) + lint + encoding | coverage, crap, mutation, Gherkin mutation, tooling profile | handoff / PR / commit 前默认 slim gate |
| `verify --full` | 默认 slim + coverage + crap | mutation, Gherkin mutation, tooling profile | 需要完整覆盖率 / CRAP 报告时；refactorer/architect 场景 |
| 终序：`verify` → `mutate.lua <file>`（每文件、`--max-workers 8`、diff 模式）→ `dry.lua` → `acceptance-mutate --level soft --status-interval 0 --feature <feature>` | 完整车道 + 单文件 mutation + 重复检测 + soft Gherkin mutation | tooling profile | 重大改动收尾，architect 承接 mutation / DRY / Gherkin mutation 责任 |

挑选提示：

- 默认 `verify` 已剥离 coverage + crap；需要这两者时显式 `--full` 或分别 `--coverage` / `--crap`。
- coder / specifier 禁 `--coverage` / `--crap` / `--full`；发现需要时 handoff 给 refactorer / architect。
- Gherkin mutation 与单文件 mutation 都不在 default / slim / full 管线里，由 architect 终序兜底。
- `tools/{quality,acceptance,shared,ops}/**` 改动跑 `lua tools/quality/busted_lane.lua --profile tooling` 单跑模块单测；需要原始 TAP 时再用 `busted --run tooling`；shell-out 端到端覆盖（luarocks 子进程等）走 `--coverage` / `--full` 触发 coverage lane。

红车道 → 看 `[verify] FAIL <lane>` 行，按 lane 名跑下钻。

## default vs smoke 边界

- **default**：跑完整 `behavior`（含 app/computer/config/player/scenarios 其余子目录）。
- **smoke**：只跑 behavior-smoke 子集（turn/foundation/host/state/rules/ui + scenarios{turn_flow,startup}）。
- smoke 从"快很多"转为"窄反馈"；两档 wall 在 D6 落地后趋同，但 smoke 仍不覆盖低频 behavior 目录。

## Pipeline 不包含（按需走单工具 skill）

- **mutate**（单文件变异诊断）：`/mutate <file>`
- **dry**（结构重复检测）：`/dry`
- **arch viewer / scan**（架构图导出 / 机器可读 JSON）：`/arch-view`
- **crap viewer / summary**（HTML 视图 / 三层覆盖率聚合）：`/crap`

这些是 opt-in 诊断工具，pipeline 故意不内含。
