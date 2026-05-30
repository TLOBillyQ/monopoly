---
name: verify
description: 质量车道编排器。模式：--smoke（~9s 迭代）、default（~50s 含 crap + coverage）、终序（verify → mutate → dry → acceptance soft）。提供选项不指挥调用者：swarm-forge 角色与 solo 按各自 prompt 边界自取。触发：src/** 迭代、handoff、PR、commit 前。不用于：单工具诊断（mutate / dry / crap viewer / arch viewer 各自有 skill）；tooling profile 单测走 `lua tools/quality/busted_lane.lua --profile tooling`（压缩输出）。
---

# Verify

质量车道编排器；合并旧 fast/full 两个 skill 入口。给调用方提供模式选项；角色边界由 `swarmforge/*.prompt` 决定，本 skill 不规定谁该跑什么。

## 模式

```bash
# 迭代信心扫，~9s
lua tools/quality/verify_full.lua --smoke

# Handoff / PR / commit 前完整车道（含 crap + coverage）
lua tools/quality/verify_full.lua

# 跳过 coverage（无 flag 默认含）
lua tools/quality/verify_full.lua --no-coverage
```

## 车道集

| 模式 | 车道 | 典型 wall |
|---|---|---|
| `--smoke` | arch, contract, behavior-smoke（turn+foundation+host+state+rules+ui+scenarios{turn_flow,startup}）, encoding, guards, lint | ~9s |
| default（无 flag） | contract, guards, arch, behavior（全跑）, crap_collect → crap, lint, encoding, coverage | ~50s |

`--smoke --no-coverage` 静默（smoke 本就不含 coverage）。
`lint` 在 luacheck 缺失或 lua5.4 缺失时 skipped；`coverage` 在 lua5.4 缺失时 skipped。

verify 不跑 `tooling profile`（混合工具契约 + 模块单测，不是验收材料）；`tools/{quality,acceptance,shared,ops}/**` 改动直接 `lua tools/quality/busted_lane.lua --profile tooling` 单跑（等价 `busted --run tooling`，但压缩 TAP 成汇总）。

## 选项画像

每个选项的覆盖、跳过、典型场景。角色或 solo 按自己 prompt 的责任边界自取，本表不规定谁该选哪条。

| 选项 | 覆盖 | 跳过 | 适合 |
|---|---|---|---|
| `lua tools/acceptance/run_acceptance.lua` | Gherkin 验收 | 整条 `verify` 管线 | 只验规约可执行性 |
| `verify --smoke` | arch + contract + 七层 + foundation 的 behavior smoke | crap, coverage, mutation, Gherkin mutation | 高频迭代；不承接 CRAP / mutation 责任 |
| `verify`（无 flag） | smoke + 全 behavior + crap_collect → crap + coverage | mutation, Gherkin mutation, `tooling profile` | handoff / PR / commit 前完整 gate |
| 终序：`verify` → `mutate.lua <file>`（每文件、`--max-workers 8`、diff 模式）→ `dry.lua` → `acceptance-mutate --level soft --status-interval 0 --feature <feature>` | 完整车道 + 单文件 mutation + 重复检测 + soft Gherkin mutation | `tooling profile` | 重大改动收尾，承接 mutation / DRY 责任 |

挑选提示：

- 无 flag `verify` 含 crap_collect → crap。prompt 明文禁 CRAP 的调用方应选 `--smoke`，否则会跑到自己不该承接的 lane。
- Gherkin mutation 与单文件 mutation 都不在 default 管线里，由终序方兜底。
- `tools/{quality,acceptance,shared,ops}/**` 改动跑 `lua tools/quality/busted_lane.lua --profile tooling` 单跑模块单测；需要原始 TAP 时再用 `busted --run tooling`；shell-out 端到端覆盖（luarocks 子进程等）走默认 `verify`（coverage lane 触发）。

红车道 → 看 `[verify] FAIL <lane>` 行，按 lane 名跑下钻。

## smoke 安全边界

smoke 已覆盖 src/foundation, src/rules, src/turn, src/state, src/host, src/ui 的 behavior spec + contract。smoke 不跑：

- `behavior/app`, `behavior/computer`, `behavior/config`, `behavior/player`, `behavior/scenarios` 其余子目录（低频改动面）
- crap_collect / crap（覆盖率分析）
- coverage（luacov 跑）

承接 crap / coverage 责任的调用方需要走无 flag `verify` 或更高级别选项补这三块。

## 汇报

- PASS / FAIL 汇总行（含 passed / failed / skipped 数和 wall）
- 失败车道名
- 跳过项原因（luacheck / lua5.4 缺失）

## Pipeline 不包含（按需走单工具 skill）

- **mutate**（单文件变异诊断）：`/mutate <file>`
- **dry**（结构重复检测）：`/dry`
- **arch viewer / scan**（架构图导出 / 机器可读 JSON）：`/arch-view`
- **crap viewer / summary**（HTML 视图 / 三层覆盖率聚合）：`/crap`

这些是 opt-in 诊断工具，pipeline 故意不内含。
