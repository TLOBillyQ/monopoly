---
kind: adr
status: stable
owner: architecture
last_verified: 2026-05-04
---
# ADR 0003 — 知识库目录重组（agent-friendly layout）

**Status**: Accepted (2026-05-04)
**Supersedes (partial)**: 旧 `.agents/harness/` 与 `docs/architecture/` 混合布局

---

## 上下文（Why）

`.agents/harness/` 与 `docs/` 此前为扁平/混合结构：架构契约、ADR、工具指南、生成报告、第三方参考与产品规格全部堆在 `docs/architecture/` 与 `docs/` 根下，agent 与人类协作者都难以按"任务 → 文档"快速定位。同时缺乏统一 front-matter，无法判断文档新鲜度与所有者，CLAUDE.md 也膨胀到难以维护。

执行人需要一个按"轴"组织、机器可读、可被 agent 直接索引的知识库。

---

## 决策（What）

### D1 — 六轴目录结构

```
docs/
  architecture/   # 架构契约（boundaries / layer-model / quality-map）
  decisions/      # ADR 序列
  guides/         # 工具使用指南（mutate4lua / scrap4lua / front-matter）
  reports/        # 工具生成报告（arch-view / crap / behavior-warns / coverage / health-signals）
  reference/eggy/ # 第三方宿主文档（只读参考）
  product/        # 产品 backlog、地图、策划原稿
```

### D2 — `.agents/harness/` → `.agents/conventions/`

`harness` 语义不清；`conventions` 明确表达"agent 约定/守则"。`eggy-types.md` 从 `coding.md` 拆出独立成文。

### D3 — Front-matter 标准

所有 markdown 必须含 `kind / status / owner / last_verified` 四字段；详见 `guides/front-matter.md`。

### D4 — 双 README + 精简 CLAUDE.md

`.agents/README.md` 为 agent 入口，`docs/README.md` 为知识库入口；CLAUDE.md 精简到 ≤15 行，只做导航。

---

## 后果（Consequences）

**正向**：
- agent 可按轴定位文档；"任务 → 文档"映射写在 README
- front-matter 让脚本可批量校验文档新鲜度
- 命名/路径稳定，引用不再随重构漂移

**代价**：
- 全仓硬编码路径需一次性更新（已在 T1-T20 完成）
- 历史链接需通过 `git log --follow` 追溯
- 新增文档必须遵守 front-matter 与目录归属规则

---

## 相关任务

T1-T20（reorganization plan，参见 `.sisyphus/plans/`）。
