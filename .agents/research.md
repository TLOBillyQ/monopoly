# UI 升级研究：UIManagerNodes v2 数据源变更

更新时间：2026-02-27
数据源节点数：171 → **179**（新增骰子屏 8 节点）

---

## 1. 变更本质

Eggitor 导出统一添加了 **屏幕前缀**，命名规则：`{屏幕}_节点名`。

| 前缀 | 屏幕 |
|---|---|
| `基础_` | 基础屏（玩家面板、道具槽、行动按钮等） |
| `黑市_` | 黑市屏（购买项、底框、道具名称等） |
| `始终显示_` | 始终显示屏（托管按钮、行动日志、托管特效） |
| `位置_` | 位置选择屏（前/后/脚下 按钮） |
| `骰子_` | 骰子屏（新增，点数图片） |
| `加载_` | 加载屏（遮挡） |

不变的前缀：`建筑升级_`、`遥控骰子_`、`玩家选择_`、`卡牌展示_`、`破产_`、状态节点。

---

## 2. 完整更名表

### UINodes.lua

| 字段路径 | 代码当前值 | 数据源实际值 |
|---|---|---|
| `action_log.toggle_image` | `倒计时时钟` | **不存在** |
| `action_log.toggle_button` | `基础_行动日志按钮` | `始终显示_行动日志图标` |
| `buttons.action` | `行动按钮` | `基础_行动按钮` |
| `buttons.auto` | `托管按钮` | `始终显示_托管按钮` |
| `buttons.close` | `关闭` | `黑市_关闭` |
| `buttons.cancel` | `取消按钮` | `黑市_取消按钮` ⚠️ |
| `labels.auto` | `托管_文本` | `始终显示_文本` |
| `labels.countdown` | `倒计时文本` | `基础_倒计时` |
| `labels.no_action` | `基础_无法行动提示` | **不存在** |
| `effects.auto` | `基础屏-AI托管光效` | `始终显示_托管按钮特效` |
| `choice.player.body` | `玩家选择_副标题` | **不存在** |
| `choice.target.slots[1-6]` | `位置前1` .. `位置后3` | `位置_前1` .. `位置_后3` |
| `choice.target.under` | `位置脚下` | `位置_脚下` |
| `popup.confirm` | `取消按钮` | `黑市_取消按钮` ⚠️ |
| `panel.player_name` | `玩家%s名字` | `基础_玩家%s名字` |
| `panel.player_cash` | `玩家%s现金` | `基础_玩家%s现金` |
| `panel.player_land_count` | `玩家%s地块数量` | `基础_玩家%s地块数量` |
| `panel.player_total_assets` | `玩家%s总资产` | `基础_玩家%s总资产` |
| `panel.player_avatar` | `玩家%s头像` | `基础_玩家%s头像` |
| `panel.player_color` | `玩家%s底板颜色` | `基础_玩家%s底板颜色` |

### UIAliases.lua

| 别名 | 代码当前值 | 数据源实际值 |
|---|---|---|
| `btn_next` | `行动按钮` | `基础_行动按钮` |
| `btn_auto` | `托管按钮` | `始终显示_托管按钮` |
| `panel_turn` | `倒计时文本` | `基础_倒计时` |
| `market_confirm_button` | `黑市购买按钮` | `黑市_购买按钮` |
| `market_cancel_button` | `关闭` | `黑市_关闭` |
| `market_price_label` | `售价：100` | `黑市_售价` |
| `market_selected_card` | `选中卡牌` | `黑市_选中卡牌` |
| `item_slot_N` | `道具槽位N` | `基础_道具槽位N` |
| `panel_player_N_*` | `玩家N名字` 等 | `基础_玩家N名字` 等 |
| `market_item_buttonN` | `黑市购买项N` | `黑市_购买项N` |
| `market_item_label_N` | `道具名称N` | `黑市_道具名称N` |
| `market_item_frame_N` | `底框N` | `黑市_底框N` |

### MarketLayout.lua

| 字段 | 代码当前值 | 数据源实际值 |
|---|---|---|
| `confirm_button` | `黑市购买按钮` | `黑市_购买按钮` |
| `cancel_button` | `关闭` | `黑市_关闭` |
| `price_label` | `售价：100` | `黑市_售价` |
| `selected_card` | `选中卡牌` | `黑市_选中卡牌` |
| `icon_placeholder` | `选中卡牌` | `黑市_选中卡牌` |
| `item_buttons[N]` | `黑市购买项N` | `黑市_购买项N` |
| `item_labels[N]` | `道具名称N` | `黑市_道具名称N` |
| `item_frames[N]` | `底框N` | `黑市_底框N` |

### UITurnEffects.lua（硬编码）

| 代码当前值 | 数据源实际值 |
|---|---|
| `基础_玩家1高亮光效` | `基础_玩家1行动动效` |
| `基础_玩家2高亮光效` | `基础_玩家2行动动效` |
| `基础_玩家3高亮光效` | `基础_玩家3行动动效` |
| `基础_玩家4高亮光效` | `基础_玩家4行动动效` |
| `基础_星星中心爆开` | `基础_行动提示特效` |
| `基础_行动提示` | ✅ 一致 |
| `基础_其他玩家行动提示` | ✅ 一致 |

### ActionAnim.lua（硬编码）

| 代码当前值 | 数据源实际值 |
|---|---|
| `骰子屏` | ✅ 一致 |
| `骰子-旋转骰子底图` | `骰子_旋转中` |
| `骰子-摇骰子结束特效1` | **不存在**（已移除） |
| `骰子-摇骰子结束特效2` | **不存在**（已移除） |
| `骰子-骰子点数1-6` | `骰子_点数1-6` |

---

## 3. 数据源内部一致性

✅ **已统一**：所有玩家行动动效节点现均使用 `基础_` + underscore 格式：
- `基础_玩家1行动动效`
- `基础_玩家2行动动效`
- `基础_玩家3行动动效`
- `基础_玩家4行动动效`

---

## 4. 待确认决策

| # | 问题 | 影响 |
|---|---|---|
| 1 | `取消按钮` → `黑市_取消按钮`：此按钮被 popup 和 player_choice 共用。改名为黑市前缀后，popup/player_choice 的取消还用同一个按钮？ 不是同一个按钮| UINodes 3 处引用 |
| 2 | `倒计时时钟` 完全消失，行动日志切换入口改用什么节点？行动日志切换是`始终显示_行动日志图标` | UIEventBindings 注册逻辑 |
| 3 | `基础_无法行动提示` 消失，功能保留还是废弃？ | UIPanelPresenter |
| 4 | `玩家选择_副标题` 消失，功能保留还是废弃？ | core.lua choice screen |
| 5 | 骰子动画特效节点（摇骰子结束特效 1/2）已移除，骰子动画流程是否简化？简化 | ActionAnim |
| 6 | `玩家选择_槽位4` 已在数据源，代码只接了 1-3，是否扩展？扩展 | UINodes + intent builders |
| 7 | `位置_确认按钮` 在数据源但代码未接入，位置选择是否需要确认步骤？ 不需要| UINodes target choice |

---

## 5. 需修改的文件

| 文件 | 改动量 |
|---|---|
| `src/presentation/shared/UINodes.lua` | **大**：几乎所有节点名 |
| `src/presentation/shared/UIAliases.lua` | **大**：所有别名目标 |
| `src/presentation/shared/MarketLayout.lua` | **中**：8 个字段 + 30 个数组项 |
| `src/presentation/ui/UITurnEffects.lua` | **小**：6 个硬编码名 |
| `src/presentation/render/ActionAnim.lua` | **小**：骰子节点名 + 移除特效引用 |
| `docs/ui/*.md` | 同步更新 |

不需改动：`UIEvents.lua`（动态扫描）、`UICanvasCoordinator.lua`（间接引用）、`status3d_service/specs.lua`（名称一致）。
