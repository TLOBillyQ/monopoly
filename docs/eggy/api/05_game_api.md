## GameAPI

GameAPI|ability_prefab_get_desc|_ability_id
GameAPI|ability_prefab_get_name|_ability_id
GameAPI|ability_prefab_get_prop_by_type|_value_type, _key, _prop
GameAPI|ability_prefab_has_kv|_ability_key, _prop
GameAPI|add_pathpoint|_path_id, _index, _point_id
GameAPI|add_sheet_column|_sheet_id, _key, _type_name
GameAPI|clear_sheet|_sheet_id
GameAPI|copy_sheet|_sheet_id
GameAPI|create_constant_wind_field|_pos, _wind_type, _wind_range, _duration
GameAPI|create_creature_fixed_scale|_u_key, _pos, _rotation, _scale_ratio, _role
GameAPI|create_customtriggerspace|_u_key, _pos, _rotation, _scale, _role
GameAPI|create_decoration|_u_key, _pos, _rotation, _scale, _parent
GameAPI|create_equipment|_equipment_eid, _pos
GameAPI|create_joint_assistant|_unit_key, _unit1, _unit2
GameAPI|create_life_entity|_unit_key, _pos, _rotation, _scale_ratio, _role
GameAPI|create_obstacle|_u_key, _pos, _rotation, _scale, _role
GameAPI|create_obstacle_from_geometry|_u_key, _pos, _rotation, _scale, _role, _geometry_path
GameAPI|create_scene_ui_at_point|_layer_key, _pos, _duration
GameAPI|create_sfx_with_socket|_sfx_key, _unit, _socket_name, _scale, _duration, _bind_type
GameAPI|create_sfx_with_socket_offset|_sfx_key, _unit, _socket_name, _offset, _rot, _scale, _duration, _bind_type
GameAPI|create_sheet
GameAPI|create_triggerspace|_u_key, _pos, _rotation, _scale, _role
GameAPI|create_unit_group|_unit_group_id, _pos, _root_quaternion, _role
GameAPI|create_unit_with_scale|_u_key, _pos, _rotation, _scale
GameAPI|creature_prefab_get_kv_by_type|_value_type, _key, _prop
GameAPI|creature_prefab_get_prop_by_type|_value_type, _key, _prop
GameAPI|creature_prefab_has_kv|_unit_key, _prop
GameAPI|customtriggerspace_prefab_get_kv_by_type|_value_type, _key, _prop
GameAPI|customtriggerspace_prefab_get_prop_by_type|_value_type, _key, _prop
GameAPI|customtriggerspace_prefab_has_kv|_key, _prop
GameAPI|deal_damage|_dst, _dmg, _src, _schema, _data
GameAPI|destroy_scene_ui|_layer
GameAPI|destroy_unit|_unit
GameAPI|destroy_unit_with_children|_unit, _destroy_children
GameAPI|enable_collision_between_unit_and_prefab|_unit, _unit_eid, _enable
GameAPI|enable_collision_between_units|_unit_1, _unit_2, _enable
GameAPI|equipment_prefab_has_kv|_equipment_key, _prop
GameAPI|game_end
GameAPI|get_achievement_target|_event_id
GameAPI|get_all_camps
GameAPI|get_all_characters
GameAPI|get_all_creatures
GameAPI|get_all_customtriggerspaces
GameAPI|get_all_equipment_keys_in_shop|_battle_shop_key
GameAPI|get_all_equipments
GameAPI|get_all_lifientities
GameAPI|get_all_obstacles
GameAPI|get_all_online_roles
GameAPI|get_all_roles
GameAPI|get_all_triggerspaces
GameAPI|get_all_valid_roles
GameAPI|get_camp|_camp_id
GameAPI|get_camp_relation|_camp1, _camp2
GameAPI|get_characters_in_aabb|_center, _length, _height, _width
GameAPI|get_characters_in_cylinder|_bottom_center, _radius, _height
GameAPI|get_characters_in_sphere|_center, _radius
GameAPI|get_creatures_by_key|_creature_key
GameAPI|get_creatures_in_aabb|_center, _length, _height, _width
GameAPI|get_creatures_in_annulus|_center, _radius1, _radius2, _height
GameAPI|get_creatures_in_cylinder|_bottom_center, _radius, _height
GameAPI|get_creatures_in_sector|_center, _face_dir, _central_angle, _radius, _height
GameAPI|get_creatures_in_sphere|_center, _radius
GameAPI|get_customtriggerspaces_by_key|_key
GameAPI|get_customtriggerspaces_in_raycast|_start_pos, _end_pos
GameAPI|get_day|_timestamp
GameAPI|get_env_time
GameAPI|get_env_time_ratio
GameAPI|get_env_time_running_enabled
GameAPI|get_eui_child_by_index|_node, _index
GameAPI|get_eui_child_by_name|_node, _name
GameAPI|get_eui_children|_node
GameAPI|get_eui_children_count|_node
GameAPI|get_eui_node_at_scene_ui|_layer, _node_id
GameAPI|get_first_customtriggerspace_in_raycast|_start_pos, _end_pos
GameAPI|get_goods_list
GameAPI|get_hour|_timestamp
GameAPI|get_joint_assistants|_unit
GameAPI|get_lifeentities_in_aabb|_center, _length, _height, _width
GameAPI|get_lifeentities_in_cylinder|_bottom_center, _radius, _height
GameAPI|get_lifeentities_in_sphere|_center, _radius
GameAPI|get_map_characters
GameAPI|get_map_rating_score
GameAPI|get_minute|_timestamp
GameAPI|get_montage_duration|_montage_id
GameAPI|get_month|_timestamp
GameAPI|get_obstacle_by_raycast|_start_pos, _end_pos
GameAPI|get_obstacles_by_key|_key
GameAPI|get_obstacles_by_raycast|_start_pos, _end_pos
GameAPI|get_obstacles_in_aabb|_center, _length, _height, _width
GameAPI|get_obstacles_in_annulus|_center, _radius1, _radius2, _height
GameAPI|get_obstacles_in_cylinder|_bottom_center, _radius, _height
GameAPI|get_obstacles_in_sector|_center, _face_dir, _central_angle, _radius, _height
GameAPI|get_obstacles_in_sphere|_center, _radius
GameAPI|get_pathpoint_by_id|_point_id
GameAPI|get_pathpoint_by_index|_path_id, _index
GameAPI|get_role|_role_id
GameAPI|get_role_friendship_value|_role_1, _role_2
GameAPI|get_second|_timestamp
GameAPI|get_sheet_col_count|_sheet_id
GameAPI|get_sheet_row_count|_sheet_id
GameAPI|get_sheet_value_by_type|_value_type, _sheet_id, _key1, _key2
GameAPI|get_timestamp
GameAPI|get_timestamp_by_time|_year, _month, _day, _hour, _minute, _second
GameAPI|get_timestamp_diff|_timestamp_1, _timestamp_2
GameAPI|get_triggerspaces_by_key|_key
GameAPI|get_unit|_unit_id
GameAPI|get_unit_id_by_name|_name
GameAPI|get_vector3s_from_path|_path_id
GameAPI|get_weekday|_timestamp
GameAPI|get_year|_timestamp
GameAPI|has_global_kv|_var_name
GameAPI|is_archives_enabled
GameAPI|is_point_in_customtriggerspace|_point, _custom_trigger_space
GameAPI|is_role_friendship_type_match|_role_1, _role_2, _friendship_type
GameAPI|load_level|_level_key
GameAPI|modifier_prefab_get_desc|_modifier_key
GameAPI|modifier_prefab_get_name|_modifier_key
GameAPI|modifier_prefab_get_prop_by_type|_value_type, _key, _prop
GameAPI|modifier_prefab_has_kv|_modifier_key, _prop
GameAPI|obstacle_prefab_get_kv_by_type|_value_type, _key, _prop
GameAPI|obstacle_prefab_get_prop_by_type|_value_type, _key, _prop
GameAPI|obstacle_prefab_has_kv|_key, _prop
GameAPI|play_3d_sound|_position, _sound_key, _duration, _volume
GameAPI|play_link_sfx|_sfx_key, _unit, _from_socket_name, _target_unit, _target_socket_name, _duration
GameAPI|play_sfx_by_key|_sfx_key, _pos, _rot, _scale, _duration, _rate, _with_sound
GameAPI|random_color
GameAPI|random_int|_min_value, _max_value
GameAPI|raycast_unit|_start_pos, _end_pos, _include_unit_types, _raycast_handler
GameAPI|register_geometry_box|_size, _chamfer_radius, _chamfer_level, _use_box_collider, _preconf
GameAPI|register_geometry_frustum|_height, _inner_radius, _outer_radius, _inner_poly_count, _outer_poly_count, _chamfer_radius, _angle, _layer, _bend, _preconf
GameAPI|register_geometry_ring|_height, _inner_radius, _outer_radius, _inner_poly_count, _outer_poly_count, _chamfer_radius, _angle, _preconf
GameAPI|register_geometry_spline|_is_rope, _pos_list, _normal_list, _radius_list, _dist_precision, _normal_precision, _depth, _preconf
GameAPI|remove_pathpoint|_path_id, _index
GameAPI|set_all_scene_ui_visible|_role, _visible
GameAPI|set_env_time|_target_time, _duration, _direction
GameAPI|set_env_time_ratio|_time_ratio
GameAPI|set_env_time_running_enabled|_enabled
GameAPI|set_equipment_max_stock_count|_battle_shop_key, _equipment_key, _max_stock_count
GameAPI|set_equipment_remaining_stock_count|_battle_shop_key, _equipment_key, _cur_stock_count
GameAPI|set_global_wind_enabled|_bool_value
GameAPI|set_global_wind_force|_x_value, _y_value
GameAPI|set_global_wind_frequency|_fixed_value
GameAPI|set_life_entity_survival_scene_boundary|_x, _y, _z
GameAPI|set_scene_ui_position|_role, _layer, _position
GameAPI|set_scene_ui_visible|_layer, _role, _visible
GameAPI|set_sheet_value_by_type|_value_type, _sheet_id, _key1, _key2, _val
GameAPI|set_unit_survival_scene_boundary|_x, _y, _z
GameAPI|stop_sound|_assigned_id
GameAPI|triggerspace_prefab_get_kv_by_type|_value_type, _key, _prop
GameAPI|triggerspace_prefab_get_prop_by_type|_value_type, _key, _prop
GameAPI|triggerspace_prefab_has_kv|_key, _prop
