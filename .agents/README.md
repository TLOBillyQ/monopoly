---
kind: contract
status: stable
owner: architecture
last_verified: 2026-05-04
---

# Agent 路由

Eggy 类型映射见 `docs/reference/eggy/eggy-types.md`，按需查阅；不预读目录树。

## 按改动入口路由

> **默认轴**：迭代用 `verify --smoke`（~8s，含 contract + behavior/rules + behavior/ui），handoff / PR / commit 前才跑 `verify`（含 crap + coverage，~30s）。
> Smoke 已覆盖 src 全部七层 + foundation 的行为 spec，对 src/** 日常编码安全。`verify`（full）保留给提交前 gate。

| 改动 glob | 迭代 | Handoff / 提交前 | 可选 |
|---|---|---|---|
| `docs/**` / `*.md` | — | — | — |
| `src/foundation/**` | `verify --smoke` | `verify` | `mutate`, `arch-view` |
| `src/rules/**` | `verify --smoke` | `verify` | `mutate`, `crap` |
| `src/turn/**` | `verify --smoke` | `verify` | `mutate` |
| `src/ui/**` | `verify --smoke` | `verify` | `dry` |
| `src/host/**` | `verify --smoke` | `verify`（+ Win 上 `busted --run e2e`，若触发 ADR 0013 D3） | `arch-view` |
| `tools/{quality,acceptance,shared,ops}/**` | `verify --smoke`* | `verify` + `busted --run tooling` | — |
| `features/**`（Gherkin） | `lua tools/acceptance/run_acceptance.lua <feature>` | `verify` | — |
| `spec/**`（改测试本身） | `busted --run <对应 lane>` | `verify` | — |

> **3 分钟决策树**：
> 1. 只动 docs/markdown → 不跑测试
> 2. 动 `src/**` 迭代 → `verify --smoke`（~8s）；handoff / PR / commit 前 → `verify`
> 3. 动 `tools/{quality,acceptance,shared,ops}/**` → 迭代 `verify --smoke`*（轻；不覆盖工具模块本身）；handoff `verify` + `busted --run tooling`（前者跑 shell-out 端到端，后者跑工具模块单测）
> 4. 动 `src/host/**` 触发 ADR 0013 D3 → handoff 时加 Windows 上 `busted --run e2e`
> 5. 提交前不确定 → `verify`（默认含 crap + coverage）
>
> *若 `tools/{quality,acceptance,shared,ops}/**` 改动牵涉 binary / PATH / env / subprocess 路径，iter 也应直接 `verify`（默认含 coverage lane，触发 luarocks 等子进程；memory: 工具链 shell-out 端到端是最低验证线）。

## 任务 → 文档

| 任务 | 文档 |
|------|------|
| 架构边界与目录 | `docs/architecture/boundaries.md` + `layer-model.md` |
| 架构决策（七层 + foundation） | `docs/decisions/0001-seven-layer-with-foundation.md` |
| 测试车道与质量职责 | `docs/architecture/quality-map.md` |
| 静态架构扫描报告 | `docs/reports/arch-view.md` |
| 风险热点（CRAP）报告 | `docs/reports/crap.md` |
| 变异测试 | `docs/guides/mutation-testing.md` |
| 行为测试 warn 判读 | `docs/reports/behavior-warns.md` |
| 覆盖率报告 | `docs/reports/coverage.md` |
| 健康信号 | `docs/reports/health-signals.md` |
| UI 组件 | `docs/reference/eggy/guide/ui_manager.md` |
| 宿主 API | `docs/reference/eggy/api/00_index.md` |
| 记忆文件 | `docs/reference/eggy/agent/memory.md` |
| Eggy 类型规范 | `docs/reference/eggy/eggy-types.md` |
| 产品 backlog | `docs/product/backlog.md` |
| 地图设计 | `docs/product/map.md` |

## 技能 → 路径

> **三层契约**：
> - `.agents/skills/*` — 工作流路由：何时用、给谁、红线（团队契约）
> - `docs/guides/`, `docs/reports/` — 技术真源：工具机制、子命令、报告读法
> - Claude Code 私人 memory — 临时复发经验，不是团队契约；workflow 性经验应升格到 skill，技术性经验应升格到 docs
>
> skill 不重复 docs 内容；技术细节看 skill 末尾的「真源」段。`tools/{quality,acceptance,shared,ops}/*` 改动一律以 `lua tools/quality/verify_full.lua` 兜底（来自工具链验证实践）。

| 技能 | 路径 | 触发时机 |
|------|------|---------|
| `verify` | `.agents/skills/verify/` | 质量车道编排器；`--smoke` 迭代信心扫（~8s，含 contract + 全 behavior smoke），无 flag 完整车道（~30s，含 crap + coverage）；tooling profile 单测走 `busted --run tooling` 不在管线内 |
| `mutate` | `.agents/skills/mutate/` | 单文件变异测试诊断；survivor 闭合 |
| `dry` | `.agents/skills/dry/` | 结构重复检测；抽函数 / 重构前 |
| `arch-view` | `.agents/skills/arch-view/` | 架构边界 check / viewer / scan；循环依赖排查 |
| `crap` | `.agents/skills/crap/` | CRAP 风险热点 + 三层覆盖率聚合 |
| `debug` | `.agents/skills/debug/` | bug 或测试失败；运行时日志分析 |

> **报告警告**：`docs/reports/` 是生成产物（`status: generated`）；`last_verified` 超过 30 天降级为"仅参考"，不作契约。

> **Eggy 警告**：`docs/reference/eggy/` 是第三方宿主文档，不是 monopoly 工程契约。
