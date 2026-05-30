---
kind: adr
status: stable
owner: architecture
last_verified: 2026-05-23
---
# ADR 0009 — Acceptance Pipeline Spec 对齐范围与契约

**Status**: Stable (2026-05-23, Stage 1-7 全部交付；CLI 端到端 + 中文 feature 回归测试通过)
**Trigger**: 2026-05-23 调研 `unclebob/Acceptance-Pipeline-Specification@e9f66dc`（2026-05-22 push）发现本地 `tools/acceptance/` 与 spec 85% 对齐，缺规约层差分突变机制
**Related**: `tools/acceptance/mutator.lua`, `tools/acceptance/cli/mutator.lua`, [ADR 0004](0004-differential-mutation-testing.md)（源代码层 mutate4lua 差分），`memory/project_acceptance_pipeline_spec_gap.md`

---

## 上下文（Why）

`unclebob/Acceptance-Pipeline-Specification` 是上游可移植 acceptance 流水线规范，927 行单文档，描述 Gherkin → IR → 生成测试 → 突变 → 报告 的完整契约。2026-05-22 上游 push 引入了 §"Differential Mutation" 一节，规定 mutator 必须支持：

| Spec 要求 | 本地状态 |
|---|---|
| `--level <full\|hard\|soft>` flag（默认 hard） | 缺 |
| Feature 文件首部 `# mutation-stamp: sha256=...` 注释行 | 缺 |
| Feature 文件首部 `# acceptance-mutation-manifest-begin/end` JSON 块 | 缺 |
| `SkippedScenarios` / `SkippedMutations` 报告字段 | 缺 |
| Conformance #22-#27 行为合约 | 不满足 |

本地已对齐部分（无需改动）：

- ✅ CLI 入口三件套 `gherkin-parser` / `acceptance-entrypoint-generator` / `gherkin-mutator`
- ✅ JSON IR shape（feature/scenarios/steps/examples）
- ✅ 值突变 8 条规则（list / boolean / null-like / int / float / date / time / duration / dither）
- ✅ 退出码 0/1/2
- ✅ JSON 报告 key 风格（`Total/Killed/Survived/Errors` + `Mutation.{ID,Path,Description,Original,Mutated}` + `Status/Output/Error/Duration`）— 精确匹配

**关键概念分层**：spec 的差分是**规约层**（feature 文件内 Gherkin example 突变跳过），与 ADR 0004 描述的 **mutate4lua 源代码层差分**（src/*.lua AST 突变跳过）是不同层次的东西。名字都叫 "differential mutation"，但作用域、manifest 位置、hash 算法、跳过粒度都不同，**不可互替**。本 ADR 锁定的是规约层契约。

---

## 决策（What）

### D1 — 对齐范围限定在 mutator 子系统

| 改 | 不改 |
|---|---|
| `tools/acceptance/mutator.lua`（差分主逻辑）| `tools/acceptance/gherkin_parser.lua`（已对齐）|
| `tools/acceptance/cli/mutator.lua`（`--level` flag）| `tools/acceptance/generator.lua`（已对齐）|
| 新增 `tools/acceptance/spec_hash.lua`（hash 原语）| `tools/acceptance/runtime.lua`（已对齐）|
| 新增 `tools/acceptance/feature_stamp.lua`（stamp 读写）| `tools/acceptance/runner.lua`（已对齐）|
| 新增 `tools/acceptance/scenario_manifest.lua`（manifest 读写）| `tools/acceptance/cli/{parser,generator}.lua`（已对齐）|

新增模块走 `tools/acceptance/` 平铺，不开子目录 — 与既有约定（`mutator.lua` / `runtime.lua` / `runner.lua` 平铺）一致。

### D2 — `implementation_hash` 覆盖范围

Spec §"Differential Mutation" 要求：

> The `implementation_hash` must identify the acceptance mutation implementation and every project adapter component whose behavior can affect mutation generation, filtering, execution, or classification.

**提议覆盖**：

- `tools/acceptance/mutator.lua`
- `tools/acceptance/generator.lua`
- `tools/acceptance/runtime.lua`
- `tools/acceptance/runner.lua`
- `tools/acceptance/gherkin_parser.lua`
- `tools/acceptance/chinese_normalizer.lua`
- `tools/acceptance/steps/*.lua`（所有 step handler）
- `tools/acceptance/feature_stamp.lua` + `scenario_manifest.lua` + `spec_hash.lua`（即将新增）

**不覆盖**：

- `tools/acceptance/cli/*.lua` — 仅调用方式，不影响突变行为
- `tools/acceptance/generated/*.lua` — 是产物不是实现
- `tools/acceptance/support/ui_mock.lua` — 仅测试 helper

**颗粒度**：单一聚合 sha256，所有 impl 文件按字典序 cat 后哈希。任一文件改一行就 invalidate 所有 manifest。

**已知代价**：`chinese_normalizer.lua` 改一行 → 全 feature 复跑。可接受（spec 强制要求；细化到 per-step-handler hash 需要 step handler registry 重构，超本次范围）。

### D3 — 与 mutate4lua 源代码层 manifest 严格隔离

| 维度 | 规约层（本 ADR）| 源代码层（ADR 0004）|
|---|---|---|
| Manifest 位置 | `features/*.feature` 内 `# acceptance-mutation-manifest-begin/end` JSON 块 | `src/*.lua` 末尾 `--[[ mutate4lua-manifest ... ]]` k=v 块 |
| Stamp 位置 | feature 首行 `# mutation-stamp: sha256=...` | 无 stamp 机制 |
| Hash 算法 | sha256 | FNV-1a 64-bit token-stream |
| 跳过粒度 | 整 feature（stamp）/ 整 scenario（manifest）| per-function scope |
| Spec 来源 | `unclebob/Acceptance-Pipeline-Specification` | `vendor/mutate4lua` 上游实装 |
| 突变对象 | Gherkin example 字符串 | Lua AST 节点 |

两层 manifest 物理不冲突（不同文件 / 不同注释语法 / 不同字段），但**绝对不可互替** — 把规约层 manifest 写进 src/*.lua 或把源代码层 manifest 写进 feature 都是 bug。代码评审和文档要明示这条边界。

### D4 — 迁移路径：自然过渡，无 bootstrap

不同于 [ADR 0004 G3](0004-differential-mutation-testing.md) 需要 `--bootstrap-all` 一次性写入：

- 首次跑 `acceptance-mutate` 时 feature 文件无 stamp / 无 manifest
- spec §"Missing/stale/malformed stamp must not be trusted" → 等效 `full` level 行为
- 跑完后落 stamp + manifest，下次自然走差分

21 个 feature 一次性 mutate 即完成迁移；无需独立 bootstrap 脚本。

### D5 — Hash 实现：pure-Lua sha256

Spec 强制 sha256。Lua 5.4 标准库无 sha256，可选：

| 方案 | 优点 | 缺点 |
|---|---|---|
| **pure-Lua sha256（推荐）** | 无外部依赖；verify_full 不引入 shell-out 复杂度（按 [[feedback-toolchain-verification]] memory）；跨平台稳定 | 千行 feature 文件性能待测 |
| Shell out 到 `openssl dgst -sha256` | 性能好 | 引入 toolchain shell-out，verify_full 测试矩阵 +1；macOS/Linux openssl 行为有微差 |
| Shell out 到 `shasum` (BSD) | 同上 | 同上 |

**提议 pure-Lua**。21 个 feature 文件最大 ~50KB，全量 hash 在百毫秒级，可接受。性能不达预期再退回 shell-out。

实现位置：`tools/acceptance/spec_hash.lua`，导出 `sha256(string) -> hex string`。

### D6 — `tested_at` 时区：ISO-8601 UTC

Spec 只说 `"<timestamp>"`，未规定格式。提议固定 **ISO-8601 UTC（`Z` 后缀）**，例如 `2026-05-23T02:14:50Z`，理由：

- 跨开发机 manifest diff 不被时区污染
- 与 git author date 风格一致
- Lua `os.date("!%Y-%m-%dT%H:%M:%SZ")` 一行实现

替代方案（本地时区 + offset）会让两个 agent 在不同时区合并 manifest 时产生 diff 噪声。

### D7 — 明确**不解决**的边界

**N1 — `--level` flag 不带"自动决定 full"逻辑**
即使检测到 mutator core 改动，也不自动升级到 `full`。`--level` 是用户/CI 显式选择，不偷偷越权。要"强制全量"用 `--level full`。

**N2 — Survived/Error 不写 manifest**
与 [ADR 0004 D4 N1](0004-differential-mutation-testing.md) 同精神：manifest 是 pass-record，不是状态机。Spec §"零 survived 零 errors 才可跳过" 自然实现这一点。

**N3 — Cross-feature mutation 优化不在本次范围**
两个 feature 共享同一 step handler，改 handler 后理论上两个都该复跑。本次实现按 spec 字面对齐（impl_hash 覆盖全部 step handler），代价是 conservative：handler 改动 → 全 21 feature 复跑。后续优化（per-handler hash + feature 引用图）独立 ADR。

---

## 后果（Consequences）

**正向**：

- 跨项目可移植性 +1：本地 `tools/acceptance/` 成为 spec 参考实现
- 增量验证性能：单 feature 改动只复跑该 feature，acceptance lane 大幅提速
- 双 manifest 边界文档化：规约层 vs 源代码层差分混淆从 memory 升级到 ADR
- coder.prompt / architect.prompt 不再需要绕开 "Acceptance-Pipeline-Specification" 这个上游引用

**代价**：

- ~5 个新模块 + mutator/cli 改造，busted spec 覆盖每个新模块
- `chinese_normalizer.lua` 单行改动 invalidate 全 manifest（D2 N1 已 accept）
- 首次跑 acceptance-mutate 会落 21 个 feature 的 stamp + manifest，commit 噪声中等
- pure-Lua sha256 性能待实测；不行得退回 shell-out

**风险**：

- D2 的 implementation_hash 颗粒度若 too aggressive，会让 `chinese_normalizer` 偶发 refactor 触发全仓复跑 — 监控；若高频则升级为 per-handler hash（独立 ADR）
- 双 manifest 命名相似（"acceptance-mutation-manifest" vs "mutate4lua-manifest"）容易让人混淆 — 在 `docs/guides/` 加专门一节区分（Stage 7 任务）

---

## 实施序列

Stage 1（本 ADR）→ Stage 2 hash 原语 → Stage 3 `--level` CLI → Stage 4 feature stamp → Stage 5 scenario manifest → Stage 6 report 扩展 → Stage 7 端到端 verify。

每个 stage 独立 commit + busted spec。Stage 5 是最复杂的（manifest JSON parser + 跳过决策状态机），单独成 PR review。

---

## 验证结果（Stage 7）

| Profile | 结果 |
|---|---|
| `busted --run tooling` | 213/213 ✅ |
| `busted --run acceptance` | 347/347 ✅ |
| `busted --run guards` | 31/31 ✅ |
| `lua5.4 tools/quality/lint.lua`（741 文件） | 0 warnings / 0 errors ✅ |
| CLI smoke：中文 feature 双轮 `--level hard` | killed=4 → skipped_scenarios=1 ✅ |

**Stage 7 抓到的真实回归**：第一版 Stage 4/5 把 `# mutation-stamp:` 写到文件第一行，但 `tools/acceptance/chinese_normalizer.lua:200` 要求**严格第一行**必须是 `# language: zh-CN`，否则要么报错（features/ 下）要么 fallback 到英文解析（导致 `功能:` 不被识别）。修复：`feature_stamp.apply_stamp` 和 `scenario_manifest.apply` 都改成"如果首行是 `# language:` 则保留它，stamp/manifest 插入到其后"。新增 busted 用例 `preserves a leading # language: zh-CN line across stamp+manifest writes` 锁定行为。

这条回归说明 D2 "单一聚合 implementation_hash" 颗粒度的边界：`chinese_normalizer` 的脆弱不变量（first-line 严格匹配）是 implementation 的一部分，但本次没把它升级成更宽松的"任意前置注释中找 `# language:`"。后续如果 Cucumber 多语言 feature 进来再做。

## Addendum 2026-05-25 — Mutator status reporting

上游 `Acceptance-Pipeline-Specification` 在 commit `f2af7e7`（2026-05-24，`Add mutator status reporting spec`）新增 **Acceptance Mutation Status** 契约。本地已对齐前序差分 manifest / skipped report / level 语义，本轮只补状态输出契约：

- `gherkin-mutator` 支持 `--status-interval <duration>`，默认 `30s`，`0` 关闭周期状态。
- mutator 在 mutation discovery 后、执行期间、结束前向 **stderr** 输出稳定单行状态。
- `stdout` 只保留最终 text / JSON report；`--json` 输出不得混入状态行。
- 状态行至少包含 `elapsed`、`total`、`completed`、`running`、`killed`、`survived`、`errors`。
- 差分跳过发生时，状态行还应包含 `skipped_scenarios` 与 `skipped_mutations`。

新增规格入口：`features/swarmforge/acceptance_mutator_status.feature`。该规格直接运行项目内 `gherkin-mutator`，当前实现预期红在 `unknown option: --status-interval`，由 coder 对齐实现后跑绿。

---

## 相关任务

- ~~coder：Stage 2-6 实现~~ 已完成
- ~~architect：Stage 7 端到端 verify_full 通过后写一条 ADR addendum 标记 Stable~~ 已完成

## Addendum 2026-05-27 — 上游 generated-files-only hash 收敛

上游 `Acceptance-Pipeline-Specification` 当前把 generator metadata 的 `implementation_hash` 限定为 **generated acceptance files only**，不再把 parser、runtime、runner、step handlers、mutator 或项目过滤器算入该 hash。本文早期 D2 的聚合实现 hash 决策被废弃。

本地收敛规则：

- `acceptance-entrypoint-generator` 写入 `metadata/<feature>.json`，`hash_scope = "generated_files"`。
- `gherkin-mutator` 默认从 generated metadata 读取 `implementation_hash`，`--implementation-hash` 只作为调试/非常规布局覆盖。
- 中文归一化、runtime、runner、step handlers 的变更不再通过 generated metadata hash 触发 hard-level 差分失效；需要全量复核时显式跑 `--level full`。

## Addendum 2026-05-27 — 抽出 acceptance4lua 子模块

通用中文 Gherkin / APS-style acceptance 框架抽出到 `vendor/acceptance4lua/`，上游仓库为 `https://github.com/TLOBillyQ/acceptance4lua.git`。framework 模块由 `acceptance4lua.*` 直接提供；本仓库不再提供 `tools/acceptance/*` facade，也不安装 `package.preload` alias。`acceptance.*` 仅保留项目业务 step 命名空间：`acceptance.steps.*`。

边界：

- `vendor/acceptance4lua/`：parser、中文 normalizer、JSON IR、generator、runtime、Gherkin example mutator、stamp/manifest、report/status。
- `tools/acceptance/steps*.lua`、`tools/acceptance/game_driver.lua`、`tools/acceptance/run_acceptance.lua`、`tools/acceptance/runner_worker.lua`：Monopoly 项目适配层，不进入子模块。
- `tools/acceptance/cli/*.lua`：项目 wrapper，只负责 bootstrap package path 并委托 `acceptance4lua.cli.*`。
