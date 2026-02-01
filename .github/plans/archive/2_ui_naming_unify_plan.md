# 统一 UI 命名并同步 Eggy 适配层

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。  
本计划遵循 `.agent/PLANS.md`。

## 目的 / 全局视角

本任务要把 UI 命名统一为简洁一致的小写蛇形命名，并同步到 `UIManagerNodes.lua`、`.github/docs/plans/ui_naming_list.md` 与 Eggy 适配层代码。完成后，UI 侧资源名与代码使用的逻辑名完全一致，不再依赖映射或中文命名。验收方式是 UI 命名清单与 `UIManagerNodes.lua` 一致，适配层引用更新完成，运行 `.github/tests/ui_nodes_audit.lua` 与回归测试不报缺失。

## 进度

- [x] (2026-01-27 14:44Z) 统一命名规范并列出全量清单  
- [x] (2026-01-27 14:44Z) 同步 `UIManagerNodes.lua` 与 `.github/docs/plans/ui_naming_list.md`  
- [x] (2026-01-27 14:44Z) 更新 Eggy 适配层与审计脚本引用  
- [x] (2026-01-27 14:50Z) 运行审计与回归验证

## 意外与发现

- 观察：UIManagerNodes.lua 已采用小写蛇形命名，.github/tests/ui_nodes_audit.lua 直接匹配节点名，无需映射表。
  证据：UIManagerNodes.lua 顶部条目均为 snake_case；.github/tests/ui_nodes_audit.lua:20-110。
若发现 UI 节点语义与命名不符（例如“弹窗确认/关闭”实际语义），在这里记录并给出 UI 侧截图或日志证据。

## 决策日志

- 决策：统一采用小写蛇形命名，并以代码逻辑名为准。  
  理由：减少映射与双语命名维护成本，便于适配层直接使用 UIManager 查询。  
  日期/作者：2026-01-27 / Codex
- 决策：补齐 ui_naming_list 中遗漏的基础屏/遮罩节点并保持与审计清单一致。  
  理由：保证清单完整可用，避免遗漏导致 UI 资源侧改名不全。  
  日期/作者：2026-01-27 / Codex

## 结果与复盘

已确认命名统一并补齐清单，审计与回归测试通过。

## 背景与导读

当前 UI 资源名主要集中在 `UIManagerNodes.lua`，其中大量节点使用中文名称；Eggy 适配层通过 `src/adapters/eggy/ui_state.lua` 与 `.github/tests/ui_nodes_audit.lua` 的映射表做兼容。适配层使用的逻辑名已基本固定（例如 `panel_title`、`btn_next`、`tile_detail_*`），因此应以逻辑名作为唯一 UI 资源名，并在 Eggitor 编辑器中同步。`Data/UINodes.lua` 与 `Data/Prefab.lua` 为 Eggitor 导出产物，不直接手改，最终由你在 Eggitor 中按新命名导出覆盖。

## 工作计划

先确认统一命名规范为小写蛇形，并给出全量 UI 命名清单，覆盖 `UIManagerNodes.lua` 现有节点、适配层要求节点、以及市场/弹窗/棋盘等缺失节点。然后编辑 `UIManagerNodes.lua`：把所有中文名替换为统一命名，并补齐缺失项（使用占位 id）；同时更新 `.github/docs/plans/ui_naming_list.md` 为新清单，移除旧的映射说明。最后更新 Eggy 适配层：包括 `src/adapters/eggy/eggy_layer.lua`、`src/adapters/eggy/market_ui.lua`、`src/adapters/eggy/eggy_runtime.lua` 与 `.github/tests/ui_nodes_audit.lua`，使其直接使用新命名；若后续决定删除 `ui_state.lua`，应在同一变更中完成。

## 具体步骤

在仓库根目录执行。先根据下方“接口与依赖”的全量命名清单，确认哪些是现有中文节点、哪些是缺失节点。随后按清单改写 `UIManagerNodes.lua` 的名称字段，并补齐缺失节点的占位记录；同步更新 `.github/docs/plans/ui_naming_list.md` 使其成为唯一命名对照表。接着把适配层中所有中文事件名与节点名替换为统一命名，并调整 `.github/tests/ui_nodes_audit.lua` 的必需清单与映射逻辑为“无映射、直接匹配”。最后运行测试并记录输出。

## 验证与验收

运行 `lua .github/tests/ui_nodes_audit.lua` 预期输出 ok；再运行 `lua .github/tests/deps_check.lua` 与 `lua .github/tests/regression.lua` 均通过。UI 侧由 Eggitor 导出后，运行 Demo 时按钮、弹窗、黑市与面板文本均正常显示与响应。

## 可重复性与恢复

改动主要在命名与引用层，均可通过 `git checkout -- <file>` 回滚。Eggitor 导出前不修改 `Data/UINodes.lua` 与 `Data/Prefab.lua`，避免手工冲突。测试命令可重复执行且不改变数据状态。

## 产物与备注

产物包括更新后的 `UIManagerNodes.lua`、`.github/docs/plans/ui_naming_list.md` 与 Eggy 适配层文件；Eggitor 最终导出的 `Data/UINodes.lua` 与 `Data/Prefab.lua` 由你在确认命名后生成。若发现 UI 中“弹窗确认/关闭”语义与代码期望不符，需要在 UI 侧调整并记录到“意外与发现”。

    .github/docs/plans/ui_naming_list.md 已补齐 base_screen/loading_screen 等节点清单。

    测试输出：
    [ui-audit] ok: all required nodes/events are present (directly or via mapping)
    Dependency self-check passed
    All regression checks passed (29)

## 接口与依赖

统一命名清单采用小写蛇形，所有 UI 资源名需严格一致。基础屏幕与遮罩使用 base_screen、loading_screen、loading_tip、overlay_mask、background_rect。主面板使用 panel_title、panel_turn、panel_current_title、panel_current_name、panel_current_role、panel_current_phase、panel_current_dice、panel_players_title、panel_item_slots、panel_tile_title、panel_log_title、panel_log_body。玩家区按 1..4 使用 panel_player_1、panel_player_1_detail、panel_player_1_info、panel_player_1_avatar、panel_player_1_cash、panel_player_1_land_count、panel_player_1_base、panel_player_1_base_color，并对 2..4 重复同样后缀。道具槽位使用 item_slot_1、item_slot_2、item_slot_3、item_slot_4、item_slot_5。格子详情使用 tile_detail_name、tile_detail_price、tile_detail_level、tile_detail_owner、tile_detail_roadblock、tile_detail_mine。主按钮使用 btn_next、btn_auto、btn_restart，并保留 btn_auto_label 作为自动控制文字节点。选择弹窗使用 modal_choice、choice_title、choice_body、choice_cancel、choice_option_1、choice_option_2、choice_option_3、choice_option_4。确认弹窗使用 modal_popup、popup_title、popup_body、popup_confirm、popup_card，并将原“弹窗确认”暂定为 popup_confirm_alt（若实际为确认按钮则与 popup_confirm 对调）。黑市面板使用 market_panel、market_confirm_button、market_cancel_button、market_price_label、market_selected_card、market_icon_placeholder、market_item_button_1..10、market_item_label_1..10、market_item_frame_1..10。棋盘格子文本使用 tile_1..tile_45。自定义事件名与节点名保持一致，黑市事件使用 market_item_button_1..10、market_confirm_button、market_cancel_button；自动与下一回合事件使用 btn_auto、btn_next；弹窗确认事件使用 popup_confirm。

附记：首次创建本计划，明确全量 UI 命名清单与同步范围，避免后续再引入映射层。
改动说明：确认命名已统一并补齐基础屏/遮罩清单，原因是当前实现已无映射且清单需完整可用。
改动说明：补充审计与回归测试结果，原因是已完成验收并需要记录输出。
