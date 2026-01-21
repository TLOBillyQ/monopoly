# 适配层代码架构审查（2026-01-21）

## 审查范围
- 实际目录为 `src/adapters/`（仓库内不存在 `src/adapter/`）。
- 涉及模块：`src/adapters/core`、`src/adapters/eggy`、`src/adapters/love2d`、`src/adapters/oasis`。

## 目标与结论摘要
适配层已完成核心逻辑抽取，但平台层仍存在大量重复实现与依赖方向不清的问题，导致维护成本高、行为一致性风险上升。当前最需要优先确认的是 Eggy 的视图模型与渲染路径是否一致，否则 UI 可能依赖隐含数据而难以维护。

## 现状结构概览
- 共享核心：`src/adapters/core/adapter_layer.lua`
  - 处理 `need_choice` 监听、自动运行驱动、选择超时、道具索引构建。
- 平台层：
  - Eggy：`src/adapters/eggy/eggy_layer.lua` + `src/adapters/eggy/eggy_runtime.lua`
  - Love2D：`src/adapters/love2d/love_layer.lua` + `src/adapters/love2d/love_runtime.lua`
  - Oasis：`src/adapters/oasis/oasis_layer.lua` + `src/adapters/oasis/oasis_runtime.lua`
- UI 状态与呈现：
  - Eggy：`src/adapters/eggy/ui_state.lua` + `src/adapters/eggy/presenter.lua`
  - Love2D：`src/adapters/love2d/ui_state.lua` + `src/adapters/love2d/presenter.lua`
  - Oasis：`src/adapters/oasis/ui_state.lua` + `src/adapters/oasis/ui_bridge.lua`（Presenter 复用 Love2D）

## 主要发现（按严重程度）

### 高：Eggy 视图模型与渲染读取字段不一致
- `src/adapters/eggy/presenter.lua` 仅返回 `current_player_name`、`current_player_cash`、`turn_count` 等派生字段，没有返回 `state` 或 `board`。
- `src/adapters/eggy/eggy_layer.lua` 的 `refresh_panel/refresh_tile_detail/refresh_board` 使用 `view.state` 和 `view.board`。
- 结果是 Eggy 的 UI 渲染路径依赖字段不对齐，后续维护或扩展时容易出现“数据为空但无明显报错”的问题。

### 高：Eggy 与 Oasis 层重复逻辑过多，风险是分叉而非复用
- 两个文件 `src/adapters/eggy/eggy_layer.lua` 与 `src/adapters/oasis/oasis_layer.lua` 有大段同构代码：
  - `build_phase_label`、`join_lines`、`map_vehicle_names`、`build_phase_title`
  - `_open_choice_modal`、`refresh_panel`、`refresh_tile_detail`、`refresh_board`
  - `tick`、`dispatch_action` 等流程
- 同构逻辑现在通过复制实现，未来修复或新增功能时必须多处同步，容易出现平台行为不一致。

### 中：跨平台依赖方向不清晰
- Eggy 与 Oasis 依赖 `src/adapters/love2d/auto_runner.lua`，Oasis 还复用 `src/adapters/love2d/presenter.lua`。
- 这会让“Love2D 只是平台实现”变成“平台通用模块”，导致依赖关系反转、命名误导、迁移困难。

### 中：IntentDispatcher 监听器注册不可撤销
- `src/adapters/core/adapter_layer.lua` 在 `attach` 中调用 `IntentDispatcher.on`，`src/util/intent_dispatcher.lua` 没有取消或去重机制。
- 如果多次创建适配层或热重载，监听器会累积并触发多次回调，造成重复弹窗或重复派发。

### 中：`game.ui_port` 绑定生命周期不清晰
- `AdapterLayer.set_game` 会将 `game.ui_port = layer`，但没有清理或显式生命周期。
- 若多个适配层并存，或存在重建 `game` 的场景，会出现最后一次赋值覆盖，且旧 layer 仍可能接收 `IntentDispatcher` 的回调。

### 低：适配层接口契约没有被正式固化
- `adapter_layer.lua` 依赖 `ui:set_label/set_button/set_visible/set_touch_enabled`，但未有文档说明或运行时校验。
- 目前靠“隐式约定”保证，新增平台时容易遗漏或误配。

## 建议与优先级（不改变既有行为的前提下）

1) 优先确认 Eggy 视图数据路径
- 方案 A：让 `src/adapters/eggy/presenter.lua` 返回 `state = store_state`、`board`（对齐 Love2D 结构）。
- 方案 B：让 `EggyLayer:refresh_panel` 等直接使用 `view.current_player_*` 等已存在字段。
- 两者任选其一，但必须收敛到单一视图模型，避免“Presenter 产物没人使用”。

2) 提取 Eggy 与 Oasis 共用的 UI 构建逻辑到共享模块
- 目标：减少重复、保持行为一致。
- 可考虑放到 `src/adapters/core/` 下的 `choice_modal.lua`、`panel_view.lua` 等最小模块，或在 `adapter_layer.lua` 中扩展可复用函数。
- 该改动满足“≥2 真实调用点”的抽象条件，且符合当前重复度。

3) 下沉 AutoRunner / Presenter 到平台无关位置
- 将 `auto_runner.lua` 移到 `src/adapters/core/` 或 `src/util/`，名称改为通用。
- Presenter 若为平台无关（目前 Love2D 仅使用配置与 board overlays），也可迁移到共享位置，避免 Oasis 依赖 Love2D 路径。

4) 给 IntentDispatcher 监听增加去重或解绑能力
- 若明确只会单实例，可在 `AdapterLayer.attach` 里加一次性防护。
- 若未来有多实例或热重载，应提供 `off`/`reset` 能力。

5) 补充适配层接口契约说明
- 在 `docs/` 或 `src/adapters/core/adapter_layer.lua` 顶部说明 `ui` 与 `layer` 需要实现的方法，降低新增平台成本。

## 风险评估
- 维持现状：重复逻辑持续分叉、跨平台依赖混乱、潜在 UI 状态不一致。
- 小步改进：只要保持行为一致并分阶段抽取，风险可控。

## 需要确认的问题
- Eggy 端的 UI 是否实际依赖 `view.state`/`view.board`？若依赖则 Presenter 需要补齐字段；若不依赖则应删除无效路径，避免误导。
- 是否存在多适配层并行运行或热重载场景？若有，需要处理 IntentDispatcher 监听器的生命周期。
