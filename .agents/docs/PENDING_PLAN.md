# `src/` 热点深审落地：先执行 P1-01（GameState 与 UI 解耦）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/.agents/PLANS.md` 维护。

## 目的 / 全局视角

这次任务先把已经完成的 Uncle Bob 审查结论落档，再立即执行第一条高优先级整改（P1-01）。用户可见目标是：在没有 UI 端口的上下文里，地块归属更新不再因 `missing ui_port` 断言崩溃；在有 UI 的正常流程里，地块归属变更仍会触发 UI 更新。验证方式是新增针对 `set_tile_owner/reset_tile` 的解耦测试，并跑回归确认不退化。

## 进度

- [x] 里程碑 M0（2026-02-10 17:12）：完成审查结果入档与执行面收敛（热点范围、问题分级、接口候选清单写入当前计划）。
- [x] 里程碑 M1（2026-02-10 17:18-17:21）：完成 P1-01（`GameState` 地块归属通知解耦）并通过回归（84 通过）。
- [ ] 里程碑 M2：执行 P1-02（`GameplayLoop` 端口化拆分，分离“回合编排”与“UI/动画副作用”）。
- [ ] 里程碑 M3：执行 P1-03（`RuntimeContext` 环境绑定与导出职责拆分，降低全局耦合）。
- [ ] 里程碑 M4：处理高价值 P2（`UIModel` 职责拆分 + `TickTimeout` 超时策略显式化）。
- [ ] 里程碑 M5：处理其余 P2/P3（`UIModalPresenter`、`UIRuntimePort`、`PaidCurrencyBridge`、`MarketView`、`UIEventRouter`）。
- [ ] 里程碑 M6：全链路验收与复盘（回归、风险清单清零、回填“结果与复盘”章节）。

## 意外与发现

- 观察：当前代码中 `GameState` 只在 `set_tile_owner/reset_tile` 两处硬依赖 `ui_port.on_tile_owner_changed`，改造切口很小，适合先做最小重构。
  证据：`src/game/game/GameState.lua` 第 306-325 行。
- 观察：现有测试构建器默认给 `game.ui_port` 注入空实现，因此之前没有暴露“无 UI 崩溃”风险，需要补专门测试。
  证据：`.agents/tests/TestSupport.lua` 第 228-237 行。
- 观察：按“默认 no-op 通知器 + `GameplayLoop.set_game` 运行态桥接”实现后，不需要触碰其他 `ui_port` 依赖点即可保证兼容。
  证据：`src/game/game/CompositionRoot.lua` 注入 no-op；`src/game/turn/GameplayLoop.lua` 在 `set_game` 中桥接回调。
- 观察：新增两条测试后回归总数从 82 增长到 84，且全量通过。
  证据：`lua .agents/tests/regression.lua` 输出 `All regression checks passed (84)`。

## 决策日志

- 决策：按审查建议先做 `P1-01`，不同时推进其他 P1/P2。
  理由：先把“高层依赖低层 UI 细节”的硬耦合拆开，风险最低、收益最高。
  日期/作者：2026-02-10 / Codex
- 决策：采用“新抽象 + 兼容旧字段”的过渡策略。
  理由：减少改动面，避免一次性触及大量 `ui_port` 既有调用点。
  日期/作者：2026-02-10 / Codex
- 决策：默认通知器在组装层注入 no-op，实现层在 `GameState` 内按“notifier 优先、ui_port 兜底”分发。
  理由：先消除硬断言，再保持运行时兼容，避免影响已有玩法链路。
  日期/作者：2026-02-10 / Codex
- 决策：运行态桥接放在 `GameplayLoop.set_game`，仅当 `state` 暴露回调时覆盖默认通知器。
  理由：保证 app 流程仍触发地块 UI 更新，同时让无 UI 场景保持无副作用。
  日期/作者：2026-02-10 / Codex

## 结果与复盘

`P1-01` 已完成并通过回归。`GameState` 中地块归属更新不再依赖 `ui_port` 强断言：  
1) 无 UI 场景现在可以安全执行 `set_tile_owner/reset_tile`；  
2) 有 UI 的 app 路径通过 `GameplayLoop.set_game` 注入通知桥接，保持地块表现更新；  
3) 保留 `ui_port` 兜底兼容，避免本轮扩大改动面。

缺口与后续：

- 还未执行 P1-02（`GameplayLoop` 深度端口化）与 P1-03（`RuntimeContext` 环境解耦）。
- 当前 notifier 仍是轻量接口，后续可统一为更完整的 board observer。

失忆接力要点：截至 2026-02-10 17:21（本地时间）本任务仍处于“未提交代码”状态，工作树里有 5 个改动文件，分别是 `/.agents/PLAN_CURRENT.md`、`/.agents/tests/suites/gameplay.lua`、`src/game/game/CompositionRoot.lua`、`src/game/game/GameState.lua`、`src/game/turn/GameplayLoop.lua`。如果接手者看不到这 5 个文件改动，先执行 `git status --short` 校验上下文是否一致，再继续后续里程碑。

## 背景与导读

本计划基于一次已完成的热点深审。审查范围不是全仓 82 个 Lua 文件，而是近 10 次提交触达的 21 个热点文件，覆盖 `src/core`、`src/game`、`src/ui` 三层关键路径，目标是用 SRP/DIP/SOLID 识别结构性风险。审查时以当前 `main` 头部代码为准，并以回归可运行性作为约束（审查前后均要求 `lua .agents/tests/regression.lua` 可通过）。

这次审查的总体结论是“可运行但结构风险集中在跨层耦合”。P0 级问题未发现，但 P1 级问题有三项，且都属于高层依赖低层细节或职责边界混杂。第一项是 `GameState` 在 `set_tile_owner/reset_tile` 中直接断言并调用 `ui_port.on_tile_owner_changed`，使领域状态更新绑定 UI 细节，导致无 UI 场景会崩溃。第二项是 `GameplayLoop` 同时承担回合编排、UI 弹窗、动画触发、输入锁和运行态 wiring，流程策略与表现副作用混在同一模块，后续替换前端或做 headless 测试成本高。第三项是 `RuntimeContext.install_globals` 直接写入全局 `GameAPI/LuaAPI` 与多组导出函数，运行环境绑定和业务 helper 构建耦合，测试隔离与环境替换困难。

P2 级问题主要是中期技术债，数量多但不构成立即故障。`UIModel` 同时做数据投影与展示文案构建，造成“模型改动”和“文案改动”互相牵连；`TickTimeout` 的默认超时策略在无显式策略时直接选第一项，扩展新选择类型时容易误选；`UIModalPresenter` 把画布切换、choice/market 分支、状态写入和脏标记集中在单入口，幂等性脆弱；`UIRuntimePort` 通过全局 `client_role` 切换上下文，嵌套场景下恢复语义不够显式；`PaidCurrencyBridge` 使用模块级 `runtime_state` 保存游戏态和角色映射，跨局生命周期边界不清晰。

P3 级问题主要是可维护性和开放封闭性不足，不是立即阻断。`MarketView.refresh_market` 对槽位渲染逻辑有较多重复分支，布局或槽位数量调整时需要改主流程；`UIEventRouter` 路由节点名和槽位数量硬编码较多，新 UI 变体接入时需要改核心路由代码而不是仅改配置。

审查还给出了一组“候选接口调整清单”，用于后续分阶段整改：一是把 `UIRuntimePort` 拆成更小端口（角色上下文、节点查询、纹理设置），降低调用方依赖面；二是把 `RuntimeContext` 的环境绑定与编辑器导出职责分离；三是让 `GameplayLoop` 通过端口调用 UI/动画能力，缩小对具体实现的依赖；四是把 `CompositionRoot` 收敛为纯组装层，不承载运行时策略判断；五是把 `PaidCurrencyBridge` 从全局状态转成显式实例上下文。

为什么本轮只执行 `P1-01`：因为它改动切口最小、风险最低、收益最直接，能先解除“无 UI 崩溃”这一高概率问题，同时保留兼容路径，不打断现有玩法链路。`P1-02` 与 `P1-03` 仍保留在后续迭代，不在本次提交范围内。

失忆后续做法：接手者不要重复改 `P1-01`，应直接从里程碑 M2 开始。M2 的起点是把 `GameplayLoop` 中 `ui_view`、`move_anim`、`tick_timeout` 的直接调用抽成端口依赖，先实现最小端口壳并保持现有行为，再逐段迁移调用点。M2 结束时必须做到“回合逻辑可在无 UI 端口下跑通”，否则禁止推进到 M3。

## 工作计划

先在 `GameState` 增加“地块归属通知器”抽象，默认允许 no-op，从而移除 `ui_port` 硬断言。然后在组装/运行入口把 UI 回调桥接到新抽象，保持现有视觉行为不变。最后补充两类测试：一类验证无 UI 时不崩溃，一类验证注入通知器可正确收到 owner 变更事件。全过程保持兼容旧 `ui_port` 路径，避免影响其他模块。

## 具体步骤

工作目录：`/Users/billyq/Dev/Github/Lua/monopoly`

1. 修改 `src/game/game/GameState.lua`  
   引入 `_notify_tile_owner_changed`，优先使用 `self.tile_owner_notifier`，兼容 `self.ui_port`，并移除 `missing ui_port` 强断言。

2. 修改 `src/game/game/CompositionRoot.lua` 或等效组装点  
   给新建 game 注入默认 no-op `tile_owner_notifier`，保证无 UI 场景稳定。

3. 修改 `src/game/turn/GameplayLoop.lua`（组装 UI 运行态）  
   在 `set_game` 中把 UI 状态对象桥接到 `tile_owner_notifier`，确保 UI 回调持续生效。

4. 修改 `.agents/tests/suites/gameplay.lua`  
   增加 `P1-01` 回归测试：  
   - 无 `ui_port` 时调用 `set_tile_owner/reset_tile` 不崩溃且状态正确。  
   - 注入 `tile_owner_notifier` 时能收到 owner 变更通知。

5. 执行并记录：  
   `lua .agents/tests/regression.lua`

如果出现失忆或上下文丢失，先按下面顺序恢复执行环境。先运行 `git status --short`，确认仍是这 5 个文件改动；再运行 `lua .agents/tests/regression.lua`，确认基线仍为 `All regression checks passed (84)`；最后再从 M2 开始编码。若基线不是 84，先排查是否有额外未记录改动，再决定是否继续。

## 验证与验收

验收标准：

- `GameState` 不再因缺失 `ui_port` 在地块归属更新处崩溃。
- 默认路径（有 UI）仍能收到地块归属通知。
- 新增测试稳定通过。
- 全量回归通过（本次为 `84` 项）。

## 可重复性与恢复

改造步骤可重复执行。若出现兼容问题，可先回退到“仅保留旧 `ui_port` 路径”并保留新增测试作为保护，再逐步重新引入通知器。该路径可通过文件级回滚恢复。

失忆恢复命令基线：只在确认需要回退时执行 `git checkout -- src/game/game/GameState.lua src/game/game/CompositionRoot.lua src/game/turn/GameplayLoop.lua .agents/tests/suites/gameplay.lua` 回到改造前代码；若只想回退计划文档，再单独执行 `git checkout -- .agents/PLAN_CURRENT.md`。任何回退后都要重新执行 `lua .agents/tests/regression.lua`，并把结果重新写入本计划的“进度”和“结果与复盘”。

## 产物与备注

计划产物：

- 一条可执行的 P1 修复路径（代码 + 测试 + 回归证据）。
- 审查结论正式入库到当前可执行计划，便于后续继续执行 P1/P2。

## 接口与依赖

本轮新增/调整接口（计划目标）：

- `game.tile_owner_notifier`：支持 `notify_owner_changed(tile_id, owner_id)` 的通知抽象（默认 no-op）。
- `GameState` 的 `set_tile_owner/reset_tile` 改为依赖通知抽象，不再硬依赖 `ui_port`。

保持不变：

- 其他 `ui_port` 行为（如 `push_popup`、`wait_action_anim`）暂不改动。
- 回合流程与玩法逻辑不变。

计划更新说明（2026-02-10）：按“先写入审查结果，再执行到 P1-01”要求，重写当前计划，纳入审查结论并锁定本轮最小改造范围。
计划更新说明（2026-02-10）：完成 `P1-01` 代码与测试落地，回填回归结果（84 通过）与复盘结论。
