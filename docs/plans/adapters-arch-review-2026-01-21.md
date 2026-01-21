# 适配层代码架构审查（2026-01-21，基于当前代码）

## 审查范围
- 实际目录为 `src/adapters/`（仓库内不存在 `src/adapter/`）。
- 涉及模块：`src/adapters/core`、`src/adapters/eggy`、`src/adapters/love2d`、`src/adapters/oasis`。

## 目标与结论摘要
适配层的核心视图模型已统一到 `src/adapters/core/presenter.lua`，Eggy/Love2D/Oasis 的视图字段现在一致，之前的“Eggy UI 读不到 view.state/board”问题已解决。当前主要风险仍是平台层重复逻辑与跨平台依赖方向不清晰，同时 Eggy 侧的 UIManager/ChooseOption 依赖未落库，导致三选一黑市界面只能在外部资源补齐后验证。

## 现状结构概览
- 共享核心：
  - `src/adapters/core/adapter_layer.lua`：need_choice 监听、自动运行驱动、选择超时、道具索引构建。
  - `src/adapters/core/presenter.lua`：统一 view 结构（`state`、`board.tiles`、`board.overlays`、当前玩家派生字段）。
- 平台层：
  - Eggy：`src/adapters/eggy/eggy_layer.lua` + `src/adapters/eggy/eggy_runtime.lua`
  - Love2D：`src/adapters/love2d/love_layer.lua` + `src/adapters/love2d/love_runtime.lua`
  - Oasis：`src/adapters/oasis/oasis_layer.lua` + `src/adapters/oasis/oasis_runtime.lua`
- UI 状态与呈现：
  - Eggy：`src/adapters/eggy/ui_state.lua` + `src/adapters/eggy/market_ui.lua`
  - Love2D：`src/adapters/love2d/ui_state.lua`
  - Oasis：`src/adapters/oasis/ui_state.lua` + `src/adapters/oasis/ui_bridge.lua`

## 主要发现（按严重程度）

### 高：Eggy 与 Oasis 仍大量复制实现，行为一致性风险高
- `src/adapters/eggy/eggy_layer.lua` 与 `src/adapters/oasis/oasis_layer.lua` 仍存在大段同构代码：
  - `build_phase_label`、`join_lines`、`build_phase_title`
  - `_open_choice_modal`、`refresh_panel`、`refresh_tile_detail`、`refresh_board`
  - `tick`、`dispatch_action` 等主流程
- 目前通过复制实现，未来修复/新增功能时需要多处同步，容易出现平台行为分叉。

### 中：跨平台依赖方向仍不清晰
- Eggy 与 Oasis 仍依赖 `src/adapters/love2d/auto_runner.lua`。
- Presenter 已迁入 core 解决了视图模型依赖方向，但 AutoRunner 仍挂在 Love2D 路径，命名与依赖方向不够清晰。

### 中：IntentDispatcher 监听器不可撤销
- `src/adapters/core/adapter_layer.lua` 在 `attach` 中调用 `IntentDispatcher.on`，但 `src/util/intent_dispatcher.lua` 没有解绑机制。
- 多实例或热重载时会出现重复回调与重复弹窗风险。

### 中：Eggy UIManager/ChooseOption 依赖未入库，功能无法在本仓库验证
- `src/adapters/eggy/ui_state.lua` 和 `src/adapters/eggy/eggy_runtime.lua` 已接入 UIManager/ChooseOption 的可选加载路径，但 `docs/eggy/lib` 为空，`src/adapters/eggy/ui_nodes.lua` 未提供。
- 现有逻辑会回退 LuaAPI 与原弹窗，不会直接报错，但 Eggy 侧黑市三选一 UI 无法在仓库内验证。

### 低：适配层接口契约未固化
- `adapter_layer.lua` 依赖 `ui:set_label/set_button/set_visible/set_touch_enabled` 等方法，但没有文档或校验。
- 新平台接入时仍需要口口相传，易漏字段或拼写错误。

## 建议与优先级（不改变既有行为的前提下）

1) 优先处理 Eggy/Oasis 重复逻辑抽取
- 目标：减少复制、保持行为一致。
- 可考虑拆出 `choice_modal.lua`、`panel_view.lua` 等最小模块，放入 `src/adapters/core/`。
- 该抽取有 ≥2 真实调用点，符合抽象条件。

2) 明确 AutoRunner 归属
- 将 `auto_runner.lua` 迁移到 `src/adapters/core/` 或 `src/util/`，保持功能不变但路径更合理。

3) 明确 Eggy UI 依赖交付物
- 需要提供 `src/adapters/eggy/ui_nodes.lua`（Eggitor 导出数据）。
- 需要补齐 UIManager/ChooseOption 运行时代码（放入 Lua 运行路径）。
- 需要填写 `src/adapters/eggy/market_ui.lua` 的容器与事件名，避免默认回退。

4) 补充适配层接口契约说明
- 在 `docs/` 或 `adapter_layer.lua` 顶部写明 UIState 与 Layer 的必要接口和期望字段。

5) 为 IntentDispatcher 增加去重或解绑策略
- 若只允许单实例，`AdapterLayer.attach` 可以加一次性防护。
- 若可能热重载，建议提供 `off`/`reset` 能力。

## 风险评估
- 维持现状：平台逻辑持续分叉、跨平台依赖路径混乱、Eggy UI 运行时功能难以验证。
- 小步改进：只要保持行为一致并分阶段抽取，风险可控。

## 需要确认的问题
- Eggy 侧是否已经具备 UIManager/ChooseOption 的运行时文件与 UI 节点导出数据？若无，三选一黑市 UI 只能走回退路径。
- 是否存在多适配层并行运行或热重载场景？若有，需要处理 IntentDispatcher 监听生命周期。
