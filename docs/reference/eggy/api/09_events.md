---
kind: reference
status: stable
owner: eggy-vendor
last_verified: 2026-05-04
---
# 事件常量

---@class EVENT
EVENT = {}

---子弹命中
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
---事件回调参数 target_unit Unit 目标对象
---事件回调参数 dmg Fixed 伤害值
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_BULLET_HIT, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
	print(data.target_unit)
	print(data.dmg)
end)
--]]
EVENT.ABILITY_BULLET_HIT = "ABILITY_BULLET_HIT"

---技能切入
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
---事件回调参数 switch_out_ability Ability 切换前的技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_SWITCH_IN, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
	print(data.switch_out_ability)
end)
--]]
EVENT.ABILITY_SWITCH_IN = "ABILITY_SWITCH_IN"

---技能切出
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
---事件回调参数 switch_in_ability Ability 切换后的技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_SWITCH_OUT, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
	print(data.switch_in_ability)
end)
--]]
EVENT.ABILITY_SWITCH_OUT = "ABILITY_SWITCH_OUT"

---技能蓄力阶段开始
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_ACCUMULATE_BEGIN, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
end)
--]]
EVENT.ABILITY_ACCUMULATE_BEGIN = "ABILITY_ACCUMULATE_BEGIN"

---技能蓄力阶段被打断
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_ACCUMULATE_INTERRUPT, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
end)
--]]
EVENT.ABILITY_ACCUMULATE_INTERRUPT = "ABILITY_ACCUMULATE_INTERRUPT"

---技能蓄力阶段结束
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_ACCUMULATE_END, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
end)
--]]
EVENT.ABILITY_ACCUMULATE_END = "ABILITY_ACCUMULATE_END"

---技能施法阶段开始
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_CAST_BEGIN, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
end)
--]]
EVENT.ABILITY_CAST_BEGIN = "ABILITY_CAST_BEGIN"

---技能施法阶段被打断
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_CAST_BREAK, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
end)
--]]
EVENT.ABILITY_CAST_BREAK = "ABILITY_CAST_BREAK"

---技能施法阶段结束
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_CAST_END, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
end)
--]]
EVENT.ABILITY_CAST_END = "ABILITY_CAST_END"

---技能冷却完成
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_CD_END, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
end)
--]]
EVENT.ABILITY_CD_END = "ABILITY_CD_END"

---技能充能完成
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_CHARGE_END, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
end)
--]]
EVENT.ABILITY_CHARGE_END = "ABILITY_CHARGE_END"

---技能降级
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_DOWNGRADE, }, function(event_name, actor, data)
	print(data.ability)
end)
--]]
EVENT.ABILITY_DOWNGRADE = "ABILITY_DOWNGRADE"

---失去技能
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_REMOVE, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
end)
--]]
EVENT.ABILITY_REMOVE = "ABILITY_REMOVE"

---获得技能
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_ADD, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
end)
--]]
EVENT.ABILITY_ADD = "ABILITY_ADD"

---技能指定锚点开始
---事件主体 Ability 技能
---注册参数 _anchor AbilityAnchorID ABILITY_ANCHOR
---事件回调参数 ability Ability 触发技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_SPEC_ANCHOR_BEGIN, _anchor}, function(event_name, actor, data)
	print(data.ability)
end)
--]]
EVENT.ABILITY_SPEC_ANCHOR_BEGIN = "ABILITY_SPEC_ANCHOR_BEGIN"

---技能指定锚点被打断
---事件主体 Ability 技能
---注册参数 _anchor AbilityAnchorID ABILITY_ANCHOR
---事件回调参数 ability Ability 触发技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_SPEC_ANCHOR_BREAK, _anchor}, function(event_name, actor, data)
	print(data.ability)
end)
--]]
EVENT.ABILITY_SPEC_ANCHOR_BREAK = "ABILITY_SPEC_ANCHOR_BREAK"

---技能指定锚点结束
---事件主体 Ability 技能
---注册参数 _anchor AbilityAnchorID ABILITY_ANCHOR
---事件回调参数 ability Ability 触发技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_SPEC_ANCHOR_END, _anchor}, function(event_name, actor, data)
	print(data.ability)
end)
--]]
EVENT.ABILITY_SPEC_ANCHOR_END = "ABILITY_SPEC_ANCHOR_END"

---技能指定锚点停止
---事件主体 Ability 技能
---注册参数 _anchor AbilityAnchorID ABILITY_ANCHOR
---事件回调参数 ability Ability 触发技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_SPEC_ANCHOR_STOP, _anchor}, function(event_name, actor, data)
	print(data.ability)
end)
--]]
EVENT.ABILITY_SPEC_ANCHOR_STOP = "ABILITY_SPEC_ANCHOR_STOP"

---技能升级
---事件主体 Ability 技能
---事件回调参数 ability Ability 触发技能
---事件回调参数 unit Unit 技能拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.ABILITY_UPGRADE, }, function(event_name, actor, data)
	print(data.ability)
	print(data.unit)
end)
--]]
EVENT.ABILITY_UPGRADE = "ABILITY_UPGRADE"

---阵营积分变化
---事件主体 Global 全局触发器
---事件回调参数 camp Camp 触发阵营
---事件回调参数 old_camp_score integer 得分前积分
---事件回调参数 new_camp_score integer 得分后积分
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_CAMP_SCORE_UPDATE, }, function(event_name, actor, data)
	print(data.camp)
	print(data.old_camp_score)
	print(data.new_camp_score)
end)
--]]
EVENT.ANY_CAMP_SCORE_UPDATE = "ANY_CAMP_SCORE_UPDATE"

---任意触发区域创建
---事件主体 Global 全局触发器
---事件回调参数 unit CustomTriggerSpace 被创建的触发区域
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_CUSTOMTRIGGERSPACE_CREATE, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.ANY_CUSTOMTRIGGERSPACE_CREATE = "ANY_CUSTOMTRIGGERSPACE_CREATE"

---任意触发区域销毁
---事件主体 Global 全局触发器
---事件回调参数 unit CustomTriggerSpace 被销毁的触发区域
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_CUSTOMTRIGGERSPACE_DESTROY, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.ANY_CUSTOMTRIGGERSPACE_DESTROY = "ANY_CUSTOMTRIGGERSPACE_DESTROY"

---任意物品位置发生变化
---事件主体 Global 全局触发器
---事件回调参数 equipment Equipment 触发事件的物品
---事件回调参数 owner LifeEntity 持有者
---事件回调参数 old_slot_type Enums.EquipmentSlotType 旧槽位类型
---事件回调参数 old_index integer 旧槽位索引
---事件回调参数 new_slot_type Enums.EquipmentSlotType 新槽位类型
---事件回调参数 new_index integer 新槽位索引
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_EQUIPMENT_CHANGE_SLOT, }, function(event_name, actor, data)
	print(data.equipment)
	print(data.owner)
	print(data.old_slot_type)
	print(data.old_index)
	print(data.new_slot_type)
	print(data.new_index)
end)
--]]
EVENT.ANY_EQUIPMENT_CHANGE_SLOT = "ANY_EQUIPMENT_CHANGE_SLOT"

---任意物品进出区域事件
---事件主体 Global 全局触发器
---注册参数 _trigger_event_type Enums.TriggerSpaceEventType 触发类型
---注册参数 _customtriggerspace_id CustomTriggerSpaceID 触发区域ID
---事件回调参数 event_unit Equipment 触发物品
---事件回调参数 event_unit_id EquipmentID TRIGGER_EQUIPMENT_ID
---事件回调参数 trigger_event_type Enums.TriggerSpaceEventType 触发类型
---事件回调参数 trigger_zone_id CustomTriggerSpaceID 触发区域ID
---事件回调参数 trigger_zone CustomTriggerSpace 事件触发区域
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_EQUIPMENT_TRIGGER_SPACE, _trigger_event_type, _customtriggerspace_id}, function(event_name, actor, data)
	print(data.event_unit)
	print(data.event_unit_id)
	print(data.trigger_event_type)
	print(data.trigger_zone_id)
	print(data.trigger_zone)
end)
--]]
EVENT.ANY_EQUIPMENT_TRIGGER_SPACE = "ANY_EQUIPMENT_TRIGGER_SPACE"

---任意生命体进出区域事件
---事件主体 Global 全局触发器
---注册参数 _trigger_event_type Enums.TriggerSpaceEventType 触发类型
---注册参数 _trigger_zone_id CustomTriggerSpaceID 触发区域ID
---事件回调参数 event_unit LifeEntity 触发角色/生物
---事件回调参数 event_unit_id UnitID 触发角色/生物ID
---事件回调参数 trigger_event_type Enums.TriggerSpaceEventType 触发类型
---事件回调参数 trigger_zone_id CustomTriggerSpaceID 触发区域ID
---事件回调参数 trigger_zone CustomTriggerSpace 事件触发区域
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_LIFEENTITY_TRIGGER_SPACE, _trigger_event_type, _trigger_zone_id}, function(event_name, actor, data)
	print(data.event_unit)
	print(data.event_unit_id)
	print(data.trigger_event_type)
	print(data.trigger_zone_id)
	print(data.trigger_zone)
end)
--]]
EVENT.ANY_LIFEENTITY_TRIGGER_SPACE = "ANY_LIFEENTITY_TRIGGER_SPACE"

---任意组件创建
---事件主体 Global 全局触发器
---事件回调参数 unit Obstacle 被创建的组件
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_OBSTACLE_CREATE, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.ANY_OBSTACLE_CREATE = "ANY_OBSTACLE_CREATE"

---任意组件销毁
---事件主体 Global 全局触发器
---事件回调参数 unit Obstacle 被销毁的组件
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_OBSTACLE_DESTROY, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.ANY_OBSTACLE_DESTROY = "ANY_OBSTACLE_DESTROY"

---任意组件被举起
---事件主体 Global 全局触发器
---事件回调参数 lift_unit Unit 抓举者
---事件回调参数 lifted_unit Obstacle 被抓举者
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_OBSTACLE_LIFTED_BEGAN, }, function(event_name, actor, data)
	print(data.lift_unit)
	print(data.lifted_unit)
end)
--]]
EVENT.ANY_OBSTACLE_LIFTED_BEGAN = "ANY_OBSTACLE_LIFTED_BEGAN"

---任意组件被放下
---事件主体 Global 全局触发器
---事件回调参数 lift_unit Unit 抓举者
---事件回调参数 lifted_unit Obstacle 被抓举者
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_OBSTACLE_LIFTED_ENDED, }, function(event_name, actor, data)
	print(data.lift_unit)
	print(data.lifted_unit)
end)
--]]
EVENT.ANY_OBSTACLE_LIFTED_ENDED = "ANY_OBSTACLE_LIFTED_ENDED"

---任意组件进出触发区域
---事件主体 Global 全局触发器
---注册参数 _trigger_event_type Enums.TriggerSpaceEventType 触发类型
---注册参数 _trigger_zone_id CustomTriggerSpaceID 触发区域ID
---事件回调参数 event_unit Obstacle 触发组件
---事件回调参数 event_unit_id ObstacleID 触发组件ID
---事件回调参数 trigger_event_type Enums.TriggerSpaceEventType 触发类型
---事件回调参数 trigger_zone_id CustomTriggerSpaceID 触发区域ID
---事件回调参数 trigger_zone CustomTriggerSpace 事件触发区域
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_OBSTACLE_TRIGGER_SPACE, _trigger_event_type, _trigger_zone_id}, function(event_name, actor, data)
	print(data.event_unit)
	print(data.event_unit_id)
	print(data.trigger_event_type)
	print(data.trigger_zone_id)
	print(data.trigger_zone)
end)
--]]
EVENT.ANY_OBSTACLE_TRIGGER_SPACE = "ANY_OBSTACLE_TRIGGER_SPACE"

---任意玩家低帧率
---事件主体 Global 全局触发器
---注册参数 _frame_rate integer 当前帧数
---事件回调参数 role Role 目标玩家
---事件回调参数 frame_rate integer 当前帧数
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_ROLE_LOW_FPS, _frame_rate}, function(event_name, actor, data)
	print(data.role)
	print(data.frame_rate)
end)
--]]
EVENT.ANY_ROLE_LOW_FPS = "ANY_ROLE_LOW_FPS"

---玩家积分变化
---事件主体 Global 全局触发器
---事件回调参数 role Role 触发玩家
---事件回调参数 old_role_score integer 得分前积分
---事件回调参数 new_role_score integer 得分后积分
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_ROLE_SCORE_UPDATE, }, function(event_name, actor, data)
	print(data.role)
	print(data.old_role_score)
	print(data.new_role_score)
end)
--]]
EVENT.ANY_ROLE_SCORE_UPDATE = "ANY_ROLE_SCORE_UPDATE"

---任意逻辑体创建
---事件主体 Global 全局触发器
---事件回调参数 unit TriggerSpace 被创建的逻辑体
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_TRIGGERSPACE_CREATE, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.ANY_TRIGGERSPACE_CREATE = "ANY_TRIGGERSPACE_CREATE"

---任意逻辑体销毁
---事件主体 Global 全局触发器
---事件回调参数 unit TriggerSpace 被销毁的逻辑体
--[[
LuaAPI.global_register_trigger_event({EVENT.ANY_TRIGGERSPACE_DESTROY, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.ANY_TRIGGERSPACE_DESTROY = "ANY_TRIGGERSPACE_DESTROY"

---自定义事件
---事件主体 Default 多类型
---注册参数 _name string 自定义事件
--[[
LuaAPI.global_register_trigger_event({EVENT.CUSTOM_EVENT, _name}, function(event_name, actor, data)
end)
--]]
EVENT.CUSTOM_EVENT = "CUSTOM_EVENT"

---环境时间到达指定时刻
---事件主体 Global 全局触发器
---注册参数 _target_time Fixed TARGET_MAP_TIME
--[[
LuaAPI.global_register_trigger_event({EVENT.ENV_TIME_REACHED, _target_time}, function(event_name, actor, data)
end)
--]]
EVENT.ENV_TIME_REACHED = "ENV_TIME_REACHED"

---输入框输入完成
---事件主体 Default 多类型
---注册参数 _eui_input_text EInputField 输入框
---事件回调参数 role Role 触发玩家
---事件回调参数 content string 内容
--[[
LuaAPI.global_register_trigger_event({EVENT.UI_INPUT_TEXT_END_EVENT, _eui_input_text}, function(event_name, actor, data)
	print(data.role)
	print(data.content)
end)
--]]
EVENT.UI_INPUT_TEXT_END_EVENT = "UI_INPUT_TEXT_END_EVENT"

---界面控件触摸交互事件
---事件主体 Default 多类型
---注册参数 _node ENode 触发事件的界面控件
---注册参数 _touch_event_type ENodeTouchEventType T
---事件回调参数 role Role 触发事件的玩家
---事件回调参数 eui_node_id ENode 触发事件的界面控件
--[[
LuaAPI.global_register_trigger_event({EVENT.EUI_NODE_TOUCH_EVENT, _node, _touch_event_type}, function(event_name, actor, data)
	print(data.role)
	print(data.eui_node_id)
end)
--]]
EVENT.EUI_NODE_TOUCH_EVENT = "EUI_NODE_TOUCH_EVENT"

---游戏结束
---事件主体 Global 全局触发器
--[[
LuaAPI.global_register_trigger_event({EVENT.GAME_END, }, function(event_name, actor, data)
end)
--]]
EVENT.GAME_END = "GAME_END"

---游戏初始化
---事件主体 Global 全局触发器
--[[
LuaAPI.global_register_trigger_event({EVENT.GAME_INIT, }, function(event_name, actor, data)
end)
--]]
EVENT.GAME_INIT = "GAME_INIT"

---进入关卡
---事件主体 Default 多类型
---事件回调参数 level_key LevelKey 当前关卡
--[[
LuaAPI.global_register_trigger_event({EVENT.LEVEL_BEGIN, }, function(event_name, actor, data)
	print(data.level_key)
end)
--]]
EVENT.LEVEL_BEGIN = "LEVEL_BEGIN"

---离开关卡
---事件主体 Default 多类型
---事件回调参数 level_key LevelKey 当前关卡
--[[
LuaAPI.global_register_trigger_event({EVENT.LEVEL_END, }, function(event_name, actor, data)
	print(data.level_key)
end)
--]]
EVENT.LEVEL_END = "LEVEL_END"

---获得效果
---事件主体 Modifier 效果
---事件回调参数 from_unit_id UnitID 效果来源ID
---事件回调参数 modifier Modifier 触发效果
---事件回调参数 unit Unit 效果拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.MODIFIER_OBTAIN, }, function(event_name, actor, data)
	print(data.from_unit_id)
	print(data.modifier)
	print(data.unit)
end)
--]]
EVENT.MODIFIER_OBTAIN = "MODIFIER_OBTAIN"

---覆盖效果
---事件主体 Modifier 效果
---事件回调参数 modifier Modifier 触发效果
---事件回调参数 unit Unit 效果拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.MODIFIER_REOBTAIN, }, function(event_name, actor, data)
	print(data.modifier)
	print(data.unit)
end)
--]]
EVENT.MODIFIER_REOBTAIN = "MODIFIER_REOBTAIN"

---效果层数变化
---事件主体 Modifier 效果
---事件回调参数 stack_count_change integer 变化层数
---事件回调参数 modifier Modifier 触发效果
---事件回调参数 unit Unit 效果拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.MODIFIER_STACK_COUNT_CHANGE, }, function(event_name, actor, data)
	print(data.stack_count_change)
	print(data.modifier)
	print(data.unit)
end)
--]]
EVENT.MODIFIER_STACK_COUNT_CHANGE = "MODIFIER_STACK_COUNT_CHANGE"

---剧情动画开始播放事件
---事件主体 Default 多类型
---事件回调参数 play_role Role 触发角色
---事件回调参数 montage_id MontageKey 触发的剧情动画
---事件回调参数 start_time Fixed start_time
---事件回调参数 play_to_end boolean play_to_end
---事件回调参数 play_time Fixed play_time
---事件回调参数 transform_origin table transform_origin
--[[
LuaAPI.global_register_trigger_event({EVENT.ON_MONTAGE_BEGIN, }, function(event_name, actor, data)
	print(data.play_role)
	print(data.montage_id)
	print(data.start_time)
	print(data.play_to_end)
	print(data.play_time)
	print(data.transform_origin)
end)
--]]
EVENT.ON_MONTAGE_BEGIN = "ON_MONTAGE_BEGIN"

---剧情动画结束播放事件
---事件主体 Default 多类型
---事件回调参数 play_role Role 触发角色
---事件回调参数 montage_id MontageKey 触发的剧情动画
--[[
LuaAPI.global_register_trigger_event({EVENT.ON_MONTAGE_END, }, function(event_name, actor, data)
	print(data.play_role)
	print(data.montage_id)
end)
--]]
EVENT.ON_MONTAGE_END = "ON_MONTAGE_END"

---玩家进入拍照
---事件主体 Global 全局触发器
---事件回调参数 role Role 触发玩家
--[[
LuaAPI.global_register_trigger_event({EVENT.ON_PLAYER_ENTER_TAKE_PHOTO, }, function(event_name, actor, data)
	print(data.role)
end)
--]]
EVENT.ON_PLAYER_ENTER_TAKE_PHOTO = "ON_PLAYER_ENTER_TAKE_PHOTO"

---玩家退出拍照
---事件主体 Global 全局触发器
---事件回调参数 role Role 触发玩家
--[[
LuaAPI.global_register_trigger_event({EVENT.ON_PLAYER_LEAVE_TAKE_PHOTO, }, function(event_name, actor, data)
	print(data.role)
end)
--]]
EVENT.ON_PLAYER_LEAVE_TAKE_PHOTO = "ON_PLAYER_LEAVE_TAKE_PHOTO"

---玩家拍照
---事件主体 Global 全局触发器
---事件回调参数 role Role 触发玩家
--[[
LuaAPI.global_register_trigger_event({EVENT.ON_PLAYER_TAKE_PHOTO, }, function(event_name, actor, data)
	print(data.role)
end)
--]]
EVENT.ON_PLAYER_TAKE_PHOTO = "ON_PLAYER_TAKE_PHOTO"

---周期性计时器超时
---事件主体 Default 多类型
---注册参数 _delay Fixed 延时
--[[
LuaAPI.global_register_trigger_event({EVENT.REPEAT_TIMEOUT, _delay}, function(event_name, actor, data)
end)
--]]
EVENT.REPEAT_TIMEOUT = "REPEAT_TIMEOUT"

---天空环境变化
---事件主体 Global 全局触发器
--[[
LuaAPI.global_register_trigger_event({EVENT.ON_SKY_ENV_CHANGE, }, function(event_name, actor, data)
end)
--]]
EVENT.ON_SKY_ENV_CHANGE = "ON_SKY_ENV_CHANGE"

---指定角色开始攀爬
---事件主体 Character 角色
---事件回调参数 unit Character 触发角色
---事件回调参数 climb_target Obstacle 攀爬对象
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_CHARACTER_CLIMB_BEGIN, }, function(event_name, actor, data)
	print(data.unit)
	print(data.climb_target)
end)
--]]
EVENT.SPEC_CHARACTER_CLIMB_BEGIN = "SPEC_CHARACTER_CLIMB_BEGIN"

---指定角色结束攀爬
---事件主体 Character 角色
---事件回调参数 unit Character 触发角色
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_CHARACTER_CLIMB_END, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.SPEC_CHARACTER_CLIMB_END = "SPEC_CHARACTER_CLIMB_END"

---指定角色获得物品后
---事件主体 Character 角色
---事件回调参数 unit Character 触发角色
---事件回调参数 equipment Equipment 获得的物品
---事件回调参数 count integer 获取数量
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_CHARACTER_GET_EQUIPMENT, }, function(event_name, actor, data)
	print(data.unit)
	print(data.equipment)
	print(data.count)
end)
--]]
EVENT.SPEC_CHARACTER_GET_EQUIPMENT = "SPEC_CHARACTER_GET_EQUIPMENT"

---指定角色获得物品前
---事件主体 Character 角色
---事件回调参数 unit Character 触发角色
---事件回调参数 equipment Equipment 获得的物品
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_CHARACTER_GET_EQUIPMENT_BEFORE, }, function(event_name, actor, data)
	print(data.unit)
	print(data.equipment)
end)
--]]
EVENT.SPEC_CHARACTER_GET_EQUIPMENT_BEFORE = "SPEC_CHARACTER_GET_EQUIPMENT_BEFORE"

---指定角色失去物品
---事件主体 Character 角色
---事件回调参数 unit Character 触发角色
---事件回调参数 equipment Equipment 丢失的物品
---事件回调参数 slot_type Enums.EquipmentSlotType 物品槽位类型
---事件回调参数 slot_index integer 物品槽位索引
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_CHARACTER_LOST_EQUIPMENT, }, function(event_name, actor, data)
	print(data.unit)
	print(data.equipment)
	print(data.slot_type)
	print(data.slot_index)
end)
--]]
EVENT.SPEC_CHARACTER_LOST_EQUIPMENT = "SPEC_CHARACTER_LOST_EQUIPMENT"

---指定角色选中物品格
---事件主体 Character 角色
---注册参数 _slot_type Enums.EquipmentSlotType 物品格类型
---注册参数 _slot_index integer EQUIPMENT_SLOT_INDEX
---事件回调参数 event_unit Character 触发角色
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_CHARACTER_SELECT_EQUIPMENT_SLOT, _slot_type, _slot_index}, function(event_name, actor, data)
	print(data.event_unit)
end)
--]]
EVENT.SPEC_CHARACTER_SELECT_EQUIPMENT_SLOT = "SPEC_CHARACTER_SELECT_EQUIPMENT_SLOT"

---指定道具被获取
---事件主体 Default 多类型
---注册参数 _commodity_id UgcCommodity 商城道具
---事件回调参数 commodity_id UgcCommodity 商城道具
---事件回调参数 camp_role_owner Role 携带道具的玩家
---事件回调参数 commodity_num integer 获得数量
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_COMMODITY_OBTAIN, _commodity_id}, function(event_name, actor, data)
	print(data.commodity_id)
	print(data.camp_role_owner)
	print(data.commodity_num)
end)
--]]
EVENT.SPEC_COMMODITY_OBTAIN = "SPEC_COMMODITY_OBTAIN"

---指定生物互动按钮被按下
---事件主体 Creature 生物
---事件回调参数 interact_lifeentity LifeEntity 互动触发者
---事件回调参数 interact_unit Creature 互动目标
---事件回调参数 interact_id InteractBtnID 互动按钮
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_INTERACTED, }, function(event_name, actor, data)
	print(data.interact_lifeentity)
	print(data.interact_unit)
	print(data.interact_id)
end)
--]]
EVENT.SPEC_LIFEENTITY_INTERACTED = "SPEC_LIFEENTITY_INTERACTED"

---指定生物被点击开始
---事件主体 Creature 生物
---事件回调参数 touch_unit Role 点击玩家
---事件回调参数 touched_unit Creature 被点击的物体
---事件回调参数 touch_pos Vector3 点击位置
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_CREATURE_TOUCH_BEGIN, }, function(event_name, actor, data)
	print(data.touch_unit)
	print(data.touched_unit)
	print(data.touch_pos)
end)
--]]
EVENT.SPEC_CREATURE_TOUCH_BEGIN = "SPEC_CREATURE_TOUCH_BEGIN"

---指定生物被点击结束
---事件主体 Creature 生物
---事件回调参数 touch_unit Role 点击玩家
---事件回调参数 touched_unit Creature 被点击的物体
---事件回调参数 touch_pos Vector3 松开位置
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_CREATURE_TOUCH_END, }, function(event_name, actor, data)
	print(data.touch_unit)
	print(data.touched_unit)
	print(data.touch_pos)
end)
--]]
EVENT.SPEC_CREATURE_TOUCH_END = "SPEC_CREATURE_TOUCH_END"

---指定触发区域销毁
---事件主体 CustomTriggerSpace 触发区域
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_CUSTOMTRIGGERSPACE_DESTROY, }, function(event_name, actor, data)
end)
--]]
EVENT.SPEC_CUSTOMTRIGGERSPACE_DESTROY = "SPEC_CUSTOMTRIGGERSPACE_DESTROY"

---指定物品即将被批量使用
---事件主体 Equipment 物品
---事件回调参数 equipment Equipment 当前物品
---事件回调参数 equipment_user LifeEntity 使用物品的角色/生物
---事件回调参数 slot_type Enums.EquipmentSlotType 物品槽位类型
---事件回调参数 slot_index integer 物品槽位索引
---事件回调参数 use_count integer 批量使用次数
---事件回调参数 cost_count integer 批量使用消耗数
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_BATCH_USE_BEFORE, }, function(event_name, actor, data)
	print(data.equipment)
	print(data.equipment_user)
	print(data.slot_type)
	print(data.slot_index)
	print(data.use_count)
	print(data.cost_count)
end)
--]]
EVENT.SPEC_EQUIPMENT_BATCH_USE_BEFORE = "SPEC_EQUIPMENT_BATCH_USE_BEFORE"

---指定物品位置发生变化
---事件主体 Equipment 物品
---事件回调参数 equipment Equipment 当前物品
---事件回调参数 owner LifeEntity 持有者
---事件回调参数 old_slot_type Enums.EquipmentSlotType 旧槽位类型
---事件回调参数 old_index integer 旧槽位索引
---事件回调参数 new_slot_type Enums.EquipmentSlotType 新槽位类型
---事件回调参数 new_index integer 新槽位索引
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_CHANGE_SLOT, }, function(event_name, actor, data)
	print(data.equipment)
	print(data.owner)
	print(data.old_slot_type)
	print(data.old_index)
	print(data.new_slot_type)
	print(data.new_index)
end)
--]]
EVENT.SPEC_EQUIPMENT_CHANGE_SLOT = "SPEC_EQUIPMENT_CHANGE_SLOT"

---指定物品销毁事件
---事件主体 Equipment 物品
---事件回调参数 equipment Equipment 当前物品
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_DESTROY, }, function(event_name, actor, data)
	print(data.equipment)
end)
--]]
EVENT.SPEC_EQUIPMENT_DESTROY = "SPEC_EQUIPMENT_DESTROY"

---指定物品进入角色栏位
---事件主体 Equipment 物品
---注册参数 _slot_type Enums.EquipmentSlotType 物品格类型
---事件回调参数 equipment Equipment 当前物品
---事件回调参数 slot_type Enums.EquipmentSlotType 物品格类型
---事件回调参数 owner Character 触发事件的角色
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_ENTER_CHAR_SLOT, _slot_type}, function(event_name, actor, data)
	print(data.equipment)
	print(data.slot_type)
	print(data.owner)
end)
--]]
EVENT.SPEC_EQUIPMENT_ENTER_CHAR_SLOT = "SPEC_EQUIPMENT_ENTER_CHAR_SLOT"

---指定物品离开角色栏位
---事件主体 Equipment 物品
---注册参数 _slot_type Enums.EquipmentSlotType 物品格类型
---事件回调参数 equipment Equipment 当前物品
---事件回调参数 slot_type Enums.EquipmentSlotType 物品格类型
---事件回调参数 owner Character 触发事件的角色
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_LEAVE_CHAR_SLOT, _slot_type}, function(event_name, actor, data)
	print(data.equipment)
	print(data.slot_type)
	print(data.owner)
end)
--]]
EVENT.SPEC_EQUIPMENT_LEAVE_CHAR_SLOT = "SPEC_EQUIPMENT_LEAVE_CHAR_SLOT"

---指定物品被失去
---事件主体 Equipment 物品
---事件回调参数 equipment Equipment 当前物品
---事件回调参数 owner LifeEntity 持有者
---事件回调参数 slot_type Enums.EquipmentSlotType 物品槽位类型
---事件回调参数 slot_index integer 物品槽位索引
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_LOST, }, function(event_name, actor, data)
	print(data.equipment)
	print(data.owner)
	print(data.slot_type)
	print(data.slot_index)
end)
--]]
EVENT.SPEC_EQUIPMENT_LOST = "SPEC_EQUIPMENT_LOST"

---指定物品被获得
---事件主体 Equipment 物品
---事件回调参数 equipment Equipment 当前物品
---事件回调参数 owner LifeEntity 持有者
---事件回调参数 count integer 获得数量
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_OBTAIN, }, function(event_name, actor, data)
	print(data.equipment)
	print(data.owner)
	print(data.count)
end)
--]]
EVENT.SPEC_EQUIPMENT_OBTAIN = "SPEC_EQUIPMENT_OBTAIN"

---指定物品被选中
---事件主体 Equipment 物品
---事件回调参数 equipment Equipment 当前物品
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_SELECT, }, function(event_name, actor, data)
	print(data.equipment)
end)
--]]
EVENT.SPEC_EQUIPMENT_SELECT = "SPEC_EQUIPMENT_SELECT"

---指定物品堆叠层数变化
---事件主体 Equipment 物品
---事件回调参数 equipment Equipment 当前物品
---事件回调参数 variation integer 变化层数
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_STACK_NUM_CHANGE, }, function(event_name, actor, data)
	print(data.equipment)
	print(data.variation)
end)
--]]
EVENT.SPEC_EQUIPMENT_STACK_NUM_CHANGE = "SPEC_EQUIPMENT_STACK_NUM_CHANGE"

---指定物品发生位置交换
---事件主体 Equipment 物品
---事件回调参数 equipment Equipment 当前物品
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_SWAP_SLOT, }, function(event_name, actor, data)
	print(data.equipment)
end)
--]]
EVENT.SPEC_EQUIPMENT_SWAP_SLOT = "SPEC_EQUIPMENT_SWAP_SLOT"

---指定物品被取消选中
---事件主体 Equipment 物品
---事件回调参数 equipment Equipment 当前物品
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_UNSELECT, }, function(event_name, actor, data)
	print(data.equipment)
end)
--]]
EVENT.SPEC_EQUIPMENT_UNSELECT = "SPEC_EQUIPMENT_UNSELECT"

---指定物品被使用
---事件主体 Equipment 物品
---事件回调参数 equipment Equipment 当前物品
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_USE, }, function(event_name, actor, data)
	print(data.equipment)
end)
--]]
EVENT.SPEC_EQUIPMENT_USE = "SPEC_EQUIPMENT_USE"

---指定物品被使用前
---事件主体 Equipment 物品
---事件回调参数 equipment Equipment 当前物品
---事件回调参数 equipment_user LifeEntity 使用物品的角色/生物
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_EQUIPMENT_USE_BEFORE, }, function(event_name, actor, data)
	print(data.equipment)
	print(data.equipment_user)
end)
--]]
EVENT.SPEC_EQUIPMENT_USE_BEFORE = "SPEC_EQUIPMENT_USE_BEFORE"

---指定生命体技能降级
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 技能拥有者
---事件回调参数 ability Ability 触发技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_ABILITY_DOWNGRADE, }, function(event_name, actor, data)
	print(data.unit)
	print(data.ability)
end)
--]]
EVENT.SPEC_LIFEENTITY_ABILITY_DOWNGRADE = "SPEC_LIFEENTITY_ABILITY_DOWNGRADE"

---指定生命体获得技能
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 技能拥有者
---事件回调参数 ability Ability 触发技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_ABILITY_OBTAIN, }, function(event_name, actor, data)
	print(data.unit)
	print(data.ability)
end)
--]]
EVENT.SPEC_LIFEENTITY_ABILITY_OBTAIN = "SPEC_LIFEENTITY_ABILITY_OBTAIN"

---指定生命体失去技能
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 技能拥有者
---事件回调参数 ability Ability 触发技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_ABILITY_REMOVE, }, function(event_name, actor, data)
	print(data.unit)
	print(data.ability)
end)
--]]
EVENT.SPEC_LIFEENTITY_ABILITY_REMOVE = "SPEC_LIFEENTITY_ABILITY_REMOVE"

---指定生命体技能升级
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 技能拥有者
---事件回调参数 ability Ability 触发技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_ABILITY_UPGRADE, }, function(event_name, actor, data)
	print(data.unit)
	print(data.ability)
end)
--]]
EVENT.SPEC_LIFEENTITY_ABILITY_UPGRADE = "SPEC_LIFEENTITY_ABILITY_UPGRADE"

---指定生命体发生碰撞开始
---事件主体 LifeEntity 生命体
---事件回调参数 unit1 LifeEntity 碰撞者
---事件回调参数 unit2 Unit 被碰撞者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_CONTACT_BEGIN, }, function(event_name, actor, data)
	print(data.unit1)
	print(data.unit2)
end)
--]]
EVENT.SPEC_LIFEENTITY_CONTACT_BEGIN = "SPEC_LIFEENTITY_CONTACT_BEGIN"

---指定生命体发生碰撞结束
---事件主体 LifeEntity 生命体
---事件回调参数 unit1 LifeEntity 碰撞者
---事件回调参数 unit2 Unit 被碰撞者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_CONTACT_END, }, function(event_name, actor, data)
	print(data.unit1)
	print(data.unit2)
end)
--]]
EVENT.SPEC_LIFEENTITY_CONTACT_END = "SPEC_LIFEENTITY_CONTACT_END"

---指定生命体击败其他生命体
---事件主体 LifeEntity 生命体
---事件回调参数 dmg_unit LifeEntity 伤害来源
---事件回调参数 die_unit LifeEntity 被击败者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_DEFEAT, }, function(event_name, actor, data)
	print(data.dmg_unit)
	print(data.die_unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_DEFEAT = "SPEC_LIFEENTITY_DEFEAT"

---指定生命体被销毁
---事件主体 LifeEntity 生命体
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_DESTROY, }, function(event_name, actor, data)
end)
--]]
EVENT.SPEC_LIFEENTITY_DESTROY = "SPEC_LIFEENTITY_DESTROY"

---指定生命体被击败
---事件主体 LifeEntity 生命体
---事件回调参数 die_unit LifeEntity 被击败者
---事件回调参数 dmg_unit LifeEntity 伤害来源
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_DIE, }, function(event_name, actor, data)
	print(data.die_unit)
	print(data.dmg_unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_DIE = "SPEC_LIFEENTITY_DIE"

---指定生命体被击败前
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 被击败者
---事件回调参数 dmg_unit Unit 伤害来源
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_DIE_BEFORE, }, function(event_name, actor, data)
	print(data.unit)
	print(data.dmg_unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_DIE_BEFORE = "SPEC_LIFEENTITY_DIE_BEFORE"

---指定生命体受到伤害后
---事件主体 LifeEntity 生命体
---事件回调参数 _dmg_schema DamageSchema DAMAGE_TYPE
---事件回调参数 _src Unit 伤害来源
---事件回调参数 _dst LifeEntity 伤害目标
---事件回调参数 _dmg Damage DAMAGE_OBJ
---事件回调参数 _shield_value Fixed 被吸收的伤害值
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_DMGED_AFTER, }, function(event_name, actor, data)
	print(data._dmg_schema)
	print(data._src)
	print(data._dst)
	print(data._dmg)
	print(data._shield_value)
end)
--]]
EVENT.SPEC_LIFEENTITY_DMGED_AFTER = "SPEC_LIFEENTITY_DMGED_AFTER"

---指定生命体受到伤害前
---事件主体 LifeEntity 生命体
---事件回调参数 _dmg_schema DamageSchema DAMAGE_TYPE
---事件回调参数 _src Unit 伤害来源
---事件回调参数 _dst LifeEntity 伤害目标
---事件回调参数 _dmg Damage DAMAGE_OBJ
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_DMGED_BEFORE, }, function(event_name, actor, data)
	print(data._dmg_schema)
	print(data._src)
	print(data._dst)
	print(data._dmg)
end)
--]]
EVENT.SPEC_LIFEENTITY_DMGED_BEFORE = "SPEC_LIFEENTITY_DMGED_BEFORE"

---指定生命体造成伤害后
---事件主体 LifeEntity 生命体
---事件回调参数 _dmg_schema DamageSchema DAMAGE_TYPE
---事件回调参数 _src LifeEntity 伤害来源
---事件回调参数 _dst LifeEntity 伤害目标
---事件回调参数 _dmg Damage DAMAGE_OBJ
---事件回调参数 _shield_value Fixed 被吸收的伤害值
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_DMG_AFTER, }, function(event_name, actor, data)
	print(data._dmg_schema)
	print(data._src)
	print(data._dst)
	print(data._dmg)
	print(data._shield_value)
end)
--]]
EVENT.SPEC_LIFEENTITY_DMG_AFTER = "SPEC_LIFEENTITY_DMG_AFTER"

---指定生命体造成伤害前
---事件主体 LifeEntity 生命体
---事件回调参数 _dmg_schema DamageSchema DAMAGE_TYPE
---事件回调参数 _src LifeEntity 伤害来源
---事件回调参数 _dst LifeEntity 伤害目标
---事件回调参数 _dmg Damage DAMAGE_OBJ
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_DMG_BEFORE, }, function(event_name, actor, data)
	print(data._dmg_schema)
	print(data._src)
	print(data._dst)
	print(data._dmg)
end)
--]]
EVENT.SPEC_LIFEENTITY_DMG_BEFORE = "SPEC_LIFEENTITY_DMG_BEFORE"

---指定生命体上载具
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 触发角色/生物
---事件回调参数 vehicle Vehicle 触发载具
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_ENTER_VEHICLE, }, function(event_name, actor, data)
	print(data.unit)
	print(data.vehicle)
end)
--]]
EVENT.SPEC_LIFEENTITY_ENTER_VEHICLE = "SPEC_LIFEENTITY_ENTER_VEHICLE"

---指定生命体持有物品槽位发生变化
---事件主体 LifeEntity 生命体
---事件回调参数 equipment Equipment 触发物品
---事件回调参数 old_slot_type Enums.EquipmentSlotType 旧槽位类型
---事件回调参数 old_index integer 旧槽位索引
---事件回调参数 new_slot_type Enums.EquipmentSlotType 新槽位类型
---事件回调参数 new_index integer 新槽位索引
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_EQUIPMENT_SLOT_CHANGE, }, function(event_name, actor, data)
	print(data.equipment)
	print(data.old_slot_type)
	print(data.old_index)
	print(data.new_slot_type)
	print(data.new_index)
end)
--]]
EVENT.SPEC_LIFEENTITY_EQUIPMENT_SLOT_CHANGE = "SPEC_LIFEENTITY_EQUIPMENT_SLOT_CHANGE"

---指定生命体下载具
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 触发角色/生物
---事件回调参数 vehicle Vehicle 触发载具
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_EXIT_VEHICLE, }, function(event_name, actor, data)
	print(data.unit)
	print(data.vehicle)
end)
--]]
EVENT.SPEC_LIFEENTITY_EXIT_VEHICLE = "SPEC_LIFEENTITY_EXIT_VEHICLE"

---生命体获得经验
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 获得者
---事件回调参数 exp Fixed 经验值
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_GAIN_EXP, }, function(event_name, actor, data)
	print(data.unit)
	print(data.exp)
end)
--]]
EVENT.SPEC_LIFEENTITY_GAIN_EXP = "SPEC_LIFEENTITY_GAIN_EXP"

---指定生命体获得道具箱
---事件主体 LifeEntity 生命体
---事件回调参数 life_entity LifeEntity 获得道具的角色/生物
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_GET_ITEMBOX, }, function(event_name, actor, data)
	print(data.life_entity)
end)
--]]
EVENT.SPEC_LIFEENTITY_GET_ITEMBOX = "SPEC_LIFEENTITY_GET_ITEMBOX"

---指定生命体跳跃
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 跳跃者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_JUMP, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_JUMP = "SPEC_LIFEENTITY_JUMP"

---生命体升级
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 获得者
---事件回调参数 level integer 当前等级
---事件回调参数 ori_level integer 升级前等级
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_LEVEL_UP, }, function(event_name, actor, data)
	print(data.unit)
	print(data.level)
	print(data.ori_level)
end)
--]]
EVENT.SPEC_LIFEENTITY_LEVEL_UP = "SPEC_LIFEENTITY_LEVEL_UP"

---指定生命体被其他单位举起
---事件主体 LifeEntity 生命体
---事件回调参数 lift_unit Unit 抓举者
---事件回调参数 lifted_unit LifeEntity 被抓举者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_LIFTED_BEGIN, }, function(event_name, actor, data)
	print(data.lift_unit)
	print(data.lifted_unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_LIFTED_BEGIN = "SPEC_LIFEENTITY_LIFTED_BEGIN"

---指定生命体被其他单位放下
---事件主体 LifeEntity 生命体
---事件回调参数 lift_unit Unit 抓举者
---事件回调参数 lifted_unit LifeEntity 被抓举者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_LIFTED_END, }, function(event_name, actor, data)
	print(data.lift_unit)
	print(data.lifted_unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_LIFTED_END = "SPEC_LIFEENTITY_LIFTED_END"

---指定生命体举起其他单位
---事件主体 LifeEntity 生命体
---事件回调参数 lift_unit LifeEntity 抓举者
---事件回调参数 lifted_unit Unit 被抓举者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_LIFT_BEGIN, }, function(event_name, actor, data)
	print(data.lift_unit)
	print(data.lifted_unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_LIFT_BEGIN = "SPEC_LIFEENTITY_LIFT_BEGIN"

---指定生命体放下其他单位
---事件主体 LifeEntity 生命体
---事件回调参数 lift_unit LifeEntity 抓举者
---事件回调参数 lifted_unit Unit 被抓举者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_LIFT_END, }, function(event_name, actor, data)
	print(data.lift_unit)
	print(data.lifted_unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_LIFT_END = "SPEC_LIFEENTITY_LIFT_END"

---指定生命体移动开始
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 获得者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_MOVE_BEGIN, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_MOVE_BEGIN = "SPEC_LIFEENTITY_MOVE_BEGIN"

---指定生命体移动结束
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 获得者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_MOVE_END, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_MOVE_END = "SPEC_LIFEENTITY_MOVE_END"

---指定生命体复活
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 复活者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_REBORN, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_REBORN = "SPEC_LIFEENTITY_REBORN"

---指定生命体释放技能
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 触发角色/生物
---事件回调参数 ability Ability 触发技能
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_RELEASE_ABILITY, }, function(event_name, actor, data)
	print(data.unit)
	print(data.ability)
end)
--]]
EVENT.SPEC_LIFEENTITY_RELEASE_ABILITY = "SPEC_LIFEENTITY_RELEASE_ABILITY"

---指定生命体滚动开始
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 滚动者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_ROLL_BEGIN, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_ROLL_BEGIN = "SPEC_LIFEENTITY_ROLL_BEGIN"

---指定生命体滚动结束
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 滚动者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_ROLL_END, }, function(event_name, actor, data)
	print(data.unit)
end)
--]]
EVENT.SPEC_LIFEENTITY_ROLL_END = "SPEC_LIFEENTITY_ROLL_END"

---指定生命体前扑
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 前扑者
---事件回调参数 dir Vector3 前扑方向
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_RUSH, }, function(event_name, actor, data)
	print(data.unit)
	print(data.dir)
end)
--]]
EVENT.SPEC_LIFEENTITY_RUSH = "SPEC_LIFEENTITY_RUSH"

---指定生命体抓举
---事件主体 LifeEntity 生命体
---事件回调参数 unit LifeEntity 抓举者
---事件回调参数 dir Vector3 抓举方向
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_LIFEENTITY_START_LIFT, }, function(event_name, actor, data)
	print(data.unit)
	print(data.dir)
end)
--]]
EVENT.SPEC_LIFEENTITY_START_LIFT = "SPEC_LIFEENTITY_START_LIFT"

---失去效果
---事件主体 Modifier 效果
---事件回调参数 modifier Modifier 触发效果
---事件回调参数 unit Unit 效果拥有者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.MODIFIER_LOSS, }, function(event_name, actor, data)
	print(data.modifier)
	print(data.unit)
end)
--]]
EVENT.MODIFIER_LOSS = "MODIFIER_LOSS"

---指定组件发生碰撞开始
---事件主体 Obstacle 组件
---事件回调参数 unit1 Obstacle 碰撞者
---事件回调参数 unit2 Unit 被碰撞者
---事件回调参数 contact_pos Vector3 碰撞位置
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_OBSTACLE_CONTACT_BEGIN, }, function(event_name, actor, data)
	print(data.unit1)
	print(data.unit2)
	print(data.contact_pos)
end)
--]]
EVENT.SPEC_OBSTACLE_CONTACT_BEGIN = "SPEC_OBSTACLE_CONTACT_BEGIN"

---指定组件发生碰撞结束
---事件主体 Obstacle 组件
---事件回调参数 unit1 Obstacle 碰撞者
---事件回调参数 unit2 Unit 被碰撞者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_OBSTACLE_CONTACT_END, }, function(event_name, actor, data)
	print(data.unit1)
	print(data.unit2)
end)
--]]
EVENT.SPEC_OBSTACLE_CONTACT_END = "SPEC_OBSTACLE_CONTACT_END"

---指定组件销毁
---事件主体 Obstacle 组件
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_OBSTACLE_DESTROY, }, function(event_name, actor, data)
end)
--]]
EVENT.SPEC_OBSTACLE_DESTROY = "SPEC_OBSTACLE_DESTROY"

---指定组件互动按钮被按下
---事件主体 Obstacle 组件
---事件回调参数 interact_lifeentity LifeEntity 互动触发者
---事件回调参数 interact_unit Obstacle 互动目标
---事件回调参数 interact_id InteractBtnID 互动按钮
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_OBSTACLE_INTERACTED, }, function(event_name, actor, data)
	print(data.interact_lifeentity)
	print(data.interact_unit)
	print(data.interact_id)
end)
--]]
EVENT.SPEC_OBSTACLE_INTERACTED = "SPEC_OBSTACLE_INTERACTED"

---指定组件被举起
---事件主体 Obstacle 组件
---事件回调参数 lift_unit Unit 抓举者
---事件回调参数 lifted_unit Obstacle 被抓举者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_OBSTACLE_LIFTED_BEGIN, }, function(event_name, actor, data)
	print(data.lift_unit)
	print(data.lifted_unit)
end)
--]]
EVENT.SPEC_OBSTACLE_LIFTED_BEGIN = "SPEC_OBSTACLE_LIFTED_BEGIN"

---指定组件被放下
---事件主体 Obstacle 组件
---事件回调参数 lift_unit Unit 抓举者
---事件回调参数 lifted_unit Obstacle 被抓举者
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_OBSTACLE_LIFTED_END, }, function(event_name, actor, data)
	print(data.lift_unit)
	print(data.lifted_unit)
end)
--]]
EVENT.SPEC_OBSTACLE_LIFTED_END = "SPEC_OBSTACLE_LIFTED_END"

---指定组件受到伤害
---事件主体 Obstacle 组件
---事件回调参数 src Unit 伤害来源
---事件回调参数 src_ability Ability 来源技能
---事件回调参数 damage Fixed 伤害值
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_OBSTACLE_ON_DAMAGED, }, function(event_name, actor, data)
	print(data.src)
	print(data.src_ability)
	print(data.damage)
end)
--]]
EVENT.SPEC_OBSTACLE_ON_DAMAGED = "SPEC_OBSTACLE_ON_DAMAGED"

---指定组件被点击开始
---事件主体 Obstacle 组件
---事件回调参数 touch_unit Role 点击玩家
---事件回调参数 touched_unit Obstacle 被点击的物体
---事件回调参数 touch_pos Vector3 点击位置
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_OBSTACLE_TOUCH_BEGIN, }, function(event_name, actor, data)
	print(data.touch_unit)
	print(data.touched_unit)
	print(data.touch_pos)
end)
--]]
EVENT.SPEC_OBSTACLE_TOUCH_BEGIN = "SPEC_OBSTACLE_TOUCH_BEGIN"

---指定组件被点击结束
---事件主体 Obstacle 组件
---事件回调参数 touch_unit Role 点击玩家
---事件回调参数 touched_unit Obstacle 被点击的物体
---事件回调参数 touch_pos Vector3 松开位置
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_OBSTACLE_TOUCH_END, }, function(event_name, actor, data)
	print(data.touch_unit)
	print(data.touched_unit)
	print(data.touch_pos)
end)
--]]
EVENT.SPEC_OBSTACLE_TOUCH_END = "SPEC_OBSTACLE_TOUCH_END"

---指定玩家完成自定义成就
---事件主体 Global 全局触发器
---注册参数 _role RoleID 目标玩家
---事件回调参数 role Role 目标玩家
---事件回调参数 achieve_id Achievement 目标成就
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_ROLE_ACHIEVEMENT_COMPLETE, _role}, function(event_name, actor, data)
	print(data.role)
	print(data.achieve_id)
end)
--]]
EVENT.SPEC_ROLE_ACHIEVEMENT_COMPLETE = "SPEC_ROLE_ACHIEVEMENT_COMPLETE"

---指定玩家领取成就奖励
---事件主体 Global 全局触发器
---注册参数 _role RoleID 目标玩家
---注册参数 _achievement Achievement 目标成就
---事件回调参数 role Role 目标玩家
---事件回调参数 achieve_id Achievement 目标成就
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_ROLE_ACHIEVEMENT_REWARD_GAIN, _role, _achievement}, function(event_name, actor, data)
	print(data.role)
	print(data.achieve_id)
end)
--]]
EVENT.SPEC_ROLE_ACHIEVEMENT_REWARD_GAIN = "SPEC_ROLE_ACHIEVEMENT_REWARD_GAIN"

---指定玩家阵营发生变化
---事件主体 Global 全局触发器
---注册参数 _role RoleID 目标玩家
---事件回调参数 role Role 目标玩家
---事件回调参数 camp_before_change Camp 变化前的阵营
---事件回调参数 camp_after_change Camp 变化后的阵营
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_ROLE_CAMP_CHANGE, _role}, function(event_name, actor, data)
	print(data.role)
	print(data.camp_before_change)
	print(data.camp_after_change)
end)
--]]
EVENT.SPEC_ROLE_CAMP_CHANGE = "SPEC_ROLE_CAMP_CHANGE"

---指定玩家离开游戏
---事件主体 Global 全局触发器
---注册参数 _role Role 目标玩家
---事件回调参数 role Role 目标玩家
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_ROLE_EXIT_GAME, _role}, function(event_name, actor, data)
	print(data.role)
end)
--]]
EVENT.SPEC_ROLE_EXIT_GAME = "SPEC_ROLE_EXIT_GAME"

---指定玩家游戏失败
---事件主体 Global 全局触发器
---注册参数 _role RoleID 目标玩家
---事件回调参数 role Role 目标玩家
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_ROLE_GAME_LOSE, _role}, function(event_name, actor, data)
	print(data.role)
end)
--]]
EVENT.SPEC_ROLE_GAME_LOSE = "SPEC_ROLE_GAME_LOSE"

---指定玩家游戏胜利
---事件主体 Global 全局触发器
---注册参数 _role RoleID 目标玩家
---事件回调参数 role Role 目标玩家
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_ROLE_GAME_WIN, _role}, function(event_name, actor, data)
	print(data.role)
end)
--]]
EVENT.SPEC_ROLE_GAME_WIN = "SPEC_ROLE_GAME_WIN"

---指定玩家播放广告失败
---事件主体 Global 全局触发器
---注册参数 _role Role 目标玩家
---注册参数 _ad_tag string ADVERTISEMENT_TAG
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_ROLE_PLAY_ADVERTISEMENT_FAILURE, _role, _ad_tag}, function(event_name, actor, data)
end)
--]]
EVENT.SPEC_ROLE_PLAY_ADVERTISEMENT_FAILURE = "SPEC_ROLE_PLAY_ADVERTISEMENT_FAILURE"

---指定玩家播放广告成功
---事件主体 Global 全局触发器
---注册参数 _role Role 目标玩家
---注册参数 _ad_tag string ADVERTISEMENT_TAG
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_ROLE_PLAY_ADVERTISEMENT_SUCCESS, _role, _ad_tag}, function(event_name, actor, data)
end)
--]]
EVENT.SPEC_ROLE_PLAY_ADVERTISEMENT_SUCCESS = "SPEC_ROLE_PLAY_ADVERTISEMENT_SUCCESS"

---指定玩家成功购买商品
---事件主体 Global 全局触发器
---注册参数 _role RoleID 目标玩家
---事件回调参数 role Role 目标玩家
---事件回调参数 goods_id UgcGoods TARGET_GOODS
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_ROLE_PURCHASE_GOODS, _role}, function(event_name, actor, data)
	print(data.role)
	print(data.goods_id)
end)
--]]
EVENT.SPEC_ROLE_PURCHASE_GOODS = "SPEC_ROLE_PURCHASE_GOODS"

---指定玩家分享地图
---事件主体 Global 全局触发器
---注册参数 _role RoleID 目标玩家
---事件回调参数 role Role 目标玩家
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_ROLE_SHARE_MAP, _role}, function(event_name, actor, data)
	print(data.role)
end)
--]]
EVENT.SPEC_ROLE_SHARE_MAP = "SPEC_ROLE_SHARE_MAP"

---语音音量变化事件
---事件主体 Default 多类型
---注册参数 _role Role 目标玩家
---事件回调参数 voice_volume Fixed 当前的音量
--[[
LuaAPI.global_register_trigger_event({EVENT.SPEC_ROLE_VOICE_VOLUME_CHANGE, _role}, function(event_name, actor, data)
	print(data.voice_volume)
end)
--]]
EVENT.SPEC_ROLE_VOICE_VOLUME_CHANGE = "SPEC_ROLE_VOICE_VOLUME_CHANGE"

---指定逻辑体销毁
---事件主体 TriggerSpace 逻辑体
--[[
LuaAPI.unit_register_trigger_event(_unit, {EVENT.SPEC_TRIGGERSPACE_DESTROY, }, function(event_name, actor, data)
end)
--]]
EVENT.SPEC_TRIGGERSPACE_DESTROY = "SPEC_TRIGGERSPACE_DESTROY"

---计时器超时
---事件主体 Default 多类型
---注册参数 _delay Fixed DELAY_TIME
--[[
LuaAPI.global_register_trigger_event({EVENT.TIMEOUT, _delay}, function(event_name, actor, data)
end)
--]]
EVENT.TIMEOUT = "TIMEOUT"

---UI自定义事件(附带玩家)
---事件主体 Default 多类型
---注册参数 _name string 自定义事件
---事件回调参数 role_id RoleID 触发事件的玩家ID
---事件回调参数 role Role 触发事件的玩家
---事件回调参数 eui_node_id ENode 触发事件的界面控件
--[[
LuaAPI.global_register_trigger_event({EVENT.UI_CUSTOM_EVENT, _name}, function(event_name, actor, data)
	print(data.role_id)
	print(data.role)
	print(data.eui_node_id)
end)
--]]
EVENT.UI_CUSTOM_EVENT = "UI_CUSTOM_EVENT"
