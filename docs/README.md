---
kind: contract
status: stable
owner: architecture
last_verified: 2026-05-04
---

# docs/ 索引

本 `docs/` 按六轴组织：**architecture**（架构契约）/ **decisions**（ADR）/ **guides**（工具指南）/ **reports**（生成报告）/ **reference**（第三方参考）/ **product**（产品规格）。

## 任务 → 文档

| 任务 | 文档 | 说明 |
|------|------|------|
| 了解架构边界与目录 | `architecture/boundaries.md` + `layer-model.md` | 七层 + foundation 物理映射 |
| 查看架构决策 | `decisions/0001-seven-layer-with-foundation.md` | D1-D7 决策记录 |
| 测试车道与质量职责 | `architecture/quality-map.md` | behavior/contract/guard/arch/crap 分工 |
| 静态架构扫描 | `reports/arch-view.md` | arch_view 工具报告 |
| 风险热点（CRAP） | `reports/crap.md` | 复杂度×覆盖率热点 |
| 变异测试 | `guides/mutation-testing.md` | mutate4lua 工具指南 |
| 行为测试 warn 判读 | `reports/behavior-warns.md` | warn 白名单说明 |
| 覆盖率报告 | `reports/coverage.md` | 覆盖率基线与趋势 |
| 健康信号 | `reports/health-signals.md` | 架构健康指标 |
| UI 组件 | `reference/eggy/guide/ui_manager.md` | Eggy 宿主 UI API |
| 宿主 API | `reference/eggy/api/00_index.md` | Eggy 宿主接口索引 |
| 产品 backlog | `product/backlog.md` | 功能待办列表 |
| 地图设计 | `product/map.md` | 地图结构设计 |
| 策划原稿 | `product/design-source/` | xlsx/docx 原稿（agent 不可读） |

## 子目录速查

| 目录 | 放什么 | 不放什么 |
|------|--------|---------|
| `architecture/` | 架构契约、边界、质量地图 | ADR、工具指南 |
| `decisions/` | ADR（架构决策记录） | 非决策文档 |
| `guides/` | 工具使用指南 | 架构契约 |
| `reports/` | 工具生成的报告（status: generated） | 手写文档 |
| `reference/eggy/` | 第三方宿主文档 | monopoly 工程契约 |
| `product/` | 产品规格、backlog、策划原稿 | 技术文档 |

## 如何添加新文档

1. **front-matter 必填**：`kind` / `status` / `owner` / `last_verified`（格式见 `guides/front-matter.md`）
2. **选目录**：契约→`architecture/`，决策→`decisions/`，指南→`guides/`，报告→`reports/`，产品→`product/`
3. **命名 kebab-case**：`my-new-doc.md`，不用下划线

Agent 入口：`.agents/README.md`
