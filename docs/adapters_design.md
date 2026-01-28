# 适配层设计与实现（开发指南）

本文面向适配维护者，说明本仓库适配层的结构、数据流、关键函数与 Eggy 细节，便于直接定位代码与排查问题。

## 1. 适配层的目标与边界

适配层负责把“规则层/回合推进”产出的状态与动作，映射到具体平台的 UI、输入与平台 API。它不改规则，只做展示与事件转发。

核心边界：
- **规则/状态**：`src/game.lua` + `src/gameplay/*` + `src/core/*`
- **适配/UI**：`src/adapters/*`
- **平台入口**：`main.lua` 安装 Eggy runtime（当前唯一运行入口）

## 2. 入口与平台选择

文件：`main.lua`

当前仓库只保留 Eggy 入口：
- `main.lua`：先调用 `require("src.bootstrap")()` 扩展 `package.path`，再调用 `require("src.adapters.eggy.eggy_runtime").install()` 安装运行时。
- Eggy runtime：`src/adapters/eggy/eggy_runtime.lua`。

说明：
- 本仓库已不再维护多平台入口分支（历史的 `src/entry.lua` 已删除）。
- 仓库根目录的 `init.lua` 是 Eggy 工程侧常用的“场景/资源绑定脚本”（创建 `G.refs/G.tiles/G.buildings` 等全局索引、并调用 `UIManager.Builder(require "Data.ui_data")`）。`EggyLayer` 会优先使用 `G.tiles`，否则会在运行时回退到 `LuaAPI.query_units("t1..tN")` 自行构建锚点缓存。

## 3. 通用适配层骨架（AdapterLayer）

文件：`src/adapters/core/adapter_layer.lua`

适配层共用逻辑集中在 `AdapterLayer`，所有平台的 Layer 都会调用它。

核心函数：
- `AdapterLayer.attach(layer, opts)`
  - 绑定 `ui`、`game_factory`、`auto_runner`。
  - 监听 `IntentDispatcher` 的 `need_choice` 事件并写入 `layer.pending_choice`（同时重置计时器）。
  - 初始化并维护：`pending_choice_elapsed/pending_choice_id`、`ui_modal_elapsed/ui_modal_ref`、`move_anim_seq` 等状态机字段。
- `AdapterLayer.set_game(layer, game, opts)`
  - 设置当前 `game` 并把 `game.ui_port` 指向 `layer`（供规则层回调）。
  - 检查是否已有 `pending_choice` 并回调 `opts.on_pending_choice`。
- `AdapterLayer.build_item_index(layer)`
  - 由 `src/config/items.lua` 生成 `layer.item_name_by_id`，用于 UI 文本显示（道具槽位/黑市等）。
- `AdapterLayer.new_game(layer, opts)`
  - 清理日志、创建新 Game、初始化物品索引、重置自动运行定时器。
- `AdapterLayer.step_auto_runner(layer, dt, context)`
  - 根据 `AutoRunner` 输出自动动作（默认是 `ui_button next`；若 `context.modal_active` 为真，会输出 `modal_*` 动作）。
- `AdapterLayer.step_choice_timeout(layer, dt, opts)`
  - 选择超时（`src/config/constants.lua: action_timeout_seconds`）时，自动生成 `choice_select` / `choice_cancel` 动作。
  - 同步 `game.store.turn.pending_choice`，确保 UI 与 store 一致（避免只靠事件导致漏刷新）。
- `AdapterLayer.step_modal_timeout(layer, dt, opts)`
  - 对“非选择类弹窗”的超时收敛：当 UI 处于激活态且超过 `action_timeout_seconds`，调用 `opts.on_timeout`（Eggy 用它自动关闭提示弹窗）。
- `AdapterLayer.step_move_anim(layer)`
  - 监听 `game.store.turn.move_anim` 与 `turn.phase == "wait_move_anim"`；当检测到新的 `move_anim.seq` 时自动派发 `{type="move_anim_done", seq=...}`，用于推进“等待移动动画结束”的回合阶段。
- `AdapterLayer.clear_choice(layer, opts)`
  - 清空当前选择状态并回调 `opts.on_close_choice`（平台侧负责把选择 UI 收起）。

说明：`IntentDispatcher` 的 `need_choice` 由规则层产生，适配层仅负责 UI 和动作回传。

## 4. 视图构建与展示数据

文件：`src/adapters/core/presenter.lua`

- `Presenter.present(store_state, env)`
  - 将 `store_state` 与运行期上下文（last_turn/finished/winner）合并为 UI View。
  - `board.tiles` 由 `src/config/map.lua` + `src/config/tiles.lua` 映射得到。
  - `board.overlays`（路障/地雷等）优先来自 `env.game.board:get_overlays()`，否则使用空集合。

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
- `install_ui_manager()`：尝试加载 `UIManager`，并执行 `UIManager.Builder(nodes)` 构建 UI。
- `register_ui_manager_events(layer)`：通过 `UIManager.query_nodes_by_name` 获取节点并监听 CLICK 事件，直接派发 `layer:dispatch_action` 或 `layer:close_popup`。
- `resolve_option_id(choice, payload, layer)`：解析黑市选择 UI 的选择项（支持 `option_id/option` 或 `index/*_index`）。

补充：仓库根目录 `init.lua` 负责初始化 `G.refs/G.tiles/G.buildings` 等全局表，并构建 UI（`Data/ui_data.lua`）。`EggyLayer` 的部分能力（例如楼房升级特效/图片 key 映射）会依赖这些全局数据。

### 5.2 UI 状态与节点查询

文件：`src/adapters/eggy/eggy_layer.lua`、`src/adapters/eggy/eggy_layer_ui.lua`

核心策略：
- 节点通过 `UIManager.query_nodes_by_name(name)` 获取，并在 `EggyLayerUI.build_ui_state()` 内用 `query_node` 取首个节点。
- 直接写节点字段 `text/visible/disabled`，不再额外封装映射层。
- `ui` 状态表内保留 `choice/popup/item_slots` 等字段，供 `EggyLayer` 逻辑使用。

关键函数：
- `EggyLayerUI.build_ui_state()`：组装 `ui` 状态表，并提供 `query_node/set_label/set_button/set_visible/set_touch_enabled` 等方法。

### 5.3 EggyLayer（主逻辑）

文件：`src/adapters/eggy/eggy_layer.lua`、`src/adapters/eggy/eggy_layer_ui.lua`、`src/adapters/eggy/eggy_layer_market.lua`、`src/adapters/eggy/eggy_layer_board.lua`

关键函数（函数级说明）：
- `EggyLayer.new(opts)`
  - 构建 `ui` 状态表（`EggyLayerUI.build_ui_state()`），并挂载 `AdapterLayer.attach`。
- `EggyLayer:set_game(g)`
  - 调 `AdapterLayer.set_game`，处理 pending_choice。
- `EggyLayer:tick(dt)`
  - `AdapterLayer.step_auto_runner`：自动推进（默认下一回合）。
  - `AdapterLayer.step_choice_timeout`：选择超时自动处理（Eggy 会先尝试 `Agent.auto_action_for_choice`）。
  - `AdapterLayer.step_modal_timeout`：弹窗超时自动关闭（调用 `close_popup()`）。
  - `AdapterLayer.step_move_anim`：等待移动动画结束时自动派发 `move_anim_done`。
  - `pending_choice` 存在时打开选择 UI，并 `refresh_view()` 刷新 UI。
- `EggyLayer:build_view()`
  - 调 `Presenter.present` 生成 `view`。
- `EggyLayer:refresh_view()`
  - 顺序调用 `refresh_panel(view)` + `refresh_board(view)`。
- `EggyLayer:refresh_panel(view)` / `EggyLayer:refresh_item_slots(view)` / `EggyLayer:refresh_tile_detail(view)`
  - 由 `eggy_layer_ui.lua` 完成 UI 面板与格子详情刷新。
- `EggyLayer:refresh_board(view)`
  - 由 `eggy_layer_board.lua` 刷新棋盘格子文本、锚点缓存与玩家单位位置。
- `EggyLayer:_open_choice_modal(pending)` / `_close_choice_modal()`
  - 根据 `pending.kind` 构建普通选择 UI 或黑市 UI（见 5.4）。
- `EggyLayer:dispatch_action(action)`
  - UI 按钮/格子选择/选择结果 -> 游戏动作。
- `EggyLayer:push_popup(payload)` / `close_popup()`
  - 控制弹窗 UI。
- `EggyLayer:on_tile_upgraded(tile_id, level)`
  - 触发楼房升级表现（依赖 `G.buildings/G.refs`，内部调用 `src/adapters/eggy/building_effects.lua`）。

### 5.4 黑市 UI（MarketUI）

文件：`src/adapters/eggy/market_ui.lua`

黑市 UI 仅保留面板式黑市路径，按可用资源自动选择：

1) **面板式黑市（10 项）**（推荐默认）
- `MarketUI.is_panel_ready()` 为真时启用（要求容器、确认按钮、以及 `item_buttons/item_labels` 等字段完整）。
- `eggy_layer_market.lua` 负责黑市面板渲染与选择状态；`EggyLayer:_open_market_panel(pending)` 负责委托并记录 `layer.market_choice_option_ids`。
- `EggyRuntime.install()` 通过 UIManager 节点监听将 `MarketUI.item_buttons` 与确认/取消按钮转为选择动作。

### 5.5 Eggy 事件流（UI -> 游戏）

流程图（简化）：

```
[Eggy UI 事件]
   │ UIManager 节点 CLICK
   ▼
EggyRuntime.register_ui_manager_events()
   │ 按节点名分发（btn_next/btn_auto/choice_option/...）
   ├─ 黑市路径（pending.kind == "market_buy"）
   │    ├─ item_buttons 顺序映射
   │    └─ resolve_option_id() → choice_select / choice_cancel
   │
   └─ 通用路径
        └─ layer:dispatch_action(action)
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
   ├─ AdapterLayer.step_modal_timeout
   ├─ AdapterLayer.step_move_anim
   └─ refresh_view()
        ├─ refresh_panel(view)
        └─ refresh_board(view)
```

### 5.7 Eggy 适配维护重点

1) **节点命名**：UI 资源改名时，直接同步 `ui_data.lua`、`docs/plans/ui_naming_list.md` 与 `MarketUI.*` 常量，避免映射层。
2) **UIManager 依赖**：节点通过 `UIManager.query_nodes_by_name` 获取首个节点。若 UIManager 构建失败，会导致节点全部为 nil（表现为 UI 不刷新）。排查顺序：`ui_data.lua` 是否可 require、`UIManager.Builder` 是否被调用、节点名是否一致。
3) **场景锚点/角色绑定**：玩家位移依赖棋盘锚点 `t1..tN`（或 `G.tiles`），玩家 unit 依赖 `GameAPI.get_all_valid_roles()`。多人同格子偏移由 `tile_spacing` 自动估算。
4) **楼房升级表现**：`on_tile_upgraded` 依赖 `G.buildings/G.refs`，并用 `Data.Prefab` 生成组单位；Eggy 工程资源变更时需要同步 Prefab/refs。
5) **黑市 UI**：优先保证面板式黑市可用（`MarketUI.item_buttons/confirm_button/cancel_button` 与 UI 资源一致）。

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
- **移动动画卡死**：若回合卡在 `wait_move_anim`，检查 `store.turn.move_anim.seq` 是否更新、以及 `AdapterLayer.step_move_anim` 是否被 tick 到（Eggy 已默认调用）。
- **Eggy API 查询**：遵守项目约定，不直接读 `docs/eggy/EggyAPI.lua`，用 `docs/eggy/api/*.md` 查接口。

## 8. 测试建议

- `lua tests/deps_check.lua`
- `lua tests/regression.lua`

## 9. 小结

适配层整体结构是：
- **Presenter + AdapterLayer** 提供跨平台的 View 与流程骨架。
- **Eggy** 通过 UI 节点驱动的方式适配平台 UI。
- **Eggy** 额外包含 UIManager 管理、黑市 UI 分支、场景单位绑定（玩家/楼房）与平台事件入口。

维护适配层时，优先确保：节点命名一致、`dispatch_action` 通路正确、`refresh_view` 在 tick 内稳定运行。
