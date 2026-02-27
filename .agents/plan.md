# Presentation 层纯 Canvas-First 重设计计划（可执行）

更新时间：2026-02-27  
适用范围：`src/presentation/**`  
目标：将当前“共享节点 + 功能分层”重构为“按 Canvas 组织的垂直切片架构”，并彻底消除跨 canvas 的隐式耦合。


## 1. 设计目标

1. 以 `canvas` 作为 Presentation 层第一维组织单位。
2. 每个 canvas 自治：节点定义、事件路由、渲染、触控策略、可见性策略都在本 canvas 模块内闭环。
3. 上层只通过统一调度器操作 canvas，不再直接拼接各功能模块。
4. 本地玩家身份在运行期固定（session 级），不依赖点击瞬时 `UIManager.client_role`。
5. 保持现有玩法行为不回归（回归用例全绿）。


## 2. 非目标

1. 不改玩法规则（`src/game/**`）业务语义。
2. 不改 UIManager 第三方库实现（`vendor/third_party/UIManager/**`）。
3. 不做美术节点重命名（除已存在迁移约定外）。


## 3. 目标架构（落地形态）

新增目录（核心）：

```text
src/presentation/canvas/
  base/
    contract.lua
    nodes.lua
    intents.lua
    presenter.lua
    touch_policy.lua
  always_show/
    contract.lua
    nodes.lua
    intents.lua
    presenter.lua
    touch_policy.lua
  player_choice/
  target_choice/
  remote_choice/
  building_choice/
  market/
  popup/
  bankruptcy/
  dice/
  loading/
  debug/
src/presentation/canvas_runtime/
  CanvasRegistry.lua
  CanvasState.lua
  CanvasEventRouter.lua
  CanvasCoordinator.lua
  LocalActorResolver.lua
```

核心约束：

1. `nodes.action_log` 并入 `always_show`（不再保留全局功能组）。
2. 除 `canvas_runtime/*` 与 canvas 自身模块外，禁止直接引用其他 canvas 的节点常量。
3. 事件路由按 canvas 注册，不再由单一 `UIEventRouter` 聚合硬编码 builders。
4. `auto`/`action_log` 等全局按钮走 `LocalActorResolver` 的固定本地 actor。


## 4. 迁移策略

采用“兼容层 + 分阶段切流”：

1. 先引入新架构与适配层，不立即删除旧接口。
2. 每个里程碑完成后切换一批调用点到新模块。
3. 最后统一删除旧路径与兼容代码。


## 5. 里程碑与执行清单

## M0：基线冻结与约束护栏

改动：

1. 新增 `docs/architecture/presentation_canvas_first.md`（架构约束说明）。
2. 在 `tests/internal/dep_rules.lua` 增加规则：
   - 禁止新代码新增 `src/presentation/shared/UINodes.lua` 的旧分层访问模式。
   - 禁止 canvas 模块之间跨目录直接 `require`（仅允许经 `canvas_runtime`）。

验收：

1. `lua tests/internal/dep_rules.lua` 通过。
2. `lua tests/regression.lua` 通过（基线确认）。


## M1：建立 Canvas Runtime 骨架

改动文件（新增）：

1. `src/presentation/canvas_runtime/CanvasRegistry.lua`
2. `src/presentation/canvas_runtime/CanvasState.lua`
3. `src/presentation/canvas_runtime/CanvasEventRouter.lua`
4. `src/presentation/canvas_runtime/CanvasCoordinator.lua`
5. `src/presentation/canvas_runtime/LocalActorResolver.lua`

改动文件（接入）：

1. `src/presentation/api/UIViewService.lua`
2. `src/presentation/interaction/UIEventRouter.lua`（改为委托到 `CanvasEventRouter`，先保留旧逻辑 fallback）
3. `src/app/bootstrap/UIBootstrap.lua`

验收：

1. 老功能不变，事件仍可触发。
2. 回归全绿。


## M2：节点定义彻底 Canvas 化

改动：

1. 为每个 canvas 新增 `nodes.lua` 与 `contract.lua`。
2. `action_log` 逻辑并入 `always_show`：
   - `always_show.nodes.action_log_button`
   - `always_show.nodes.action_log_label`
   - `always_show.contract.toggle_targets`
3. `src/presentation/shared/UINodes.lua` 降级为只读兼容映射（deprecated），内部转发到各 canvas `nodes.lua`。

验收：

1. 旧调用仍可运行（通过兼容映射）。
2. 新代码全部通过 canvas 节点文件取值。


## M3：交互层按 Canvas 切片

改动：

1. 将 `intent_builders/*` 拆到各 canvas `intents.lua`。
2. `UIEventBindings.lua` 仅保留通用绑定能力，不再持有业务节点名。
3. `UIIntentDispatcher.lua`：
   - `auto` 意图优先使用 `intent.actor_role_id`
   - 缺失时使用 `LocalActorResolver` 固定本地 actor
   - 不再因 `UIManager.client_role=nil` 吞事件
4. `ActionLogIntents.lua` 迁移到 `always_show/intents.lua`。

验收：

1. 托管按钮支持高频连续切换。
2. `toggle_action_log` 行为无回归。


## M4：渲染层按 Canvas 切片

改动：

1. 将以下能力迁移到对应 canvas presenter：
   - 基础信息渲染（当前 `UIPanelPresenter.lua`）
   - 选择弹窗开闭（`choice_screen_service/*`）
   - 卡牌/破产弹窗（`PopupRenderer.lua`）
   - 黑市展示（`MarketModalRenderer.lua`）
2. `UIModalPresenter.lua` 改为 orchestrator（只调 canvas presenter）。
3. `UICanvasCoordinator.lua` 只保留“显示/隐藏 canvas”通用能力。

验收：

1. 所有 modal/canvas 切换路径一致。
2. 回归全绿。


## M5：状态构建层按 Canvas 切片

改动：

1. `api/ui_view_service/*` 拆分为：
   - `canvas_runtime/CanvasState.lua`（统一 state 容器）
   - 各 canvas `presenter.lua` 的 state slice 读写
2. `state.ui` 内字段改成 `ui.canvas_state.<canvas_key>.*`。
3. 移除旧 `choice_screens/popup_screen/bankruptcy_screen` 平铺结构，提供兼容 getter（短期）。

验收：

1. `ui` 状态字段来源可追踪到单一 canvas。
2. 不再在 service 层组装跨 canvas 结构体。


## M6：删除兼容层与旧入口

改动：

1. 删除/清空旧模块逻辑（保留空壳导出或直接移除）：
   - `interaction/intent_builders/*`（若已全部迁移）
   - `shared/UINodes.lua` 中 deprecated 映射
   - `UIEventRouter` 中旧聚合 route 逻辑
2. 清理旧测试假设（旧节点名、旧路径、旧行为）。

验收：

1. `rg` 检索无旧路径残留（见“最终验收”）。
2. 回归全绿。


## M7：文档与交付

改动：

1. 更新 `README.md` 的 presentation 架构说明。
2. 更新 `docs/architecture/presentation_canvas_first.md`（最终版）。
3. 增加“新增 canvas 的开发模板/步骤”。

验收：

1. 新增一个示例 canvas 能按模板独立接入。


## 6. 关键实现规则（必须遵守）

1. Canvas 模块之间禁止直接读对方节点常量。
2. 事件 actor 解析统一走 `LocalActorResolver`，不得在业务层临时读取 `UIManager.client_role` 做最终裁决。
3. `UIRuntimePort` 保持基础能力，业务决策不放入 runtime。
4. 每个里程碑完成后必须跑全量回归。


## 7. 最终验收标准

命令：

```bash
lua tests/internal/dep_rules.lua
lua tests/regression.lua
```

残留搜索（预期 0 匹配）：

```bash
rg "ui_nodes\\.action_log"
rg "intent_builders"
rg "choice_screens|popup_screen|bankruptcy_screen" src/presentation/api/ui_view_service
rg "UIManager\\.client_role" src/presentation/interaction
```

行为验收（人工）：

1. 托管按钮连续快速点击可稳定开关。
2. 行动日志开关只作用当前本地客户端玩家。
3. 各 modal/canvas 切换无串屏、无卡死。


## 8. 执行顺序建议

`M0 -> M1 -> M2 -> M3 -> M4 -> M5 -> M6 -> M7`

每个里程碑单独提交，建议 commit 粒度：

1. `refactor(presentation): canvas-runtime scaffold`
2. `refactor(presentation): canvas nodes/contracts`
3. `refactor(interaction): canvas intents and actor resolver`
4. `refactor(ui): canvas presenters and modal orchestration`
5. `refactor(state): canvas state slices`
6. `chore(presentation): remove legacy compatibility`
7. `docs(presentation): canvas-first architecture`
