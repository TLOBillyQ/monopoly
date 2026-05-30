---
kind: adr
status: accepted-deferred
owner: architecture
last_verified: 2026-05-22
---
# ADR 0008 — Harness Warn Allowlist 输出补回评估

**Status**: Accepted-Deferred (2026-05-22 specifier 据 [[feedback-adr-decisions-as-stack]] 接受 architect §3 推荐, 不立即落地; reactivation triggers 见 §3.2)
**Trigger**: specifier 转交 — ADR 0006 D1 Option C 后, behavior 路径双跑 (busted-run 出 warn signal + crap_collect 出 coverage 数据), CPU duplication 是否值得用 harness 原生补回 warn 输出来消除
**Related**: ADR 0006 D1 (crap fold), [[feedback-adr-decisions-as-stack]]

---

## 上下文（Why）

ADR 0006 D1 用 crap_collect 取代 busted-run 跑 behavior lane 后, `spec/log_warns_handler.lua` 的 warn summary 输出 (`# warn summary:\n#   [non-whitelisted] x{count} ...`) 从默认 verify_full 输出消失。crap_collect 走 `tools/quality/shared/test_harness.lua`, 不挂 busted 钩子。

用户选 Option C (双跑 hybrid) 作为 immediate fix:
- parallel lane: behavior 跑 busted-run (5s, 保留 warn signal)
- parallel lane: behavior 跑 crap_collect (11s, 出 coverage 数据)

并行槽位本来闲着, 不杀 wall; 但 CPU/能耗多花 5s × N developers × M builds。

本 ADR 评估: 在 harness 路径原生集成 warn allowlist 输出, 是否值得做。**只交付评估, 不预付劳动。**

---

## 1. Ground truth (当前机制)

### 1.1 数据源

- **`docs/reports/behavior_warns_data.lua`** — 单源真值; 36 个白名单条目, 4 个类别 (Eggy 宿主桩 / 音效资源 / 黑市桩 / 反面测试拒绝)。匹配规则: 去掉 `[warn] ` 前缀后做**前缀匹配**。
- **`docs/reports/behavior-warns.md`** — 人类文档, 与 data 文件同步。`last_verified: 2026-05-14`。
- **变更频率: 极低**。过去 11 个月仅 5 commit 触碰 data 文件 (d99b28a / b2defe7 / 72591a4 / 8cf2cda / a1598d1)。最近一次 d99b28a 是 v102 item targeting feature 顺手补 4 条; 不是 active 开发面。

### 1.2 busted 侧机制 (`spec/log_warns_handler.lua`, 201 行)

- busted output handler, 替换 `busted.outputHandlers.TAP`
- 订阅 `test start/end` + `suite end` 三个 busted 事件
- 每个 case: 自己实现 `_start_capture/_stop_capture` (内部 `case_buffer` + 覆盖 `_G.print`); case end 后 scan captured.lines → `[warn]` → 应用 allowlist → 命中 emit `# WARN <line>` + 累加 `aggregated`
- suite end: 排序 `aggregated` 出 `# warn summary:` + `# total non-whitelisted warns: N`
- 同时还兼任 slow case (>=500ms) tracker + quiet/verbose mode

### 1.3 harness 侧机制 (`tools/quality/shared/test_harness.lua`, 217 行)

- 不挂 busted, 走自实现的 `run_all(suites, opts)` 循环
- 每个 case: `log_capture.capture(run, ...)` (即 `spec/support/log_capture.lua`) — 已经覆盖 `_G.print`, 收 `captured.lines`
- `log_capture.collect_summary(summary, captured)` — **已经聚合 `[warn]`/`[info]`/`[event]` 行为 count 表**
- `summary` 字段在返回的 result 里, 但 **harness 自己不打印**, crap_collect 也不读

**关键发现**: 数据通路已经存在。harness 已经在每个 case 后聚合 warn count。差的是 (a) 加 allowlist 过滤; (b) suite-end 输出格式。

### 1.4 调用拓扑

```
verify_full (Option C, post-D1)
├── parallel lane: busted-run (spec/support/behavior_parallel.lua)
│   └── shells out: busted --output=spec/log_warns_handler.lua
│       └── log_warns_handler subscribes → captures → emits "# warn summary:"
└── parallel lane: crap_collect (tools/quality/crap.lua)
    └── crap4lua.cli → tools/quality/crap/adapter.lua:run
        └── harness.run_all (test_harness.lua)
            └── log_capture.capture (有 summary, 不打印)
```

---

## 2. 工作量 / 修改面 / 验证面 / 风险面

### 2.1 修改面 (估计 ~45-60 净增行)

1. **`tools/quality/shared/test_harness.lua`** (~30-40 行新增):
   - 新参数 `opts.warn_allowlist` (允许传入 set/table)
   - per-case 处理: 复用 `captured.lines`, 应用 allowlist, emit `# WARN` 非白名单
   - suite-end 输出: 排序 + emit `# warn summary:` 段, 与 log_warns_handler 字节同形 (排序键 / 标签 `[ok]`/`[non-whitelisted]` / `# total non-whitelisted warns: N`)

2. **新 helper module** (~10-15 行) — 例如 `tools/quality/shared/warn_allowlist.lua`:
   - `load_default()` → 读 `docs/reports/behavior_warns_data.lua` 返回 set
   - `is_whitelisted(line, set)` → 去 `[warn] ` 前缀 + 前缀匹配
   - **抽出来是为了 busted handler 与 harness 公用一份匹配实现, 杜绝两边 drift**

3. **`spec/log_warns_handler.lua`** (~6-10 行替换): 把内联的 `_whitelist_set` / `_is_whitelisted` 改成 require 新 helper

4. **`tools/quality/crap/adapter.lua`** 或 `tools/quality/crap.lua` (~3-5 行): load allowlist, 透传 `opts.warn_allowlist` 给 harness; 仅当 lane=="behavior" 时启用 (contract / guards 无 allowlist 文档)

### 2.2 验证面

- **A/B 等价测试** (必要): 同一组 spec/behavior 测试, busted-run + handler 出的 `# warn summary:` 与 harness-run + 新代码出的 `# warn summary:` 应**字节相等**或至少**逻辑相等** (顺序 / 总数 / 每条 count 一致)。可以写一条 tooling profile 内的 `warn_allowlist_parity_spec.lua` 自动断言。
- **回归**: ADR 0006 D1 现有的 `crap_tooling_contract` 仍通过 (crap.lua report/collect 子命令未改)。
- **手动确认**: 触发一条**非白名单 warn** 跑 verify_full, 确认 harness 路径下也 emit `# WARN` + summary 末尾计数 +1。

### 2.3 风险面

- **drift risk**: log_warns_handler 跟 harness 两边都要打印 `# warn summary:` 直到 busted-run 从 verify_full 下线; 任何输出格式改动都得改两处。**用共享 helper (§2.1#2) 把匹配算法绑死, 输出格式仍是两份, 但行内容由共享算法保证一致。**
- **`_G.print` 双重 hijack 冲突**: log_capture 和 log_warns_handler 都覆盖 `_G.print`, 都做 restore-original。同进程内只跑其中一个, 无冲突。Option C 是两个不同进程并行, 互不影响。
- **测试顺序敏感**: warn 聚合是 count 表, 顺序无关。无风险。
- **测试集合差异**: busted-run 与 crap_collect 应跑同一份 `spec/behavior/**/*_spec.lua`。如果两边集合漂移 (例如 crap_collect 排除某些 spec), warn summary 必然不一致。当前两边都基于 `test_catalog.load_behavior_suites()` 或 find-glob, 需要在 A/B spec 里固定基线。
- **维护成本极低**: allowlist 11 个月 5 commit, 这条工作量本身不会引入 hot maintenance path。

### 2.4 总估时

实施 + A/B 验证 + 文档更新: **2-3 小时实工**, 1 个 PR。
归属: refactorer 或 coder 均可 (test_harness 改动 + 新 helper 是 small/local refactor; 无 cross-layer)。

---

## 3. 推荐 — Defer, 有 reactivation trigger

### 3.1 推荐理由 (defer 而不是立即做)

1. **没有 user-visible 性能压力**: ADR 0006 D1+D2+D3 实测 176s → 98s (-44%), 大幅超出 D1+D2 预测的 -20%。用户原话设的 D4 重启阈值 (~140s) 已被远远跑赢; 没有"我们需要更多 perf"的拉力。
2. **5s CPU duplication 绝对值小**: × N developer × M builds 是聚合成本, 但单次 wall 不变; 没有 latency 痛感。
3. **可被 ADR 0006 末尾 "D1 升级版" 自然包住** — 见 §4。**如果 D1 升级版要做, 这条工作量自然包含其中; 现在独立做有重复风险。**
4. **stack-rank 原则** ([[feedback-adr-decisions-as-stack]]): 低杠杆决策应等测量结果决定是否需要。Option C 的 "凑合" 不是 user-visible 痛点, 没必要现在投入 ~3h + 长期 drift 风险换 5s CPU。
5. **maintenance 风险大于收益**: 落地后 busted-run 仍要保留 (历史 spec / 开发者本地 `busted --run behavior` 工作流不会消失); 长期看两条 warn 输出代码路径并存, 共享 helper 缓解但不消除 drift 面。

### 3.2 Reactivation triggers (任一满足就重启本 ADR)

- **D1 升级版 ADR 被起草** → ADR 0008 工作量包入 D1 升级
- **Option C 5s CPU 成为 user-visible 痛点** (例如 CI 计费 / pre-push hook 卡顿用户反馈)
- **log_warns_handler 与 allowlist 出 drift bug** (warn signal 漏报 / 误报被发现, 现状双源风险显现)
- **busted-run 从 verify_full 下线意向被提出** (任何把 behavior 单跑收敛到 harness 的动议会立即需要本工作)

### 3.3 反方观点 (供 keep 决策参考)

如果用户优先级是 "每条 凑合 的技术债都要清", 可以 keep:
- 工作量小 (~3h), 一次性
- 数据通路 90% 已存在 (log_capture.collect_summary)
- 共享 helper 是 net positive structural improvement
- 长期来看 verify_full 一定向"单条路径"收敛, 早做晚做都得做

这条不强争, 拍板权在用户。

---

## 4. 与 ADR 0006 末尾 "D1 升级版" 路线的关系

ADR 0006 §路线图 "需要更深结构调整" 列出:
> **后续**: 把 LUACOV-instrumented behavior 与 uninstrumented behavior 合并为单次跑 (即 D1 升级版) | architect | D1 落地、验证 coverage instrumentation overhead 对 baseline 测试时间影响在可接受范围

D1 升级版的本质 = 把 behavior 测试只跑一次 (with LUACOV), 同时产出 warn signal + coverage stats。这要求:
- 单次 busted-run with LUACOV 输出 warn summary (已有, log_warns_handler 路径) **或**
- 单次 harness-run with LUACOV 输出 warn summary (需要本 ADR 0008 工作)

哪条路赢取决于 LUACOV instrumentation 在 busted 内部 vs harness 内部哪个更干净。Coder b7ac0e9 (D2 实现) 已在 coverage.lua 内并行跑 3 个 busted profile + LUACOV-merge, 证明 busted+LUACOV 是 working baseline。但 D1 升级版要求"既出 warn, 也出 coverage", 这是 busted-run 与 coverage.lua 之间的合并 — 当前两者用 busted, 但 D1 把 behavior lane 挪到 crap_collect (harness), 所以已经是混合架构, **再向单条路径收敛只能选 harness 那条**, 因为 LUACOV 与 crap_collect 都已在 harness 上跑通了。

→ **D1 升级版几乎必然需要 ADR 0008 的工作。**

### 4.1 推荐合并节奏

- **不要现在独立做 ADR 0008**。等 D1 升级版动议起草时一并落地。
- 如果 D1 升级版 6 个月内不动 (因为现有 -44% 已经足够好), ADR 0008 也不动; Option C 长期保留是可接受的 stable state。
- 如果 D1 升级版动议起草, ADR 0008 工作量 (本节 §2 估的 ~3h) 自动纳入 D1 升级版 work item, 本 ADR 改为 "Superseded by ADR XXXX D1 升级版"。

---

## 5. 决策（What）

**Defer**, with stated reactivation triggers (§3.2)。

- 不立即排 refactorer / coder 落地。
- Option C 保留为 stable hybrid (不是过渡态)。
- 如 D1 升级版动议起草, 本 ADR 工作量并入。
- 如 reactivation trigger 触发, 由 specifier 重新排队, 本 ADR 改 status → accepted + 转 refactorer。

---

## 6. 后果（Consequences）

**正向 (本次 defer 决策)**:
- 不投入 ~3h 工程 + 长期 drift 维护 换 5s CPU
- 不锁死 D1 升级版方案 (留两条路: 全 busted vs 全 harness)
- 给后续测量数据更多时间累积 (Option C 是否真有 CI 计费痛点 / 是否真出 drift bug)

**负向**:
- Option C "凑合" 状态长期存在, 新人 onboard 可能要问"为什么 behavior 跑两次"
- 双源 warn 输出代码路径并存, 任何输出格式改动需要两处同步 (drift 责任分摊到 busted handler + harness 各自维护者)
- 如果 D1 升级版永远不动议, ADR 0008 永远 deferred, 5s CPU 浪费成累计成本

**不变量**:
- ADR 0006 D5 ("--no-coverage handoff 默认") 不变
- ADR 0006 D1 现有 crap_tooling_contract 不变
- ADR 0004 D5/D6 (mutate 单文件 pass-only) 与本 ADR 无关, 不变
- behavior warn 信号继续由 busted-run 路径保证, log_warns_handler 不动

---

## 7. 相关任务

- specifier: 审阅本评估, 决定 keep (转 refactorer) / drop (本 ADR status → declined) / defer (本 ADR status → accepted-deferred)
- 用户: 拍板; 特别是 §3.3 反方观点的"凑合技术债优先级"取向
- architect: 监测 §3.2 reactivation triggers; 任一触发即重新开放本 ADR
