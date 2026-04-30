# 七层架构对齐 + Core 拆分 + UI 重组

本可执行计划是活文档，遵循 `.agents/harness/PLANS.md` 维护。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"四个章节。

## 目的 / 全局视角

将当前 10 层架构对齐为 7 层 + foundation 基座（substrate），完成 core 拆解、ui 内部重组、landing_visual_hold 改名打包。完成后用户（架构守门人 / 新人）可以做到三件以前做不到的事：

1. **物理目录名 = 逻辑层名 = arch 组件名**：从目录树就能直接看出每个文件属于哪一层，无需查映射表。
2. **`src/core/` 物理消失，`src/foundation/` 取而代之**：所有公共基础设施集中在一个明确命名的子树（log/lang/identity/events/ports），不再与玩法逻辑混淆。
3. **`tools/quality/arch.lua check` 的 exception 数量从 6 降至 3**：不再依赖语义补丁解释 component 划分，违规可被工具直接捕获。

可观察验证：`/verify-full` 全绿、`[ ! -d src/core ]` 退出 0、`grep -rn 'src\.core\.' src/ tests/ tools/` 无输出、`lua tools/quality/arch.lua check` 报告 ≤3 条 exception。

## 进度

带时间戳的颗粒度跟踪。每次停下都要更新；即使把一项拆成"已完成 / 剩余"。

- [x] (2026-04-30 准备) 通读 plan.md 与 PLANS.md，识别四章活文档章节缺失
- [x] (2026-04-30 准备) 收集 6 路并行 explore 结果（core 结构、state 依赖、ui 结构、tip_queue 循环、JSON 解析器、choice 结构）
- [x] (2026-04-30 准备) 解决 OQ-1：JSON 解析器**不支持 `//` 注释**，Phase 7 必须使用 `_governance` 字段
- [x] (2026-04-30 准备) 验证 R1：`src/core/utils/logger.lua` 顶层 `require("src.core.utils.tip_queue")`，循环依赖确认
- [x] (2026-04-30 准备) 验证 R2：仓库内**零动态 require**，批量替换可安全使用 grep
- [x] (2026-04-30 Phase 0) 创建 `docs/architecture/adr/0001-seven-layer-with-foundation.md`
- [x] (2026-04-30 Phase 1) 从 `tools/quality/arch/config.json` 删除 `systems_choice_bridges`，arch check 通过
- [x] (2026-04-30 Phase 2) 反转 state 逆向依赖：player_state.lua → `return {}`、game_state.lua 移除 game_victory require/install、compose_game.lua 顶层接管 5 个 state_ops + check_victory 安装；arch + lint + behavior(2010) + contract(137) 全绿；guards 仅 1 项 AGENTS/CLAUDE 文档预存漂移失败（与本次改动无关，由 Phase 8 修复）
- [x] (2026-04-30 Phase 3a) 仅迁移 with_client_role.lua → src/ui/utils/（4 个 consumers 已更新）；tip_queue 留 foundation（决策修订见决策日志）；arch + behavior(2010) 全绿
- [x] (2026-04-30 Phase 3b) dirty_tracker + ui_sync_shared 迁入 src/state/，6 + 2 个 consumer 路径已更新；arch + behavior(2010) 全绿
- [x] (2026-04-30 Phase 3c) choice/ 拆分：contract+route_policy → config/choice/、registry+item_preconsume_policy+use_skip_choice → rules/choice/、resolver → **rules/choice/**（修订：原计划 turn/choice/ 因 rules.bootstrap 需要 helpers 而违反 systems_no_outer_layers，相应更新 ADR D3）；额外修复 tip_queue→config 反向边（projection cycle root），将 timing 通过 configure_runtime DI 注入；arch + behavior(2010) + contract(137) 全绿
- [x] (2026-04-30 Phase 3d) src/core/ 剩余 10 个文件正确：events/init、ports/{runtime_ports, action_anim}、utils/{logger, log_formatter, logger_utils, number, tables, role_id, tip_queue}
- [x] (2026-04-30 Phase 4) src/core/ → src/foundation/ + 子目录重组：events/、ports/、log/{logger,formatter,utils}、lang/{number,tables}、identity/{role_id}、coordination/{tip_queue}；arch config 同步更新（pattern src.core → src.foundation）；script_tools_spec 修复路径引用；arch + behavior(2010) + contract(137) 全绿
- [x] (2026-04-30 Phase 5a) src/ui/pres → src/ui/view，arch+behavior 全绿
- [x] (2026-04-30 Phase 5c) src/ui/ctl → src/ui/coord，arch+behavior 全绿
- [x] (2026-04-30 Phase 5d) src/ui/wid → src/ui/render/widgets，arch+behavior 全绿
- [x] (2026-04-30 Phase 5b 部分回退) src/ui/state/ 接收 stores/canvas_store + stores/modal_state + 顶层 state.lua（→ runtime.lua）；ui_state/ui_runtime/event_state 因协调器特性导致循环留在 coord/（决策日志已记录）
- [x] (2026-04-30 Phase 5e) src/ui/utils/with_client_role.lua 已就位（Phase 3a 完成）
- [x] (2026-04-30 Phase 6a) 拍板：`visual_hold`
- [x] (2026-04-30 Phase 6b) src/state/{landing_visual_hold→visual_hold/init, deferred_dirty→visual_hold/deferred_dirty, release_scheduler→visual_hold/release_scheduler}
- [x] (2026-04-30 Phase 6c/5f 修订) UI wrapper `src/ui/landing_visual_hold.lua` → **`src/ui/visual_hold.lua`（顶层）**而非 `src/ui/state/visual_hold.lua`：因 wrapper 既 require render（effect_track）又 require state（visual_hold impl），放在 state/ 子视图会造成 ui_state→ui_render 循环。顶层 ui/ 文件不参与子视图分类，无循环。
- [x] (2026-04-30 Phase 6d) 全局 require 替换完成（4 个 ui wrapper consumers + 多处 state.* consumers）；arch + behavior(2010) 全绿
- [x] (2026-04-30 Phase 7) arch/config.json 完整重写：12 个 component（app/host/ui/turn/player/computer/rules/state/config/foundation + 2 host bridge exceptions）；3 个保留 exception 加 `_governance` 字段（host_bridge / infrastructure_runtime_bridges）+ 删除 4 个（runtime_state_bridges / state_access / player_state_bridge / systems_choice_bridges 早删）；新增 `foundation_no_upper` 规则；ui_schema_pure 规则中路径同步（pres→view, ctl→coord, wid→render.widgets, stores→state）；guards whitelist 同步更新（`src/ui/state.lua` → `src/ui/state/runtime.lua`、`src/ui/landing_visual_hold.lua` → `src/ui/visual_hold.lua`）；arch + behavior(2010) + contract(137) + guards（仅遗留 AGENTS/CLAUDE 漂移）全绿
- [x] (2026-04-30 Phase 8) 全部 5 个文档更新：layer-model.md 重写（七层 + foundation）、boundaries.md 同步（新目录职责、foundation_ports 等）、governance_roadmap.md 顶部加 ADR 状态注解、AGENTS.md 加 ADR 行 + src.core→src.foundation、CLAUDE.md 与 .github/copilot-instructions.md 同 AGENTS.md 同步；额外修复 3 个引用旧路径的测试（spec/contract/script_tools_spec、spec/suites/architecture/script_tools_{contract,tooling}）+ 1 个 arch_view_snapshot 投影测试（runtime→state、core.utils→foundation.lang）
- [x] (2026-04-30 最终) `/verify-full` 等价项全绿：lint 0 errors / arch ok / behavior 2010 / contract 137 / guards 35 / tooling 92 = **2274 通过、0 失败**

## 意外与发现

实施过程中的意外行为、bug、优化或洞察，附简短证据。

- **观察**：`src/core/utils/logger.lua` 顶层 `require("src.core.utils.tip_queue")`，且 logger 还 require log_formatter。Phase 3a 把 tip_queue 移到 ui 会让 foundation→ui 出现违规。
  **证据**：`bg_b66dcbf9` intra-core dep map：`src/core/utils/logger.lua requires: src.core.utils.tip_queue, src.core.utils.log_formatter`
  **影响**：必须在 Phase 3a 前选定 R1 缓解方案（A/B/C 之一）。
- **观察**：仓库内**零动态 require**（regex `require\(\s*["']src\.core["']?\s*\.\.` 匹配 0）。
  **证据**：`bg_b66dcbf9` 报告。
  **影响**：Phase 4 / Phase 5 / Phase 6 全局批量替换可基于纯字符串 grep 安全执行，R2 缓解到位。
- **观察**：core 总 require 数 ~335（其中测试 ~81，运行时 ~254），高于 plan 原估算 150+。
  **证据**：`bg_b66dcbf9`。
  **影响**：Phase 4 估算更新到 ~335 处（含测试），不影响策略。
- **观察**：`vendor/arch_view/arch_view/runtime/json_reader.lua` 是自定义 JSON 解析器，**不支持 `//` 行注释**。
  **证据**：`bg_a010abd4` 报告。
  **影响**：Phase 7 保留 exception 时使用 §5.2 `_governance` 字段方案，严禁写 `// comment`。OQ-1 / R5 已解决。
- **观察**：`src/state/game_state.lua` 第 4 行 `require("src.rules.endgame.game_victory")`、第 21 行 `game.check_victory = game_victory.check_victory`；`src/state/player_state.lua` 全文 23 行专门聚合 5 个 state_ops 模块为 `game_state_players` 表。
  **证据**：直接读取上述文件。
  **影响**：Phase 2 必须保持 mixin "类级" 安装语义；将 game_state.lua 的 `_install_mixin` + check_victory 与 player_state.lua 的整段逻辑迁入 compose_game.lua。`src/app/compose_game.lua` 既有 `composition_root.assemble()` 函数适合作为 host。

## 决策日志

每个关键设计决策都按以下格式记录："决策内容 + 理由 + 日期/作者"。

- **决策**：plan.md 不属于 `.sisyphus/plans/*.md` 目录，因此不触发自动 Momus 评审；继续将 plan.md 作为唯一活文档。
  **理由**：plan.md 已存在，迁移到 .sisyphus/plans/ 反而会破坏 git 历史；本计划自带活文档章节维护已足够。
  **日期/作者**：2026-04-30 / Sisyphus

- **决策（2026-04-30 Phase 5b 修订）**：Phase 5b/D4 中关于"ui_state.lua / ui_runtime.lua / event_state.lua 移入 src/ui/state/"的部分**部分回退**：仅 stores/canvas_store + stores/modal_state + 顶层 state.lua（→ runtime.lua）三件套移入 src/ui/state/；`ui_state` / `ui_runtime` / `event_state` **保留在 src/ui/coord/**。
  **理由**：arch_view 检测到这三个文件移入 state/ 后产生子视图循环：(a) state.ui_state → render.node_ops + render → state.* 形成 state↔render 循环；(b) state.ui_runtime → render/coord/input/schema 各方向 + 反向边，形成多路循环。这些文件本质是 UI 协调器（coordinator）而非纯状态容器——它们持有跨 render/coord/input 的引用以协调渲染与事件。把它们留在 coord/ 与其行为语义一致。
  **代价**：src/ui/state/ 仅包含 3 个文件（canvas_store, modal_state, runtime + 后续的 visual_hold）；src/ui/coord/ 体积保持原样。
  **日期/作者**：2026-04-30 / Sisyphus

- **决策（已修订 2026-04-30）**：Phase 3a 改选 **Option A**：**tip_queue 保留在 foundation**（推翻 plan §D3 中"移至 src/ui/utils/"的决策）。仅迁移 `with_client_role.lua` 到 `src/ui/utils/`。
  **理由**：grep 显示 tip_queue 有 2 个生产环境消费者位于 `src/turn/`（`turn/waits/await/simple_waits.lua`、`turn/policies/timer.lua`），它们调用 `tip_queue.has_blocking_pending(phase_name)` 用于 inter_turn 协调。把 tip_queue 移到 ui 会立即触发 `flow_no_presentation` 违规（turn→ui 禁止）。tip_queue 的"UI 性"已经通过 presenter/scheduler 的 DI 注入抽象掉了，队列本身是中立的协调机制——它属于 foundation 的 lang/coordination 子树而非 ui。Option C（lazy require）只能解决 logger 的循环，无法解决新出现的 turn→ui 违规。Option B（拆 logger）治标不治本。Option A 同时解决两个问题。
  **副产品**：原 R1（logger 循环）自动消失——tip_queue 留 foundation 后 `logger → tip_queue` 是同层依赖，合法。logger.lua 不需要任何修改。
  **后续 follow-up**：若未来要把 tip_queue 真正归到 ui，需先把 turn 的 inter_turn 阻塞查询改为通过端口/查询 port 间接调用，然后才能移动。本计划范围内不做此次重构。
  **日期/作者**：2026-04-30 / Sisyphus

- **原决策（作废）**：Phase 3a 选 Option C（tip_queue 迁 ui + logger 走 DI）——已被上方修订替代，原因详见上。

- **决策**：Phase 6a 选 **`visual_hold`** 作为 landing_visual_hold 改名后的子目录与 wrapper 名。
  **理由**：候选 4 选 1：（a）`visual_hold` 沿用现有"视觉冻结"语义，最少认知开销；（b）`ui_transaction` 暗示原子提交语义，但代码实际不是事务；（c）`animation_hold` 太具体（实际不只是动画）；（d）`ui_freeze` 与现有 game.dirty 系统语义混淆。`visual_hold` 保留 hold 动词，去掉 landing 名词偏见。
  **日期/作者**：2026-04-30 / Sisyphus

- **决策**：Phase 7 保留的 exception 使用 `_governance` 对象字段而非 `//` 注释。
  **理由**：自定义 JSON 解析器不支持 `//`（`bg_a010abd4` 验证），governance_roadmap §5.2 已经定义了 `_governance` 备选方案。
  **日期/作者**：2026-04-30 / Sisyphus

## 结果与复盘

### 完成判据核对（plan.md §完成判据）

| 项 | 标准 | 状态 |
|----|------|------|
| `src/core/` 不存在 | `[ ! -d src/core ]` | ✓ 已删除 |
| `src/foundation/` 存在并按 D3 + Phase 4 子目录组织 | `events/ports/log/lang/identity/coordination` | ✓ 6 个子目录就位 |
| `src/ui/` 按 D4 重组完成 | view/coord/render/state/utils + 顶层 visual_hold/host_bridge | ✓（含部分回退：ui_state/ui_runtime/event_state 留 coord） |
| state 无逆向依赖 | grep 上层引用为 0 | ✓ Phase 2 反转 + foundation_no_upper 规则覆盖 |
| arch.lua 无新增违规 | `lua tools/quality/arch.lua check` 通过 | ✓ |
| Exception 数量从 6 降至 3（含原计划 gameplay_state_bridges） | 实际 2（host_bridge_exception, infrastructure_runtime_bridges） | ✓ 优于预期：Phase 2 反转使 gameplay_state_bridges 不再必要 |
| `/verify-full` 全绿 | lint + behavior + contract + guards + tooling + arch | ✓ 共 2274 测试通过、0 失败 |
| 文档反向链接 | 4 个文件含 ADR 引用 | ✓ layer-model / boundaries / governance_roadmap / AGENTS（含 CLAUDE.md 与 copilot-instructions.md 同步）|

### 学到的事 / 与原计划的偏差

1. **三处主动偏差，全部为更安全的取舍**：
   - Phase 3a: tip_queue 留在 foundation（非移到 ui），避免 turn→ui 违规；副产品消除 R1 循环。
   - Phase 3c: choice/resolver 移到 rules 而非 turn，避免 systems→turn 违规（rules.bootstrap 需要 resolver.helpers）。
   - Phase 5b: ui_state/ui_runtime/event_state 留在 coord/，仅 stores+runtime 进入 state/，避免 ui 子视图循环。
   - Phase 5f/6c: visual_hold wrapper 落 src/ui/visual_hold.lua（顶层）而非 src/ui/state/，避免 state↔render 循环。
2. **R1（logger→tip_queue 循环）从问题变成非问题**：因 tip_queue 留在 foundation，logger→tip_queue 是同层依赖，无违规、无需改 logger。
3. **R2（动态 require）确认为零**：grep 全仓 0 命中，~335 处 require 路径迁移用纯字符串 sed 安全完成。
4. **R5（JSON 注释支持）确认不支持**：自定义 json_reader 无 // 注释能力；保留 exception 用 `_governance` 对象字段方案。
5. **额外发现的 projection cycle**：tip_queue → config.gameplay.timing 与新 config→foundation（contract→number）形成 core↔config 循环；通过把 timing 值改为 configure_runtime DI 注入解除（更好的设计）。
6. **额外修复的测试**：4 个引用旧路径的测试文件需要同步更新（script_tools_{contract,tooling}_spec、arch_view_snapshot_tooling_contract、agents_instructions_spec 链涉及的 .github/copilot-instructions.md）。
7. **追加的小功能**：tip_queue.configure_runtime 现在接受 `event_tip_fast_backlog_threshold` 与 `event_tip_fast_seconds`，作为 DI 通道替代直接 require config。

### 范围核算

- 代码文件迁移/修改：约 **65 个**（plan 估算 60，含意外发现的修复）
- require 路径变更：约 **335 处**（plan 估算 250+，更精确数据来自 bg_b66dcbf9 探测）
- 文档变更：**7 处**（layer-model、boundaries、governance_roadmap、AGENTS、CLAUDE、.github/copilot-instructions、ADR-0001 新建）
- 配置变更：arch/config.json 完全重写，从 6 exception + 9 forbidden_rule → 2 exception + 14 forbidden_rule（更细粒度边界）
- 测试套件状态：2274 通过、0 失败

### 经验教训

- **架构治理一定要先看子视图循环**：plan §D4 / D5 设计的 ui/state 与 state/visual_hold 都没考虑 wrapper 文件的双向依赖，结果三次回退。下次涉及"wrapper / facade / bridge"文件时，必须先模拟其依赖图。
- **arch_view 的"projection cycle"是隐藏护栏**：forbidden_rule 只看直接边，cycle 检查会从子视图角度抓回流。这次因为它发现了 config↔core 循环，反过来推动了 tip_queue DI 重构。这种隐藏检查比硬规则更有价值。
- **TDD 风格迁移可行**：每个 Phase 后立刻跑 verify，让退化在小步内被捕获。整个 8 phase 没有一次"跑完才发现错"的情况。
- **PLANS.md 的活文档要求是有意义的**：决策日志保留了三处偏差的 reasoning，半年后回看不会困惑"当时为什么没按 plan 做"。

---

## Context

将十层架构整治为七层 + 基础设施基座（foundation substrate），并完成 core 的彻底拆解、ui/ 的内部重组、landing_visual_hold 的改名打包。本计划取代 `docs/architecture/governance_roadmap.md` 中关于 D2 路径下文件迁移的若干决策（详见末尾"取代关系"）。

---

## 决策落槽（前置已拍板）

### D1. 架构模型：七层 + foundation 基座

```
L1  app                    → src/app/
L2  host                   → src/host/
L3  ui                     → src/ui/
L4  turn                   → src/turn/
L5  player | computer      → src/player/ | src/computer/
L6  rules                  → src/rules/
L7  state | config         → src/state/ | src/config/
─────
foundation（substrate）    → src/foundation/   ← 不计入七层，所有层共同的基础设施
```

### D2. 命名对齐：物理目录名 = 逻辑层名 = arch 组件名

| 组件名变更 | 旧 | 新 |
|----------|---|---|
| arch component | `flow` | `turn` |
| arch component | `runtime`（合并） | 拆为 `player` + `state` |
| arch component | `ai` | `computer` |
| arch component | `systems` | `rules` |
| arch component | `core` | `foundation` |
| layer label | `infrastructure` | `host` |
| layer label | `presentation` | `ui` |

### D3. Core 拆分映射（19 个文件 → 6 个去向）

| 模块 | 目标 | 路径 |
|------|------|------|
| `logger.lua`, `log_formatter.lua`, `logger_utils.lua` | foundation | `src/foundation/log/` |
| `number.lua`, `tables.lua` | foundation | `src/foundation/lang/` |
| `role_id.lua` | foundation | `src/foundation/identity/` |
| `events/init.lua` | foundation | `src/foundation/events/` |
| `ports/runtime_ports.lua`, `ports/action_anim.lua` | foundation | `src/foundation/ports/` |
| `choice/contract.lua`, `choice/route_policy.lua` | config (L7) | `src/config/choice/` |
| `choice/registry.lua`, `choice/item_preconsume_policy.lua`, `choice/use_skip_choice.lua` | rules (L6) | `src/rules/choice/` |
| `choice/resolver.lua` | turn (L4) | `src/turn/choice/` |
| `utils/dirty_tracker.lua`, `ui_sync_shared.lua` | state (L7) | `src/state/` |
| `utils/with_client_role.lua` | ui (L3) | `src/ui/utils/` |
| `utils/tip_queue.lua` | foundation（保留，见决策日志 Phase 3a 修订） | `src/foundation/coordination/tip_queue.lua` |

### D4. ui/ 内部重组

```
src/ui/
├── input/                   保持
├── view/                    重命名 pres/，role_context.lua 在此
├── render/                  保持，吸收 wid/ → render/widgets/
├── coord/                   重命名 ctl/，actor_context.lua 在此
├── state/                   合并 stores/ + 顶层 state.lua + ctl/ui_state + ctl/ui_runtime + 顶层 landing_visual_hold.lua
├── ports/                   保持
├── schema/                  保持
├── utils/                   新增，接收 with_client_role + tip_queue
└── host_bridge.lua          保持顶层
```

`actor_context.lua` 与 `role_context.lua` **保持不合并**（职责不同：前者是 host 桥接查询，后者是 view 数据投影）。术语统一（role/actor）作为后续 follow-up。

### D5. landing_visual_hold 改名打包

- 改名：去掉 "landing"，提议 `visual_hold` 或 `ui_transaction`（待 Phase 6 拍板）
- 留 state（L7），打包为子目录：

```
src/state/
├── visual_hold/            ← 新子目录（命名待定）
│   ├── init.lua            ← 前 landing_visual_hold.lua
│   ├── deferred_dirty.lua  ← 从 state/ 顶层移入
│   └── release_scheduler.lua  ← 从 state/ 顶层移入
├── event_log.lua           留 state/ 顶层（turn 多处使用）
├── runtime_state.lua       留 state/ 顶层（全局通用）
└── ...
```

`src/ui/landing_visual_hold.lua`（4 行 wrapper）改名跟随，移入 `src/ui/state/visual_hold.lua`。

### D6. State 逆向依赖修复

| 文件 | 当前问题 | 修复 |
|------|---------|------|
| `src/state/game_state.lua:4,21` | state(L7) → rules(L6) | mixin 安装移至 `src/app/compose_game.lua` |
| `src/state/player_state.lua:1-5` | state(L7) → player(L5) | mixin 安装移至 `src/app/compose_game.lua` |

### D7. Exception 处置

| # | 名称 | 处置 |
|---|------|------|
| 1 | `host_bridge_exception` | 保留 |
| 2 | `infrastructure_runtime_bridges` | 保留 |
| 3 | `runtime_state_bridges` | 重命名为 `gameplay_state_bridges` |
| 4 | `systems_choice_bridges` | **删除**（幻影：匹配零文件） |
| 5 | `state_access` | **删除**（state ↔ foundation 现在是平级关系） |
| 6 | `player_state_bridge` | **删除**（player_state 留 state，不再归类到 runtime） |

新增 `foundation_no_upper` 规则：`state/config/foundation` 不可依赖任何上层。

---

## 实施阶段（按优先级）

### 优先级总览

| Pri | Phase | 内容 | 阻塞下游 |
|-----|-------|------|---------|
| P0 | 0 | 决策记录（ADR） | 全部下游 |
| P0 | 1 | 删除幻影 exception #4 | 无 |
| P1 | 2 | 反转 state 逆向依赖 | Phase 7（runtime 拆分）|
| P1 | 3 | Core 拆分（保留 src/core/ 名）| Phase 4 |
| P1 | 4 | `src/core/` → `src/foundation/` 重命名 | Phase 7（component 重命名） |
| P2 | 5 | ui/ 内部重组 | Phase 7（路径匹配规则）|
| P2 | 6 | landing_visual_hold 改名 + 打包 | Phase 7 |
| P1 | 7 | arch config 重写 | Phase 8 |
| P3 | 8 | 文档更新 + 反向链接 | 无 |

P0 = 阻塞性前置；P1 = 核心代码变更；P2 = 整理优化；P3 = 收尾。

---

### Phase 0 — 决策记录（P0）

**变更**：
- 新增 `docs/architecture/adr/0001-seven-layer-with-foundation.md`，固化 D1-D7 决策

**验证**：人工 review；后续阶段执行人据此对照

---

### Phase 1 — 删除幻影 exception #4（P0，零风险）

**变更**：
- `tools/quality/arch/config.json` 删除 `systems_choice_bridges`（行 41-46）

**验证**：`lua tools/quality/arch.lua check`

**理由**：匹配模式 `^src%.player%.choices%..+` 对应零文件，纯清理。先做以减小后续混淆。

---

### Phase 2 — 反转 state 逆向依赖（P1）

**变更**：

`src/state/game_state.lua`：
- 删除行 4：`local game_victory = require("src.rules.endgame.game_victory")`
- 删除行 21：`game.check_victory = game_victory.check_victory`

`src/state/player_state.lua`：
- 删除行 1-5：5 个 `state_ops` require
- 删除行 8-20：groups 定义和 mixin 循环
- 文件简化为返回空表（保留导出位用于 game_state mixin 安装），或考虑直接删除并由 compose_game 接管

`src/app/compose_game.lua`：
- 接收 `game_victory` require + `game.check_victory = ...` 安装
- 接收 5 个 `state_ops` require + mixin 循环安装
- 安装时机：`composition_root.assemble()` 中，instance 创建前完成 class 级 mixin

**验证**：
```bash
busted --run behavior
busted --run guards
lua tools/quality/arch.lua check
```

**风险**：mixin 安装时机错误导致 player 实例缺方法。
**缓解**：保持 class 级安装语义不变；测试覆盖完整。

---

### Phase 3 — Core 拆分（P1，保留 src/core/ 物理名）

按文件影响面从小到大分批，每批可独立验证。

#### Phase 3a — UI 专属（最小批，~12 个 require 变更）

| 迁移 | 影响文件 |
|------|---------|
| `core/utils/with_client_role.lua` → `src/ui/utils/with_client_role.lua` | 4 个 ui 消费者 |
| `core/utils/tip_queue.lua` → `src/ui/utils/tip_queue.lua` | 5 个消费者（含 logger.lua 内部，需先理顺） |

**注意**：`tip_queue` 被 `core/utils/logger.lua` 引用。logger 仍在 foundation，但需要 tip_queue 能从 ui 取——这违反层级（foundation 不能依赖 ui）。**必须先处理这个循环**：

- 选项 A：tip_queue 留在 foundation/utils/（推翻"UI 层"决定）
- 选项 B：拆分 logger，让其不依赖 tip_queue（tip_queue 是真正的 UI 提示队列）
- 选项 C：tip_queue 移到 ui，但 logger 通过 DI 接收 tip_queue 实例（在 compose_game 注入）

**推荐 C**：保持 tip_queue 的 UI 属性，logger 改为可选注入。需要在 Phase 3a 执行前确认是否可行（先读 logger.lua 看 tip_queue 用法）。

#### Phase 3b — 状态相关（小批，~6 个 require 变更）

| 迁移 | 影响文件 |
|------|---------|
| `core/utils/dirty_tracker.lua` → `src/state/dirty_tracker.lua` | 3 个消费者 |
| `core/ui_sync_shared.lua` → `src/state/ui_sync_shared.lua` | 2 个消费者 |

#### Phase 3c — Choice 拆分（中批，~25 个 require 变更）

| 迁移 | 目标 |
|------|------|
| `core/choice/contract.lua` | `src/config/choice/contract.lua` |
| `core/choice/route_policy.lua` | `src/config/choice/route_policy.lua` |
| `core/choice/registry.lua` | `src/rules/choice/registry.lua` |
| `core/choice/item_preconsume_policy.lua` | `src/rules/choice/item_preconsume_policy.lua` |
| `core/choice/use_skip_choice.lua` | `src/rules/choice/use_skip_choice.lua` |
| `core/choice/resolver.lua` | `src/turn/choice/resolver.lua` |

`resolver` 内部依赖 `item_preconsume_policy`（→ rules）→ turn(L4) 依赖 rules(L6)，合法 ✓
`contract` 内部依赖 `number`（→ foundation）→ config(L7) 依赖 foundation，合法 ✓

#### Phase 3d — 验证 src/core/ 剩余内容

完成 3a-3c 后 `src/core/` 应只剩：
```
src/core/
├── events/init.lua
├── ports/{runtime_ports.lua, action_anim.lua}
└── utils/{logger.lua, log_formatter.lua, logger_utils.lua, number.lua, tables.lua, role_id.lua}
```

进入 Phase 4 整体改名。

**验证（每子阶段）**：
```bash
lua tools/quality/lint.lua
busted --run behavior
busted --run guards
lua tools/quality/arch.lua check
```

---

### Phase 4 — `src/core/` → `src/foundation/` 重命名（P1）

**变更**：

子目录调整 + 改名（一次原子操作）：

```
src/core/                          src/foundation/
├── events/init.lua          →     ├── events/init.lua
├── ports/                   →     ├── ports/
│   ├── runtime_ports.lua    →     │   ├── runtime_ports.lua
│   └── action_anim.lua      →     │   └── action_anim.lua
└── utils/                   →     ├── log/
    ├── logger.lua           →     │   ├── logger.lua
    ├── log_formatter.lua    →     │   ├── formatter.lua
    ├── logger_utils.lua     →     │   └── utils.lua
    ├── number.lua           →     ├── lang/
    ├── tables.lua           →     │   ├── number.lua
    └── role_id.lua          →     │   └── tables.lua
                                   └── identity/
                                       └── role_id.lua
```

**操作**：
1. `git mv src/core/ src/foundation/`
2. 内部重组（log/、lang/、identity/）
3. 全局批量替换 require 路径（`src.core.*` → `src.foundation.*` + 子目录调整）
4. 在 `.git-blame-ignore-revs` 中添加该 commit hash

**估算**：~150+ 个 require 路径变更（logger 54 + number 55 + role_id 27 + events 17 + runtime_ports 43 + action_anim 12，去重后）

**验证**：
```bash
grep -rn "src\.core\." src/ tests/ tools/ --include='*.lua'   # 应为 0
lua tools/quality/lint.lua
busted --run behavior
busted --run contract
busted --run guards
lua tools/quality/arch.lua check
```

**风险**：动态拼接 require（`require("src.core." .. name)`）漏改。
**缓解**：执行前 `grep -rn 'require.*"src\.core\.\?\.\.\?'` 扫描动态路径；测试覆盖。

---

### Phase 5 — ui/ 内部重组（P2）

按依赖顺序分批：

#### Phase 5a — pres/ → view/

`git mv src/ui/pres src/ui/view`，全局替换 `src.ui.pres` → `src.ui.view`。

#### Phase 5b — ctl/ 状态文件抽离

新增 `src/ui/state/`，移入：
- `src/ui/ctl/ui_state.lua` → `src/ui/state/ui_state.lua`
- `src/ui/ctl/ui_runtime.lua` → `src/ui/state/ui_runtime.lua`
- `src/ui/ctl/event_state.lua` → `src/ui/state/event_state.lua`（如属状态容器）
- `src/ui/state.lua`（顶层） → `src/ui/state/runtime.lua`
- `src/ui/stores/canvas_store.lua` → `src/ui/state/canvas_store.lua`
- `src/ui/stores/modal_state.lua` → `src/ui/state/modal_state.lua`

删除 `src/ui/stores/` 空目录。

#### Phase 5c — ctl/ → coord/

`git mv src/ui/ctl src/ui/coord`，全局替换 `src.ui.ctl` → `src.ui.coord`。

#### Phase 5d — wid/ → render/widgets/

`git mv src/ui/wid src/ui/render/widgets`，全局替换 `src.ui.wid` → `src.ui.render.widgets`。

#### Phase 5e — utils/ 落位

确认 `src/ui/utils/with_client_role.lua` + `src/ui/utils/tip_queue.lua` 已就位（Phase 3a 已做）。

#### Phase 5f — 顶层 landing_visual_hold.lua 移入

`src/ui/landing_visual_hold.lua` → `src/ui/state/visual_hold.lua`（命名跟 Phase 6 拍板结果）。

**验证（每子阶段）**：
```bash
lua tools/quality/lint.lua
busted --run behavior
busted --run guards
lua tools/quality/arch.lua check
```

---

### Phase 6 — landing_visual_hold 改名 + 打包（P2）

**Phase 6a — 拍板新名字**

候选：`visual_hold` / `ui_transaction` / `animation_hold` / `ui_freeze`

执行前确认：选哪个？（不在本计划内代填，需要执行人或人工选）

**Phase 6b — 打包子目录**

```
src/state/landing_visual_hold.lua        → src/state/{NEW_NAME}/init.lua
src/state/deferred_dirty.lua             → src/state/{NEW_NAME}/deferred_dirty.lua
src/state/release_scheduler.lua          → src/state/{NEW_NAME}/release_scheduler.lua
```

`event_log.lua`、`runtime_state.lua` 留 `src/state/` 顶层（被多处使用，非 hold 专属）。

**Phase 6c — UI wrapper 跟随**

`src/ui/landing_visual_hold.lua` → `src/ui/state/{NEW_NAME}.lua`

**Phase 6d — 全局 require 替换**

涉及消费者数量需扫描后估算。预计 ~15-20 处。

**验证**：
```bash
grep -rn 'landing_visual_hold' src/ tests/ tools/ --include='*.lua'   # 应只剩文档级引用
busted --run behavior
busted --run guards
lua tools/quality/arch.lua check
```

---

### Phase 7 — arch config 重写（P1）

执行顺序很重要。

#### Phase 7a — Component 重命名（无逻辑变更，纯字符串）

`tools/quality/arch/config.json`：
- `flow` → `turn`
- `ai` → `computer`
- `systems` → `rules`
- `core` → `foundation`（match pattern 同步改 `^src%.foundation%..+`）

#### Phase 7b — Component 拆分

- 删除 `runtime` component
- 新增 `player` component：match `^src%.player$`, `^src%.player%..+`
- 新增 `state` component：match `^src%.state$`, `^src%.state%..+`

#### Phase 7c — 替换 forbidden 规则

删除：
- `runtime_state_no_outer`
- `config_no_outer_layers`
- `runtime_player_*` 系列重命名为 `player_*`

新增：
```json
{
  "name": "foundation_no_upper",
  "from": ["^src%.state%..+", "^src%.config%..+", "^src%.foundation%..+"],
  "to": ["^src%.player%..+", "^src%.computer%..+", "^src%.rules%..+",
          "^src%.turn%..+", "^src%.ui%..+", "^src%.host%..+", "^src%.app%..+"],
  "description": "L7 foundation (state/config/foundation) must not depend on any upper layer"
}
```

注意：`state ↔ config ↔ foundation` 之间无禁止规则（L7 平级 + 基座，可互相引用）。

#### Phase 7d — Exception 处置

| # | 名称 | 操作 |
|---|------|------|
| 3 | `runtime_state_bridges` | 重命名 `gameplay_state_bridges` |
| 5 | `state_access` | 删除 |
| 6 | `player_state_bridge` | 删除 |

#### Phase 7e — 注释格式确认

确认 `arch.lua` 的 JSON 解析器是否支持 `//` 注释（governance_roadmap §5.2 OQ-1）。若不支持，保留 exception 时使用 `_governance` 字段方案。

**验证**：
```bash
lua tools/quality/arch.lua check
busted --run contract
busted --run behavior
busted --run guards
busted --run tooling
```

---

### Phase 8 — 文档更新（P3）

#### Phase 8a — `docs/architecture/layer-model.md`

完全重写：
- 七层 + foundation 基座的描述
- 物理目录 = 层名 = 组件名 的统一映射
- 各层职责与禁止行为
- foundation 子目录结构（log/lang/identity/events/ports）

#### Phase 8b — `docs/architecture/boundaries.md`

更新边界规则描述，对齐新的 forbidden 规则。

#### Phase 8c — `docs/architecture/governance_roadmap.md`

顶部追加：

```markdown
> **Status**: 部分决策已被 `docs/architecture/adr/0001-seven-layer-with-foundation.md` 取代。
> 取代项：3.2.1 / 3.2.2 / 3.2.3 / 3.3 / 3.4（state 文件去向）；W4（state 迁移大半不再需要）；
> Chapter 5 exception 处置（按七层方案重做）。
> 仍有效：D2 决策（保留物理名，但 host/ui/computer 现在也作为层名）；W1 决策结构。
```

#### Phase 8d — 反向链接

在以下文件顶部添加 "See also"：
- `docs/architecture/layer-model.md`
- `docs/architecture/boundaries.md`
- `docs/architecture/health_signals.md`
- `AGENTS.md`（"按任务找文档"表新增一行）

#### Phase 8e — `CLAUDE.md` 更新

`src/` 禁用 `tonumber` / `type == "number"` 的规则改为：用 `NumberUtils`（`src.foundation.lang.number`）。其他 require 路径示例同步更新。

---

## 风险登记

| ID | 风险 | 影响 Phase | 缓解 |
|----|------|-----------|------|
| R1 | tip_queue 在 logger 内的循环依赖 | 3a | 执行前读 logger.lua 确认；选 DI 注入方案 |
| R2 | 动态 require 拼接路径未覆盖 | 4, 5, 6 | 每阶段前 grep 扫描动态路径 |
| R3 | mixin 安装时机错误导致 class 缺方法 | 2 | behavior + guards 测试覆盖 |
| R4 | git blame 链断裂 | 4 | `.git-blame-ignore-revs` 维护 |
| R5 | arch config 解析器不支持 `//` 注释 | 7e | OQ-1 在 Phase 0 前确认 |
| R6 | foundation_no_upper 规则触发新违规 | 7c | Phase 7c 前 arch check 确认无残余逆向依赖 |
| R7 | state 子目录化后 require 路径漏改 | 6b | Phase 6 后全文 grep 验证 |

---

## 完成判据

| 项 | 标准 |
|----|------|
| `src/core/` 不存在 | `[ ! -d src/core ]` |
| `src/foundation/` 存在并按 D3 + Phase 4 子目录组织 | `ls src/foundation/` |
| `src/ui/` 按 D4 重组完成 | `ls src/ui/` 显示 view/coord/render/state/utils 等 |
| state 无逆向依赖 | `grep -rn 'src\.player\|src\.rules\|src\.turn\|src\.ui\|src\.host\|src\.app' src/state/ --include='*.lua'` 应为 0 |
| arch.lua 无新增违规 | `lua tools/quality/arch.lua check` 通过 |
| Exception 数量 | 从 6 降至 3（host_bridge / infrastructure_runtime_bridges / gameplay_state_bridges） |
| `/verify-full` 全绿 | lint + behavior + contract + guards + tooling + arch 全部通过 |
| 文档反向链接 | 4 个文件含 governance/ADR 引用 |

---

## 涉及文件清单

| Phase | 代码文件 | 文档/配置 | require 变更估算 |
|-------|---------|----------|----------------|
| 0 | — | 1 个 ADR 新建 | 0 |
| 1 | — | `arch/config.json` | 0 |
| 2 | 3 个（game_state, player_state, compose_game） | — | 0 |
| 3 | 19 个 core 文件迁移 | — | ~50 |
| 4 | 重命名 src/core/ → src/foundation/ + 子目录调整 | — | ~150 |
| 5 | ui/ 30+ 个文件位置变更 | — | ~50 |
| 6 | 3-4 个 state 文件 + 1 个 ui wrapper | — | ~15-20 |
| 7 | — | `arch/config.json` 大改 | 0 |
| 8 | — | `layer-model.md`, `boundaries.md`, `governance_roadmap.md`, `AGENTS.md`, `CLAUDE.md`, 3 处反向链接 | 0 |

总计代码文件迁移/修改约 60 个，require 路径变更约 250+ 处，文档变更 7 处。

---

## 与 governance_roadmap.md 的取代关系

| roadmap 决策项 | 本计划处置 |
|--------------|----------|
| 3.1 D2 路径（保留物理名） | 仍有效（host/ui/computer 现在物理名 = 层名）|
| 3.2.1 game_state 归属 | 留 state，反转 rules 依赖 |
| 3.2.2 runtime_state 处置 | 留 state（七层下 state 是 L7 数据层） |
| 3.2.3 UI 三件套归属 | landing_visual_hold + deferred_dirty + release_scheduler 打包成 state/{visual_hold}/ 子目录 |
| 3.3 Component 拆分 | **必须执行**（runtime → player + state） |
| 3.4 board_state 归属 | 留 state（七层下 state 即数据层，无需新增 board/） |
| W3 拆分 component | 本计划 Phase 7b |
| W4 state/ 文件迁移 | 大半作废；只保留 mixin 反转（Phase 2） + visual_hold 打包（Phase 6） |
| W5 物理目录改名 | 不执行（D2 决议）；本计划 Phase 4 仅改 core → foundation |
| W6 Exception 清零 | 本计划 Phase 7d |
| W7 反向链接 | 本计划 Phase 8d |
