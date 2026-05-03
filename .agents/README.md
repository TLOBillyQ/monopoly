---
kind: contract
status: stable
owner: architecture
last_verified: 2026-05-04
---

# Agent 路由

你的常驻纪律在 `conventions/`，按需查文档；不预读目录树。

## 任务 → 文档

| 任务 | 文档 |
|------|------|
| 架构边界与目录 | `docs/architecture/boundaries.md` + `layer-model.md` |
| 架构决策（七层 + foundation） | `docs/decisions/0001-seven-layer-with-foundation.md` |
| 架构治理路线图 | `docs/architecture/governance-roadmap.md` |
| 测试车道与质量职责 | `docs/architecture/quality-map.md` |
| 静态架构扫描报告 | `docs/reports/arch-view.md` |
| 风险热点（CRAP）报告 | `docs/reports/crap.md` |
| 语义导航（SCRAP） | `docs/guides/semantic-navigation.md` |
| 变异测试 | `docs/guides/mutation-testing.md` |
| 行为测试 warn 判读 | `docs/reports/behavior-warns.md` |
| 覆盖率报告 | `docs/reports/coverage.md` |
| 健康信号 | `docs/reports/health-signals.md` |
| UI 组件 | `docs/reference/eggy/guide/ui_manager.md` |
| 宿主 API | `docs/reference/eggy/api/00_index.md` |
| 子系统归属 | `docs/architecture/subsystems.md` |
| 记忆文件 | `docs/reference/eggy/agent/memory.md` |
| 可执行计划规范 | `.agents/conventions/planning.md` |
| 按需读代码规范 | `.agents/conventions/reading.md` |
| 命名与新增文件规范 | `.agents/conventions/coding.md` |
| Eggy 类型规范 | `.agents/conventions/eggy-types.md` |
| 产品 backlog | `docs/product/backlog.md` |
| 地图设计 | `docs/product/map.md` |

## 技能 → 路径

| 技能 | 路径 | 触发时机 |
|------|------|---------|
| `clean-architecture-reviewer` | `.agents/skills/clean-architecture-reviewer/` | 跨层重构或边界可疑 |
| `uncle-bob-reviewer` | `.agents/skills/uncle-bob-reviewer/` | SRP/DIP 违反或结构混乱 |
| `quality` | `.agents/skills/quality/` | 质量检查流水线 |
| `debug` | `.agents/skills/debug/` | bug 或测试失败 |
| `explain-code` | `.agents/skills/explain-code/` | 解释代码逻辑 |
| `verify-fast` | `.agents/skills/verify-fast/` | 快速信心扫（encoding/guards/arch/behavior） |
| `verify-full` | `.agents/skills/verify-full/` | 完整质量车道（含 contract/tooling/regression） |

> **报告警告**：`docs/reports/` 是生成产物（`status: generated`）；`last_verified` 超过 30 天降级为"仅参考"，不作契约。

> **Eggy 警告**：`docs/reference/eggy/` 是第三方宿主文档，不是 monopoly 工程契约。
