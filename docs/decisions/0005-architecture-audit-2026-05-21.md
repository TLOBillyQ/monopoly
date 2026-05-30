---
kind: adr
status: stable
owner: architecture
last_verified: 2026-05-22
---
# ADR 0005 — Architecture Audit Improvement Backlog (2026-05-21)

**Status**: Accepted (2026-05-22；所有 5 项有 resolution，详见下方)
**Resolution sources**:
- I1 — architect 自执，commit `4a1320e` on `swarmforge-architect`
- I2 — specifier 在 main `64ca1df` 写了 superset 版本（含 4-pattern dep_rules guard），架构侧撤回我自己较轻量的 addendum，认这版为权威
- I3 — coder 在 swarmforge-coder worktree 跑了 step 1，发现 tier 阈值与代码不一致并修正；user 接受 step 2 deferred
- I4 — user 决策为 standalone `tools/quality/verify_mutation_diff.lua` + survived=warn；specifier 在 main `64ca1df` 锁了 Gherkin
- I5 — specifier 在 main `64ca1df` 路由给 coder
**Trigger**: 用户要求 architect 做一次项目层面体检并通知 specifier
**Related**: ADR 0004（differential mutation testing），`docs/architecture/layer-model.md`，`docs/decisions/0002-foundation-state-boundary.md`

---

## 上下文（Why）

`arch_view check` 通过（无边界违规、零循环依赖）。但通过结构性扫描看不到的几类
**漂移 / 机会** 在本次审计中浮出水面。本 ADR 把它们集中列出，每条配
"现状 / 影响 / 建议动作 / 归属"，由 specifier 排队并选择进 Gherkin。

不包含 ADR 0004 已经路由的 G1（mutate4lua 上游 spec）/ G2（mutation 文档漂移）
/ G3（manifest bootstrap rollout）。

---

## 决策（What）—— Improvement 清单

### I1 — `docs/architecture/layer-model.md` foundation 子树描述过期（HIGH，✅ DONE 2026-05-22）

**现状**：文档声称 `src/foundation/` 含 `events/`、`log/`、`lang/`、`identity/`、
`coordination/` 五个子目录。实际：`refactor e9e3ae1 (2026-05-15)` "foundation 子目录
打平" 已合并；当前 foundation 只有 `ports/` 一个子目录 + 6 个 flat .lua 文件
（events.lua / identity.lua / log.lua / number.lua / tables.lua / tips.lua）。

**自执行结果（2026-05-22）**：
- 直接编辑 `docs/architecture/layer-model.md`：替换 "Foundation 子树结构" 段落到现状结构；同时修正 "Port 注入" 段 `ports/` 描述补齐 `move_anim`；`last_verified` bump 到 2026-05-22；加一行 e9e3ae1 历史说明。
- 不再需要 specifier / coder 跟进。

### I2 — ADR 0002 引用已不存在的路径 `src/foundation/log/utils.lua`（MED，✅ SUPERSEDED 2026-05-22）

**现状**：`docs/decisions/0002-foundation-state-boundary.md` 多处（lines 11/24/27/49/53/56/132）
引用 `src/foundation/log/utils.lua`。该文件在 `refactor e9e3ae1` 中并入
`src/foundation/log.lua`。

**严重性修订**：原 ADR 0005 初稿写 "guard 默默失效"不准确。ADR 0002 完成判据
第 1 行的 grep 是目录级递归扫描，flatten 之后仍然有效，今天命中数为 0。
**invariant guard 一直在工作**，只是叙事路径过期。降级 HIGH → MED。

**Resolution**：specifier 在 main `64ca1df` 写了 ADR 0002 addendum 的 superset
版本，包含：
- 显式路径映射表（旧→新）
- 完成判据 line 132 description column 重写
- `spec/guards/lib/dep_rules.lua` 新增 4-pattern 规则
  （双引号/单引号 × 精确 src.state / 子模块 src.state.X）
- 显式保留历史叙事段落不动

我自己较轻量的 addendum（仅有路径映射 + invariant 核验，没有 guard 代码）已
从 architect branch revert，以避免合并冲突 + 让 specifier 的 superset 成为权威
版本。`last_verified` 回退到 2026-05-04（保持 ADR 0002 在 main 上的历史值）。

**归属（完成）**：specifier 写的 dep_rules 4-pattern 规则等 coder 实现；纯文本
addendum 部分已经在 main。

### I3 — `core_logic` 覆盖率基线过期 + 离目标 10.6pp（MED，✅ RESOLVED 2026-05-22）

**原 Audit 现状**：2026-04-28 基线显示 79.4% vs 90% target，top 5 含
`session_script.lua` 6.7%、`state_adapter.lua` 27.1% 等。

**Step 1 — DONE by coder（swarmforge-coder worktree）**：
- 跑刷新发现 `docs/reports/crap.md` 的 tier 阈值 vs `tools/quality/crap/coverage_tiers.lua`
  实际值不一致（doc 90/70，code 75/65），属于另一种 doc drift。已修正
  `docs/reports/crap.md` core_logic 90→75、ui_surface 70→65 对齐代码真源。
- 我审计列举的 top-N 文件多数已 RETIRED（`session_script.lua`、`state_adapter.lua`
  不再存在或已重写）；新 top-N 是 `validator.lua`、`tips.lua`、`items/handlers.lua`。
- 刷新后 core_logic 76.3% vs 75% target = **PASS** (+1.3pp 余量)。
- 后续 `06af526` 又把 `src/app/host_install.lua` 加入 core_logic excludes
  （见关联架构决策章节），余量进一步抬升约 0.8-1pp。

**Step 2 — DEFERRED, user accepted**：当前 tier 已 pass；剩余 sub-60% 文件
属于 wrong-instrument（`runtime_ports` 是 host plumbing，应该走 contract test 而非
Gherkin；`items/strategy` 57.5% 离阈值仅 2.5pp，不紧急）。

**Resolution**：原 I3 假设（"基线过期且 10.6pp 缺口"）部分错误——doc 报告
基线过期是真的，但 90% 不是当前 target（代码真源是 75%），缺口实际只有 ~1pp。
教训：架构审计引用 `last_verified=2026-05-04` 的 generated report 时，
应先 cross-check 是否与代码真源一致。

**归属（完成）**：coder 已完成；user 已签收 step 2 defer。

### I4 — 差分 mutation 解锁了"按变更文件门禁"的新选项（MED，✅ DECIDED 2026-05-22）

**Resolution**：user 拍了独立工具路线 + warn 语义。

- **入口**：独立 `tools/quality/verify_mutation_diff.lua`（不并入 verify_full）
- **触发条件**：git diff `<base>...HEAD` 中的 `src/**/*.lua` 文件
- **失败语义**：survived > 0 = warn（exit 0），baseline 失败 = hard fail（exit 1）
- **基准**：默认 `main`，可 `--base` 覆盖
- **新增/删除文件**：新增 = 全量变异（无 manifest 即视为全 scope changed）；
  删除 = 跳过，不报错
- **输出**：stderr 列改动文件 + survived 计数；JSON 输出可选
- **Gherkin**：specifier 在 main `64ca1df` 锁了
  `features/quality/verify_mutation_diff.feature`（113 行）

**归属（完成）**：coder 落地中。

### I5 — `docs/reports/*` last_verified 同期 vs 实际 git mtime（LOW，✅ ROUTED 2026-05-22）

**Resolution**：specifier 已在 main `64ca1df` 路由给 coder。coder 自行选择
sh one-liner 还是 `tools/quality/refresh_frontmatter_dates.lua` 实现路径。

---

## 不在本 ADR 范围

- ADR 0004 的 G1 / G2 / G3：已由独立 notify 消息路由给 specifier，不重复。
- 用户 D4 (N1/N2)：specifier 已在 `3b7b508` 内确认接受，按 N1/N2 落地 Gherkin。
- `verify_full.lua` 整体改造（除 I4 外）：当前编排已稳定，不动。
- `arch_view`、`crap4lua` 包装层职责拆分：当前职责清晰，不动。
- 文档目录重组：ADR 0003 刚做完不久，不要又翻一次。

## 关联架构决策（不属 I1-I5 但应记录）

### host_install 留在 src/app/（2026-05-22）

coder 尝试把 `src/app/host_install.lua` 移到 `src/host/install.lua`，失败于
`arch_view` 的 `host_no_gameplay_chain` 规则——这个文件实质上把 host / rules /
ui 桥接起来，是 src/app 的本职（参 `docs/architecture/boundaries.md`：
"src/app: 装配：拼接运行时端口、bootstrap、game_state class-level mixin 安装"）。

User 拍板：文件留在 `src/app/`，改进 `vendor/crap4lua` 支持 per-tier `excludes`
字段，把 host_install 从 core_logic tier 排除掉。

**架构含义**：
- src/app 的"装配点 / cross-layer wiring"职责得到强化；任何未来 install/bootstrap
  文件如果有同样桥接性质，都属 src/app 而非 src/host
- coverage tier 是一种与目录边界并行的分类轴；当一个文件在目录上属于某层
  但语义上不该被该层 coverage 衡量时，`excludes` 是干净出口而不是层移动
- Gherkin 锁在 main `06af526` 的 `features/quality/coverage_tier_excludes.feature`
- 边界文档 `docs/architecture/boundaries.md` 已暗含此语义，不需要重写

---

## 后果（Consequences）

**正向**：
- I1 / I2 修完，文档路径与实际代码再次一致，agent 路由有效
- I3 推动 turn 层覆盖率上来，差分 mutation 信号才有意义
- I4 让差分 mutation 真正进入开发反馈环
- I5 修完，"30 天 stale" 判定准确

**代价**：
- I1 / I2 是 doc 级动作，零代码风险但需 review
- I3 补测意味着 spec 工作量；不要追求一次 90%
- I4 如果决定做，会让 PR 的反馈时间变长（取决于改动文件数）
- I5 一次性脚本是 housekeeping，无长期负担

---

## 相关任务（全部 closed 2026-05-22）

- ✅ architect 自执：I1（layer-model.md 刷新）已落地于 `4a1320e`
- ✅ specifier 在 `64ca1df`：I2 superset addendum + I4 Gherkin + I5 路由 + D5#3 chunk-hash 措辞修正
- ✅ specifier 在 `fef43e4`：ADR 0004 G2 + G3 Gherkin
- ✅ specifier 在 `06af526`：coverage_tier_excludes 机制 + host_install 关联架构决策
- ✅ coder 已跑 I3 step 1（tier 阈值修正 + 刷新 top-N），user 接受 step 2 defer
- ✅ user 决策 I4（standalone + warn）
- coder / refactorer 继续推进 I4 / I5 + ADR 0004 G3 实现

ADR 0005 关闭。后续任何 architecture 漂移以新 ADR 编号开启。
