# 适配层设计与实现（开发指南）

本文面向适配维护者，说明本仓库适配层的结构、数据流、关键函数与 Eggy 细节。内容以函数级别为主，便于直接定位代码。

## 1. 适配层的目标与边界

适配层负责把“规则层/回合推进”产出的状态与动作，映射到具体平台的 UI、输入与平台 API。它不改规则，只做展示与事件转发。

核心边界：
- **规则/状态**：`src/game.lua` + `src/gameplay/*` + `src/core/*`
- **适配/UI**：`src/adapters/*`
- **平台入口**：`src/entry.lua` 选择平台并安装对应 runtime

## 2. 入口与平台选择

文件：`src/entry.lua`

关键函数：
- `Entry.run(opts)`：根据环境决定平台并安装适配层。
- `resolve_platform(opts)`：依据 CLI、环境变量与运行环境判定平台（eggy/headless）。

平台分支：
- `eggy`：`src/adapters/eggy/eggy_runtime.lua`
- `headless`：纯逻辑跑 AI，用于回归和验证

## 3. 通用适配层骨架（AdapterLayer）

文件：`src/adapters/core/adapter_layer.lua`

适配层共用逻辑集中在 `AdapterLayer`，所有平台的 Layer 都会调用它。

核心函数：
- `AdapterLayer.attach(layer, opts)`
  - 绑定 `ui`、`game_factory`、`auto_runner`。
  - 监听 `IntentDispatcher` 的 `need_choice` 事件并写入 `layer.pending_choice`。
- `AdapterLayer.set_game(layer, game, opts)`
  - 设置当前 `game` 并把 `game.ui_port` 指向 `layer`（供规则层回调）。
  - 检查是否已有 `pending_choice` 并回调 `opts.on_pending_choice`。
- `AdapterLayer.new_game(layer, opts)`
  - 清理日志、创建新 Game、初始化物品索引、重置自动运行定时器。
- `AdapterLayer.step_auto_runner(layer, dt, context)`
  - 根据 `AutoRunner` 输出自动动作（通常是 `ui_button next`）。
- `AdapterLayer.step_choice_timeout(layer, dt, opts)`
  - 若选择超时，自动生成 `choice_select` / `choice_cancel` 动作。
- `AdapterLayer.clear_choice(layer, opts)`
  - 清空当前选择状态并通知 UI 关闭。

说明：`IntentDispatcher` 的 `need_choice` 由规则层产生，适配层仅负责 UI 和动作回传。

## 4. 视图构建与展示数据

文件：`src/adapters/core/presenter.lua`

- `Presenter.present(store_state, env)`
  - 将 `store_state` 与运行期上下文（last_turn/finished/winner）合并为 UI View。
  - `board.tiles` 由 `src/config/map.lua` + `src/config/tiles.lua` 映射得到。

共享 UI 小组件：
- `src/adapters/core/ui_panel.lua`：面板文本（当前玩家、状态、道具等）。
- `src/adapters/core/ui_tile.lua`：棋盘格子文本与详情。
- `src/adapters/core/ui_choice.lua`：选择框文本与按钮列表。
- `src/adapters/core/ui_log.lua`：日志裁剪显示。
- `src/adapters/core/ui_phase.lua`：阶段名与标题前缀。

这些模块只做文本拼装，具体 UI 渲染在各平台 adapter 内完成。

## 5. Eggy 适配层（重点）

Eggy 适配层为当前主要实现，**事件入口、UI 查询、以及选择 UI 更复杂**。

### 5.1 Runtime 入口

文件：`src/adapters/eggy/eggy_runtime.lua`

关键函数：
- `EggyRuntime.install()`：注册 Eggy 事件与 Tick。
  - `LuaAPI.global_register_trigger_event(EVENT.GAME_INIT, ...)`：初始化 UI 管理器并创建 Game。
  - `LuaAPI.set_tick_handler(function(delta_seconds) ... end)`：每帧调用 `layer:tick()`。
  - `LuaAPI.global_register_trigger_event(EVENT.UI_CUSTOM_EVENT, ...)`：接收 UI 事件并派发动作。
- `install_ui_manager()`：尝试加载 `UIManager`，并执行 `UIManager.Builder(nodes)` 构建 UI。
- `resolve_option_id(choice, payload, layer)`：解析黑市选择 UI 的选择项。

入口脚本（主工程）：`LuaSource_大富翁/init.lua`
- 初始化 `G.tiles = LuaAPI.query_units(t1..t45)`（棋盘锚点）。
- 控制 UI 显示与测试移动（`move.start_to_finish`）。

### 5.2 UIState 与节点查询

文件：`src/adapters/eggy/ui_state.lua`

核心策略：
- 优先使用 `UIManager.query_nodes_by_name` 查节点。
- 若 UIManager 不可用，则回退到 `LuaAPI.query_ui_node(name)`。
- `safe_set_label/set_button/set_visible/set_touch_enabled` 统一调用 Role API。

关键函数：
- `UIState.get_node(self, name)`：缓存节点，避免重复查询。
- `UIState.set_label / set_button / set_visible / set_touch_enabled`：封装 Role UI API。

### 5.3 EggyLayer（主逻辑）

文件：`src/adapters/eggy/eggy_layer.lua`

关键函数（函数级说明）：
- `EggyLayer.new(opts)`
  - 创建 `UIState`，挂载 `AdapterLayer.attach`。
- `EggyLayer:set_game(g)`
  - 调 `AdapterLayer.set_game`，处理 pending_choice。
- `EggyLayer:tick(dt)`
  - 处理 `pending_choice` 打开 UI。
  - 自动运行与超时选择。
  - 调 `refresh_view()` 生成并刷新 UI。
- `EggyLayer:build_view()`
  - 调 `Presenter.present` 生成 `view`。
- `EggyLayer:refresh_view()`
  - 顺序调用 `refresh_panel(view)` + `refresh_board(view)`。
- `EggyLayer:refresh_panel(view)`
  - 写入面板节点（玩家、回合、日志）。
- `EggyLayer:refresh_tile_detail(view)`
  - 根据 `selected_tile` 更新格子详情节点。
- `EggyLayer:refresh_board(view)`
  - 只更新棋盘格子的文字；**玩家位置渲染需在此扩展**。
- `EggyLayer:_open_choice_modal(pending)` / `_close_choice_modal()`
  - 根据 `pending.kind` 构建普通选择 UI 或黑市 UI（MarketUI）。
- `EggyLayer:dispatch_action(action)`
  - UI 按钮/格子选择/选择结果 -> 游戏动作。
- `EggyLayer:push_popup(payload)` / `close_popup()`
  - 控制弹窗 UI。

### 5.4 黑市 UI（MarketUI）

文件：`src/adapters/eggy/market_ui.lua`

- `MarketUI.is_ready()`：要求容器与事件名字段完整。
- `_open_choice_modal` 在 `pending.kind == "market_buy"` 时走该通道。
- `EggyRuntime.install()` 在 UI 事件里识别 `MarketUI.choose_event / confirm_event / cancel_event`。

### 5.5 Eggy 事件流（UI -> 游戏）

流程图（简化）：

```
[Eggy UI 事件]
   │ EVENT.UI_CUSTOM_EVENT
   ▼
EggyRuntime.install()
   │ 解析 event_name / payload
   ├─ MarketUI 路径 → resolve_option_id()
   │
   └─ 通用路径 → action = {type=...}
             ▼
        EggyLayer:dispatch_action(action)
             ▼
           Game:dispatch_action(action)
```

### 5.6 Eggy 刷新流（游戏 -> UI）

```
LuaAPI.set_tick_handler
   ▼
EggyLayer:tick(dt)
   ├─ AdapterLayer.step_auto_runner
   ├─ AdapterLayer.step_choice_timeout
   └─ refresh_view()
        ├─ refresh_panel(view)
        └─ refresh_board(view)
```

### 5.7 Eggy 适配维护重点

1) **节点命名**：Eggy UI 依赖节点名（如 `panel_title`、`tile_1`）。改 UI 资源需同步代码。
2) **UIManager**：优先使用 `UIManager` 查询节点；若构建失败，必须保证 `LuaAPI.query_ui_node` 可用。
3) **玩家位置渲染**：目前 Eggy 只写格子文本，不绘制角色位置。后续需使用 `Unit.set_position(pos)` 或 SceneUI 绑定。
4) **黑市 UI**：`pending.kind == "market_buy"` 会走 MarketUI 分支，事件名必须与资源配置一致。

## 6. 适配层与规则层的通信

规则层向适配层输出的主要入口：
- `IntentDispatcher` 触发 `need_choice` → `AdapterLayer.attach` 监听。
- `Game.ui_port` 指向 Layer，使规则层能调用 `ui_port:push_popup()` 等。

适配层向规则层回传：
- `layer:dispatch_action(action)` → `Game:dispatch_action(action)`。

## 7. 常见维护点

- **新增 UI 节点**：先在 UI 资源中添加节点名，再在 `EggyLayer:refresh_panel/refresh_board` 中设置文本。
- **新增选择 UI**：通过 `pending.kind` 分支处理；优先复用 `ChoiceView.build_choice_view`。
- **改自动运行**：调整 `src/adapters/core/auto_runner.lua` 的 `interval` 与动作生成规则。
- **Eggy API 查询**：遵守项目约定，不直接读 `docs/eggy/EggyAPI.lua`，用 `docs/eggy/api/*.md` 查接口。

## 8. 测试建议

- `lua tests/deps_check.lua`
- `lua tests/regression.lua`
## 9. 小结

适配层整体结构是：
- **Presenter + AdapterLayer** 提供跨平台的 View 与流程骨架。
- **Eggy** 通过 UI 节点驱动的方式适配平台 UI。
- **Eggy** 额外包含 UIManager 管理、黑市 UI 分支与平台事件入口。

维护适配层时，优先确保：节点命名一致、`dispatch_action` 通路正确、`refresh_view` 在 tick 内稳定运行。
