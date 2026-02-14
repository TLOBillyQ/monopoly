# 回合与UI边界重构计划（分治里程碑版）

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。  
本计划遵循 `.agents/PLANS.md`。

## 目的 / 全局视角

本计划用于把当前审查中发现的关键结构债拆成可落地的小步改造：先修确定性逻辑风险，再逐步清理依赖方向与接口耦合，最后收敛重复策略与验证。完成后，用户可观察到三类结果：
1) 业务行为不变且回归通过；
2) 关键模块职责更单一、跨层依赖减少；
3) 后续新增功能改动面更小、更容易测试。

## 进度

- [x] (2026-02-14T05:46Z) 完成全量代码审查与问题分级（P1/P2/P3）
- [x] (2026-02-14T05:47Z) 输出重构方向并确定“先稳后拆”的顺序
- [x] (2026-02-14T05:48Z) 将重构拆分为可独立验收的分治里程碑
- [x] (2026-02-14T05:58Z) 里程碑 M1：修复 `discard_properties` 遍历删除风险（P1）
- [x] (2026-02-14T05:59Z) 里程碑 M2：去除 `TickUISync` 对 UI 细节的反向依赖（DIP）
- [x] (2026-02-14T06:01Z) 里程碑 M3：拆分 GameplayLoop Ports 大接口（ISP/SRP）
- [x] (2026-02-14T06:03Z) 里程碑 M4：胜负结算事件化，分离领域与表现层（SRP/DIP）
- [x] (2026-02-14T06:03Z) 里程碑 M5：统一 debug 开关策略，消除重复实现（SRP/DRY）
- [x] (2026-02-14T06:05Z) 里程碑 M6：回归验证、更新架构文档与复盘
- [x] (2026-02-14T06:09Z) 按 `.agents/docs/eggy/lua_env.md` 重审未提交改动（通过）
- [x] (2026-02-14T07:09Z) 里程碑 M3 追加收尾：清理 ports 平铺兼容层并迁移调用方/测试桩到分组接口

## 意外与发现

- 观察：`discard_properties` 在 `pairs(player.properties)` 中删除同一 table 的 key，存在行为不稳定风险。  
  证据：`src/game/systems/chance/ChanceRegistry.lua:349-365` + `src/game/core/runtime/GameStatePlayers.lua:71-77`。
- 观察：回合层 `TickUISync` 直接读取 `UIManager` 并 require presentation 模块，依赖方向反转。  
  证据：`src/game/flow/turn/TickUISync.lua:129-133`。
- 观察：GameplayLoop Ports 当前是 29 个函数的大接口，适配层聚合了过多职责。  
  证据：`src/game/flow/turn/GameplayLoopPortTypes.lua:3-29`、`src/presentation/api/GameplayLoopPortsAdapter.lua:20-275`。
- 观察：胜负结算混入 UI 引擎调用，领域规则与表现细节耦合。  
  证据：`src/game/core/runtime/GameVictory.lua:42-60`。
- 观察：端口分组可在不破坏旧调用的前提下落地，`GameplayLoop` 已迁移到分组优先读取。  
  证据：`src/game/flow/turn/GameplayLoopPorts.lua`、`src/game/flow/turn/GameplayLoop.lua`。
- 观察：当前仓库回归基线稳定。  
  证据：执行 `lua .agents/tests/regression.lua` 输出 `All regression checks passed (135)`。

## 决策日志

- 决策：采用“先行为安全，再架构优化”的顺序。  
  理由：先处理确定性业务风险（P1）可快速降风险，后续拆层在行为稳定基线上进行更安全。  
  日期/作者：2026-02-14 / Copilot CLI
- 决策：每个里程碑必须可单独回归与可回滚，不做跨里程碑大爆改。  
  理由：降低一次性改动面，减少排障复杂度。  
  日期/作者：2026-02-14 / Copilot CLI
- 决策：M3 引入“兼容适配阶段”，先增量并行，再删除旧路径。  
  理由：端口拆分涉及面大，先保留兼容层可避免中断现有逻辑。  
  日期/作者：2026-02-14 / Copilot CLI
- 决策：M4 改为“领域发事件、表现层消费”，将胜负面板逻辑迁移到 `UIEventHandlers`。  
  理由：让 `GameVictory` 保持领域纯度，减少引擎 API 对核心规则的污染。  
  日期/作者：2026-02-14 / Copilot CLI
- 决策：M6 保留端口平铺兼容层，不在本轮删除。  
  理由：现有调用面较广，先完成分组迁移与回归稳定，再在后续小步清理兼容入口。  
  日期/作者：2026-02-14 / Copilot CLI
- 决策：根据用户要求重申 M3，立即清理残留兼容层并同步改造调用方与测试桩。  
  理由：当前调用面已可控，继续保留兼容层会掩盖接口边界并增加维护负担。  
  日期/作者：2026-02-14 / Copilot CLI

## 结果与复盘

已完成 M1-M6 全部里程碑并通过回归（`All regression checks passed (135)`）。  
主要结果：  
1) 修复了 `discard_properties` 的遍历删除不稳定风险；  
2) `TickUISync` 去除了对 UI 运行时细节的反向依赖，debug 策略统一由 `UIEventState` 提供；  
3) GameplayLoop ports 增加 `modal/anim/ui_sync/debug/state` 分组并迁移主循环使用；  
4) `GameVictory` 改为发出 `game.finished` 事件，胜负面板行为下沉到 `UIEventHandlers`；  
5) 已移除 ports 平铺兼容逻辑（resolver/adapter/callers/测试桩均切到分组接口）；  
6) `ARCHITECTURE.md` 已同步更新端口分组与胜负事件链路说明。

## 背景与导读

与本计划最相关的模块如下：
- 回合编排与端口：
  - `src/game/flow/turn/GameplayLoop.lua`
  - `src/game/flow/turn/GameplayLoopPortTypes.lua`
  - `src/game/flow/turn/GameplayLoopPorts.lua`
  - `src/presentation/api/GameplayLoopPortsAdapter.lua`
- 回合同步与调试判定：
  - `src/game/flow/turn/TickUISync.lua`
  - `src/presentation/interaction/UIEventState.lua`
- 业务风险点（机会卡丢地产）：
  - `src/game/systems/chance/ChanceRegistry.lua`
- 领域与表现耦合点（胜负结算）：
  - `src/game/core/runtime/GameVictory.lua`
- 回归入口：
  - `.agents/tests/regression.lua`

术语说明：
- DIP（依赖倒置）：高层策略依赖抽象，不直接依赖低层细节。
- SRP（单一职责）：一个模块只因一种原因变化。
- ISP（接口隔离）：调用方只依赖自己真正需要的最小接口。

## 里程碑（分治）

### 里程碑 M1：修复 P1 行为风险（`discard_properties`）

目标是把“遍历中删除”改成“先收集再删除”，保证丢地产数量与结果可预测。完成后可通过构造 `count=1/2/全部` 场景验证地产数量变化准确。

分治步骤：
1. 在 `ChanceRegistry.discard_properties` 内先复制 `tile_id` 到数组并排序（稳定顺序）。
2. 再按数组逐项执行 `reset_tile + set_player_property(..., false)`。
3. 保持原有日志与事件语义不变。
4. 补回归测试或最小场景验证脚本。

验收：对应场景不再出现漏删或非确定顺序。

### 里程碑 M2：修复依赖方向（`TickUISync` 不直连 UI 细节）

目标是让回合层不直接触碰 `UIManager` 和 presentation 的运行时实现。完成后 `TickUISync` 仅通过 ports 或注入函数获取 debug 开关状态。

分治步骤：
1. 在 ports 抽象层新增 `resolve_debug_enabled(state)`（默认实现保底）。
2. `GameplayLoopPortsAdapter` 负责绑定现有 UI 判定逻辑。
3. `TickUISync` 改为调用注入能力，不再 `require("src.presentation.api.UIRuntimePort")`。
4. 保持现有调试开关行为不变（含按 role 覆盖）。

验收：行为一致、跨层 require 减少、回合层无 UIManager 直接依赖。

### 里程碑 M3：拆分 GameplayLoop Ports 大接口

目标是把 29 个端口按职责拆为小接口集合，降低编排层与适配层耦合。完成后新增/修改单个能力只影响对应子接口。

分治步骤：
1. 定义分组：`modal_ports`、`anim_ports`、`ui_sync_ports`、`debug_ports`、`state_ports`。
2. 在 `GameplayLoopPorts` 保留兼容入口（旧字段映射到新分组）。
3. `GameplayLoop` 分批改为依赖分组接口（一次仅迁移一组）。
4. 迁移完成后再删旧平铺字段与兼容映射。

验收：
- `GameplayLoop.lua` 依赖的字段数量显著下降；
- `GameplayLoopPortsAdapter` 结构按分组可读；
- 回归通过。

### 里程碑 M4：胜负结算事件化

目标是让 `GameVictory` 只负责计算赢家与设置领域状态，UI 表现动作移到表现层订阅。完成后领域层可脱离引擎 API 独立测试。

分治步骤：
1. 在 `GameVictory` 产出胜负事件（含 winners/winner_names）。
2. 在 UI 事件处理层消费该事件并调用 `role.game_win_and_show_result_panel/lose`。
3. 保留短期兼容开关（必要时允许旧路径兜底）。
4. 验证多人并列胜利、无人存活、回合上限触发三类分支。

验收：`GameVictory` 内不再直接操作 UI role 展示 API。

### 里程碑 M5：统一 debug 开关策略

目标是合并 `TickUISync` 与 `UIEventState` 重复判定，实现单一事实来源。完成后 debug 显示行为在所有入口一致。

分治步骤：
1. 抽取统一策略模块（建议 `presentation/interaction` 层）。
2. `UIIntentDispatcher` 与 `GameplayLoopPortsAdapter` 共用该策略。
3. 删除重复逻辑并保留等价单测/回归场景。

验收：两处重复逻辑收敛为一处，行为无回归。

### 里程碑 M6：收尾与验证

目标是收敛兼容层、补齐测试与文档，形成稳定交付。完成后计划中的结构债修复具备可持续维护基础。

分治步骤：
1. 删除 M3/M4 引入的临时兼容代码（若已无引用）。
2. 补充关键路径测试说明（至少覆盖 M1/M2/M4）。
3. 更新 `ARCHITECTURE.md` 中端口与分层描述。
4. 全量回归并记录基线结果。

验收：代码路径简化，文档与实现一致。

## 工作计划

按 M1 -> M6 顺序串行执行；每个里程碑只改与目标直接相关的文件，避免跨里程碑“顺手重构”。每完成一个里程碑，必须先跑回归，再更新本计划“进度/发现/决策/复盘”，然后进入下一个里程碑。涉及大改（M3/M4）时采用“并行路径 + 兼容层”策略，确保主干行为始终可运行。

## 具体步骤

工作目录：`/Users/billyq/Dev/Github/Lua/monopoly`

1) 进入里程碑实施前基线检查
   - `lua .agents/tests/regression.lua`
   - 预期：`All regression checks passed (N)`

2) 实施每个里程碑后统一执行
   - `lua .agents/tests/regression.lua`
   - 若失败：仅修复与当前里程碑直接相关的问题，不扩散改动面。

3) 每次停点更新计划
   - 更新本文件“进度/意外与发现/决策日志/结果与复盘”。

## 验证与验收

总体验收标准：
1. 业务行为不倒退（回归通过）。
2. 关键架构目标达成：
   - `TickUISync` 去除 UI 细节依赖；
   - GameplayLoop 端口由平铺大接口拆为分组；
   - `GameVictory` 去除直接 UI 调用。
3. P1 风险点修复可被场景证明：`discard_properties` 丢地产数量稳定可预测。

建议验证清单：
- 自动回归：`lua .agents/tests/regression.lua`
- 手动场景：
  - 触发机会卡丢地产（不同 count）
  - 切换调试开关（含多 role）
  - 回合上限触发胜负结算

## 可重复性与恢复

本计划按里程碑增量执行，任一里程碑失败可独立回退，不影响前序稳定里程碑。M3/M4 的兼容层保证中途可运行；若出现不可控回归，先回退当前里程碑变更再重试，不跨里程碑补丁式修复。

## 产物与备注

计划产物：
- `.agents/PLAN_CURRENT.md`（本文件）
- `/Users/billyq/.copilot/session-state/0403e262-a78c-4b54-a776-863188a64789/plan.md`（会话镜像）

分析产物（本次审查已生成）：
- `.../files/review_scope.txt`
- `.../files/review_metrics.csv`
- `.../files/review_hotspots.txt`
- `.../files/review_dep_edges.csv`
- `.../files/review_cross_layer.txt`
- `.../files/review_summary_stats.txt`

## 接口与依赖

实施时优先复用现有模块，不新增跨层全局变量。
- 回合层对 UI 的需求通过 `GameplayLoopPorts` 暴露。
- 表现层细节留在 `src/presentation/**`。
- 领域事件通过既有事件通道（`MonopolyEvents` / `UIEventHandlers`）传递。

M3 里程碑结束时，至少应存在以下分组能力（命名可微调，但语义需稳定）：
- `ports.modal.*`
- `ports.anim.*`
- `ports.ui_sync.*`
- `ports.debug.*`
- `ports.state.*`

### 变更记录

- 2026-02-14：基于全量审查结果重写为分治里程碑计划，明确 M1-M6 验收与回滚策略。
- 2026-02-14：执行完成 M1-M6；完成端口分组迁移、胜负事件化、debug 策略收敛、P1 修复与回归验证。
- 2026-02-14：依据 `lua_env.md` 复审未提交代码，未发现沙盒禁用库/键类型/隐式转换相关违规。
- 2026-02-14：根据环境约束移除 `discard_properties` 中对 `type(...) == \"number\"` 的假设，改为 `math.tointeger` 判定。
- 2026-02-14：订正 `NumberUtils` 并全仓替换显式数值类型判断/转换入口，统一走 `NumberUtils`；回归通过 135。
