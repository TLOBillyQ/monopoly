---
kind: reference
status: stable
owner: eggy-vendor
last_verified: 2026-05-04
---
# eggy 示例工程知识抽取（面向 LuaSource_大富翁）

本文基于 knowledge/ 下 Eggy 官方示例工程源码，提炼可复用的机制、API用法与工程组织方式，方便在 LuaSource_大富翁 中落地。

## 1. 通用结构与初始化模式
- 所有示例均在 `EVENT.GAME_INIT` 中做初始化与事件注册，入口通常在各自 `main.lua`。
- 复杂玩法采用全局表 `G` 作为单例容器（如跑商、割草），集中管理 manager 与共享状态。
- 帧更新统一使用 `LuaAPI.set_tick_handler(onPreTick, onPostTick)`，或者使用 `EVENT.REPEAT_TIMEOUT` 计时器代替 tick。

可复用：在大富翁中可统一“初始化 -> 注册事件 -> 设定 tick/定时器”的流程，并把玩法模块挂到 `G`。

## 2. 事件与触发器模式
### 2.1 玩家举起/放下
- 通过 `LuaAPI.unit_register_trigger_event(character, { EVENT.SPEC_LIFEENTITY_LIFT_BEGAN }, cb)` 监听举起。
- 放下使用 `EVENT.SPEC_LIFEENTITY_LIFT_ENDED`，常见处理：恢复物理、调整位置与朝向。
- 示例里对物体禁用物理/交互，避免误操作。

应用建议：大富翁道具“拿起-放下-使用”可沿用此事件链，并在放下时统一做位置修正。

### 2.2 区域触发
- 通用封装 `TriggerAreaHandler`：基于触发器单位ID监听 `ENTER/LEAVE`。
- 回调中通过 `data.event_unit.get_role()` 获取角色。

应用建议：地图格子、商店、事件点可用触发区包装，统一进入/离开处理。

### 2.3 UI 自定义事件
- `LuaAPI.global_register_custom_event("点击XX", cb)` 绑定 UI 按钮事件。
- 事件中 data.role/role_id 可定位操作角色。

应用建议：大富翁的“掷骰子/使用卡牌/结束回合”统一走 custom event，逻辑更清晰。

## 3. UI 机制与节点操作
- UI 节点通常通过 `Data.UINodes` 读取，避免直接 name 查询。
- 常用操作：
  - `role.set_node_visible` 显隐
  - `role.set_label_text` 文本
  - `role.set_button_text` 按钮
  - `role.set_image_texture_by_key_with_auto_resize` 设置图标
- UI 3D 绑定层：`create_scene_ui_bind_unit` 绑定到角色或生物骨骼位（如称号系统）。

应用建议：大富翁角色头顶标识、格子事件提示可用 3D UI 绑定层，近距离显示/远距离隐藏。

## 4. 资源与预设使用
- 通过 `GameAPI.create_obstacle` 创建静态物体，传入 prefabId/位置/朝向/缩放/父对象。
- 通过 `GameAPI.create_creature_fixed_scale` 创建展示角色。
- `LuaAPI.query_unit("名字")` 获取编辑器场景中已有单位。

应用建议：地图地块、装饰物、事件物体可用 prefab + 对象池机制复用。

## 5. 物体池与动态加载
- 无穷大世界示例：
  - 根据玩家坐标计算网格 key。
  - `usedTiles` 存活表，`freeTiles` 作为对象池。
  - 通过加载半径/卸载半径控制创建与回收。

应用建议：大富翁中可用于“动态地图块 / 环形地图”的优化，避免频繁创建销毁。

## 6. 射线检测与焊接系统
- 动态搭建示例：
  - `GameAPI.raycast_unit` 从角色头顶向相机方向射线。
  - 命中后创建 `GameAPI.create_joint_assistant(Enums.JointAssistantKey.FIXED, a, b)`。
  - 关节标记 `set_kv_by_type(Enums.ValueType.Bool, "isDynamicStick", true)` 便于回收。

应用建议：大富翁可用于“建筑拼装/格子升级/装饰粘合”等需要动态绑定的玩法。

## 7. 商城与道具流程
### 7.1 官方商城商品
- `GameAPI.get_goods_list()` 读取官方商品。
- `role.show_goods_purchase_panel(goodsId, 10.0)` 打开购买面板。
- `role.get_commodity_count` / `role.consume_commodity` 查询/消耗。

应用建议：大富翁收费道具或通行证可以走官方商城流程。

### 7.2 自定义商店与经济
- 跑商玩法：
  - 用 KV 存储金币 `role.set_kv_by_type`。
  - `ItemManager` 管理创建/销毁/买卖，UIHandler 负责界面。
  - 商店基于触发区显示“购买/出售”按钮。
  - 价格刷新用 `EVENT.REPEAT_TIMEOUT`。

应用建议：大富翁内部金币/资产系统可以套用 KV + 商店刷新机制。

## 8. 存档与数据持久化
- 称号系统示例：
  - `role.get_archive_by_type` / `set_archive_by_type` 保存称号状态。
  - 使用配置表 `ArchivesData` 统一管理存档字段。

应用建议：大富翁的玩家资产、称号、卡牌解锁状态建议接入存档，避免重进丢失。

## 9. 定时器与帧更新
- `LuaAPI.global_register_trigger_event({ EVENT.REPEAT_TIMEOUT, 1.0 }, cb)` 每秒触发。
- 对性能敏感模块可用 tick handler 统一驱动更新列表（参考割草玩法）。

应用建议：
- 回合倒计时、商店刷新、事件提示可用 REPEAT_TIMEOUT。
- 全局动画/系统更新集中到 tickables 列表。

## 10. Lua 实用封装模式
- `Utils.ClassUtils.class` 提供类封装，适合玩法模块化。
- `FrameLoader` 等工具用于分帧加载，避免一次性创建卡顿。

应用建议：大富翁可封装为 “BoardManager / RoleManager / EventManager / UIManager” 类结构。

## 11. 适配大富翁的落地建议
1. 统一初始化入口：在 `EVENT.GAME_INIT` 里初始化核心管理器与 UI。
2. 地图格子逻辑建议触发区 + UI 组合，进入显示操作按钮，离开隐藏。
3. 回合制节奏建议用 `REPEAT_TIMEOUT` 或 tickables 管理，避免散落定时器。
4. 道具/事件物件建议使用 `ItemManager` 风格：创建-拾取-使用-销毁。
5. 玩家状态持久化统一走存档表，避免散落 KV。

## 12. 关键示例文件索引
- 动态焊接：`knowledge/LuaSource_动态搭建/StickController.lua`
- 动态地块：`knowledge/LuaSource_无限大世界/main.lua`
- 商城道具：`knowledge/LuaSource_商城道具/main.lua`
- 跑商玩法：`knowledge/LuaSource_跑商玩法/`
- 称号系统：`knowledge/LuaSource_称号系统/main.lua`
- 割草 Stage0 能力确认：`knowledge/LuaSource_生存割草/Stage0Demo.lua`
- UI 管理工具：`knowledge/LuaSource_汉堡UI/UIManager/`
