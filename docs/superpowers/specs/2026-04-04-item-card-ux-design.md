# 道具卡使用交互优化设计

## 问题

当前道具卡每个阶段弹窗询问 + 二次确认 + repeatable 循环弹窗，不想用卡时操作繁琐。多张相同卡片（如遥控骰子）效果会覆盖却仍重复弹窗。

## 方案：槽位驱动 + 智能提醒

取消所有 `item_phase_choice` 弹窗，改为槽位高亮主动点击。时机敏感卡通过气泡提醒。

## 卡片分类

`items.lua` 新增两个配置字段：

- `prompt_style`：`"alert"`（气泡提醒）或 `"passive"`（仅高亮）
- `effect_group`（可选）：同组卡用完一张后其余变灰

| 卡片 | prompt_style | effect_group |
|------|-------------|-------------|
| 免税卡/送神卡/免费卡/强征卡/偷窃卡 | alert | — |
| 遥控骰子卡 | passive | dice_control |
| 骰子加倍卡 | passive | dice_multiply |
| 其余所有卡 | passive | — |

## 阶段流程

```
阶段开始 → rules 计算 slot_states → 下发 kind="item_phase_passive"
  ├─ UI 高亮可用槽位 + alert 卡显示气泡 + 显示"继续"按钮
  ├─ 玩家点槽位 → 直接执行（无二次确认）→ 刷新 slot_states → 继续等待
  ├─ 玩家点"继续" → 结束阶段
  └─ 无可用卡 → 跳过整个阶段
```

不满足 `can_offer_in_phase` 或同 `effect_group` 已使用的卡 → 槽位置灰不可点。

## Choice Spec 结构

```lua
{
  kind = "item_phase_passive",
  uses_item_slots = true,
  pre_confirm_before_slot_pick = false,
  slot_states = {
    [1] = { available = true,  alert = true,  alert_text = "免税卡可用！" },
    [2] = { available = true,  alert = false },
    [3] = { available = false, alert = false },
  },
  show_continue_button = true,
  continue_label = "继续",
}
```

`slot_states` 由 rules 层（`phase.lua`）计算，UI 层只消费渲染，不读配置。

## 分层职责

| 数据/逻辑 | 所属层 | 位置 |
|-----------|--------|------|
| `prompt_style`/`effect_group` 配置 | config | `src/config/content/items.lua` |
| 可用性判断 + slot_states 计算 | rules | `src/rules/items/phase.lua` + `availability.lua` |
| `used_effect_groups` 记录 | state | `game.turn` |
| 槽位渲染/气泡/置灰 | presentation | `src/ui/ctl/item_slots.lua` |
| 槽位点击 intent | presentation | `src/ui/input/canvas_route_item_slots.lua` |

依赖方向：presentation → turn → rules → config/state，无逆流。

## UI 新增节点

`base_nodes.lua` 新增 5 个气泡文本节点（`基础_道具气泡1~5`），挂在槽位上方。

## 槽位三态

| 状态 | 视觉 | 交互 |
|------|------|------|
| 可用 | 高亮（alert 加气泡） | 可点击 |
| 不可用 | 置灰 | 不响应 |
| 常态 | 正常 | 不响应 |

## effect_group 生命周期

- 记录在 `game.turn.used_effect_groups`
- 每回合开始清空
- 用完一张卡后写入，刷新时检查

## 边界情况

- 背包为空/无匹配卡 → 阶段自动跳过
- AI 玩家 → 保留 `_run_auto_phase` 不变，`effect_group` 同样生效
- 多阶段串联 → 各自独立计算，`used_effect_groups` 跨阶段生效
- 卡片被外部消耗 → 下次刷新自然反映
- 后续选择流程（路障选位等）→ 隐藏气泡和"继续"，完成后恢复
- 动画播放期间 → 槽位不可点，动画结束后刷新

## 涉及文件

- `src/config/content/items.lua` — 新增 prompt_style/effect_group
- `src/rules/items/phase.lua` — 新 kind + slot_states 计算
- `src/rules/items/availability.lua` — effect_group 检查
- `src/ui/ctl/item_slots.lua` — 三态渲染 + 气泡
- `src/ui/input/dispatch_pre_confirm.lua` — 跳过预确认
- `src/ui/schema/base_nodes.lua` — 新增气泡节点
- `src/ui/ctl/modal.lua` — 新 kind 路由
