# API指引（Eggy）

按官方“API指引”的功能系统结构整理，便于快速定位类型、枚举与主要API。

- 来源: `docs/eggy/EggyAPI.lua`

## 1. 单位与对象系统
### 相关类型
```lua
---@alias CampID integer 阵营ID
---@alias CharacterKey LifeEntityKey 角色编号
---@alias CreatureKey LifeEntityKey 生物编号
---@class Decoration: Unit
---@alias DecorationKey UnitKey 装饰物编号
---@alias EquipmentID UnitID 物品ID
---@alias EquipmentKey integer 物品编号
---@alias EquipmentSlot integer 物品槽位
---@class JointAssistant: JointAssistantComp, Unit
---@alias JointAssistantType integer 关节类型
---@alias LifeEntityKey UnitKey 生命体编号
---@alias ModifierKey integer 效果编号
---@alias ObstacleID UnitID 组件ID
---@alias ObstacleKey UnitKey 组件编号
---@alias PathID UnitID 路径ID
---@alias PathPointID UnitID 路点ID
---@class UnitGroup: Unit
---@alias UnitGroupKey UnitKey 组件组编号
---@alias UnitID integer 单位ID
---@alias UnitKey integer 单位编号
---@class Camp: AttrComp, KVBase
---@class Character: LifeEntity
---@class CharacterComp
---@class Creature: LifeEntity, OwnerComp
---@class DisplayComp
---@class Equipment: KVBase, OwnerComp, TriggerSystem
---@class EquipmentComp
---@class ItemBox: DisplayComp, ExprDeviceComp, SceneUI
---@class JointAssistantComp
---@class JumpComp
---@class LifeEntity: AbilityComp, AttrComp, BuffStateComp, CharacterComp, DisplayComp, EquipmentComp, JumpComp, LevelComp, LifeComp, LiftComp, LiftedComp, ModifierComp, MoveStatusComp, RollComp, RushComp, SceneUI, Unit, UnitInteractVolumeComp
---@class LiftComp
---@class LiftedComp
---@class Modifier: Actor
---@class ModifierComp
---@class MoveStatusComp
---@class Obstacle: DisplayComp, ExprDeviceComp, LiftedComp, OwnerComp, SceneUI, Unit, UnitInteractVolumeComp
---@class OwnerComp
---@class RollComp
---@class RushComp
---@class Unit: Actor
---@class UnitInteractVolumeComp
---@class VehicleComp
---@class VirtualEquipment
```

### 相关枚举
```lua
---@enum Enums.BuffState 状态
---@enum Enums.CampRelationType 阵营关系类型
---@enum Enums.CommonUnitType 常用单位类型
---@enum Enums.EquipmentSlotType 物品槽位类型
---@enum Enums.EquipmentType 物品类型
---@enum Enums.MoveMode AI移动模式
---@enum Enums.PatrolType AI巡逻类型
---@enum Enums.RigidBodyType 物理类型
---@enum Enums.UnitType 单位类型
```

### 主要API
```lua
AttrComp.change_attr_bonus_fixed(_key, _value)
AttrComp.change_attr_ratio_fixed(_key, _value)
AttrComp.change_attr_raw_fixed(_key, _value)
AttrComp.get_attr_base_extra_fixed(_key)
AttrComp.get_attr_bonus_fixed(_key)
AttrComp.get_attr_by_type(_value_type, _key)
AttrComp.get_attr_ratio_fixed(_key)
AttrComp.get_attr_raw_fixed(_key)
AttrComp.set_attr_bonus_fixed(_key, _value)
AttrComp.set_attr_by_type(_value_type, _key, _val)
AttrComp.set_attr_ratio_fixed(_key, _value)
AttrComp.set_attr_raw_fixed(_key, _value)
BuffStateComp.add_state(_state_id)
BuffStateComp.clear_state(_state_id)
BuffStateComp.get_state_count(_state_id)
BuffStateComp.get_state_list()
BuffStateComp.remove_state(_state_id)
Camp.change_camp_score(_add_score)
Camp.get_camp_role_list()
Camp.get_camp_score()
Camp.get_name()
Camp.get_roles()
Camp.set_camp_score(_score)
Character.change_character_prefab(_c_key, _reset_prop, _reset_trigger_system, _reset_model)
Character.change_model_by_creature(_creature, _include_custom_model, _inherit_scale, _inherit_capsule_size)
Character.change_target_socket_model(_model_socket, _creature, _creature_model_socket)
Character.change_target_socket_model_by_creature_key(_model_socket, _creature_key, _creature_model_socket)
Character.change_ugc_model_by_creature(_creature)
Character.change_ugc_model_by_creature_key(_creature_key)
Character.cmd_lift()
Character.cmd_move_to_pos(_target_pos, _duration)
Character.cmd_rush()
Character.destroy_buff(_modifier)
Character.enable_aim_move_mode(_enable)
Character.fling_rush()
Character.get_ability_point()
Character.get_buff(_modifier_id)
Character.get_buffs()
Character.get_camp_role()
Character.get_climb_obstacle()
Character.get_ctrl_role()
Character.get_face_dir()
Character.increase_ability_point(_increase)
Character.is_forced_moving()
Character.is_ghost_mode()
Character.is_have_buff_with_id(_modifier_key)
Character.jump()
Character.lift()
Character.recover_model()
Character.recover_target_socket_model(_model_socket)
Character.remove_buff(_modifier_id)
Character.reset_target_socket_model(_model_socket)
Character.set_aim_move_enabled(_enable)
Character.set_aim_move_mode(_enable)
Character.set_character_act_voice_enabled(_enabled)
Character.set_character_prefab(_c_key, _reset_prop, _reset_trigger_system, _reset_model)
Character.set_climb_enabled(_enable)
Character.set_climb_max_angle(_angle)
Character.set_climb_min_angle(_angle)
Character.set_climb_speed(_speed)
Character.set_mass_bar_visible(_visible)
Character.set_socket_model(_model_socket, _creature, _creature_model_socket)
Character.set_socket_model_by_creature_key(_model_socket, _creature_key, _creature_model_socket)
Character.set_voice_enabled(_enabled)
Character.start_forced_move(_vel, _duration, _enable_phy)
Character.start_move_to_pos(_target_pos, _duration)
Character.stop_forced_move()
Character.try_exit_ugcvehicle()
Character.try_exit_vehicle()
Creature.change_model_by_creature(_creature, _include_custom_model, _inherit_scale, _inherit_capsule_size)
Creature.change_target_socket_model(_model_socket, _creature, _creature_model_socket)
Creature.change_target_socket_model_by_creature_key(_model_socket, _creature_key, _creature_model_socket)
Creature.force_start_move(_direction, _t)
Creature.force_stop_move()
Creature.get_face_dir()
Creature.is_drag_enable()
Creature.is_touch_enable()
Creature.recover_model()
Creature.recover_target_socket_model(_model_socket)
Creature.reset_target_socket_model(_model_socket)
Creature.set_drag_enable(_enable)
Creature.set_draggable(_enable)
Creature.set_dragged_plane_type(_value)
Creature.set_mass_bar_visible(_visible)
Creature.set_name(_name)
Creature.set_name_visible(_visible)
Creature.set_socket_model(_model_socket, _creature, _creature_model_socket)
Creature.set_socket_model_by_creature_key(_model_socket, _creature_key, _creature_model_socket)
Creature.set_touch_drag_plane(_value)
Creature.set_touch_enable(_enable)
Creature.set_touchable(_enable)
DisplayComp.add_banned_anim(_anim_name)
DisplayComp.api_add_banned_anim(_anim_name)
DisplayComp.api_clear_banned_anim()
DisplayComp.api_remove_banned_anim(_anim_name)
DisplayComp.bind_model(_model_id, _socket, _offset, _rot, _scale)
DisplayComp.bind_model_by_unit(_unit, _socket, _offset, _rot)
DisplayComp.clear_banned_anim()
DisplayComp.play_body_anim_by_id(_anim_id, _start_time, _play_time, _is_loop)
DisplayComp.play_upper_anim_by_id(_anim_id, _start_time, _play_time, _is_loop)
DisplayComp.remove_banned_anim(_anim_name)
DisplayComp.remove_bind_model(_bind_id)
DisplayComp.set_anim_rate(_anim_rate)
DisplayComp.set_skeleton_scale(_skeleton, _scale)
DisplayComp.stop_anim()
DisplayComp.stop_play_body_anim()
DisplayComp.stop_play_body_anim_by_id(_anim_id)
DisplayComp.stop_play_body_anim_with_id(_anim_id)
DisplayComp.stop_play_upper_anim()
DisplayComp.stop_play_upper_anim_by_id(_anim_id)
DisplayComp.stop_play_upper_anim_with_id(_anim_id)
DisplayComp.ugc_add_bind_model(_model_id, _socket, _offset, _rot, _scale)
DisplayComp.unbind_model(_bind_id)
Equipment.can_drop()
Equipment.change_current_stack_size(_num)
Equipment.change_max_stack_size(_num)
Equipment.destroy_equipment()
Equipment.drop()
Equipment.get_current_stack_num()
Equipment.get_desc()
Equipment.get_economic_value(_res_type)
Equipment.get_equipment_slot()
Equipment.get_equipment_type()
Equipment.get_key()
Equipment.get_max_stack_num()
Equipment.get_name()
Equipment.get_owner_character()
Equipment.get_owner_creature()
Equipment.get_position()
Equipment.get_price(_res_type)
Equipment.get_slot_type()
Equipment.get_unit()
Equipment.has_owner()
Equipment.is_auto_picking()
Equipment.is_auto_using()
Equipment.move_to_slot(_slot_type, _slot)
Equipment.set_auto_aim(_is_auto_aim)
Equipment.set_auto_aim_enabled(_is_auto_aim)
Equipment.set_auto_fire(_is_auto_fire)
Equipment.set_auto_fire_enabled(_is_auto_fire)
Equipment.set_charge_cost_free(_is_free)
Equipment.set_current_stack_num(_num)
Equipment.set_desc(_desc)
Equipment.set_droppable(_droppable)
Equipment.set_economic_value(_res_type, _price)
Equipment.set_icon(_icon_key)
Equipment.set_max_stack_num(_num)
Equipment.set_name(_name)
Equipment.set_price(_res_type, _price)
Equipment.set_saleable(_saleable)
Equipment.set_usable(_usable)
Equipment.start_charge()
ItemBox.add_ability(_ability_key, _weight)
ItemBox.add_equipment(_key, _weight)
ItemBox.remove_ability(_ability_key)
ItemBox.remove_equipment(_key)
JumpComp.get_multi_jump_current_cooldown()
JumpComp.get_multi_jump_remaining_cooldown()
JumpComp.is_on_ground()
JumpComp.set_multi_jump_current_cooldown(_cd)
JumpComp.set_multi_jump_remaining_cooldown(_cd)
LifeEntity.activate_multi_animation(_anim_id, _acceptor_type)
LifeEntity.ai_command_alert(_tagert_pos, _target_dir, _dalay_time, _reject_time, _move_mode)
LifeEntity.ai_command_chase_with_ability(_target, _chase_range, _reject_time, _action_distance, _ability_key, _move_mode, _action_count)
LifeEntity.ai_command_chase_with_action(_target, _chase_range, _reject_time, _action_distance, _action_mode, _move_mode, _action_count)
LifeEntity.ai_command_chase_with_equipment(_target, _chase_range, _reject_time, _action_distance, _equipment_key, _move_mode, _action_count)
LifeEntity.ai_command_follow(_target_unit, _follow_dis, _tolerate_dis, _reject_time, _move_mode)
LifeEntity.ai_command_imitate(_target_unit, _delay, _disable_actions)
LifeEntity.ai_command_jump()
LifeEntity.ai_command_lift()
LifeEntity.ai_command_nav(_waypoint, _reject_time, _round_mode, _move_mode)
LifeEntity.ai_command_patrol(_waypoint, _reject_time, _round_mode, _move_mode)
LifeEntity.ai_command_pick_up_equipment(_target_equipment, _move_mode, _reject_time)
LifeEntity.ai_command_roll()
LifeEntity.ai_command_rush()
LifeEntity.ai_command_start_move(_direction, _t)
LifeEntity.ai_command_start_move_high_priority(_target_position, _duration, _threshold)
LifeEntity.ai_command_stop_move(_duration)
LifeEntity.change_model_by_character(_character, _include_ugc_model, _inherit_scale, _inherit_capsule_size)
LifeEntity.change_model_by_creature(_creature, _include_custom_model, _inherit_scale, _inherit_capsule_size)
LifeEntity.change_model_by_creature_key(_creature_key, _include_custom_model, _inherit_scale, _inherit_capsule_size)
LifeEntity.get_direction()
LifeEntity.get_face_dir()
LifeEntity.get_face_direction()
LifeEntity.get_hard_punch_threshold()
LifeEntity.get_hpbar_scale_x()
LifeEntity.get_hpbar_scale_y()
LifeEntity.get_lifted_lifeentity()
LifeEntity.get_lifted_obstacle()
LifeEntity.get_owner()
LifeEntity.get_punch_threshold()
LifeEntity.interrupt_multi_animation()
LifeEntity.is_drag_enable()
LifeEntity.is_draggable()
LifeEntity.is_ghost_mode()
LifeEntity.is_jumping()
LifeEntity.is_moving()
LifeEntity.is_rushing()
LifeEntity.is_touch_enable()
LifeEntity.is_touchable()
LifeEntity.jump()
LifeEntity.play_emoji_with_offset(_emoji_key, _show_time, _offset)
LifeEntity.play_face_emoji(_emoji_key, _show_time)
LifeEntity.play_face_expression(_emoji_key, _show_time)
LifeEntity.recover_model()
LifeEntity.reset_model()
LifeEntity.set_ai_move_threshold(_threshold)
LifeEntity.set_direction(_face_dir)
LifeEntity.set_face_dir(_face_dir)
LifeEntity.set_face_direction(_face_dir)
LifeEntity.set_hard_punch_threshold(_punch_threshold)
LifeEntity.set_hpbar_scale(_hpbar_scale_x, _hpbar_scale_y)
LifeEntity.set_mass_bar_visible(_visible)
LifeEntity.set_model_by_character(_character, _include_ugc_model, _inherit_scale, _inherit_capsule_size)
LifeEntity.set_model_by_creature(_creature, _include_custom_model, _inherit_scale, _inherit_capsule_size)
LifeEntity.set_model_by_creature_key(_creature_key, _include_custom_model, _inherit_scale, _inherit_capsule_size)
LifeEntity.set_multi_animation_acceptor_enabled(_enable)
LifeEntity.set_multi_animation_acceptor_type(_acceptor_type)
LifeEntity.set_punch_threshold(_punch_threshold)
LifeEntity.set_search_enemy_focus_target(_target)
LifeEntity.set_search_enemy_priority_value_by_tag(_tag, _priority)
LifeEntity.set_search_enemy_priority_value_by_unit(_unit, _priority)
LifeEntity.set_search_enemy_priority_value_by_unit_key(_unit_key, _priority)
LifeEntity.set_search_enemy_priority_value_by_unit_type(_unit_prefab_type, _priority)
LifeEntity.set_skeleton_offset(_skeleton, _offset)
LifeEntity.set_skeleton_scale(_skeleton, _scale)
LifeEntity.show_bubble_msg_with_offset(_show_msg, _show_time, _max_dis, _offset)
LifeEntity.start_ai()
LifeEntity.start_move_by_direction(_direction, _duration)
LifeEntity.start_move_to_pos_with_threshold(_target_pos, _duration, _threshold)
LifeEntity.stop_ai()
LifeEntity.swap_equipment_slot(_equipment, _slot_type, _slot)
LifeEntity.try_exit_vehicle()
LiftComp.get_lift_cd()
LiftComp.get_lift_cooldown()
LiftComp.get_lift_left_cd()
LiftComp.get_lift_remaining_cooldown()
LiftComp.is_lift_status()
LiftComp.lift_unit(_unit)
LiftComp.set_lift_cd(_cd_time)
LiftComp.set_lift_cooldown(_cd_time)
LiftComp.set_lift_left_cd(_time)
LiftComp.set_lift_remaining_cooldown(_time)
LiftedComp.is_lifted_enable()
LiftedComp.is_lifted_enabled()
LiftedComp.is_lifted_status()
LiftedComp.set_custom_thrown_force(_force)
LiftedComp.set_custom_thrown_force_enabled(_enable)
LiftedComp.set_is_use_custom_thrown_force(_enable)
LiftedComp.set_lifted_enable(_enable)
LiftedComp.set_lifted_enabled(_enable)
Modifier.add_duration(_add_time)
Modifier.add_stack_count(_stack_count_add)
Modifier.change_shield_value(_shield_value)
Modifier.get_desc()
Modifier.get_key()
Modifier.get_max_stack_count()
Modifier.get_name()
Modifier.get_owner_ability()
Modifier.get_owner_character()
Modifier.get_owner_creature()
Modifier.get_owner_life_entity()
Modifier.get_owner_unit()
Modifier.get_releaser_unit()
Modifier.get_remain_duration()
Modifier.get_remain_time()
Modifier.get_shield_value()
Modifier.get_stack_count()
Modifier.set_remain_duration(_remain_duration)
Modifier.set_remain_time(_remain_duration)
Modifier.set_shield_value(_shield_value)
Modifier.set_stack_count(_stack_count_add)
MoveStatusComp.is_fling_status()
MoveStatusComp.is_lost_control_status()
MoveStatusComp.start_face_lock_target(_target_unit, _time)
MoveStatusComp.stop_face_lock_target()
Obstacle.get_billboard_font_size()
Obstacle.get_billboard_text()
Obstacle.get_bound_equipment()
Obstacle.get_chess_rank()
Obstacle.get_chess_type()
Obstacle.is_drag_enable()
Obstacle.is_draggable()
Obstacle.is_touch_enable()
Obstacle.is_touchable()
Obstacle.reset_collision_limit(_limit_type)
Obstacle.set_billboard_font_size(_font_size)
Obstacle.set_billboard_text(_content)
Obstacle.set_billboard_text_color(_color, _gradient_color_1, _gradient_color_2, _gradient_color_3, _gradient_color_4)
Obstacle.set_chess_type_and_rank(_card_type, _card_rank)
Obstacle.set_climbable(_enable)
Obstacle.set_collision_count_limit(_limit_type, _value)
Obstacle.set_collision_interval_limit(_limit_type, _value)
Obstacle.set_collision_limit_count(_limit_type, _value)
Obstacle.set_collision_limit_interval(_limit_type, _value)
Obstacle.set_drag_enable(_enabled)
Obstacle.set_draggable(_enabled)
Obstacle.set_ranklist_score(_role, _score)
Obstacle.set_ranklist_score_by_role(_role, _score)
OwnerComp.change_owner(_role)
OwnerComp.get_owner_role()
RollComp.get_roll_cooldown()
RollComp.get_roll_left_cd()
RollComp.get_roll_remaining_cooldown()
RollComp.set_roll_cooldown(_time)
RollComp.set_roll_left_cd(_remaining_time)
RollComp.set_roll_remaining_cooldown(_remaining_time)
RushComp.get_rush_cooldown()
RushComp.get_rush_left_cd()
RushComp.get_rush_remaining_cooldown()
RushComp.set_rush_cooldown(_time)
RushComp.set_rush_left_cd(_time)
RushComp.set_rush_remaining_cooldown(_time)
Unit.add_ability_to_slot(_ability_index, _ability_id, _kv_args, _kv_types)
Unit.add_angular_motor(_vel, _time, _is_local)
Unit.add_child(_unit)
Unit.add_circle_motor(_vel, _time, _is_local)
Unit.add_linear_motor(_vel, _time, _is_local)
Unit.add_surround_motor(_follow_target, _ang_vel, _time, _follow_rotate)
Unit.add_ugc_skill_to_slot(_ability_index, _ability_id, _kv_args, _kv_types)
Unit.ai_command_alert(_tagert_pos, _target_dir, _dalay_time, _reject_time, _move_mode)
Unit.ai_command_follow(_target_unit, _follow_dis, _tolerate_dis, _reject_time, _move_mode)
Unit.ai_command_imitate(_target_unit, _delay, _disable_actions)
Unit.ai_command_jump()
Unit.ai_command_lift()
Unit.ai_command_nav(_waypoint, _reject_time, _round_mode, _move_mode)
Unit.ai_command_pick_up_equipment(_target_equipment, _move_mode, _reject_time)
Unit.ai_command_roll()
Unit.ai_command_rush()
Unit.ai_command_start_move(_direction, _t)
Unit.ai_command_start_move_high_priority(_target_position, _duration, _threshold)
Unit.ai_command_stop_move(_duration)
Unit.apply_force(_force)
Unit.apply_impact_force(_force, _max_speed, _force_lost_control, _lost_ctrl_time)
Unit.break_ability_accumulate()
Unit.break_ability_cast()
Unit.break_accumulate_skill()
Unit.break_cast_skill()
Unit.cast_ability_by_ability_slot_and_direction(_direction, _ability_slot, _duration)
Unit.cast_ability_by_ability_slot_and_position(_position, _ability_slot, _duration)
Unit.cast_ability_by_ability_slot_and_target(_target, _ability_slot, _duration)
Unit.cast_ability_by_direction(_ability_key, _duration, _direction, _ability_slot)
Unit.cast_ability_by_position(_ability_key, _duration, _position, _ability_slot)
Unit.cast_ability_by_target(_ability_key, _duration, _target, _ability_slot)
Unit.change_comp_color(_paint_area, _color)
Unit.change_owner(_role)
Unit.clear_selected_equipment_slot()
Unit.del_surround_motor()
Unit.destroy_ability(_ability)
Unit.destroy_skill(_ability)
Unit.disable_gravity()
Unit.disable_interact()
Unit.disable_motor(_index)
Unit.enable_gravity()
Unit.enable_interact()
Unit.enable_motor(_index)
Unit.execute_ability_by_ability_slot_index_and_dir(_direction, _ability_slot, _duration)
Unit.execute_ability_by_ability_slot_index_and_pos(_position, _ability_slot, _duration)
Unit.execute_ability_by_ability_slot_index_and_target(_target, _ability_slot, _duration)
Unit.execute_ability_by_dir(_ability_key, _duration, _direction, _ability_slot)
Unit.execute_ability_by_pos(_ability_key, _duration, _position, _ability_slot)
Unit.execute_ability_by_target(_ability_key, _duration, _target, _ability_slot)
Unit.get_abilities()
Unit.get_ability_by_slot(_ability_slot)
Unit.get_ability_in_slot(_ability_slot)
Unit.get_angular_velocity()
Unit.get_camp()
Unit.get_camp_id()
Unit.get_child_by_name(_name)
Unit.get_child_customtriggerspaces()
Unit.get_child_obstacles()
Unit.get_children()
Unit.get_children_customtriggerspace()
Unit.get_children_obstacle()
Unit.get_customtriggerspaces_random_point()
Unit.get_equipment_by_slot(_slot_type, _slot_index)
Unit.get_equipment_list(_equipment_key, _exclude_equipped, _exclude_bag)
Unit.get_equipment_list_by_slot(_slot_type)
Unit.get_equipment_max_num_by_slot(_slot_type)
Unit.get_key()
Unit.get_lift_cd()
Unit.get_lift_left_cd()
Unit.get_linear_velocity()
Unit.get_local_dir(_direction_type)
Unit.get_local_direction(_direction_type)
Unit.get_local_offset_position(_offset)
Unit.get_local_quaternion(_direction_type)
Unit.get_name()
Unit.get_orientation()
Unit.get_parent()
Unit.get_position()
Unit.get_rigid_body_type()
Unit.get_role()
Unit.get_role_id()
Unit.get_roll_left_cd()
Unit.get_rush_left_cd()
Unit.get_scale()
Unit.get_selected_equipment()
Unit.get_skills()
Unit.get_ugc_skill(_ability_slot)
Unit.get_unit_type()
Unit.hide_bubble_msg()
Unit.interrupt_ability()
Unit.is_character()
Unit.is_creature()
Unit.is_dynamic()
Unit.is_dynamic_body()
Unit.is_in_custom_trigger_space(_custom_trigger_space, _consider_mask)
Unit.is_in_customtriggerspace(_custom_trigger_space, _consider_mask)
Unit.is_kinematic_body()
Unit.is_model_visible()
Unit.is_physic_active()
Unit.is_physic_enable()
Unit.is_physics_active()
Unit.is_static_body()
Unit.is_valid_ability_target(_ability)
Unit.model_play_animation(_anim_name, _start_time, _is_loop, _play_speed)
Unit.model_stop_anim()
Unit.model_stop_animation()
Unit.play_3d_sound(_sound_key, _duration, _volume)
Unit.play_emoji(_emoji_key)
Unit.play_emoji_with_offset(_emoji_key, _show_time, _offset)
Unit.play_sound_with_dis_and_attenuation(_event_id, _vis_dis, _sound_attenuation_curve)
Unit.remove_ability(_ability_slot)
Unit.remove_ability_by_ability_key(_ability_key)
Unit.remove_ability_by_key(_ability_key)
Unit.remove_ability_in_slot(_ability_slot)
Unit.remove_from_parent()
Unit.remove_skill_by_skill_key(_ability_key)
Unit.remove_surround_motor()
Unit.remove_ugc_skill_in_slot(_ability_slot)
Unit.reset_ability_cd(_ability_index)
Unit.reset_skill_cd(_ability_index)
Unit.set_ability_to_slot(_ability, _ability_index)
Unit.set_acc_motor_init_velocity(_index, _init_vel)
Unit.set_angular_velocity(_vel)
Unit.set_lift_cd(_cd_time)
Unit.set_lift_left_cd(_time)
Unit.set_linear_motor_velocity(_index, _vel, _is_local)
Unit.set_linear_velocity(_vel)
Unit.set_mirror_reflect_enabled(_enable)
Unit.set_model_physic_visible(_is_active)
Unit.set_model_visible(_v)
Unit.set_orientation(_rot)
Unit.set_paint_area_color(_paint_area, _color)
Unit.set_paintarea_color(_paint_area, _color)
Unit.set_physic_enable(_is_active)
Unit.set_physics_active(_is_active)
Unit.set_position(_pos)
Unit.set_roll_left_cd(_remaining_time)
Unit.set_rush_cd(_time)
Unit.set_rush_left_cd(_time)
Unit.set_selected_equipment_slot(_slot_type, _slot_index)
Unit.set_skill_to_slot(_ability, _ability_index)
Unit.set_world_scale(_scale)
Unit.show_bubble_msg(_show_msg, _show_time, _max_dis, _offset)
Unit.start_ai()
Unit.stop_ai()
Unit.stop_sound(_lres_id)
Unit.vehicle_start_move(_direction, _duration)
Unit.vehicle_stop_move()
VehicleComp.reset()
VehicleComp.start_move_by_direction(_direction, _duration)
VehicleComp.stop_move()
VirtualEquipment.add_equipment_current_stack_num(_num)
VirtualEquipment.add_equipment_max_stack_num(_num)
VirtualEquipment.can_drop()
VirtualEquipment.change_current_stack_size(_num)
VirtualEquipment.change_max_stack_size(_num)
VirtualEquipment.destroy_equipment()
VirtualEquipment.get_current_stack_num()
VirtualEquipment.get_desc()
VirtualEquipment.get_economic_value(_res_type)
VirtualEquipment.get_equipment_auto_pick()
VirtualEquipment.get_equipment_auto_use()
VirtualEquipment.get_equipment_can_drop()
VirtualEquipment.get_equipment_current_stack_num()
VirtualEquipment.get_equipment_desc()
VirtualEquipment.get_equipment_key_prefab()
VirtualEquipment.get_equipment_max_stack_num()
VirtualEquipment.get_equipment_name()
VirtualEquipment.get_equipment_owner_character()
VirtualEquipment.get_equipment_owner_creature()
VirtualEquipment.get_equipment_slot()
VirtualEquipment.get_equipment_slot_index()
VirtualEquipment.get_equipment_slot_type()
VirtualEquipment.get_equipment_type()
VirtualEquipment.get_key()
VirtualEquipment.get_max_stack_num()
VirtualEquipment.get_name()
VirtualEquipment.get_owner_character()
VirtualEquipment.get_owner_creature()
VirtualEquipment.get_position()
VirtualEquipment.get_slot_index()
VirtualEquipment.get_slot_type()
VirtualEquipment.has_owner()
VirtualEquipment.is_auto_pick()
VirtualEquipment.is_auto_picking()
VirtualEquipment.is_auto_use()
VirtualEquipment.is_auto_using()
VirtualEquipment.set_current_stack_num(_num)
VirtualEquipment.set_desc(_desc)
VirtualEquipment.set_droppable(_droppable)
VirtualEquipment.set_economic_value(_res_type, _price)
VirtualEquipment.set_equipment_current_stack_num(_num)
VirtualEquipment.set_equipment_desc(_desc)
VirtualEquipment.set_equipment_icon(_icon_key)
VirtualEquipment.set_equipment_max_stack_num(_num)
VirtualEquipment.set_equipment_name(_name)
VirtualEquipment.set_icon(_icon_key)
VirtualEquipment.set_max_stack_num(_num)
VirtualEquipment.set_name(_name)
VirtualEquipment.set_usable(_usable)
```

## 2. 技能与战斗系统
### 相关类型
```lua
---@alias AbilityKey integer 技能编号
---@alias AbilitySlot integer 技能槽位
---@class Damage
---@alias DamageSchema integer 伤害方案
---@class Ability: Actor, AttrComp, KVBase, TriggerSystem
---@class AbilityComp
```

### 相关枚举
```lua
---@enum Enums.AbilityLimitation 技能使用限制
---@enum Enums.AbilityPointerType 技能指示器类型
---@enum Enums.AbilityTargetType 技能目标类型
```

### 主要API
```lua
Ability.ability_active_cd()
Ability.ability_api_change_affect_radius(_delta_affect_radius)
Ability.ability_api_change_affect_width(_delta_affect_width)
Ability.ability_api_change_max_release_distance(_delta_level)
Ability.ability_api_decrease_ability_level(_delta_level)
Ability.ability_api_get_ability_level()
Ability.ability_api_get_ability_max_level()
Ability.ability_api_get_affect_radius()
Ability.ability_api_get_affect_width()
Ability.ability_api_get_max_release_distance()
Ability.ability_api_increase_ability_level(_delta_level)
Ability.ability_api_set_ability_level(_new_level)
Ability.ability_api_set_ability_max_level(_new_max_level)
Ability.ability_api_set_affect_radius(_new_affect_radius)
Ability.ability_api_set_affect_width(_new_affect_width)
Ability.ability_api_set_max_release_distance(_new_max_release_distance)
Ability.add_state_to_target(_unit, _state_id)
Ability.begin_cast(_dir_info, _target_point, _target_unit)
Ability.break_accumulate()
Ability.break_cast()
Ability.change_affect_radius(_delta_affect_radius)
Ability.change_affect_width(_delta_affect_width)
Ability.change_max_release_distance(_delta_level)
Ability.downgrade_ability_level(_delta_level)
Ability.enter_cd()
Ability.get_ability_can_affect_character_list_v2(_height, _use_fixed_release_point)
Ability.get_ability_can_affect_creature_list_v2(_height, _use_fixed_release_point)
Ability.get_ability_can_affect_life_entity_list_v2(_height, _use_fixed_release_point)
Ability.get_ability_can_affect_obstacle_list_v2(_height, _use_fixed_release_point)
Ability.get_ability_index()
Ability.get_ability_level()
Ability.get_ability_max_level()
Ability.get_ability_slot()
Ability.get_accumulate_ratio()
Ability.get_affect_character_list(_height, _use_fixed_release_point)
Ability.get_affect_creature_list(_height, _use_fixed_release_point)
Ability.get_affect_lifeentity_list(_height, _use_fixed_release_point)
Ability.get_affect_obstacle_list(_height, _use_fixed_release_point)
Ability.get_affect_radius()
Ability.get_affect_width()
Ability.get_cd_time()
Ability.get_charge_time()
Ability.get_cur_release_num()
Ability.get_desc()
Ability.get_is_in_cd()
Ability.get_is_in_charge()
Ability.get_key()
Ability.get_left_cd_time()
Ability.get_left_charge_time()
Ability.get_limitation_active(_limit)
Ability.get_lock_obstacle()
Ability.get_lock_target()
Ability.get_lock_target_char()
Ability.get_lock_target_creature()
Ability.get_max_release_distance()
Ability.get_max_release_num()
Ability.get_name()
Ability.get_owner()
Ability.get_owner_character()
Ability.get_owner_creature()
Ability.get_owner_equipment()
Ability.get_owner_unit()
Ability.get_pointer_type()
Ability.get_release_dir()
Ability.get_release_direction()
Ability.get_release_direction_list()
Ability.get_release_point()
Ability.get_release_point_list()
Ability.is_in_cd()
Ability.is_in_charge()
Ability.is_limitation_enabled(_limit)
Ability.play_countdown_ui(_time)
Ability.remove_state_to_target(_unit, _state_id)
Ability.set_ability_level(_new_level)
Ability.set_ability_max_level(_new_max_level)
Ability.set_affect_radius(_new_affect_radius)
Ability.set_affect_width(_new_affect_width)
Ability.set_cur_release_num(_release_num)
Ability.set_left_cd_time(_cd_time)
Ability.set_left_charge_time(_cd_time)
Ability.set_max_release_distance(_new_max_release_distance)
Ability.set_max_release_num(_release_num_max)
Ability.upgrade_ability_level(_delta_level)
AbilityComp.add_ability_to_slot(_ability_index, _ability_id, _kv_args, _kv_types)
AbilityComp.add_item_ability_with_check(_ability_id, _kv_args, _kv_types)
AbilityComp.add_prop_ability(_ability_id, _kv_args, _kv_types)
AbilityComp.break_ability_accumulate()
AbilityComp.cast_ability_by_ability_slot_and_direction(_direction, _ability_slot, _duration)
AbilityComp.cast_ability_by_ability_slot_and_position(_position, _ability_slot, _duration)
AbilityComp.cast_ability_by_ability_slot_and_target(_target, _ability_slot, _duration)
AbilityComp.cast_ability_by_direction(_ability_key, _duration, _direction, _ability_slot)
AbilityComp.cast_ability_by_position(_ability_key, _duration, _position, _ability_slot)
AbilityComp.cast_ability_by_target(_ability_key, _duration, _target, _ability_slot)
AbilityComp.destroy_ability(_ability)
AbilityComp.get_abilities()
AbilityComp.get_ability_by_slot(_ability_slot)
AbilityComp.get_ability_list()
AbilityComp.get_prop_ability()
AbilityComp.interrupt_ability()
AbilityComp.remove_ability(_ability_slot)
AbilityComp.remove_ability_by_key(_ability_key)
AbilityComp.remove_prop_ability()
AbilityComp.reset_ability_cd(_ability_index)
AbilityComp.set_ability_enabled_on_vehicle(_enable)
AbilityComp.set_ability_to_slot(_ability, _ability_index)
GameAPI.ability_prefab_get_desc(_ability_id)
GameAPI.ability_prefab_get_name(_ability_id)
GameAPI.ability_prefab_get_prop_by_type(_value_type, _key, _prop)
GameAPI.ability_prefab_has_kv(_ability_key, _prop)
```

## 3. 触发与事件系统
### 相关类型
```lua
---@alias CustomTriggerSpaceID UnitID 触发区域ID
---@alias CustomTriggerSpaceKey UnitKey 触发区域编号
---@alias TriggerSpaceKey UnitKey 逻辑体编号
---@class CustomTriggerSpace: ExprDeviceComp, OwnerComp, SceneUI, Unit, UnitInteractVolumeComp
---@class TriggerSpace: ExprDeviceComp, OwnerComp, SceneUI, Unit, UnitInteractVolumeComp
---@class TriggerSystem
```

### 相关枚举
```lua
---@enum Enums.TriggerSpaceEventType 触发区域类型
```

### 主要API
```lua
CustomTriggerSpace.random_point()
GameAPI.create_customtriggerspace(_u_key, _pos, _rotation, _scale, _role)
GameAPI.create_triggerspace(_u_key, _pos, _rotation, _scale, _role)
LuaAPI.global_register_trigger_event(_event_desc, _callback)
LuaAPI.global_send_custom_event(_event_name, _data)
LuaAPI.global_unregister_trigger_event(_id)
LuaAPI.set_tick_handler(_pre_handler, _post_handler)
LuaAPI.unit_register_trigger_event(_unit, _event_desc, _callback)
LuaAPI.unit_send_custom_event(_unit, _event_name, _data)
LuaAPI.unit_unregister_trigger_event(_unit, _id)
TriggerSpace.get_virtual_light_brightness()
TriggerSpace.set_virtual_light_brightness(_brightness)
TriggerSystem.has_timer(_timer)
```

## 4. UI与交互系统
### 相关类型
```lua
---@alias E3DLayer string 场景UI实例
---@alias E3DLayerKey integer 场景UI预设
---@alias EAnimationState integer UI动画状态
---@alias EBagSlot ENode UI物品槽位节点
---@alias EButton ENode UI按钮节点
---@alias EEffectNode ENode UI动效节点
---@alias EImage ENode UI图片节点
---@alias EInputField ENode UI输入节点
---@alias ELabel ENode UI文本节点
---@alias ENode string UI节点
---@alias ENodeTouchEventType integer 界面交互事件类型
---@alias EProgressbar ENode UI进度条节点
---@class SceneUI
```

### 相关枚举
（未发现）

### 主要API
```lua
GameAPI.create_scene_ui_at_point(_layer_key, _pos, _duration)
LuaAPI.query_ui_node(_name)
LuaAPI.query_ui_nodes(_name_list)
Role.game_lose_and_show_result_panel()
Role.game_win_and_show_result_panel()
Role.play_ui_animation_effect(_effect_node)
Role.play_ui_effect(_effect_node)
Role.reset_animation(_node)
Role.send_ui_custom_event(_event_name, _data)
Role.set_animation_state(_node, _animation_name, _state)
Role.set_bagslot_related_life_entity(_bag_slot, _life_entity)
Role.set_bagslot_related_lifeentity(_bag_slot, _life_entity)
Role.set_battle_shop_visible(_battle_shop_id, _visible)
Role.set_button_enabled(_button, _enabled)
Role.set_button_font_size(_key, _font_size)
Role.set_button_normal_image(_button, _image_key)
Role.set_button_pressed_image(_button, _image_key)
Role.set_button_text(_button, _text)
Role.set_button_text_color(_button, _text_color)
Role.set_goods_panel_visible(_visible)
Role.set_goods_visible(_goods_key, _visible)
Role.set_image_color(_image, _image_color, _transition_time)
Role.set_image_texture_by_key_with_auto_resize(_image, _image_key, _reset_size)
Role.set_image_texture_with_auto_resize(_image, _image_path, _reset_size)
Role.set_image_texture_with_size(_image, _image_key, _reset_size)
Role.set_input_field_text(_input_field, _text)
Role.set_label_background_color(_label, _color, _transition_time)
Role.set_label_background_opacity(_label, _opacity, _transition_time)
Role.set_label_color(_label, _color, _transition_time)
Role.set_label_enable_outline(_label, _enable)
Role.set_label_enable_shadow(_label, _enable)
Role.set_label_font(_label, _font_key)
Role.set_label_font_size(_label, _font_size, _transition_time)
Role.set_label_outline_color(_label, _color)
Role.set_label_outline_enabled(_label, _enable)
Role.set_label_outline_opacity(_label, _opacity)
Role.set_label_outline_width(_label, _width)
Role.set_label_shadow_color(_label, _color)
Role.set_label_shadow_enabled(_label, _enable)
Role.set_label_shadow_x_offset(_label, _offset)
Role.set_label_shadow_y_offset(_label, _offset)
Role.set_label_text(_label, _text)
Role.set_name_visible(_visible)
Role.set_nickname_visible(_visible)
Role.set_node_touch_enabled(_node, _touch_enabled)
Role.set_node_visible(_node, _visible)
Role.set_progressbar_current(_progress_bar, _current)
Role.set_progressbar_max(_progress_bar, _max)
Role.set_progressbar_min(_progress_bar, _min)
Role.set_progressbar_transition(_progress_bar, _current, _transition_time)
Role.set_ugc_goods_panel_visible(_visible)
Role.set_ui_opacity(_node, _opacity)
Role.set_uipreset_visible(_ui, _visible)
Role.set_unit_visible(_unit, _is_visible)
Role.show_bag_panel(_visible)
Role.show_dynamic_text(_text, _pos, _color, _duration, _anim_type)
Role.show_goods_purchase_panel(_raw_goods_id, _show_time)
Role.show_like_interact_ui()
Role.show_like_panel()
Role.show_tips(_content, _duration)
Role.show_ugc_good_purchase_panel(_raw_goods_id, _show_time)
Role.show_ultimate_ability_panel(_keep_time)
Role.stop_ui_animation_effect(_effect_node)
Role.stop_ui_effect(_effect_node)
Role.unbind_label_text(_label)
Role.unbind_progressbar_current(_progress_bar)
Role.unbind_progressbar_max(_progress_bar)
```

## 5. 场景与相机系统
### 相关类型
```lua
---@class Vector3
---@class Quaternion
---@alias Color integer 颜色
---@alias SkyBoxBackground integer 天空盒背景
```

### 相关枚举
```lua
---@enum Enums.CameraBindMode 相机绑定模式
---@enum Enums.CameraDragType 相机拖动类型
---@enum Enums.CameraProjectionType 相机投影类型
---@enum Enums.CameraPropertyType 相机属性预设
---@enum Enums.CameraShakeCurve 屏幕震动曲线
---@enum Enums.CameraShakeType 屏幕震动类型
---@enum Enums.ColorPaintAreaType 染色区域
---@enum Enums.SkyBoxGradualType 天空盒渐变类型
```

### 主要API
```lua
math.Vector3(x, y, z)
math.Quaternion(pitch, yaw, roll)
GlobalAPI.change_render_color(_hue, _brightness, _saturation, _contrast, _amount, _mid_tones, _mid_tones_power, _shadows, _shadows_power, _highlight, _highlight_power, _duration)
GlobalAPI.set_direct_light(_param_dict, _duration)
GlobalAPI.set_render_color(_hue, _brightness, _saturation, _contrast, _amount, _mid_tones, _mid_tones_power, _shadows, _shadows_power, _highlight, _highlight_power, _duration)
GlobalAPI.set_skybox_texture(_texture_key, _change_type, _duration)
GlobalAPI.set_skyfog(_param_dict, _duration)
GameAPI.set_life_entity_survival_scene_boundary(_x, _y, _z)
GameAPI.set_unit_survival_scene_boundary(_x, _y, _z)
Role.get_camera_dir()
Role.get_camera_direction()
Role.get_camera_rotation()
Role.listen_camera_rotation(_enabled)
Role.pause_camera_motor()
Role.reset_camera(_reset_angle, _reset_bind, _reset_point, _reset_prop_pitch)
Role.resume_camera_motor()
Role.set_camera_bind_mode(_mode)
Role.set_camera_draggable(_draggable)
Role.set_camera_gyroscope_control_enabled(_is_control)
Role.set_camera_lock_position(_pos)
Role.set_camera_projection_type(_projection_type)
Role.set_camera_property(_property, _value)
Role.set_camera_rotation_by_direction(_target_dir, _duration)
Role.set_camera_rotation_sync_enabled(_enabled)
```

## 6. 音效与特效系统
### 相关类型
```lua
---@alias SfxID integer 特效ID
---@alias SfxKey integer 特效编号
---@alias SoundID integer 音效ID
---@alias SoundKey integer 音效编号
```

### 相关枚举
（未发现）

### 主要API
```lua
GlobalAPI.destroy_sfx(_sfx_id, _fade_out)
GlobalAPI.mute_sfx_sound(_sfx_id)
GlobalAPI.set_sfx_orientation(_sfx_id, _orientation)
GlobalAPI.set_sfx_position(_sfx_id, _pos)
GlobalAPI.set_sfx_rate(_sfx_id, _rate)
GlobalAPI.set_sfx_scale(_sfx_id, _scale)
GlobalAPI.set_sfx_visible(_sfx_id, _visible)
GameAPI.create_sfx_with_socket(_sfx_key, _unit, _socket_name, _scale, _duration, _bind_type)
GameAPI.create_sfx_with_socket_offset(_sfx_key, _unit, _socket_name, _offset, _rot, _scale, _duration, _bind_type)
GameAPI.play_3d_sound(_position, _sound_key, _duration, _volume)
GameAPI.play_link_sfx(_sfx_key, _unit, _from_socket_name, _target_unit, _target_socket_name, _duration)
GameAPI.play_sfx_by_key(_sfx_key, _pos, _rot, _scale, _duration, _rate, _with_sound)
GameAPI.stop_sound(_assigned_id)
Role.play_2d_sound_with_params(_event_id, _duration, _volume, _speed)
Role.play_screen_sfx(_sfx_key, _duration, _rate)
Role.stop_2d_sound(_sound_instance_id)
```

## 7. 存档与成就系统
### 相关类型
```lua
---@alias Achievement integer 自定义成就
---@alias Archive integer 自定义存档
```

### 相关枚举
```lua
---@enum Enums.ArchiveType 存档类型
```

### 主要API
```lua
Role.add_achieve_count(_event_id, _add_count)
Role.add_achievement_progress(_event_id, _add_count)
Role.get_achieve_count(_event_id)
Role.get_achievement_progress(_event_id)
Role.get_archive_by_type(_archive_type, _key)
Role.get_archive_configtable(_key)
Role.get_archive_sheetid(_key)
Role.is_achieve_finish(_event_id)
Role.is_achievement_completed(_event_id)
Role.set_achievement_progress(_event_id, _count)
Role.set_archive_by_type(_archive_type, _key, _val)
Role.set_archive_configtable(_key, _val)
Role.set_archive_point(_position, _priority, _direction)
Role.set_archive_sheetid(_key, _val)
```

## 8. 通用与工具API
### 相关类型
```lua
---@alias Fixed number
---@class dict
---@class (partial) math
---@alias AnimKey integer 动画编号
---@alias BattleShopKey integer 商店
---@alias ChessType integer 麻将/扑克花色
---@alias DynamicTextID integer 动态文字ID
---@alias EmojiKey integer 气泡表情编号
---@alias FontKey integer 字体key
---@alias ImageKey integer 图片编号
---@alias InteractBtnID integer 交互按钮编号
---@alias LevelKey string 关卡编号
---@alias MontageKey string 剧情动画编号
---@alias PaintArea integer 染色区域
---@alias RoleID integer 玩家ID
---@alias SheetID integer 表格
---@alias Skeleton string 骨骼
---@class Timer
---@alias Timestamp integer 时间戳
---@alias UIPreset string UIPreset
---@alias UgcCommodity integer 道具
---@alias UgcGoods string 商品
---@class Enums
---@class GlobalAPI
---@class Actor: KVBase, TriggerSystem
---@class AttrComp
---@class BuffStateComp
---@class ExprDeviceComp
---@class GameAPI
---@class GoodsInfo
---@alias CommodityInfo {[1]: UgcCommodity, [2]: integer}  {商品项目ID, 道具数量}
---@class KVBase
---@class LevelComp
---@class LifeComp
---@class LuaAPI
---@class Role: AttrComp, KVBase
---@class EVENT
```

### 相关枚举
```lua
---@enum Enums.AIBasicCommand AI基础命令类型
---@enum Enums.AxisType 方向轴类型
---@enum Enums.BindType 绑定类型
---@enum Enums.CollisionLimitType 碰撞限制枚举
---@enum Enums.CoordinateSystemType 坐标系类型
---@enum Enums.DirectionType 方向枚举
---@enum Enums.DropType 掉落类型
---@enum Enums.FixedRoundType 实数取整方式
---@enum Enums.FriendshipType 好友关系
---@enum Enums.GameResult 游戏结局
---@enum Enums.HpBarDisplayMode 血条显示模式
---@enum Enums.InteractBtnType 交互按钮类型
---@enum Enums.JointAssistantKey 关节预设编号
---@enum Enums.JointAssistantProperty 关节属性
---@enum Enums.ModelSocket 部位
---@enum Enums.NavMode AI寻路模式
---@enum Enums.OrientationType 方位枚举
---@enum Enums.PlaneType 拖动平面
---@enum Enums.QuestStatus 任务状态
---@enum Enums.SearchEnemyPriority 搜敌优先级模式
---@enum Enums.ValueType 值类型
---@enum Enums.WindFieldShapeType 风场形状
```

### 主要API
```lua
Vector3:set_pitch_yaw(pitch, yaw)
Vector3:length()
Vector3:getUnit()
Vector3:getAbsoluteVector()
Vector3:normalize()
Vector3:dot(rhs)
Vector3:cross(rhs)
Quaternion:inverse()
Quaternion:apply(v)
dict:set(key, value)
dict:get(key)
dict:keyvalues()
dict:keys()
dict:values()
math.tointeger(x)
math.toreal(x)
math.tofixed(x)
math.isfinite(x)
math.sin(x)
math.cos(x)
math.tan(x)
math.asin(x)
math.acos(x)
math.atan(x)
math.atan2(y, x)
math.sqrt(x)
math.log(x)
math.log2(x)
math.log10(x)
math.log1p(x)
math.exp(x)
math.exp2(x)
math.fmod(x, y)
math.pow(x, y)
math.round(x)
math.ceil(x)
math.floor(x)
math.trunc(x)
math.min(a, b)
math.max(a, b)
math.abs(a)
math.fabs(x)
math.clamp(x, min, max)
math.equal001(a, b)
math.rad_to_deg(rad)
math.deg_to_rad(deg)
GlobalAPI.add_kill_broadcast(_kill_char, _dead_char, _duration)
GlobalAPI.debug(_content)
GlobalAPI.error(_content)
GlobalAPI.get_lines_intersection_point_on_plane(_point_1, _point_2, _point_3, _point_4, _value, _plane_type)
GlobalAPI.get_point_to_line_perpendicular_point(_point_1, _point_2, _point_3)
GlobalAPI.get_vector_projection(_vec, _direction)
GlobalAPI.has_sub_str(_str1, _str2)
GlobalAPI.is_none(_obj)
GlobalAPI.is_not_none(_obj)
GlobalAPI.show_message_marquee(_content)
GlobalAPI.show_tips(_content, _duration)
GlobalAPI.str_contain(_str1, _str2)
GlobalAPI.str_contains(_str1, _str2)
GlobalAPI.str_to_color(_color_str)
GlobalAPI.warning(_content)
Actor.get_id()
CharacterComp.get_scale_ratio()
CharacterComp.is_forced_moving()
CharacterComp.set_face_dir(_face_dir)
CharacterComp.start_forced_move(_vel, _duration, _enable_phy)
CharacterComp.stop_forced_move()
EquipmentComp.clear_selected_equipment_slot()
EquipmentComp.consume_equipment(_equipment_key, _consume_num)
EquipmentComp.create_equipment_to_slot(_key, _slot_type)
EquipmentComp.get_equipment_by_slot(_slot_type, _slot_index)
EquipmentComp.get_equipment_list(_equipment_key, _exclude_equipped, _exclude_bag)
EquipmentComp.get_equipment_list_by_slot(_slot_type)
EquipmentComp.get_equipment_list_by_slot_type(_slot_type)
EquipmentComp.get_equipment_max_count(_slot_type)
EquipmentComp.get_equipment_max_num_by_slot(_slot_type)
EquipmentComp.get_selected_equipment()
EquipmentComp.select_equipment_slot(_slot_type, _slot_index)
EquipmentComp.set_equipment_max_count(_slot_type, _slot_num)
EquipmentComp.set_selected_equipment_slot(_slot_type, _slot_index)
ExprDeviceComp.disable_expr_device_by_name(_name)
ExprDeviceComp.enable_expr_device_by_name(_name)
GameAPI.add_pathpoint(_path_id, _index, _point_id)
GameAPI.add_road_point(_path_id, _index, _point_id)
GameAPI.add_sheet_column(_sheet_id, _key, _type_name)
GameAPI.add_table_column(_sheet_id, _key, _type_name)
GameAPI.clear_sheet(_sheet_id)
GameAPI.clear_table(_sheet_id)
GameAPI.config_table_add_column(_sheet_id, _key, _type_name)
GameAPI.copy_sheet(_sheet_id)
GameAPI.copy_table(_sheet_id)
GameAPI.create_config_table()
GameAPI.create_constant_wind_field(_pos, _wind_type, _wind_range, _duration)
GameAPI.create_creature_fixed_scale(_u_key, _pos, _rotation, _scale_ratio, _role)
GameAPI.create_decoration(_u_key, _pos, _rotation, _scale, _parent)
GameAPI.create_equipment(_equipment_eid, _pos)
GameAPI.create_equipment_in_scene(_equipment_eid, _pos)
GameAPI.create_joint_assistant(_unit_key, _unit1, _unit2)
GameAPI.create_life_entity(_unit_key, _pos, _rotation, _scale_ratio, _role)
GameAPI.create_obstacle(_u_key, _pos, _rotation, _scale, _role)
GameAPI.create_obstacle_from_geometry(_u_key, _pos, _rotation, _scale, _role, _geometry_path)
GameAPI.create_sheet()
GameAPI.create_table()
GameAPI.create_unit_group(_unit_group_id, _pos, _root_quaternion, _role)
GameAPI.create_unit_with_scale(_u_key, _pos, _rotation, _scale)
GameAPI.creature_prefab_get_kv_by_type(_value_type, _key, _prop)
GameAPI.creature_prefab_get_prop_by_type(_value_type, _key, _prop)
GameAPI.creature_prefab_has_kv(_unit_key, _prop)
GameAPI.customtriggerspace_prefab_get_kv_by_type(_value_type, _key, _prop)
GameAPI.customtriggerspace_prefab_get_prop_by_type(_value_type, _key, _prop)
GameAPI.customtriggerspace_prefab_has_kv(_key, _prop)
GameAPI.deal_damage(_dst, _dmg, _src, _schema, _data)
GameAPI.del_road_point(_path_id, _index)
GameAPI.destroy_scene_ui(_layer)
GameAPI.destroy_unit(_unit)
GameAPI.destroy_unit_with_children(_unit, _destroy_children)
GameAPI.enable_collision_between_unit_and_prefab(_unit, _unit_eid, _enable)
GameAPI.enable_collision_between_units(_unit_1, _unit_2, _enable)
GameAPI.equipment_prefab_has_kv(_equipment_key, _prop)
GameAPI.game_api_create_unit_group(_unit_group_id, _pos, _root_quaternion, _role)
GameAPI.game_end()
GameAPI.get_ability_prefab_desc(_ability_id)
GameAPI.get_ability_prefab_name(_ability_id)
GameAPI.get_achieve_target_count(_event_id)
GameAPI.get_achievement_target(_event_id)
GameAPI.get_all_camps()
GameAPI.get_all_characters()
GameAPI.get_all_creatures()
GameAPI.get_all_customtriggerspaces()
GameAPI.get_all_equipment_keys_in_shop(_battle_shop_key)
GameAPI.get_all_equipments()
GameAPI.get_all_lifientities()
GameAPI.get_all_obstacles()
GameAPI.get_all_online_roles()
GameAPI.get_all_roles()
GameAPI.get_all_roles_in_game()
GameAPI.get_all_triggerspaces()
GameAPI.get_all_valid_roles()
GameAPI.get_camp(_camp_id)
GameAPI.get_camp_relation(_camp1, _camp2)
GameAPI.get_characters_in_aabb(_center, _length, _height, _width)
GameAPI.get_characters_in_cylinder(_bottom_center, _radius, _height)
GameAPI.get_characters_in_sphere(_center, _radius)
GameAPI.get_config_table_col_len(_sheet_id)
GameAPI.get_config_table_row_len(_sheet_id)
GameAPI.get_creatures_by_key(_creature_key)
GameAPI.get_creatures_in_aabb(_center, _length, _height, _width)
GameAPI.get_creatures_in_annulus(_center, _radius1, _radius2, _height)
GameAPI.get_creatures_in_cylinder(_bottom_center, _radius, _height)
GameAPI.get_creatures_in_sector(_center, _face_dir, _central_angle, _radius, _height)
GameAPI.get_creatures_in_sphere(_center, _radius)
GameAPI.get_customtriggerspace_in_raycast(_start_pos, _end_pos)
GameAPI.get_customtriggerspaces_by_key(_key)
GameAPI.get_customtriggerspaces_in_raycast(_start_pos, _end_pos)
GameAPI.get_day(_timestamp)
GameAPI.get_env_time()
GameAPI.get_env_time_ratio()
GameAPI.get_env_time_running_enabled()
GameAPI.get_eui_child_by_index(_node, _index)
GameAPI.get_eui_child_by_name(_node, _name)
GameAPI.get_eui_children(_node)
GameAPI.get_eui_children_count(_node)
GameAPI.get_eui_node_at_scene_ui(_layer, _node_id)
GameAPI.get_first_customtriggerspace_in_raycast(_start_pos, _end_pos)
GameAPI.get_goods_list()
GameAPI.get_hour(_timestamp)
GameAPI.get_joint_assistants(_unit)
GameAPI.get_life_entities_in_aabb(_center, _length, _height, _width)
GameAPI.get_life_entities_in_cylinder(_bottom_center, _radius, _height)
GameAPI.get_life_entities_in_sphere(_center, _radius)
GameAPI.get_lifeentities_in_aabb(_center, _length, _height, _width)
GameAPI.get_lifeentities_in_cylinder(_bottom_center, _radius, _height)
GameAPI.get_lifeentities_in_sphere(_center, _radius)
GameAPI.get_map_appreciate_score()
GameAPI.get_map_characters()
GameAPI.get_map_rating_score()
GameAPI.get_map_time()
GameAPI.get_map_time_ratio()
GameAPI.get_map_time_running_enabled()
GameAPI.get_minute(_timestamp)
GameAPI.get_modifier_prefab_desc(_modifier_key)
GameAPI.get_modifier_prefab_name(_modifier_key)
GameAPI.get_montage_duration(_montage_id)
GameAPI.get_month(_timestamp)
GameAPI.get_obstacle_by_raycast(_start_pos, _end_pos)
GameAPI.get_obstacle_in_raycast(_start_pos, _end_pos)
GameAPI.get_obstacles_by_key(_key)
GameAPI.get_obstacles_by_raycast(_start_pos, _end_pos)
GameAPI.get_obstacles_in_aabb(_center, _length, _height, _width)
GameAPI.get_obstacles_in_annulus(_center, _radius1, _radius2, _height)
GameAPI.get_obstacles_in_cylinder(_bottom_center, _radius, _height)
GameAPI.get_obstacles_in_raycast(_start_pos, _end_pos)
GameAPI.get_obstacles_in_sector(_center, _face_dir, _central_angle, _radius, _height)
GameAPI.get_obstacles_in_sphere(_center, _radius)
GameAPI.get_pathpoint_by_id(_point_id)
GameAPI.get_pathpoint_by_index(_path_id, _index)
GameAPI.get_random_color()
GameAPI.get_road_point_vector3(_path_id, _index)
GameAPI.get_roadpoint_position(_point_id)
GameAPI.get_roadpoint_position_vector3(_point_id)
GameAPI.get_role(_role_id)
GameAPI.get_role_friendship_level(_role_1, _role_2)
GameAPI.get_role_friendship_value(_role_1, _role_2)
GameAPI.get_second(_timestamp)
GameAPI.get_sheet_col_count(_sheet_id)
GameAPI.get_sheet_row_count(_sheet_id)
GameAPI.get_sheet_value_by_type(_value_type, _sheet_id, _key1, _key2)
GameAPI.get_table_col_count(_sheet_id)
GameAPI.get_table_row_count(_sheet_id)
GameAPI.get_table_value_by_type(_value_type, _sheet_id, _key1, _key2)
GameAPI.get_timestamp()
GameAPI.get_timestamp_by_time(_year, _month, _day, _hour, _minute, _second)
GameAPI.get_timestamp_diff(_timestamp_1, _timestamp_2)
GameAPI.get_triggerspaces_by_key(_key)
GameAPI.get_unit(_unit_id)
GameAPI.get_unit_all_joint_assistant(_unit)
GameAPI.get_unit_id_by_name(_name)
GameAPI.get_vector3_from_path(_path_id)
GameAPI.get_vector3_list_from_road(_path_id)
GameAPI.get_vector3s_from_path(_path_id)
GameAPI.get_weekday(_timestamp)
GameAPI.get_year(_timestamp)
GameAPI.has_global_kv(_var_name)
GameAPI.has_var(_var_name)
GameAPI.is_archives_enabled()
GameAPI.is_point_in_custom_trigger_space(_point, _custom_trigger_space)
GameAPI.is_point_in_custom_trigger_spaces(_point, _custom_trigger_space)
GameAPI.is_point_in_customtriggerspace(_point, _custom_trigger_space)
GameAPI.is_role_friendship_type_match(_role_1, _role_2, _friendship_type)
GameAPI.is_role_friendship_type_matched(_role_1, _role_2, _friendship_type)
GameAPI.load_level(_level_key)
GameAPI.modifier_prefab_get_desc(_modifier_key)
GameAPI.modifier_prefab_get_name(_modifier_key)
GameAPI.modifier_prefab_get_prop_by_type(_value_type, _key, _prop)
GameAPI.modifier_prefab_has_kv(_modifier_key, _prop)
GameAPI.obstacle_prefab_get_kv_by_type(_value_type, _key, _prop)
GameAPI.obstacle_prefab_get_prop_by_type(_value_type, _key, _prop)
GameAPI.obstacle_prefab_has_kv(_key, _prop)
GameAPI.randint(_min_value, _max_value)
GameAPI.random_color()
GameAPI.random_int(_min_value, _max_value)
GameAPI.raycast_unit(_start_pos, _end_pos, _include_unit_types, _raycast_handler)
GameAPI.register_geometry_box(_size, _chamfer_radius, _chamfer_level, _use_box_collider, _preconf)
GameAPI.register_geometry_frustum(_height, _inner_radius, _outer_radius, _inner_poly_count, _outer_poly_count, _chamfer_radius, _angle, _layer, _bend, _preconf)
GameAPI.register_geometry_ring(_height, _inner_radius, _outer_radius, _inner_poly_count, _outer_poly_count, _chamfer_radius, _angle, _preconf)
GameAPI.register_geometry_spline(_is_rope, _pos_list, _normal_list, _radius_list, _dist_precision, _normal_precision, _depth, _preconf)
GameAPI.remove_pathpoint(_path_id, _index)
GameAPI.set_all_scene_ui_visible(_role, _visible)
GameAPI.set_enable_collide_unit_and_prefab(_unit, _unit_eid, _enable)
GameAPI.set_enable_collide_with_units(_unit_1, _unit_2, _enable)
GameAPI.set_env_time(_target_time, _duration, _direction)
GameAPI.set_env_time_ratio(_time_ratio)
GameAPI.set_env_time_running_enabled(_enabled)
GameAPI.set_equipment_current_stock_num(_battle_shop_key, _equipment_key, _cur_stock_count)
GameAPI.set_equipment_max_stock_count(_battle_shop_key, _equipment_key, _max_stock_count)
GameAPI.set_equipment_max_stock_num(_battle_shop_key, _equipment_key, _max_stock_count)
GameAPI.set_equipment_remaining_stock_count(_battle_shop_key, _equipment_key, _cur_stock_count)
GameAPI.set_global_wind_enabled(_bool_value)
GameAPI.set_global_wind_force(_x_value, _y_value)
GameAPI.set_global_wind_frequency(_fixed_value)
GameAPI.set_map_time(_target_time, _duration, _direction)
GameAPI.set_map_time_ratio(_time_ratio)
GameAPI.set_map_time_running_enabled(_enabled)
GameAPI.set_scene_ui_position(_role, _layer, _position)
GameAPI.set_scene_ui_visible(_layer, _role, _visible)
GameAPI.set_sheet_value_by_type(_value_type, _sheet_id, _key1, _key2, _val)
GameAPI.set_table_value_by_type(_value_type, _sheet_id, _key1, _key2, _val)
GameAPI.timestame_to_weekday(_timestamp)
GameAPI.triggerspace_prefab_get_kv_by_type(_value_type, _key, _prop)
GameAPI.triggerspace_prefab_get_prop_by_type(_value_type, _key, _prop)
GameAPI.triggerspace_prefab_has_kv(_key, _prop)
JointAssistantComp.get_joint_assistant_object1_obstacle()
JointAssistantComp.get_joint_assistant_object2_obstacle()
JointAssistantComp.get_joint_assistant_primary_obstacle()
JointAssistantComp.get_joint_assistant_target_obstacle()
JointAssistantComp.get_joint_assistant_type()
JointAssistantComp.set_joint_assistant_enabled(_enable)
JointAssistantComp.set_joint_assistant_property(_property_type, _value)
JointAssistantComp.set_joint_assistant_visible(_visible)
KVBase.add_tag(_tag)
KVBase.clear_kv()
KVBase.clear_tag()
KVBase.delete_tag(_tag)
KVBase.get_billboard_content()
KVBase.get_billboard_font_size()
KVBase.get_kv_by_type(_value_type, _key)
KVBase.has_kv(_key)
KVBase.has_tag(_tag)
KVBase.remove_kv(_key)
KVBase.remove_tag(_tag)
KVBase.set_billboard_content(_content)
KVBase.set_billboard_font_color(_color, _gradient_color_1, _gradient_color_2, _gradient_color_3, _gradient_color_4)
KVBase.set_billboard_font_size(_font_size)
KVBase.set_billboard_text_color(_color, _gradient_color_1, _gradient_color_2, _gradient_color_3, _gradient_color_4)
KVBase.set_kv_by_type(_value_type, _key, _val)
KVBase.set_tag(_tag)
LevelComp.gain_exp(_killed_exp)
LevelComp.get_exp()
LevelComp.get_killed_exp()
LevelComp.get_level()
LevelComp.level_up()
LevelComp.set_killed_exp(_killed_exp)
LifeComp.can_reborn()
LifeComp.change_hp(_value)
LifeComp.die(_dmg_unit)
LifeComp.get_hp()
LifeComp.get_hp_max()
LifeComp.get_life()
LifeComp.get_life_max()
LifeComp.is_die_status()
LifeComp.is_infinite_reborn()
LifeComp.reborn(_immediate)
LifeComp.set_auto_reborn(_auto_reborn)
LifeComp.set_auto_reborn_enable(_auto_reborn)
LifeComp.set_auto_reborn_enabled(_auto_reborn)
LifeComp.set_hp_max(_value)
LifeComp.set_infinite_reborn(_enable_reborn)
LifeComp.set_infinite_reborn_enable(_enable_reborn)
LifeComp.set_infinite_reborn_enabled(_enable_reborn)
LifeComp.set_life(_value)
LifeComp.set_life_count(_value)
LifeComp.set_life_max(_value)
LifeComp.set_reborn_in_place(_reborn_in_place, _reset_camera)
LifeComp.set_reborn_time(_reborn_time)
LuaAPI.call_delay_frame(_interval, _callback)
LuaAPI.call_delay_time(_interval, _callback)
LuaAPI.dispatch_flush()
LuaAPI.dispatch_init(_count)
LuaAPI.dispatch_queue(_i, _name, _args)
LuaAPI.enable_developer_mode()
LuaAPI.enable_error_interruption_mode(_enable)
LuaAPI.get_component_list(_obj)
LuaAPI.get_current_unit()
LuaAPI.get_dispatch_count()
LuaAPI.get_global_var(_var_name)
LuaAPI.get_unit_id(_unit)
LuaAPI.get_value_type(_value)
LuaAPI.global_register_custom_event(_event_name, _callback)
LuaAPI.global_unregister_custom_event(_id)
LuaAPI.has_component(_object, _name)
LuaAPI.log(_content)
LuaAPI.query_unit(_name)
LuaAPI.query_units(_name_list)
LuaAPI.query_units_by_type(_unit_type, _unit_eid)
LuaAPI.rand()
LuaAPI.set_deadloop_check_enabled(_enable, _max_instruction_count)
LuaAPI.unit_register_creation_handler(_unit_type, _unit_eid, _callback)
LuaAPI.unit_register_custom_event(_unit, _event_name, _callback)
LuaAPI.unit_unregister_creation_handler(_unit_type, _unit_eid)
LuaAPI.unit_unregister_custom_event(_unit, _id)
ModifierComp.add_modifier(_modifier_id)
ModifierComp.add_modifier_by_key(_modifier_id, _params_dict)
ModifierComp.destroy_buff(_modifier)
ModifierComp.destroy_modifier(_modifier)
ModifierComp.get_buff(_modifier_id)
ModifierComp.get_buffs()
ModifierComp.get_modifier_by_modifier_key(_modifier_id)
ModifierComp.get_modifiers()
ModifierComp.has_modifier_by_key(_modifier_key)
ModifierComp.remove_buff(_modifier_id)
ModifierComp.remove_modifier_by_key(_modifier_id)
ModifierComp.remove_modifier_by_modifier_key(_modifier_id)
Role.add_score(_add_score)
Role.consume_commodity(_commodity_id, _num)
Role.consume_ugc_commodity(_commodity_id, _num)
Role.disable_unit_fresnel(_unit)
Role.disable_unit_mask(_unit)
Role.disable_unit_outline(_unit)
Role.enter_watch_mode(_camp_limit, _exit_visible)
Role.exit_watch_mode()
Role.game_lose()
Role.get_camp()
Role.get_commodity_count(_commodity_id)
Role.get_ctrl_unit()
Role.get_game_result()
Role.get_head_icon()
Role.get_name()
Role.get_roleid()
Role.get_score()
Role.get_ugc_commodity_num(_commodity_id)
Role.get_voice_volume()
Role.has_commodity(_commodity_id)
Role.has_saved_archive()
Role.has_ugc_commodity(_commodity_id)
Role.is_gallery_vip()
Role.is_lose()
Role.is_losed()
Role.is_loss()
Role.is_lost()
Role.is_map_favorited()
Role.is_map_liked()
Role.is_online()
Role.is_pass_premium_vip()
Role.is_role_lose()
Role.is_role_win()
Role.is_subscribed_map_author()
Role.is_watch_mode()
Role.is_win()
Role.is_won()
Role.listen_gyroscope_info(_enabled)
Role.load_level_by_voting(_level_key)
Role.lose()
Role.play_advertisement_with_event(_success_event, _fail_event, _ad_tag, _success_data, _fail_data)
Role.play_montage(_montage_key, _start_time, _play_to_end, _play_time)
Role.play_montage_by_id(_montage_key, _start_time, _play_to_end, _play_time)
Role.send_track_data_change(_track_data_key, _change_num)
Role.send_track_data_log(_track_data_key, _change_num)
Role.set_achieve_count(_event_id, _count)
Role.set_blind_corner(_enable, _strength, _color)
Role.set_gyroscope_control_unit(_is_control, _unit)
Role.set_gyroscope_sync_enabled(_enabled)
Role.set_listen_camera_rotation(_enabled)
Role.set_role_camp(_camp)
Role.set_role_ctrl(_enable)
Role.set_role_ctrl_enabled(_enable)
Role.set_score(_score)
Role.set_unit_fresnel(_unit, _fresnel_scale, _color, _intensity)
Role.set_unit_fresnel_gradual(_unit, _fresnel_scale, _color, _intensity, _duration)
Role.set_unit_mask(_unit, _color)
Role.set_unit_outline(_unit, _width, _color)
Role.set_unit_see_through(_unit, _enabled)
Role.set_unit_see_through_enabled(_unit, _enabled)
Role.set_voice_volume_sync_enabled(_enabled)
Role.shake_camera(_shake_type, _shake_max_amplitude, _shake_time, _shake_source, _shake_frequency, _shake_time_decay, _shake_effect_scope, _shake_undamped_scope, _shake_distance_decay)
Role.skip_current_montage(_has_black_screen)
Role.start_level_vote(_level_key)
Role.start_vibration(_vibrate_type, _vibrate_count, _vibrate_interval)
Role.stop_camera_motor()
Role.stop_montage(_montage_key, _has_black_screen)
Role.vote_for_switch_level(_level_key)
Role.win()
SceneUI.create_scene_ui_bind_unit(_layer_key, _socket_name, _offset_pos, _duration, _bind_event, _inherit_visible)
UnitInteractVolumeComp.get_interact_id(_interact_index, _interact_btn_type)
UnitInteractVolumeComp.set_interact_btn_icon(_interact_id, _icon)
UnitInteractVolumeComp.set_interact_btn_name(_interact_id, _text)
UnitInteractVolumeComp.set_interact_button_icon(_interact_id, _icon)
UnitInteractVolumeComp.set_interact_button_text(_interact_id, _text)
UnitInteractVolumeComp.set_interact_button_text_by_index(_interact_index, _text)
UnitInteractVolumeComp.set_interact_enable(_enable)
UnitInteractVolumeComp.set_interact_enable_by_index(_interact_index, _enable)
UnitInteractVolumeComp.set_interact_enabled(_enable)
UnitInteractVolumeComp.set_interact_enabled_by_index(_interact_index, _enable)
```

## 9. 事件（EVENT）
### 主要事件类型
```lua
EVENT.ABILITY_ACCUMULATE_BEGIN
EVENT.ABILITY_ACCUMULATE_END
EVENT.ABILITY_ACCUMULATE_INTERRUPT
EVENT.ABILITY_ADD
EVENT.ABILITY_BULLET_HIT
EVENT.ABILITY_CAST_BEGIN
EVENT.ABILITY_CAST_BREAK
EVENT.ABILITY_CAST_END
EVENT.ABILITY_CD_END
EVENT.ABILITY_CHARGE_END
EVENT.ABILITY_DOWNGRADE
EVENT.ABILITY_REMOVE
EVENT.ABILITY_SWITCH_IN
EVENT.ABILITY_SWITCH_OUT
EVENT.ABILITY_UPGRADE
EVENT.ANY_CAMP_SCORE_UPDATE
EVENT.ANY_CUSTOMTRIGGERSPACE_CREATE
EVENT.ANY_CUSTOMTRIGGERSPACE_DESTROY
EVENT.ANY_EQUIPMENT_CHANGE_SLOT
EVENT.ANY_EQUIPMENT_TRIGGER_SPACE
EVENT.ANY_LIFEENTITY_TRIGGER_SPACE
EVENT.ANY_OBSTACLE_CREATE
EVENT.ANY_OBSTACLE_DESTROY
EVENT.ANY_OBSTACLE_LIFTED_BEGAN
EVENT.ANY_OBSTACLE_LIFTED_ENDED
EVENT.ANY_OBSTACLE_TRIGGER_SPACE
EVENT.ANY_ROLE_SCORE_UPDATE
EVENT.ANY_TRIGGERSPACE_CREATE
EVENT.ANY_TRIGGERSPACE_DESTROY
EVENT.CUSTOM_EVENT
EVENT.ENV_TIME_REACHED
EVENT.EUI_NODE_TOUCH_EVENT
EVENT.GAME_END
EVENT.GAME_INIT
EVENT.LEVEL_BEGIN
EVENT.LEVEL_END
EVENT.MODIFIER_LOSS
EVENT.MODIFIER_OBTAIN
EVENT.MODIFIER_REOBTAIN
EVENT.MODIFIER_STACK_COUNT_CHANGE
EVENT.ON_MONTAGE_BEGIN
EVENT.ON_MONTAGE_END
EVENT.ON_PLAYER_ENTER_TAKE_PHOTO
EVENT.ON_PLAYER_LEAVE_TAKE_PHOTO
EVENT.ON_PLAYER_TAKE_PHOTO
EVENT.ON_SKY_ENV_CHANGE
EVENT.REPEAT_TIMEOUT
EVENT.SPEC_CHARACTER_CLIMB_BEGIN
EVENT.SPEC_CHARACTER_CLIMB_END
EVENT.SPEC_CHARACTER_SELECT_EQUIPMENT_SLOT
EVENT.SPEC_COMMODITY_OBTAIN
EVENT.SPEC_CUSTOMTRIGGERSPACE_DESTROY
EVENT.SPEC_EQUIPMENT_CHANGE_SLOT
EVENT.SPEC_EQUIPMENT_DESTROY
EVENT.SPEC_EQUIPMENT_ENTER_CHAR_SLOT
EVENT.SPEC_EQUIPMENT_LEAVE_CHAR_SLOT
EVENT.SPEC_EQUIPMENT_LOST
EVENT.SPEC_EQUIPMENT_OBTAIN
EVENT.SPEC_EQUIPMENT_SELECT
EVENT.SPEC_EQUIPMENT_STACK_NUM_CHANGE
EVENT.SPEC_EQUIPMENT_SWAP_SLOT
EVENT.SPEC_EQUIPMENT_UNSELECT
EVENT.SPEC_EQUIPMENT_USE
EVENT.SPEC_EQUIPMENT_USE_BEFORE
EVENT.SPEC_LIFEENTITY_ABILITY_DOWNGRADE
EVENT.SPEC_LIFEENTITY_ABILITY_OBTAIN
EVENT.SPEC_LIFEENTITY_ABILITY_REMOVE
EVENT.SPEC_LIFEENTITY_ABILITY_UPGRADE
EVENT.SPEC_LIFEENTITY_CONTACT_BEGIN
EVENT.SPEC_LIFEENTITY_CONTACT_END
EVENT.SPEC_LIFEENTITY_DEFEAT
EVENT.SPEC_LIFEENTITY_DESTROY
EVENT.SPEC_LIFEENTITY_DIE
EVENT.SPEC_LIFEENTITY_DIE_BEFORE
EVENT.SPEC_LIFEENTITY_DMGED_AFTER
EVENT.SPEC_LIFEENTITY_DMGED_BEFORE
EVENT.SPEC_LIFEENTITY_DMG_AFTER
EVENT.SPEC_LIFEENTITY_DMG_BEFORE
EVENT.SPEC_LIFEENTITY_ENTER_VEHICLE
EVENT.SPEC_LIFEENTITY_EQUIPMENT_SLOT_CHANGE
EVENT.SPEC_LIFEENTITY_EXIT_VEHICLE
EVENT.SPEC_LIFEENTITY_GAIN_EXP
EVENT.SPEC_LIFEENTITY_GET_ITEMBOX
EVENT.SPEC_LIFEENTITY_INTERACTED
EVENT.SPEC_LIFEENTITY_JUMP
EVENT.SPEC_LIFEENTITY_LEVEL_UP
EVENT.SPEC_LIFEENTITY_LIFTED_BEGIN
EVENT.SPEC_LIFEENTITY_LIFTED_END
EVENT.SPEC_LIFEENTITY_LIFT_BEGIN
EVENT.SPEC_LIFEENTITY_LIFT_END
EVENT.SPEC_LIFEENTITY_MOVE_BEGIN
EVENT.SPEC_LIFEENTITY_MOVE_END
EVENT.SPEC_LIFEENTITY_REBORN
EVENT.SPEC_LIFEENTITY_RELEASE_ABILITY
EVENT.SPEC_LIFEENTITY_ROLL_BEGIN
EVENT.SPEC_LIFEENTITY_ROLL_END
EVENT.SPEC_LIFEENTITY_RUSH
EVENT.SPEC_LIFEENTITY_START_LIFT
EVENT.SPEC_OBSTACLE_CONTACT_BEGIN
EVENT.SPEC_OBSTACLE_CONTACT_END
EVENT.SPEC_OBSTACLE_DESTROY
EVENT.SPEC_OBSTACLE_INTERACTED
EVENT.SPEC_OBSTACLE_LIFTED_BEGIN
EVENT.SPEC_OBSTACLE_LIFTED_END
EVENT.SPEC_OBSTACLE_ON_DAMAGED
EVENT.SPEC_OBSTACLE_TOUCH_BEGIN
EVENT.SPEC_OBSTACLE_TOUCH_END
EVENT.SPEC_ROLE_ACHIEVEMENT_COMPLETE
EVENT.SPEC_ROLE_ACHIEVEMENT_REWARD_GAIN
EVENT.SPEC_ROLE_CAMP_CHANGE
EVENT.SPEC_ROLE_EXIT_GAME
EVENT.SPEC_ROLE_GAME_LOSE
EVENT.SPEC_ROLE_GAME_WIN
EVENT.SPEC_ROLE_PLAY_ADVERTISEMENT_FAILURE
EVENT.SPEC_ROLE_PLAY_ADVERTISEMENT_SUCCESS
EVENT.SPEC_ROLE_PURCHASE_GOODS
EVENT.SPEC_ROLE_VOICE_VOLUME_CHANGE
EVENT.SPEC_TRIGGERSPACE_DESTROY
EVENT.TIMEOUT
EVENT.UI_CUSTOM_EVENT
EVENT.UI_INPUT_TEXT_END_EVENT
```
