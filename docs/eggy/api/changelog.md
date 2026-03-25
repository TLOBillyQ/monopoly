# EggyAPI 变更记录

## 2026-01-30

Added: 26
  - Character.change_custom_model_by_creature
  - Character.change_custom_model_by_creature_key
  - Character.get_joystick_direction
  - DisplayComp.force_play_animation_by_anim_key
  - EVENT.SPEC_CREATURE_TOUCH_BEGIN
  - EVENT.SPEC_CREATURE_TOUCH_END
  - EVENT.SPEC_ROLE_SHARE_MAP
  - GameAPI.create_sfx_with_socket_offset
  - GameAPI.register_geometry_frustum
  - GameAPI.register_geometry_ring
  - GameAPI.register_geometry_spline
  - GlobalAPI.set_render_color
  - LifeEntity.ai_command_chase_with_ability
  - LifeEntity.ai_command_chase_with_action
  - LifeEntity.ai_command_chase_with_equipment
  - LifeEntity.disable_yaw_speed_limit
  - LifeEntity.set_max_yaw_speed
  - Obstacle.set_billboard_text_color
  - Role.shake_camera
  - SceneUI.create_scene_ui_bind_unit
  - Unit.get_current_mass
  - Unit.get_current_mass_center
  - Unit.set_current_mass
  - Unit.set_current_mass_center
  - Unit.set_orientation_smooth
  - Unit.set_position_smooth
Removed: 2
  - GlobalAPI.has_sub_str
  - GlobalAPI.str_contain
Signature changed: 1
  - LuaAPI.log: _content -> _content, _log_level
Type changed: 0

## 2026-02-08

Added: 11
  - GameAPI.create_sfx_with_socket_offset
  - GameAPI.register_geometry_frustum
  - GameAPI.register_geometry_ring
  - GameAPI.register_geometry_spline
  - GlobalAPI.set_render_color
  - LifeEntity.ai_command_chase_with_ability
  - LifeEntity.ai_command_chase_with_action
  - LifeEntity.ai_command_chase_with_equipment
  - Obstacle.set_billboard_text_color
  - Role.shake_camera
  - SceneUI.create_scene_ui_bind_unit
Removed: 0
Signature changed: 0
Type changed: 0

## 2026-03-11

Added: 1
  - Role.show_map_share_panel
Removed: 0
Signature changed: 1
  - GameAPI.create_unit_group: _unit_group_id, _pos, _root_quaternion, _role -> _unit_group_id, _pos, _root_quaternion, _role, _use_center_offset
Type changed: 0

## 2026-03-25

新增 / Added: 23
  - AbilityAnchorID
  - DebugAPI
  - DebugAPI.draw_line
  - DebugAPI.draw_text
  - EVENT.ABILITY_SPEC_ANCHOR_BEGIN
  - EVENT.ABILITY_SPEC_ANCHOR_BREAK
  - EVENT.ABILITY_SPEC_ANCHOR_END
  - EVENT.ABILITY_SPEC_ANCHOR_STOP
  - EVENT.ANY_ROLE_LOW_FPS
  - EVENT.SPEC_EQUIPMENT_BATCH_USE_BEFORE
  - GameAPI.copy_vehicle
  - GameAPI.create_vehicle
  - GameAPI.delay_destroy_vehicle
  - GameAPI.get_driving_vehicle
  - GameAPI.get_party_roles
  - LifeEntity.try_enter_vehicle
  - ListAbilityAnchorID
  - ListVehicle
  - ListVehicleKey
  - Role.get_party_id
  - Unit.set_scale
  - Vehicle
  - VehicleKey
删除 / Removed: 11
  - GameAPI.create_sfx_with_socket_offset
  - GameAPI.register_geometry_frustum
  - GameAPI.register_geometry_ring
  - GameAPI.register_geometry_spline
  - GlobalAPI.set_render_color
  - LifeEntity.ai_command_chase_with_ability
  - LifeEntity.ai_command_chase_with_action
  - LifeEntity.ai_command_chase_with_equipment
  - Obstacle.set_billboard_text_color
  - Role.shake_camera
  - SceneUI.create_scene_ui_bind_unit
签名变更 / Signature changed: 0
类型变更 / Type changed: 0

