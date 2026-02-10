# 冻结声明

本文档为旧 UI 方案归档（Legacy），仅供历史追溯，不作为当前实现规范。
当前规范请查看同目录下不带 `_Legacy` 后缀的 V2 文档。

# UI：通用选择屏

画布名：`通用选择屏`。展示标题 + 正文 + 最多 6 个选项按钮 + 可选取消按钮。所有需要玩家选择的场景均通过此画布呈现（黑市购买在节点就绪时优先使用黑市屏）。

## 节点清单

| 节点名 | 类型 | 用途 |
|--------|------|------|
| `通用选择_标题` | ELabel | 标题 |
| `通用选择_正文` | ELabel | 正文（`body_lines` 以 `\n` 拼接） |
| `通用选择_面板` | EImage | 面板容器 |
| `通用选择_选项区` | EImage | 选项区容器 |
| `通用选择_选项_01` ~ `通用选择_选项_06` | EButton | 最多 6 个选项 |
| `通用选择_取消` | EButton | 取消按钮 |

## 打开选择屏

`_open_generic_choice(state, choice, choice_id)` 在 `UIView.lua` 中：

1. 若黑市正在显示则先关闭。
2. 切换到通用选择屏画布。
3. 设置标题和正文。
4. 遍历 6 个选项按钮：有对应选项则设置文字并显示，无则隐藏。
5. `allow_cancel = false` 时隐藏取消按钮；否则设置取消按钮文字并显示。

## 关闭选择屏

`ui_view.close_choice_modal(state)`：

1. 隐藏通用选择屏。
2. 若黑市活跃则关闭黑市面板。
3. 若弹窗活跃 → 切到弹窗屏；否则 → 切到基础屏。

## 选项数据来源

所有选项先以 `choice_spec` 注入 `game.turn.pending_choice`，再由 `UIChoice.build_choice_view` 转为视图结构：

```lua
{
  title = "[阶段前缀] " .. base_title,  -- 道具阶段时追加 [行动前] 等前缀
  body = body_lines 拼接字符串,
  options = { { id, label, raw }, ... },
  cancel_label = pending.cancel_label or "取消",
  allow_cancel = pending.allow_cancel ~= false,
}
```

标题前缀逻辑：若 `game.turn.item_phase_active` 非空，则在标题前追加 `[行动前]`、`[投骰后]` 或 `[行动后]`。

## 全部运行时场景

### `item_phase_choice` — 道具使用阶段

来源：`ItemPhase.lua`。行动前 / 投骰后 / 行动后三个道具阶段均可触发。

| 字段 | 值 |
|------|----|
| title | `"行动前：使用道具？"` / `"投骰后：使用道具？"` / `"行动后：使用道具？"` |
| body_lines | 每行 `"{道具名}"` 或 `"{道具名}：{用途}"`，末行 `"丢弃道具：从背包丢弃一张"` |
| options | 可用道具 `{ id: item_id, label: 道具名 }` + `{ id: "discard_item", label: "丢弃道具" }` |
| allow_cancel | `true` |
| cancel_label | `"结束阶段"` |

### `discard_item` — 丢弃道具

来源：`ItemChoiceHandler.lua`。在道具使用阶段选择 `"丢弃道具"` 后弹出。

| 字段 | 值 |
|------|----|
| title | `"选择要丢弃的道具"` |
| body_lines | `"{序号}. {道具名}"`（对应背包全部道具） |
| options | `{ id: 序号, label: 道具名 }` |
| allow_cancel | `true` |
| cancel_label | `"返回"` |

### `rent_card_prompt` — 强征卡 / 免费卡

来源：`LandChoiceSpecs.lua`。踩到他人地块且持有对应卡时弹出。

| 字段 | 强征卡 | 免费卡 |
|------|--------|--------|
| title | `"是否使用强征卡"` | `"是否使用免费卡"` |
| body_lines | `"支付 {cost} 强制购入 {地块名}"` | `"免除本次租金"` |
| options | `使用` / `放弃` | `使用` / `放弃` |
| allow_cancel | `false` | `false` |

### `tax_card_prompt` — 免税卡

来源：`LandChoiceSpecs.lua`。踩到税务局且持有免税卡时弹出。

| 字段 | 值 |
|------|----|
| title | `"是否使用免税卡"` |
| body_lines | `"使用免税卡可免除本次税金"` |
| options | `使用` / `放弃` |
| allow_cancel | `false` |

### `steal_prompt` — 偷窃卡使用确认

来源：`ItemSteal.lua`。路过其他非淘汰、非天使附身玩家且持有偷窃卡时弹出。可连续对多个目标依次弹出。

| 字段 | 值 |
|------|----|
| title | `"是否使用偷窃卡"` |
| body_lines | `"目标：{目标玩家名}"` |
| options | `使用` / `放弃` |
| allow_cancel | `false` |

### `steal_item` — 选择偷取的道具

来源：`ItemChoiceHandler.lua`。确认偷窃后目标有多个道具时弹出。

| 字段 | 值 |
|------|----|
| title | `"选择要偷的道具"` |
| body_lines | `"{序号}. {道具名}"` |
| options | `{ id: 序号, label: 道具名 }` |
| allow_cancel | `true` |
| cancel_label | `"取消"` |

### `item_target_player` — 道具目标玩家选择

来源：`ItemRegistry.lua`。使用需要选择目标的道具（诅咒卡等）时弹出。

| 字段 | 值 |
|------|----|
| title | `"{道具名}：选择目标玩家"` |
| body_lines | `"{玩家名} 现金:{cash}"` ，附身则追加 `" 神:{deity.type}"` |
| options | `{ id: player.id, label: 玩家名 }` |
| allow_cancel | `true` |
| cancel_label | `"取消"` |

### `remote_dice_value` — 遥控骰子选择点数

来源：`ItemRegistry.lua`。

| 字段 | 值 |
|------|----|
| title | `"遥控骰子：选择点数"` |
| body_lines | `"点数 1"` ~ `"点数 6"` |
| options | `{ id: 1~6, label: "1"~"6" }` |
| allow_cancel | `true` |
| cancel_label | `"放弃"` |

### `roadblock_target` — 路障卡选择位置

来源：`ItemRegistry.lua`。使用路障卡，选择前方 3 格内可放置的位置。

| 字段 | 值 |
|------|----|
| title | `"路障卡：选择位置"` |
| body_lines | 候选格子名称列表 |
| options | `{ id: tile_index, label: 格子名 }` |
| allow_cancel | `true` |
| cancel_label | `"放弃"` |

### `demolish_target` — 怪兽卡 / 导弹卡选择目标

来源：`ItemDemolish.lua`。使用怪兽卡或导弹卡，选择前方 3 格内有建筑的他人地块。

| 字段 | 值 |
|------|----|
| title | `"{道具标题}：选择目标格子"`（如 `"怪兽卡：选择目标格子"`） |
| body_lines | `"#{index} {地块名}"` |
| options | `{ id: tile_index, label: 地块名 }` |
| allow_cancel | `true` |
| cancel_label | `"取消"` |

### `market_buy` — 黑市购买（降级模式）

来源：`Market.lua`。此 kind 优先使用黑市屏渲染。仅当 `market_ui.is_panel_ready()` 返回 `false` 时降级到通用选择屏。

| 字段 | 值 |
|------|----|
| title | `"黑市"` |
| body_lines | `"{商品名} - {价格} {货币}"` |
| options | `{ id: product_id, label: 完整描述 }` |
| allow_cancel | `true` |
| cancel_label | `"不买"` |

### `market_vehicle_replace` — 更换座驾确认

来源：`Market.lua`。已有座驾时在黑市购买新座驾触发。

| 字段 | 值 |
|------|----|
| title | `"是否更换座驾"` |
| body_lines | `"当前座驾：{current}"` / `"新座驾：{next}"` / `"价格：{price} {currency}"` |
| options | `更换` / `算了` |
| allow_cancel | `false` |

### `landing_optional_effect` — 着陆可选效果

来源：`EffectPipeline.lua`。着陆时存在可选效果时弹出。

| 字段 | 值 |
|------|----|
| title | 由调用方 `opts.optional_title` 指定 |
| body_lines | 各效果的 label |
| options | `{ id: effect.id, label: effect.label }` |
| allow_cancel | 由调用方 `opts.optional_allow_cancel` 指定 |
| cancel_label | 由调用方 `opts.optional_cancel_label` 指定 |
