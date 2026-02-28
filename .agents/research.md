# Monopoly 项目重写研究：Canvas-First UI + 协程化逻辑层

更新时间：2026-02-28  
范围：`src/presentation/**`、`src/game/**`、`src/app/bootstrap/**`

---

## 1. 结论摘要

1. 项目已经完成了第一阶段的 Canvas-First 迁移，但仍是“结构先行、运行时未完全收敛”状态。
2. UI 层核心问题不是“有没有 canvas 目录”，而是“状态与事件仍在多处并行维护”，导致选择屏、弹窗、输入锁、倒计时存在跨模块时序耦合。
3. 逻辑层当前是显式状态机（`wait_choice`/`wait_move_anim`/`wait_action_anim` + `resume_state/resume_args`）实现，功能可用但复杂度高、错误面大。
4. 若目标是长期稳定扩展，推荐进行“协程化回合脚本内核”重写：把等待点从“字符串状态跳转”改为“`yield/await` 语义”。
5. 推荐策略：先建协程运行时骨架并保持外部接口不变，再按阶段切流，避免一次性推翻。

---

## 2. 现状深度分析

## 2.1 代码规模与模块分布

1. `src/presentation`：101 个 Lua 文件，约 6455 行。
2. `src/game`：96 个 Lua 文件，约 9558 行。
3. 回归测试主入口：`tests/regression.lua`，当前聚合 19 个 suite。

这个规模已经超过“轻量脚本堆叠”边界，进入“需要明确运行时架构约束”的阶段。

## 2.2 启动与运行拓扑

关键链路：

1. `main.lua` -> `src/app/init.lua`
2. `GameStartup` 构建运行态 state（同时承载 UI state + gameplay loop state）
3. `UIBootstrap` 在 `GAME_INIT` 绑定 UI 节点并启动 runtime
4. `GameRuntimeBootstrap` 用 `SetFrameOut` 驱动 `GameplayLoop.tick(...)`

观察：

1. `state` 是“全局大状态对象”，同时被 UI、输入、动画、倒计时、回合流使用。
2. 这让 UI 与逻辑存在隐式共享状态通道，调试时难界定状态所有权。

## 2.3 UI 层：Canvas-First 已落地一半

已完成部分：

1. 存在 `src/presentation/canvas/*` 与 `src/presentation/canvas_runtime/*`。
2. 节点已按 canvas 拆分，例如 `canvas/base/nodes.lua`、`canvas/always_show/nodes.lua`。
3. 事件路由统一从 `UIEventRouter` 委托到 `CanvasEventRouter`。

未完成/风险点：

1. `CanvasRegistry` 仍直接引用 `interaction/intent_builders/*`，说明意图层仍是“旧聚合”模式。
2. `UIViewService` 仍同时编排 `render/*`、`ui/*`、`canvas/*`，属于混合 orchestrator。
3. 兼容入口 `shared/UINodes.lua` 仍被广泛使用（历史包袱未清空）。
4. modal/choice/popup 状态分散在：
   - `state.ui`（`choice_active/market_active/popup_active`）
   - `state.pending_choice_*`
   - `game.turn.pending_choice`
5. `UISyncPorts.refresh_from_dirty` 在“模型更新 -> UI 刷新 -> 打开 choice modal”链路里同时做相机跟随、输入锁、UI 渲染，职责过重。

结论：目录形态是 Canvas-First，但运行时仍是“中心化服务 + 多处状态并写”。

## 2.4 逻辑层：显式状态机复杂度偏高

当前核心：

1. `src/core/Flow.lua` 负责字符串状态推进。
2. `TurnFlow` 维护 `wait_choice`/`wait_move_anim`/`wait_action_anim`/`detained_wait`。
3. 各 phase 通过返回 `next_state + resume_args` 手动串接。

主要复杂性来源：

1. 业务 phase 中大量 `resume_state/resume_args` 传递（`TurnStart/Roll/Move/Land`）。
2. 动画等待依赖“外部 action done 事件 + seq 对齐”。
3. choice 等待依赖 `pending_action`、auto policy、validator、resolver 多模块协作。
4. timeout 逻辑独立在 `TickTimeout`，再通过 `GameplayLoop` 拼接。
5. 没有使用 Lua 协程（全仓 `coroutine.*` 命中为 0），意味着“等待语义”全部由显式状态字符串编码。

直接后果：

1. 新增等待点成本高，容易遗漏恢复参数。
2. 时序 bug（重复弹窗、等待卡死、错误回落）更容易发生。
3. 代码可读性下降，业务逻辑被状态跳转噪音淹没。

---

## 3. 重写目标

## 3.1 UI：Canvas-First Runtime 2.0

目标：

1. 每个 canvas 形成“节点 + 状态 slice + 意图 + 渲染 + 触控”闭环。
2. 跨 canvas 交互只通过 `canvas_runtime` 的显式接口。
3. `UIViewService` 降级为薄适配，不再承担业务编排。
4. 去除 `shared/UINodes.lua` 兼容依赖，改为生成式 node contract。

## 3.2 逻辑：协程化回合内核

目标：

1. 回合流程改为“单协程脚本 + await 原语”。
2. 等待点由 `yield` 表达，而非手写 `wait_*` 字符串。
3. 保持对外接口不变：
   - `game:advance_turn()`
   - `game:dispatch_action(action)`
4. 对 UI 暴露稳定事件契约（choice/popup/anim/timer），减少双向耦合。

---

## 4. 目标架构设计

## 4.1 UI 目标架构（Canvas-First）

建议目录：

```text
src/presentation/canvas/<canvas_key>/
  nodes.lua
  contract.lua
  state.lua
  intents.lua
  presenter.lua
  touch_policy.lua

src/presentation/canvas_runtime/
  CanvasRegistry.lua
  CanvasStore.lua
  CanvasCoordinator.lua
  CanvasEventRouter.lua
  CanvasRenderPipeline.lua
  LocalActorResolver.lua
```

核心设计：

1. `CanvasStore` 统一管理 `ui.canvas_state.<canvas_key>`，禁止 canvas 直接写其他 canvas 状态。
2. `CanvasRenderPipeline` 以 dirty-slice 驱动，避免全量 render。
3. `CanvasEventRouter` 仅分发事件，不做业务判定。
4. `route_key` 成为唯一选择屏路由输入；未知路由默认 `base_inline`。
5. 建立节点契约生成脚本（从 `Data/UIManagerNodes.lua` 生成），替代手写字符串散落。

## 4.2 逻辑目标架构（协程内核）

建议目录：

```text
src/game/runtime_coroutine/
  Scheduler.lua
  TurnScript.lua
  Await.lua
  Signals.lua
  Session.lua
  ActionRouter.lua
  CompatBridge.lua
```

核心对象：

1. `TurnScript`：每位当前玩家回合对应一个 coroutine。
2. `Scheduler`：在 tick 中推进 coroutine，处理 signal/timeout。
3. `Await`：统一等待原语。
4. `Signals`：事件总线（choice resolved、anim done、timer elapsed、external interrupt）。

Await 原语建议：

1. `await.choice(spec)`：发起选择并等待结果。
2. `await.action_anim(payload)`：播放动作动画并等待完成。
3. `await.move_anim(payload)`：播放移动动画并等待完成。
4. `await.seconds(sec, opts)`：等待时长（可取消）。
5. `await.until(predicate, opts)`：条件等待。

示意（伪代码）：

```lua
function turn_script.run(ctx)
  local player = ctx:current_player()
  if player.eliminated then
    return ctx:end_turn()
  end

  await.item_phase("pre_action", player)
  local roll = await.roll(player)
  await.item_phase("pre_move", player)
  local move_res = await.move(player, roll)
  await.resolve_landing(player, move_res)
  await.item_phase("post_action", player)
  ctx:end_turn()
end
```

结果：

1. `resume_state/resume_args` 消失。
2. `wait_choice/wait_action_anim/wait_move_anim` 作为实现细节下沉到 Scheduler，不暴露给业务 phase。

---

## 5. 分阶段重写路线（可执行）

## Phase 0：冻结基线与契约

1. 冻结当前回归基线（`tests/regression.lua`）。
2. 新增协程重写验收集：
   - 事件顺序
   - choice owner 校验
   - 动画等待语义
3. 新增依赖规则：禁止新代码继续扩散 `interaction/intent_builders/*`。

交付物：

1. `docs/architecture/rewrite_canvas_coroutine.md`
2. 测试护栏脚本。

## Phase 1：引入协程运行时骨架（不切流）

1. 新建 `runtime_coroutine/*` 空实现。
2. `CompatBridge` 把协程输出映射为当前 `game.turn` 结构（只镜像，不主导）。
3. 保持 `TurnFlow` 仍为主路径。

验收：

1. 全回归通过。
2. 新增协程骨架测试通过。

## Phase 2：先切等待点，再切 phase 业务

顺序：

1. `wait_action_anim` -> 协程 await。
2. `wait_move_anim` -> 协程 await。
3. `wait_choice` -> 协程 await。
4. timeout/auto 决策接入 scheduler signal。

策略：

1. 每次只替换一个等待类型。
2. 通过 feature flag 切换（例如 `runtime_constants.experimental_coroutine_turn = true`）。

## Phase 3：UI Canvas Runtime 2.0 切流

1. 引入 `CanvasStore` + `CanvasRenderPipeline`。
2. 把 `intent_builders` 分批迁移到 canvas intents。
3. `UIViewService` 去中心化，只保留 API 适配。
4. 删除 `shared/UINodes` 兼容映射。

## Phase 4：删除旧状态机路径

1. 移除 `src/core/Flow.lua` 在 turn 主流程中的依赖。
2. 旧 `TurnFlow` 退化为兼容层或直接移除。
3. 清理 `resume_state/resume_args` 相关字段与分支。

## Phase 5：性能与可维护性收尾

1. coroutine 生命周期监控（泄漏检测、挂起统计、超时告警）。
2. UI 渲染 dirty 统计与压测。
3. 文档与新开发模板完善。

---

## 6. 风险与缓解

1. 风险：事件顺序变更导致行为回归。  
   缓解：建立事件快照测试，对比旧内核输出序列。

2. 风险：协程泄漏或挂死。  
   缓解：Scheduler 强制超时与状态诊断日志（coroutine id、await 类型、等待时长）。

3. 风险：UI 状态双写窗口期产生闪烁。  
   缓解：切流期间采用“新 store 主写、旧字段只读镜像”。

4. 风险：自动托管与手动输入竞争。  
   缓解：ActionRouter 统一仲裁，建立优先级（人工输入 > 系统超时 > auto）。

---

## 7. 验收标准（重写完成定义）

1. UI：
   - 不再依赖 `shared/UINodes` 兼容层。
   - 每个 canvas 有独立 state/intents/presenter。
   - 选择屏路由只由 `route_key` 决定，无隐式 fallback。

2. 逻辑：
   - 回合主流程由 coroutine 驱动。
   - 不再出现 `resume_state/resume_args` 业务传递。
   - `wait_*` 状态不再暴露为业务 phase 的直接跳转目标。

3. 质量：
   - `lua tests/regression.lua` 全绿。
   - 新增协程回归套件全绿。
   - 关键路径日志可追踪（choice、anim、timeout、auto）。

---

## 8. 立即执行建议（下一步）

1. 先做一个最小 POC：仅把 `wait_choice` 改为 `await.choice`，其他保持不变。
2. 同时落地 `CanvasStore`，先接入 `base` + `always_show` 两个 canvas。
3. 在 POC 阶段加一个运行时开关，允许一键回退旧 TurnFlow。
4. POC 通过后再扩到 `move/land/item_phase`，避免大爆炸改造。

