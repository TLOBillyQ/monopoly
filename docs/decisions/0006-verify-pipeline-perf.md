---
kind: adr
status: stable
owner: architecture
last_verified: 2026-05-22
---
# ADR 0006 — Verify Pipeline 速度优化

**Status**: Stable (2026-05-22, D1 hybrid + D2 parallel profiles + D3 in-process driver 全部进 main；D4 暂缓 ≠ 决策未定)
**Trigger**: specifier 转交用户请求"端到端 profile 验证管道 + 优雅速度方案"
**Related**: ADR 0004（differential mutation testing 契约），`tools/quality/verify_full.lua`，`tools/quality/coverage.lua`，`tools/quality/crap.lua`，`tools/quality/verify_mutation_diff.lua`

---

## 上下文（Why）

每次 commit 前跑 `lua tools/quality/verify_full.lua` 是开发 / handoff 必经道。
本 ADR 基于 2026-05-22 在 swarmforge-architect 工作树（HEAD ade0448，
vendor/mutate4lua e960131）的实测，把热路径拆开摆桌面，给出
"可立即落地" 与 "需要结构调整" 两套优化路线。

### 实测耗时（本机：darwin 25.5.0，Lua 5.4，busted via luarocks）

| 步骤 | wall (s) | 占比 | 备注 |
|---|---:|---:|---|
| `verify_full --no-coverage` 总 | **19s** | 100% | parallel 4s + crap 14s |
| ↳ parallel lanes (contract/guards/arch/behavior/lint/encoding) | 4s | 21% | 6 子任务并行；longest lane 决定时长 |
| ↳ crap (sequential after parallel) | **14s** | 74% | 重跑 2305 behavior 用例 + 覆盖率收集 |
| `verify_full` 总（含 coverage） | **176s** | 100% | parallel 4s + crap 14s + coverage 157s |
| ↳ coverage (sequential after crap) | **157s** | 89% | busted × 3 profiles（behavior+contract+guards）with LUACOV + luacov 聚合 |
| `mutate_bootstrap` 全扫描 (351 src 文件) | 0.78s | — | unchanged=351 快路径 |
| `mutate.lua --scan` 单文件 | 0.017s | — | 仅扫描，不变异 |
| `mutate.lua --mutate-all` 单文件（panel_interrupt 51 sites） | 10.3s | — | ≈200ms/site |
| `verify_mutation_diff` 全项目（80 文件，0 sites/file） | 36.5s | — | 进程冷启 × N 是主成本 |
| `run_acceptance.lua` 单 feature (panel_interrupt 38 examples) | 0.24s | — | 一次性 ad-hoc 调用 |
| `busted --run acceptance` (15 generated specs, 278 examples) | 1.0s | — | 已是 verify_full parallel 里的子集 |

### 关键观察

1. **同一组 busted 测试被运行 3 次**：parallel lanes 跑一次 behavior（uninstrumented，2305 用例），crap 再跑一次（带 coverage 检测），coverage 再跑三次（behavior/contract/guards，全带 LUACOV）。三次重跑同一份测试集合占了 verify_full 时间的 ≥85%。

2. **coverage 内的三个 lane 是 sequential**：`tools/quality/coverage.lua` 用循环依次调用 `run_busted_profile(profile)`，不并行。verify_full 在更外层并行已经证明可行。

3. **process startup cost 在 diff 场景下显著**：`verify_mutation_diff` 跑 80 个 0-sites 文件，wall 36.5s，bootstrap cold start × N = 大头。每文件 fork 出一个 Lua 解释器只为读 manifest + 输出 "no sites"，浪费 ≈0.3s × 80 = 24s。

4. **acceptance / mutate_bootstrap 不是瓶颈**：
   - run_acceptance 是 specifier 写 feature 时 ad-hoc 触发；不在 verify_full 路径
   - mutate_bootstrap 全 351 文件扫描 0.78s，hash-skip 已是设计
   - chinese_normalizer 47 features × M examples 的"O(N·M) 顾虑"在我测的数据里不成立——所有 generated specs 已落盘并跑 1s 整批

5. **mutate.lua 的差分语义在 bootstrap 后会"自治零化"**：refactorer 跑 mutate_bootstrap 把 manifest 全量重写后，verify_mutation_diff 看见所有 scope 的 semanticHash 都跟 manifest 匹配 → 报告"all clean"。这是机制上的，不是漏测。但意味着 bootstrap **不应在差分 mutation 之前无条件跑**——否则差分 lane 变成 no-op。这条与 ADR 0004 D5（pass-only 写 manifest）的精神一致，但 bootstrap CLI 路径绕过了这道闸。详见 §D4。

---

## 决策（What）

### D1 — 把 crap 折叠进 parallel lanes，共享 behavior 跑一次

**现状**：`verify_full` 的 parallel 阶段已经把 behavior 跑过一次（uninstrumented），随后 `crap` 又把 behavior 重跑一次（带覆盖率收集，14s）。两次跑的是同一组 2305 测试。

**决策**：扩展 parallel lane 的 behavior 任务，让它单次跑就同时产出 `tap` 结果 + crap 需要的覆盖率/CRAP 评分数据。crap 步骤改为"读取 parallel 阶段产出的中间文件并出 JSON 报告"。

**约束保持**：
- 仍跑全 2305 用例（不弱化覆盖）
- crap_report.json 字段不变
- coverage tier 阈值机制（ADR 0005 I3 锁定的）不动

**预期节省**：14s / verify_full --no-coverage 19s 总 → 约降到 5-7s（节省 60%+）。

### D2 — coverage.lua 内部三 profile 并行

**现状**：`tools/quality/coverage.lua::run_busted_profile` 在 `_main` 里被串行调用三次（behavior / contract / guards）。三次跑独立，唯一共享是 `luacov.stats.out` 写文件。

**决策**：复用 `verify_full._run_parallel` 的并行 launcher 机制，把三次 busted 调用拆 3 个 lane 并行跑。LUACOV stats 文件按 profile 分文件写入（如 `luacov.behavior.stats.out`），最后由 `run_luacov` 汇总。

**约束保持**：
- LUACOV 配置（include/exclude）不变
- 最终聚合 report 字段不变
- 阈值（threshold=90）不变

**预期节省**：157s → ≈ max(behavior, contract, guards)。behavior 通常占 80%，所以新值 ≈120s。节省 ≈37s / verify_full 总 176s = 21% 降幅。

**前提验证项**（落地前必须确认）：
- LUACOV 是否支持多进程同时写 stats（一般做法是每进程独立 stats 文件，最后 merge）
- luarocks busted/luacov 在 macOS 上是否支持子进程隔离的 LUA_PATH（已知 coverage.lua 已经 export LUACOV=1 + LUA_PATH，可复制）

### D3 — verify_mutation_diff 批处理 / 进程复用

**现状**：`verify_mutation_diff.lua::M.run` 对每个 changed file 调用 `runtime.mutate_file(file)`，后者 fork 一个新 Lua 解释器跑 mutate.lua。冷启 ≈0.3s × N。

**决策**：在 mutate.lua 入口加 `--files <file1>,<file2>,...` 多文件批模式，verify_mutation_diff 把所有 changed file 拼一次性传入，单进程依次跑。

**约束保持**：
- 单文件 `mutate.lua <file>` 调用接口不变（不破坏 architect.prompt 里 "Run mutate4lua one file at a time" 的人工调用约定——批模式是工具内部的优化，人工调用仍走单文件）
- ADR 0004 D5/D6 的写入策略（pass-only 写 manifest）不变，按单文件粒度判断
- `--mutate-all` / `--lines` 等 flag 在批模式中仍按 per-file 应用

**预期节省**：在 N=80、0-sites 场景下 36.5s → 5-8s（节省 ≥75%）。N=10 改动文件场景节省 ≈3-6s。

### D4 — Bootstrap 与差分 mutation 的协议清晰化

**现状**：`mutate_bootstrap.lua` 在跑完之后，所有 src/ 文件的 manifest semanticHash 都跟当前代码精确匹配。此时 `verify_mutation_diff` 看不到任何差分，跑出 "all clean" 0 sites。如果在 commit / handoff 流程里习惯性"先 bootstrap 再 mutate-diff"，那 mutation 测试事实上被绕过。

**决策**：
- **不改 ADR 0004 D5/D6 契约**——pass-only 写 manifest 是 mutate.lua 单文件路径的契约，仍然成立
- 给 mutate_bootstrap 加 `--projectHash-only` flag：只更新顶部 projectHash（受 projectHash 算法影响的协调字段），保留各 scope 的 semanticHash 不变。这样补"项目其他文件变了但本文件没变"导致的 projectHash 漂移，又不会假装本文件的 mutation 已通过。
- handoff/workflow 文档（不在本 ADR 范围）后续应明确：bootstrap 是 **新增文件首次落 manifest** 的工具，不是日常 "重置 manifest 状态" 的工具。这条由 specifier 在 Gherkin 里固定下来更合适。

**这条对 ADR 0004 的影响**：
- 0004 D5 "Pass-only 写 manifest" 不变
- 0004 D6 "显式 --update-manifest" 仍是单文件强制路径
- 新增的 `--projectHash-only` flag 是 bootstrap 的 strict subset 行为，不与上游 manifest 写入策略冲突
- 如果用户 / specifier 评估认为这违反 ADR 0004 契约，本 ADR 的 D4 应单独 review 不要落地，D1-D3 / D5 不受影响

### D5 — 默认 verify_full 跳过 coverage（与现状一致，把它写进 ADR）

**现状**：`verify_full --no-coverage` 已是命令行可选；refactorer / coder 实际 handoff 路径就用 no-coverage（19s），coverage（176s）只在显式需要覆盖率报告时跑。

**决策**：把这条约定写进 ADR 作为 normative：
- 日常 handoff = `--no-coverage`
- 周期性 / release 前 = 全量（含 coverage）
- 不修改 `verify_full.lua` 默认值（保持向后兼容；用户/CI 自选）

**理由**：D1+D2 落地后，coverage 即使全量也 ≈120s；19s baseline + 120s coverage = 139s。仍属"按需触发"区间，不应每次 handoff 强制。

---

## 路线图（Routing）

### 立即可落地（refactorer / coder 接）

| 项 | 归属 | 估工 | 风险 |
|---|---|---|---|
| **D1**：crap 折叠进 parallel | refactorer | 中（改 crap.lua + parallel lane spec） | 低-中（需保 crap_report.json 字段不变） |
| **D2**：coverage 三 profile 并行 | coder | 中（复制 verify_full._run_parallel 机制） | 中（LUACOV 多进程 stats 合并要验） |
| **D3**：mutate.lua 多文件批模式 | coder | 小-中（mutate.lua + verify_mutation_diff 协调） | 低（vendor/mutate4lua 改动可能需 PR upstream） |

### 需要更深结构调整（architect 后续 ADR / 进一步评估）

| 项 | 归属 | 触发条件 |
|---|---|---|
| **D4**：bootstrap `--projectHash-only` flag | architect 提案 → coder 落地 | 用户 / specifier 拍板与 ADR 0004 D5/D6 不冲突后 |
| **后续**：把 LUACOV-instrumented behavior 与 uninstrumented behavior 合并为单次跑（即 D1 升级版） | architect | D1 落地、验证 coverage instrumentation overhead 对 baseline 测试时间影响在可接受范围（评估 LUACOV jit-hook 对 2305 用例的额外开销） |

### 不在本 ADR 范围

- **acceptance generator skip-if-unchanged**：实测 acceptance 不在 verify_full 热路径（run_acceptance 0.24s ad-hoc / busted lane 1s 整批），优化收益 ＜0.5s，不值得引入 mtime 比较逻辑
- **chinese_normalizer 改写**：47 features × M examples 在我测的数据里不是瓶颈；如确有目标场景再起 ADR
- **arch_view 缓存**：parallel lane 里 arch.lua 跑得很快（被 4s 总时长包住），不优先
- **lint cold start**：luacheck 启动成本被 parallel 吸收，单独优化收益小

---

## 后果（Consequences）

**正向**：
- D1 落地后日常 handoff 验证从 19s 降到 ≈6s（节省 70%）
- D1+D2 落地后全量 verify（含 coverage）从 176s 降到 ≈140s（节省 20%）
- D3 落地后差分 mutation 在大改 PR（N>20 文件）场景下从 ≈分钟级降到 ≈10s 级
- D4 关闭"bootstrap 后差分变 no-op"的隐性陷阱，与 ADR 0004 pass-only 策略一致

**代价**：
- D1 让 crap.lua 与 parallel lane 的 IPC 耦合（中间文件契约要稳）
- D2 让 LUACOV stats 合并成新的失败点（多进程并发写文件容易出竞争）
- D3 改 vendor/mutate4lua 的 CLI 参数集，需 upstream PR 或本地 patch 维护
- D4 引入新 flag 增加文档面；要在 G3 (bootstrap rollout) 文档里加节

**不变量**：
- mutation 总变异数（D5 contract）保持等价或更严
- acceptance 总 example 数（278 +）保持等价
- coverage tier 阈值（ADR 0005 I3 锁定 src/foundation/rules/turn/state/player/computer 6 个 dir）不变
- ADR 0004 D5/D6 单文件 mutate.lua 行为契约不变

---

## 相关任务

- specifier：把 D1 / D2 / D3 转 Gherkin acceptance（"verify_full 跑 N s 内完成" + "crap 不重跑 behavior" + "coverage 三 profile 并行" 这类可测断言）
- refactorer：D1 落地
- coder：D2 + D3 落地；D4 视用户决策
- 用户：D4 是否落地 / 是否接受向 vendor/mutate4lua 提 D3 batch-mode upstream PR

---

## D6 — Verify slim：长耗时 lane 归特定 swarm role（Draft，pending execution）

**Status**: Draft (2026-06-25，grilling 会话共识；architect 终稿化 prose + role prompt，refactorer 落代码)
**Trigger**: 用户请求"verify 精简，运行耗时长的只由特定 swarm role 执行"
**Related**: D1（crap fold）、D5（默认跳 coverage）、ADR 0008（warn allowlist，本决策不回归其 trigger）

### 上下文

D5 早有"默认应跳 coverage"方向但从未强制——SKILL.md 无 flag 默认仍含 coverage+crap（~50s，数字已 stale）。实测真正长耗时 lane 只有 `coverage`(~120-157s) 与 `crap_collect`(~14s)，两者都已是 refactorer 的 owns（`swarmforge/roles/refactorer.prompt:8-19`）。其余 lane（含完整 behavior）并行后 ≤4s。

### 决策（9 条）

1. **剥 coverage + crap** 出默认（mutation/dry/gherkin-mutation 本就不在默认，归 architect 终序）。
2. **新默认 (无 flag)** = `contract + guards + arch + behavior(全) + lint + encoding`，并行后无 sequential 步。~5s（实测待补）。
3. **opt-in flags**：`--coverage`（加 coverage 并行 lane；toolchain 缺失时发 warning 而非静默 skip）、`--crap`（加 crap_collect 并行 lane + crap_analyze + crap_gate sequential）、`--full`（= `--coverage --crap` 别名，恢复旧默认）。
4. **`--no-coverage` 保留为静默 no-op**（向后兼容 D5 文本；等价裸 verify；与现有 `--smoke --no-coverage` 静默行为一致）。`--smoke`/`--tooling`/`--verbose` 不变。
5. **role prompt 显式禁/准**：coder/specifier 禁 `--coverage`/`--crap`/`--full`（转跑 refactorer/architect owns 的工具）；refactorer/architect 准。
6. **终序不变**：`verify` → mutate → dry → acceptance-mutate 的 `verify` 步透明继承 slim（architect 本不 owns coverage/crap）。
7. **本 D6 即决策记录落点**（见决策共识 7）。
8. **warn summary 不回归 ADR 0008**：由 `behavior` lane 出（`spec/support/behavior_parallel.lua:81,144-159`，走 `--output=spec/log_warns_handler.lua`），不依赖 crap_collect。移除 crap_collect 不触发 ADR 0008 任何 reactivation trigger（那些是 busted-run 下线，与本次相反），且合其"单条路径收敛"长期方向。
9. **无 CI 依赖**：无 `.github/workflows/`、无 pre-commit；唯一 bare-verify 调用方 `Makefile:4`（`verify`→`check`）按预期变 slim。无 role prompt 硬编码旧 flag。

### 落地轨道（并行）

**轨道 A — refactorer（代码）**：`tools/quality/verify_full.lua` + `verify_full/spec/*.lua`
- `_default_lanes`（:244-283）：`crap_collect` 与 `coverage` lane 从默认加入改为 opt-in。
- `_main`（:305-373）：`crap`/`crap_gate` sequential 步（:339-350）仅在 `--crap`/`--full` 时跑。
- CLI 解析（:386-397）：新增 `--coverage`/`--crap`/`--full`；`--no-coverage` 静默 no-op（`opts.coverage` 不再默认 true）。
- `--coverage` 显式请求但 `env.coverage_available == false` 时 emit warning。
- `_resolve_lanes`（:285-296）接 `coverage`/`crap` opt；`--full` = `--coverage --crap`。
- spec 更新：`verify_full_smoke_spec.lua` 默认期望去 coverage/crap；新增 opt-in 用例；`--no-coverage` no-op 用例。
- 约束保持：`crap_report.json` 字段不变；coverage tier 阈值（ADR 0005 I3）不变；`--smoke` 车道集不变。
- 验证：`lua tools/quality/busted_lane.lua --profile tooling`；落地后 `verify_full`（新默认 ~5s）、`--full` 等价旧默认、`--no-coverage` no-op。

**轨道 B — architect（文档/治理）**：并行于 A，不阻塞
- `swarmforge/roles/coder.prompt` / `specifier.prompt`：加禁 `--coverage`/`--crap`/`--full`。
- `swarmforge/roles/refactorer.prompt` / `architect.prompt`：加准 flag；终序 `verify` 步用裸 verify。
- `.agents/skills/verify/SKILL.md`：mode 表、车道集、option 画像、"default vs smoke 边界"重写；wall 写"~5s（实测待补）"；opt-in 标归属角色。
- 本 D6 终稿化（status → stable）。
- `docs/architecture/quality-map.md`：wall-time、flag 文档更新。

### 后果

**正向**：默认 verify ~50s → ~5s（-90%）；"长耗时只由特定角色"由默认 slim + role prompt 显式禁/准 flag 双重保证；ADR 0008 不回归。
**代价**：`--full`/`--coverage`/`--crap` 三个新 flag 增文档面；role prompt 增约束行。
**不变量**：`crap_report.json` 字段、coverage tier 阈值、`--smoke` 车道集、ADR 0004 D5/D6 mutate 契约、warn summary 输出（经 behavior lane）均不变。

### 注意

smoke(~9s) 与新默认(~5s) wall 趋同；`--smoke` 价值从"快很多"转为"behavior 子集窄反馈"。两档真实 wall 由 refactorer 落地后实测回填。`--full` = `--coverage --crap`（不含 tooling）；`--full --tooling` 正交叠加。
