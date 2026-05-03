---
kind: guide
status: stable
owner: quality
last_verified: 2026-05-04
---

# Front-Matter 规范

本仓库的活文档统一以 YAML front-matter 标识"它是什么、谁负责、是否新鲜"。最小集合优先，只定义四个核心字段加一个可选字段，其余元数据交给 git 与文件路径表达。

## 字段定义

| 字段 | 必填 | 允许值 | 说明 |
|------|------|--------|------|
| `kind` | 是 | `contract` / `adr` / `guide` / `report` / `reference` / `spec` | 文档体裁。决定读者预期与失效策略。 |
| `status` | 是 | `stable` / `generated` / `draft` / `deprecated` | 生命周期状态。`generated` 由脚本产出，不要手改。 |
| `owner` | 是 | `architecture` / `quality` / `agents` / `product` / `eggy-vendor` | 责任小组。出问题先找这个。 |
| `last_verified` | 视情况 | ISO 日期 `YYYY-MM-DD` | `kind: report` 必填，其余建议填。报告类取 `git log -1 --format=%cs <file>`，不是今天日期。 |
| `supersedes` | 否 | 旧文件相对路径 | 替换关系。废弃旧文件请同时把旧文件 `status` 改成 `deprecated`。 |

## 示例

合约（`docs/architecture/layer-model.md` 风格）：

```yaml
---
kind: contract
status: stable
owner: architecture
last_verified: 2026-04-20
---
```

ADR（`docs/architecture/adr/0001-seven-layer-with-foundation.md` 风格）：

```yaml
---
kind: adr
status: stable
owner: architecture
last_verified: 2025-11-12
---
```

指南（本文自身即范例）：

```yaml
---
kind: guide
status: stable
owner: quality
last_verified: 2026-05-04
---
```

报告（`docs/reports/arch-view.md` 风格，`last_verified` 必填，取自 git）：

```yaml
---
kind: report
status: generated
owner: quality
last_verified: 2026-05-03
---
```

外部参考（`docs/reference/eggy/api/00_index.md` 风格）：

```yaml
---
kind: reference
status: stable
owner: eggy-vendor
last_verified: 2026-03-01
supersedes: docs/reference/eggy/api/legacy-index.md
---
```
