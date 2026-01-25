# Eggy 官方示例工程知识汇总（knowledge/）

> 目标: 从 knowledge/ 下的示例工程抽取可复用的脚本结构、事件/定时器/UI/资源使用方式，辅助 LuaSource_大富翁 开发。

## 总览与目录

knowledge/ 下包含多个独立示例工程，每个目录都是可直接放入 Eggitor 的 LuaSource。常见结构如下：

- `main.lua`：入口脚本，统一在 `EVENT.GAME_INIT` 中初始化。
- `Data/*`：由编辑器导出的静态配置（Prefab、UINodes、道具/怪物/称号等表）。
- `Utils/*`：通用工具，主要是 ClassUtils、MathUtils、Deque、FrameLoader 等。

示例目录一览：

- `LuaSource_动态搭建`：动态焊接/拼装玩法。
- `LuaSource_商城道具`：商品购买、消耗、商城 UI。
- `LuaSource_换装玩法`：换装区域与展示。
- `LuaSource_生存割草`：刷怪、生存、成长、装备与分帧加载。
- `LuaSource_称号系统`：称号存档、UI、3D UI。
- `LuaSource_无限大世界`：无限地块加载/回收。
- `LuaSource_自动跳台`：单位创建与碰撞触发。
- `LuaSource_空白图`：最小可运行模板。
- `LuaSource_跑商玩法`：买卖、触发区域、简易经济系统。

## 统一脚本模式（建议在 LuaSource_大富翁 复用）

1. **入口统一在 GAME_INIT**
   - `LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function() ... end)`
   - 在入口里初始化管理器、UI、事件监听。

2. **全局单例容器**
   - 多数示例把运行态对象放到 `G = {}`：如 `G.itemManager`、`G.monsterManager`。

3. **UI 操作以导出的 UINodes 为主**
   - `Data/UINodes.lua` 由编辑器导出，使用 `role.set_label_text`、`role.set_button_text` 等更新。

4. **定时器与 Tick 的两种用法**
   - Tick：`LuaAPI.set_tick_handler(onPreTick, onPostTick)`，适合高频更新。
   - 定时器：`EVENT.REPEAT_TIMEOUT`，适合 1s 刷新/倒计时。

5. **区域触发统一用 TriggerSpace 事件**
   - `EVENT.ANY_LIFEENTITY_TRIGGER_SPACE` + `Enums.TriggerSpaceEventType.ENTER/LEAVE`。

6. **Prefab 与资源 ID 来自 Data/Prefab**
   - 通过导出的 `Prefab.lua` 或其他 Data 表获得 prefabID，再使用 `GameAPI.create_*` 创建。

## 各示例核心知识点

### 1) LuaSource_空白图（最小模板）

- 入口：`knowledge/LuaSource_空白图/main.lua`
- 仅打印 `Hello, PC Editor Lua Script!`，用于验证脚本生效。
- 适合作为 LuaSource_大富翁 新模块的最小启动样例。

### 2) LuaSource_动态搭建（焊接/拼装）

- 入口：`knowledge/LuaSource_动态搭建/main.lua`
- 核心类：`StickController`
  - 监听 `SPEC_LIFEENTITY_LIFT_BEGAN/ENDED`，处理举起/放下。
  - 通过 `GameAPI.raycast_unit` 获取焊接点。
  - 用 `GameAPI.create_joint_assistant` 创建固定关节，并用 KV 标记可拆。
- 使用 `role.set_camera_rotation_sync_enabled(true)` 确保相机朝向与角色同步更新。
- UI：`Data/UINodes.lua` 中的“焊接按钮”控制显示。
- 可迁移点：用于大富翁中“道具拼接/建筑摆放/地块改造”。

### 3) LuaSource_商城道具（商品/消耗）

- 入口：`knowledge/LuaSource_商城道具/main.lua`
- 数据：`Data/GoodData.lua` 从 `GameAPI.get_goods_list()` 动态映射商品。
- 事件：自定义 UI 点击事件 + `EVENT.SPEC_ROLE_PURCHASE_GOODS` 购买成功回调。
- 角色商品 API：
  - `role.get_commodity_count`/`role.consume_commodity`
  - `role.show_goods_purchase_panel`
- 可迁移点：大富翁“皮肤/道具购买、商城入口”。

### 4) LuaSource_换装玩法（换装区）

- 入口：`knowledge/LuaSource_换装玩法/main.lua`
- 数据：`Data/DressUpData.lua` 定义装扮名和模型 key。
- 逻辑：
  - 在一个圆环内批量生成装扮区域（Prefab）。
  - 进入区域时调用 `character.set_model_by_creature_key`。
  - 退出或默认区域时 `character.reset_model()`。
- 可迁移点：用于角色换装或棋子外观切换区。

### 5) LuaSource_生存割草（刷怪+成长）

- 入口：`knowledge/LuaSource_生存割草/main.lua`
- 系统组成：
  - `MonsterManager`：刷怪波次、倒计时 UI、波次间隔。
  - `Monster`：怪物 AI、攻击、死亡回收。
  - `HeroManager/Hero`：等级、经验、UI 进度条。
  - `PrefabFactory`：对象池 + 分帧创建。
  - `FrameLoader` + `Deque`：分帧加载队列。
  - `Stage0Demo`：最小 API 能力验证示例（UI、存档、声音、定时器）。
- 可迁移点：
  - 大富翁“动态生成棋子/特效”的分帧加载。
  - 波次/计时器逻辑可借鉴为“回合倒计时/事件冷却”。

### 6) LuaSource_称号系统（称号存档+3D UI）

- 入口：`knowledge/LuaSource_称号系统/main.lua`
- 数据：`Data/ArchivesData.lua`（存档键）、`Data/DesignationData.lua`（称号配置）
- 核心流程：
  - 读取/写入存档：`role.get_archive_by_type`/`role.set_archive_by_type`。
  - 佩戴称号：更新 UI + 3D UI 图层。
  - 3D UI 绑定：`create_scene_ui_bind_unit` 绑定到 `socket_head`。
  - 距离判定显示：角色距离 < 10 时显示。
- 可迁移点：
  - 大富翁“角色头顶状态/称号/房产状态提示”。

### 7) LuaSource_跑商玩法（交易/经济）

- 入口：`knowledge/LuaSource_跑商玩法/main.lua`
- 结构：
  - `ItemManager`：生成/购买/出售/举起跟踪。
  - `BuyShop`：桌面商品刷新、倒计时公告牌。
  - `SellShop`：出售价格倍率与时间公告牌。
  - `TriggerAreaHandler`：统一进入/离开触发区域逻辑。
  - `UIHandler`：统一按钮点击事件与金币显示。
- 经济数据：`Data/ItemData.lua`（买价、概率、prefabID）。
- 可迁移点：
  - 大富翁“资产买卖/地块购买/市场刷新”。

### 8) LuaSource_无限大世界（动态地块加载）

- 入口：`knowledge/LuaSource_无限大世界/main.lua`
- 逻辑要点：
  - 以玩家位置为中心，LOAD/UNLOAD 半径控制地块创建与回收。
  - 使用 free list 复用地块模型，避免频繁创建销毁。
  - UI 实时显示玩家坐标。
- 可迁移点：
  - 大富翁“动态棋盘扩展/缓存棋盘单位”。

### 9) LuaSource_自动跳台（单位创建与碰撞）

- 入口：`knowledge/LuaSource_自动跳台/main.lua`
- 逻辑要点：
  - 监听指定预设的创建事件。
  - 碰撞时生成云朵，并在重生回调中选择是否清理。
- 可迁移点：
  - 大富翁“特定机关触发生成物体”。

## 常用 API 清单（从示例中抽取）

仅列出示例出现频率高且对大富翁有价值的 API。

- **事件注册**
  - `LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, fn)`
  - `LuaAPI.global_register_trigger_event({ EVENT.REPEAT_TIMEOUT, seconds }, fn)`
  - `LuaAPI.unit_register_trigger_event(unit, { EVENT.SPEC_LIFEENTITY_LIFT_BEGAN }, fn)`
  - `LuaAPI.global_register_custom_event("事件名", fn)`

- **角色 & UI**
  - `GameAPI.get_all_valid_roles()`
  - `role.set_label_text / set_button_text / set_node_visible / show_tips`
  - `role.set_kv_by_type / get_kv_by_type`（经济/状态值）
  - `role.get_archive_by_type / set_archive_by_type`（存档）

- **单位/资源创建**
  - `GameAPI.create_obstacle / create_unit_group / create_creature / create_equipment`
  - `LuaAPI.query_unit("名字")` 直接获取场景单位
  - `GameAPI.destroy_unit / destroy_unit_with_children`

- **场景 UI**
  - `create_scene_ui_bind_unit` 绑定 3D UI
  - `GameAPI.set_scene_ui_visible`

- **随机/射线**
  - `LuaAPI.rand()`
  - `GameAPI.raycast_unit()`

## 对 LuaSource_大富翁 的可落地建议

1. **沿用 `G` 容器**： 集中管理棋盘、角色、UI、计时器。
2. **地块/单位使用对象池**： 参考 `PrefabFactory` 或“无限大世界” free list 方案。
3. **回合/事件用定时器**： `EVENT.REPEAT_TIMEOUT` 适合倒计时或冷却。
4. **UI 节点统一来自 Data/UINodes**： 保证脚本与 Eggitor UI 一致。
5. **经济系统可参考跑商玩法**： 商品刷新、买卖、金币 UI 更新。
6. **称号系统可迁移为“角色头顶状态/资产提示”**。

## 参考文件索引（相对路径）

- `knowledge/LuaSource_空白图/main.lua`
- `knowledge/LuaSource_动态搭建/StickController.lua`
- `knowledge/LuaSource_商城道具/main.lua`
- `knowledge/LuaSource_换装玩法/main.lua`
- `knowledge/LuaSource_生存割草/main.lua`
- `knowledge/LuaSource_称号系统/main.lua`
- `knowledge/LuaSource_跑商玩法/main.lua`
- `knowledge/LuaSource_无限大世界/main.lua`
- `knowledge/LuaSource_自动跳台/main.lua`
