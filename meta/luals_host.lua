---@meta

---@alias Fixed number
---@alias AbilityAnchorID string 技能锚点ID
---@alias AbilityKey integer 技能编号
---@alias AbilitySlot integer 技能槽位
---@alias Achievement integer 自定义成就
---@alias AnimKey integer 动画编号
---@alias Archive integer 自定义存档
---@alias BattleShopKey integer 商店
---@alias CampID integer 阵营ID
---@alias CharacterKey LifeEntityKey 角色编号
---@alias ChessType integer 麻将/扑克花色
---@alias Color integer 颜色
---@alias CreatureKey LifeEntityKey 生物编号
---@alias CustomTriggerSpaceID UnitID 触发区域ID
---@alias CustomTriggerSpaceKey UnitKey 触发区域编号
---@alias DamageSchema integer 伤害方案
---@alias DecorationKey UnitKey 装饰物编号
---@alias DynamicTextID integer 动态文字ID
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
---@alias EmojiKey integer 气泡表情编号
---@alias EquipmentID UnitID 物品ID
---@alias EquipmentKey integer 物品编号
---@alias EquipmentSlot integer 物品槽位
---@alias FontKey integer 字体key
---@alias ImageKey integer 图片编号
---@alias InteractBtnID integer 交互按钮编号
---@alias JointAssistantType integer 关节类型
---@alias LevelKey string 关卡编号
---@alias LifeEntityKey UnitKey 生命体编号
---@alias ModifierKey integer 效果编号
---@alias MontageKey string 剧情动画编号
---@alias ObstacleID UnitID 组件ID
---@alias ObstacleKey UnitKey 组件编号
---@alias PaintArea integer 染色区域
---@alias PathID UnitID 路径ID
---@alias PathPointID UnitID 路点ID
---@alias RoleID integer 玩家ID
---@alias SfxID integer 特效ID
---@alias SfxKey integer 特效编号
---@alias SheetID integer 表格
---@alias Skeleton string 骨骼
---@alias SkyBoxBackground integer 天空盒背景
---@alias SoundID integer 音效ID
---@alias SoundKey integer 音效编号
---@alias Timestamp integer 时间戳
---@alias TriggerSpaceKey UnitKey 逻辑体编号
---@alias UIPreset string UIPreset
---@alias UgcCommodity integer 道具
---@alias UgcGoods string 商品
---@alias UnitGroupKey UnitKey 组件组编号
---@alias UnitID integer 单位ID
---@alias UnitKey integer 单位编号
---@alias VehicleKey UnitKey 单位编号(载具)
---@alias CommodityInfo {[1]: UgcCommodity, [2]: integer}  {商品项目ID, 道具数量}

---@class Vector3
---@operator add(Vector3): Vector3
---@operator sub(Vector3): Vector3
---@operator mul(Vector3): Vector3
---@operator div(Vector3): Vector3
---@operator unm: Vector3
---@operator add(Fixed): Vector3
---@operator sub(Fixed): Vector3
---@operator mul(Fixed): Vector3
---@operator div(Fixed): Vector3
---@field x Fixed
---@field y Fixed
---@field z Fixed
---@field pitch Fixed
---@field yaw Fixed
---@field set_pitch_yaw fun(self: Vector3, pitch: Fixed, yaw: Fixed)
---@field length fun(self: Vector3): Fixed
---@field getUnit fun(self: Vector3): Fixed
---@field getAbsoluteVector fun(self: Vector3): Fixed
---@field normalize fun(self: Vector3): Fixed
---@field dot fun(self: Vector3, rhs: Vector3): Fixed
---@field cross fun(self: Vector3, rhs: Vector3): Vector3

---@class Quaternion
---@operator mul(Vector3): Vector3
---@operator mul(Quaternion): Quaternion
---@field x Fixed
---@field y Fixed
---@field z Fixed
---@field w Fixed
---@field yaw Fixed 注意: 由于历史原因，在2025.10.30维护前的游戏版本中，Lua中math库默认欧拉角的旋转顺序为：pitch->yaw->roll（即XYZ顺序），而编辑器内显示的角度为roll->pitch->yaw（即ZXY顺序）。为了避免不同顺序引起的混乱，我们将于2025.10.30维护后，将Lua中math库的默认欧拉角旋转顺序调整至与编辑器内一致。此次更改只影响维护后新创建的地图，您无需修改已经创建或发布的地图。但是如果需要将旧地图的代码迁移到新地图，请留意此处的更改。
---@field pitch Fixed 注意: 由于历史原因，在2025.10.30维护前的游戏版本中，Lua中math库默认欧拉角的旋转顺序为：pitch->yaw->roll（即XYZ顺序），而编辑器内显示的角度为roll->pitch->yaw（即ZXY顺序）。为了避免不同顺序引起的混乱，我们将于2025.10.30维护后，将Lua中math库的默认欧拉角旋转顺序调整至与编辑器内一致。此次更改只影响维护后新创建的地图，您无需修改已经创建或发布的地图。但是如果需要将旧地图的代码迁移到新地图，请留意此处的更改。
---@field roll Fixed 注意: 由于历史原因，在2025.10.30维护前的游戏版本中，Lua中math库默认欧拉角的旋转顺序为：pitch->yaw->roll（即XYZ顺序），而编辑器内显示的角度为roll->pitch->yaw（即ZXY顺序）。为了避免不同顺序引起的混乱，我们将于2025.10.30维护后，将Lua中math库的默认欧拉角旋转顺序调整至与编辑器内一致。此次更改只影响维护后新创建的地图，您无需修改已经创建或发布的地图。但是如果需要将旧地图的代码迁移到新地图，请留意此处的更改。
---@field euler Vector3 注意: 由于历史原因，在2025.10.30维护前的游戏版本中，Lua中math库默认欧拉角的旋转顺序为：pitch->yaw->roll（即XYZ顺序），而编辑器内显示的角度为roll->pitch->yaw（即ZXY顺序）。为了避免不同顺序引起的混乱，我们将于2025.10.30维护后，将Lua中math库的默认欧拉角旋转顺序调整至与编辑器内一致。此次更改只影响维护后新创建的地图，您无需修改已经创建或发布的地图。但是如果需要将旧地图的代码迁移到新地图，请留意此处的更改。
---@field inverse fun(self: Quaternion)
---@field apply fun(self: Quaternion, v: Vector3): Vector3

---@class dict
---@field set fun(): dict
---@field get fun(self: dict, key: any): any
---@field keyvalues fun(self: dict): any[]
---@field keys fun(self: dict): any[]
---@field values fun(self: dict): any[]

---@class math
---@field pi Fixed
---@field e Fixed
---@field maxval Fixed
---@field minval Fixed
---@field zero Fixed
---@field one Fixed
---@field neg_one Fixed
---@field tointeger fun(x: Fixed): integer
---@field toreal fun(x: Fixed): Fixed
---@field tofixed fun(x: integer): Fixed
---@field isfinite fun(x: Fixed): boolean
---@field sin fun(x: Fixed): Fixed
---@field cos fun(x: Fixed): Fixed
---@field tan fun(x: Fixed): Fixed
---@field asin fun(x: Fixed): Fixed
---@field acos fun(x: Fixed): Fixed
---@field atan fun(x: Fixed): Fixed
---@field atan2 fun(y: Fixed, x: Fixed): Fixed
---@field sqrt fun(x: Fixed): Fixed
---@field log fun(x: Fixed): Fixed
---@field log2 fun(x: Fixed): Fixed
---@field log10 fun(x: Fixed): Fixed
---@field log1p fun(x: Fixed): Fixed
---@field exp fun(x: Fixed): Fixed
---@field exp2 fun(x: Fixed): Fixed
---@field fmod fun(x: Fixed, y: Fixed): Fixed
---@field pow fun(x: Fixed, y: Fixed): Fixed
---@field round fun(x: Fixed): Fixed
---@field ceil fun(x: Fixed): Fixed
---@field floor fun(x: Fixed): Fixed
---@field trunc fun(x: Fixed): Fixed
---@field min fun(a: Fixed, b: Fixed): Fixed
---@field max fun(a: Fixed, b: Fixed): Fixed
---@field abs fun(a: Fixed): Fixed
---@field fabs fun(x: Fixed): Fixed
---@field clamp fun(x: Fixed, min: Fixed, max: Fixed): Fixed
---@field equal001 fun(a: Fixed, b: Fixed): boolean
---@field rad_to_deg fun(rad: Fixed): Fixed
---@field deg_to_rad fun(deg: Fixed): Fixed
---@field Vector3 fun(x: Fixed?, y: Fixed?, z: Fixed?): Vector3
---@field Quaternion fun(x: Fixed, y: Fixed, z: Fixed, w: Fixed): Quaternion

---@class Damage

---@class Decoration: Unit

---@class JointAssistant: JointAssistantComp, Unit

---@class Timer

---@class UnitGroup: Unit

---@class Vehicle: Unit, VehicleComp

---@class Enums

---@class GlobalAPI
---@field add_kill_broadcast fun(_kill_char: Character, _dead_char: Character, _duration: Fixed)
---@field debug fun(_content: string)
---@field destroy_sfx fun(_sfx_id: SfxID, _fade_out: boolean?)
---@field error fun(_content: string)
---@field get_lines_intersection_point_on_plane fun(_point_1: Vector3, _point_2: Vector3, _point_3: Vector3, _point_4: Vector3, _value: Fixed, _plane_type: Enums.PlaneType): Vector3
---@field get_point_to_line_perpendicular_point fun(_point_1: Vector3, _point_2: Vector3, _point_3: Vector3): Vector3
---@field get_vector_projection fun(_vec: Vector3, _direction: Vector3): Vector3
---@field is_none fun(_obj: Unit?): boolean
---@field is_not_none fun(_obj: Unit?): boolean
---@field mute_sfx_sound fun(_sfx_id: SfxID)
---@field set_direct_light fun(_param_dict: table, _duration: Fixed)
---@field set_render_color fun(_hue: Fixed, _brightness: Fixed, _saturation: Fixed, _contrast: Fixed, _amount: Fixed, _mid_tones: Color, _mid_tones_power: Fixed, _shadows: Color, _shadows_power: Fixed, _highlight: Color, _highlight_power: Fixed, _duration: Fixed)
---@field set_sfx_orientation fun(_sfx_id: SfxID, _orientation: Quaternion)
---@field set_sfx_position fun(_sfx_id: SfxID, _pos: Vector3)
---@field set_sfx_rate fun(_sfx_id: SfxID, _rate: Fixed)
---@field set_sfx_scale fun(_sfx_id: SfxID, _scale: Vector3)
---@field set_sfx_visible fun(_sfx_id: SfxID, _visible: boolean)
---@field set_skybox_texture fun(_texture_key: SkyBoxBackground, _change_type: Enums.SkyBoxGradualType, _duration: Fixed)
---@field set_skyfog fun(_param_dict: table, _duration: Fixed)
---@field show_message_marquee fun(_content: string?)
---@field show_tips fun(_content: string, _duration: Fixed?)
---@field str_contains fun(_str1: string, _str2: string): boolean
---@field str_to_color fun(_color_str: string): Color
---@field warning fun(_content: string)

---@class Ability: Actor, AttrComp, KVBase, TriggerSystem
---@field add_state_to_target fun(_unit: Unit, _state_id: Enums.BuffState)
---@field begin_cast fun(_dir_info: Vector3?, _target_point: Vector3?, _target_unit: Unit?)
---@field break_accumulate fun()
---@field break_cast fun()
---@field change_affect_radius fun(_delta_affect_radius: Fixed)
---@field change_affect_width fun(_delta_affect_width: Fixed)
---@field change_max_release_distance fun(_delta_level: Fixed)
---@field downgrade_ability_level fun(_delta_level: integer)
---@field enter_cd fun()
---@field get_ability_level fun(): integer
---@field get_ability_max_level fun(): integer
---@field get_ability_slot fun(): AbilitySlot
---@field get_accumulate_ratio fun(): Fixed
---@field get_affect_character_list fun(_height: Fixed, _use_fixed_release_point: boolean?): Character[]
---@field get_affect_creature_list fun(_height: Fixed, _use_fixed_release_point: boolean?): Creature[]
---@field get_affect_lifeentity_list fun(_height: Fixed, _use_fixed_release_point: boolean?): LifeEntity[]
---@field get_affect_obstacle_list fun(_height: Fixed, _use_fixed_release_point: boolean?): Obstacle[]
---@field get_affect_radius fun(): Fixed
---@field get_affect_width fun(): Fixed
---@field get_cd_time fun(): Fixed
---@field get_charge_time fun(): Fixed
---@field get_cur_release_num fun(): integer
---@field get_desc fun(): string
---@field get_key fun(): AbilityKey
---@field get_left_cd_time fun(): Fixed
---@field get_left_charge_time fun(): Fixed
---@field get_lock_obstacle fun(): Obstacle
---@field get_lock_target fun(): LifeEntity
---@field get_lock_target_char fun(): Character
---@field get_lock_target_creature fun(): Creature
---@field get_max_release_distance fun(): Fixed
---@field get_max_release_num fun(): integer
---@field get_name fun(): string
---@field get_owner fun(): LifeEntity
---@field get_owner_character fun(): Unit
---@field get_owner_creature fun(): Unit
---@field get_owner_equipment fun(): Equipment
---@field get_pointer_type fun(): Enums.AbilityPointerType
---@field get_release_direction fun(): Vector3
---@field get_release_direction_list fun(): Vector3[]
---@field get_release_point fun(): Vector3
---@field get_release_point_list fun(): Vector3[]
---@field is_in_cd fun(): boolean
---@field is_in_charge fun(): boolean
---@field is_limitation_enabled fun(_limit: Enums.AbilityLimitation): boolean
---@field play_countdown_ui fun(_time: Fixed)
---@field remove_state_to_target fun(_unit: Unit, _state_id: Enums.BuffState)
---@field set_ability_level fun(_new_level: integer)
---@field set_ability_max_level fun(_new_max_level: integer)
---@field set_affect_radius fun(_new_affect_radius: Fixed)
---@field set_affect_width fun(_new_affect_width: Fixed)
---@field set_cur_release_num fun(_release_num: integer)
---@field set_left_cd_time fun(_cd_time: Fixed)
---@field set_left_charge_time fun(_cd_time: Fixed)
---@field set_max_release_distance fun(_new_max_release_distance: Fixed)
---@field set_max_release_num fun(_release_num_max: integer)
---@field upgrade_ability_level fun(_delta_level: integer)

---@class AbilityComp
---@field add_ability_to_slot fun(_ability_index: AbilitySlot, _ability_id: AbilityKey, _kv_args: table?, _kv_types: table?): Ability
---@field add_prop_ability fun(_ability_id: AbilityKey, _kv_args: table?, _kv_types: table?): Ability
---@field break_ability_accumulate fun()
---@field cast_ability_by_ability_slot_and_direction fun(_direction: Vector3, _ability_slot: AbilitySlot, _duration: Fixed)
---@field cast_ability_by_ability_slot_and_position fun(_position: Vector3, _ability_slot: AbilitySlot, _duration: Fixed)
---@field cast_ability_by_ability_slot_and_target fun(_target: LifeEntity, _ability_slot: AbilitySlot, _duration: Fixed)
---@field cast_ability_by_direction fun(_ability_key: AbilityKey, _duration: Fixed, _direction: Vector3, _ability_slot: AbilitySlot?)
---@field cast_ability_by_position fun(_ability_key: AbilityKey, _duration: Fixed, _position: Vector3, _ability_slot: AbilitySlot?)
---@field cast_ability_by_target fun(_ability_key: AbilityKey, _duration: Fixed, _target: LifeEntity, _ability_slot: AbilitySlot?)
---@field destroy_ability fun(_ability: Ability): boolean
---@field get_abilities fun(): Ability[]
---@field get_ability_by_slot fun(_ability_slot: AbilitySlot): Ability
---@field get_ability_list fun(): Ability[]
---@field get_prop_ability fun(): Ability
---@field interrupt_ability fun()
---@field remove_ability fun(_ability_slot: AbilitySlot): boolean
---@field remove_ability_by_key fun(_ability_key: AbilityKey): boolean
---@field remove_prop_ability fun(): boolean
---@field reset_ability_cd fun(_ability_index: AbilitySlot)
---@field set_ability_enabled_on_vehicle fun(_enable: boolean)
---@field set_ability_to_slot fun(_ability: Ability, _ability_index: AbilitySlot): Ability

---@class Actor: KVBase, TriggerSystem
---@field get_id fun(): UnitID

---@class AttrComp
---@field change_attr_bonus_fixed fun(_key: string, _value: Fixed)
---@field change_attr_ratio_fixed fun(_key: string, _value: Fixed)
---@field change_attr_raw_fixed fun(_key: string, _value: Fixed)
---@field get_attr_base_extra_fixed fun(_key: string): Fixed
---@field get_attr_bonus_fixed fun(_key: string): Fixed
---@field get_attr_by_type fun(_value_type: Enums.ValueType, _key: string): any
---@field get_attr_ratio_fixed fun(_key: string): Fixed
---@field get_attr_raw_fixed fun(_key: string): Fixed
---@field set_attr_bonus_fixed fun(_key: string, _value: Fixed)
---@field set_attr_by_type fun(_value_type: Enums.ValueType, _key: string, _val: any)
---@field set_attr_ratio_fixed fun(_key: string, _value: Fixed)
---@field set_attr_raw_fixed fun(_key: string, _value: Fixed)

---@class BuffStateComp
---@field add_state fun(_state_id: Enums.BuffState)
---@field clear_state fun(_state_id: Enums.BuffState)
---@field get_state_count fun(_state_id: Enums.BuffState): integer
---@field get_state_list fun(): Enums.BuffState[]
---@field remove_state fun(_state_id: Enums.BuffState)

---@class Camp: AttrComp, KVBase
---@field change_camp_score fun(_add_score: integer)
---@field get_camp_score fun(): integer
---@field get_name fun(): string
---@field get_roles fun(): Role[]
---@field set_camp_score fun(_score: integer)

---@class Character: LifeEntity
---@field change_custom_model_by_creature fun(_creature: Creature)
---@field change_custom_model_by_creature_key fun(_creature_key: CreatureKey)
---@field fling_rush fun()
---@field get_ability_point fun(): integer
---@field get_climb_obstacle fun(): Obstacle
---@field get_ctrl_role fun(): Role
---@field get_joystick_direction fun(): Vector3
---@field increase_ability_point fun(_increase: integer)
---@field lift fun()
---@field reset_target_socket_model fun(_model_socket: Enums.ModelSocket)
---@field set_aim_move_enabled fun(_enable: boolean)
---@field set_character_prefab fun(_c_key: CharacterKey, _reset_prop: boolean, _reset_trigger_system: boolean, _reset_model: boolean)
---@field set_climb_enabled fun(_enable: boolean)
---@field set_climb_max_angle fun(_angle: Fixed)
---@field set_climb_min_angle fun(_angle: Fixed)
---@field set_climb_speed fun(_speed: Fixed)
---@field set_socket_model fun(_model_socket: Enums.ModelSocket, _creature: Creature, _creature_model_socket: Enums.ModelSocket)
---@field set_socket_model_by_creature_key fun(_model_socket: Enums.ModelSocket, _creature_key: CreatureKey, _creature_model_socket: Enums.ModelSocket)
---@field set_voice_enabled fun(_enabled: boolean)
---@field start_move_to_pos fun(_target_pos: Vector3, _duration: Fixed)

---@class CharacterComp
---@field get_scale_ratio fun(): Fixed
---@field is_forced_moving fun(): boolean
---@field start_forced_move fun(_vel: Vector3, _duration: Fixed, _enable_phy: boolean?)
---@field stop_forced_move fun()

---@class Creature: LifeEntity, OwnerComp
---@field force_start_move fun(_direction: Vector3, _t: Fixed)
---@field force_stop_move fun()
---@field reset_target_socket_model fun(_model_socket: Enums.ModelSocket)
---@field set_draggable fun(_enable: boolean)
---@field set_dragged_plane_type fun(_value: Enums.PlaneType)
---@field set_name fun(_name: string)
---@field set_name_visible fun(_visible: boolean)
---@field set_socket_model fun(_model_socket: Enums.ModelSocket, _creature: Creature, _creature_model_socket: Enums.ModelSocket)
---@field set_socket_model_by_creature_key fun(_model_socket: Enums.ModelSocket, _creature_key: CreatureKey, _creature_model_socket: Enums.ModelSocket)
---@field set_touchable fun(_enable: boolean)

---@class CustomTriggerSpace: ExprDeviceComp, OwnerComp, SceneUI, Unit, UnitInteractVolumeComp
---@field random_point fun(): Vector3

---@class DebugAPI
---@field draw_line fun(_start_pos: Vector3, _end_pos: Vector3, _color: Color, _duration: Fixed)
---@field draw_text fun(_pos: Vector3, _text: string)

---@class DisplayComp
---@field add_banned_anim fun(_anim_name: string)
---@field bind_model fun(_model_id: UnitKey, _socket: Enums.ModelSocket, _offset: Vector3?, _rot: Quaternion?, _scale: Vector3?): string
---@field bind_model_by_unit fun(_unit: Unit, _socket: Enums.ModelSocket, _offset: Vector3?, _rot: Quaternion?): string
---@field clear_banned_anim fun()
---@field force_play_animation_by_anim_key fun(_anim_key: AnimKey, _start_time: Fixed?, _play_time: Fixed?, _play_rate: Fixed?, _is_loop: boolean?)
---@field play_body_anim_by_id fun(_anim_id: AnimKey, _start_time: Fixed?, _play_time: Fixed?, _is_loop: boolean?)
---@field play_upper_anim_by_id fun(_anim_id: AnimKey, _start_time: Fixed?, _play_time: Fixed?, _is_loop: boolean?)
---@field remove_banned_anim fun(_anim_name: string)
---@field set_anim_rate fun(_anim_rate: Fixed)
---@field stop_anim fun()
---@field stop_play_body_anim fun()
---@field stop_play_body_anim_by_id fun(_anim_id: AnimKey)
---@field stop_play_upper_anim fun()
---@field stop_play_upper_anim_by_id fun(_anim_id: AnimKey)
---@field unbind_model fun(_bind_id: string)

---@class Equipment: KVBase, OwnerComp, TriggerSystem
---@field can_drop fun(): boolean
---@field change_current_stack_size fun(_num: integer)
---@field change_max_stack_size fun(_num: integer)
---@field destroy_equipment fun()
---@field drop fun()
---@field get_current_stack_num fun(): integer
---@field get_desc fun(): string
---@field get_equipment_slot fun(): EquipmentSlot
---@field get_equipment_type fun(): Enums.EquipmentType
---@field get_key fun(): EquipmentKey
---@field get_max_stack_num fun(): integer
---@field get_name fun(): string
---@field get_owner_character fun(): Character
---@field get_owner_creature fun(): Creature
---@field get_position fun(): Vector3
---@field get_price fun(_res_type: string): integer
---@field get_slot_type fun(): Enums.EquipmentSlotType
---@field get_unit fun(): Obstacle
---@field has_owner fun(): boolean
---@field is_auto_picking fun(): boolean
---@field is_auto_using fun(): boolean
---@field move_to_slot fun(_slot_type: Enums.EquipmentSlotType, _slot: integer)
---@field set_auto_aim_enabled fun(_is_auto_aim: boolean)
---@field set_auto_fire_enabled fun(_is_auto_fire: boolean)
---@field set_charge_cost_free fun(_is_free: boolean)
---@field set_current_stack_num fun(_num: integer)
---@field set_desc fun(_desc: string)
---@field set_droppable fun(_droppable: boolean)
---@field set_icon fun(_icon_key: ImageKey)
---@field set_max_stack_num fun(_num: integer)
---@field set_name fun(_name: string)
---@field set_price fun(_res_type: string, _price: integer)
---@field set_saleable fun(_saleable: boolean)
---@field set_usable fun(_usable: boolean)
---@field start_charge fun()

---@class EquipmentComp
---@field clear_selected_equipment_slot fun()
---@field consume_equipment fun(_equipment_key: EquipmentKey, _consume_num: integer)
---@field create_equipment_to_slot fun(_key: EquipmentKey, _slot_type: Enums.EquipmentSlotType): Equipment
---@field get_equipment_by_slot fun(_slot_type: Enums.EquipmentSlotType, _slot_index: integer): Equipment
---@field get_equipment_list fun(_equipment_key: EquipmentKey, _exclude_equipped: boolean?, _exclude_bag: boolean?): Equipment[]
---@field get_equipment_list_by_slot_type fun(_slot_type: Enums.EquipmentSlotType): Equipment[]
---@field get_equipment_max_count fun(_slot_type: Enums.EquipmentSlotType): integer
---@field get_selected_equipment fun(): Equipment
---@field select_equipment_slot fun(_slot_type: Enums.EquipmentSlotType, _slot_index: integer)
---@field set_equipment_max_count fun(_slot_type: Enums.EquipmentSlotType, _slot_num: integer)

---@class ExprDeviceComp
---@field disable_expr_device_by_name fun(_name: string)
---@field enable_expr_device_by_name fun(_name: string)

---@class GameAPI
---@field ability_prefab_get_desc fun(_ability_id: AbilityKey): string
---@field ability_prefab_get_name fun(_ability_id: AbilityKey): string
---@field ability_prefab_get_prop_by_type fun(_value_type: Enums.ValueType, _key: AbilityKey, _prop: string): any
---@field ability_prefab_has_kv fun(_ability_key: AbilityKey, _prop: string): boolean
---@field add_pathpoint fun(_path_id: PathID, _index: integer, _point_id: PathPointID)
---@field add_sheet_column fun(_sheet_id: SheetID, _key: string, _type_name: string)
---@field clear_sheet fun(_sheet_id: SheetID)
---@field copy_sheet fun(_sheet_id: SheetID): SheetID
---@field copy_vehicle fun(_vehicle: Vehicle, _pos: Vector3, _direction: Vector3, _role: Role?): Vehicle
---@field create_constant_wind_field fun(_pos: Vector3, _wind_type: Enums.WindFieldShapeType, _wind_range: Fixed, _duration: Fixed)
---@field create_creature_fixed_scale fun(_u_key: UnitKey, _pos: Vector3, _rotation: Quaternion, _scale_ratio: Fixed, _role: Role?): Creature
---@field create_customtriggerspace fun(_u_key: CustomTriggerSpaceKey, _pos: Vector3, _rotation: Quaternion, _scale: Vector3, _role: Role?): CustomTriggerSpace
---@field create_decoration fun(_u_key: DecorationKey, _pos: Vector3, _rotation: Quaternion, _scale: Vector3, _parent: Unit?): Decoration
---@field create_equipment fun(_equipment_eid: EquipmentKey, _pos: Vector3): Equipment
---@field create_joint_assistant fun(_unit_key: Enums.JointAssistantKey, _unit1: Unit, _unit2: Unit): JointAssistant
---@field create_life_entity fun(_unit_key: UnitKey, _pos: Vector3, _rotation: Quaternion, _scale_ratio: Fixed, _role: Role?): LifeEntity
---@field create_obstacle fun(_u_key: UnitKey, _pos: Vector3, _rotation: Quaternion, _scale: Vector3, _role: Role?): Obstacle
---@field create_obstacle_from_geometry fun(_u_key: UnitKey, _pos: Vector3, _rotation: Quaternion, _scale: Vector3, _role: Role?, _geometry_path: string?): Obstacle
---@field create_scene_ui_at_point fun(_layer_key: E3DLayerKey, _pos: Vector3, _duration: Fixed?): E3DLayer
---@field create_sfx_with_socket fun(_sfx_key: SfxKey, _unit: Unit, _socket_name: Enums.ModelSocket, _scale: Fixed, _duration: Fixed, _bind_type: Enums.BindType): SfxID
---@field create_sfx_with_socket_offset fun(_sfx_key: SfxKey, _unit: Unit, _socket_name: Enums.ModelSocket, _offset: Vector3, _rot: Quaternion, _scale: Fixed, _duration: Fixed, _bind_type: Enums.BindType): SfxID
---@field create_sheet fun(): SheetID
---@field create_triggerspace fun(_u_key: TriggerSpaceKey, _pos: Vector3, _rotation: Quaternion, _scale: Vector3, _role: Role?): TriggerSpace
---@field create_unit_group fun(_unit_group_id: UnitGroupKey, _pos: Vector3, _root_quaternion: Quaternion, _role: Role?, _use_center_offset: boolean?): UnitGroup
---@field create_unit_with_scale fun(_u_key: UnitKey, _pos: Vector3, _rotation: Quaternion, _scale: Vector3): Unit
---@field create_vehicle fun(_vehicle_key: VehicleKey, _pos: Vector3, _direction: Vector3, _role: Role?): Vehicle
---@field creature_prefab_get_kv_by_type fun(_value_type: Enums.ValueType, _key: CreatureKey, _prop: string): any
---@field creature_prefab_get_prop_by_type fun(_value_type: Enums.ValueType, _key: CreatureKey, _prop: string): any
---@field creature_prefab_has_kv fun(_unit_key: CreatureKey, _prop: string): boolean
---@field customtriggerspace_prefab_get_kv_by_type fun(_value_type: Enums.ValueType, _key: CustomTriggerSpaceKey, _prop: string): any
---@field customtriggerspace_prefab_get_prop_by_type fun(_value_type: Enums.ValueType, _key: CustomTriggerSpaceKey, _prop: string): any
---@field customtriggerspace_prefab_has_kv fun(_key: CustomTriggerSpaceKey, _prop: string): boolean
---@field deal_damage fun(_dst: LifeEntity, _dmg: Fixed, _src: Unit?, _schema: DamageSchema?, _data: table?)
---@field delay_destroy_vehicle fun(_unit: Vehicle)
---@field destroy_scene_ui fun(_layer: E3DLayer)
---@field destroy_unit fun(_unit: Unit)
---@field destroy_unit_with_children fun(_unit: Unit, _destroy_children: boolean?)
---@field enable_collision_between_unit_and_prefab fun(_unit: Unit, _unit_eid: UnitKey, _enable: boolean)
---@field enable_collision_between_units fun(_unit_1: Unit, _unit_2: Unit, _enable: boolean)
---@field equipment_prefab_has_kv fun(_equipment_key: EquipmentKey, _prop: string): boolean
---@field game_end fun()
---@field get_achievement_target fun(_event_id: Achievement): integer
---@field get_all_camps fun(): Camp[]
---@field get_all_characters fun(): Character[]
---@field get_all_creatures fun(): Creature[]
---@field get_all_customtriggerspaces fun(): CustomTriggerSpace[]
---@field get_all_equipment_keys_in_shop fun(_battle_shop_key: BattleShopKey): EquipmentKey[]
---@field get_all_equipments fun(): Equipment[]
---@field get_all_lifientities fun(): LifeEntity[]
---@field get_all_obstacles fun(): Obstacle[]
---@field get_all_online_roles fun(): Role[]
---@field get_all_roles fun(): Role[]
---@field get_all_triggerspaces fun(): TriggerSpace[]
---@field get_all_valid_roles fun(): Role[]
---@field get_camp fun(_camp_id: CampID): Camp
---@field get_camp_relation fun(_camp1: Camp, _camp2: Camp): Enums.CampRelationType
---@field get_characters_in_aabb fun(_center: Vector3, _length: Fixed, _height: Fixed, _width: Fixed): Character[]
---@field get_characters_in_cylinder fun(_bottom_center: Vector3, _radius: Fixed, _height: Fixed): Character[]
---@field get_characters_in_sphere fun(_center: Vector3, _radius: Fixed): Character[]
---@field get_creatures_by_key fun(_creature_key: CreatureKey): Creature[]
---@field get_creatures_in_aabb fun(_center: Vector3, _length: Fixed, _height: Fixed, _width: Fixed): Creature[]
---@field get_creatures_in_annulus fun(_center: Vector3, _radius1: Fixed, _radius2: Fixed, _height: Fixed): Creature[]
---@field get_creatures_in_cylinder fun(_bottom_center: Vector3, _radius: Fixed, _height: Fixed): Creature[]
---@field get_creatures_in_sector fun(_center: Vector3, _face_dir: Fixed, _central_angle: Fixed, _radius: Fixed, _height: Fixed): Creature[]
---@field get_creatures_in_sphere fun(_center: Vector3, _radius: Fixed): Creature[]
---@field get_customtriggerspaces_by_key fun(_key: CustomTriggerSpaceKey): CustomTriggerSpace[]
---@field get_customtriggerspaces_in_raycast fun(_start_pos: Vector3, _end_pos: Vector3): CustomTriggerSpace[]
---@field get_day fun(_timestamp: Timestamp): integer
---@field get_driving_vehicle fun(_character: Character): Vehicle
---@field get_env_time fun(): Fixed
---@field get_env_time_ratio fun(): Fixed
---@field get_eui_child_by_index fun(_node: ENode, _index: integer): ENode
---@field get_eui_child_by_name fun(_node: ENode, _name: string): ENode
---@field get_eui_children fun(_node: ENode): ENode[]
---@field get_eui_children_count fun(_node: ENode): integer
---@field get_eui_node_at_scene_ui fun(_layer: E3DLayer, _node_id: ENode): ENode
---@field get_first_customtriggerspace_in_raycast fun(_start_pos: Vector3, _end_pos: Vector3): CustomTriggerSpace
---@field get_goods_list fun(): GoodsInfo[]
---@field get_hour fun(_timestamp: Timestamp): integer
---@field get_joint_assistants fun(_unit: Unit): JointAssistant[]
---@field get_lifeentities_in_aabb fun(_center: Vector3, _length: Fixed, _height: Fixed, _width: Fixed): LifeEntity[]
---@field get_lifeentities_in_cylinder fun(_bottom_center: Vector3, _radius: Fixed, _height: Fixed): LifeEntity[]
---@field get_lifeentities_in_sphere fun(_center: Vector3, _radius: Fixed): LifeEntity[]
---@field get_map_characters fun(): Character[]
---@field get_map_rating_score fun(): Fixed
---@field get_minute fun(_timestamp: Timestamp): integer
---@field get_montage_duration fun(_montage_id: MontageKey): Fixed
---@field get_month fun(_timestamp: Timestamp): integer
---@field get_obstacle_by_raycast fun(_start_pos: Vector3, _end_pos: Vector3): Obstacle
---@field get_obstacles_by_key fun(_key: ObstacleKey): Obstacle[]
---@field get_obstacles_by_raycast fun(_start_pos: Vector3, _end_pos: Vector3): Obstacle[]
---@field get_obstacles_in_aabb fun(_center: Vector3, _length: Fixed, _height: Fixed, _width: Fixed): Obstacle[]
---@field get_obstacles_in_annulus fun(_center: Vector3, _radius1: Fixed, _radius2: Fixed, _height: Fixed): Obstacle[]
---@field get_obstacles_in_cylinder fun(_bottom_center: Vector3, _radius: Fixed, _height: Fixed): Obstacle[]
---@field get_obstacles_in_sector fun(_center: Vector3, _face_dir: Fixed, _central_angle: Fixed, _radius: Fixed, _height: Fixed): Obstacle[]
---@field get_obstacles_in_sphere fun(_center: Vector3, _radius: Fixed): Obstacle[]
---@field get_party_roles fun(_party_id: string): Role[]
---@field get_pathpoint_by_id fun(_point_id: PathPointID): Vector3
---@field get_pathpoint_by_index fun(_path_id: PathID, _index: integer): Vector3
---@field get_role fun(_role_id: RoleID): Role
---@field get_role_friendship_value fun(_role_1: Role, _role_2: Role): integer
---@field get_second fun(_timestamp: Timestamp): integer
---@field get_sheet_cell_value fun(_value_type: Enums.ValueType, _sheet_id: SheetID, _key1: integer, _key2: string): any
---@field get_sheet_col_count fun(_sheet_id: SheetID): integer
---@field get_sheet_row_count fun(_sheet_id: SheetID): integer
---@field get_timestamp fun(): Timestamp
---@field get_timestamp_by_time fun(_year: integer, _month: integer, _day: integer, _hour: integer, _minute: integer, _second: integer): Timestamp
---@field get_timestamp_diff fun(_timestamp_1: Timestamp, _timestamp_2: Timestamp): integer
---@field get_triggerspaces_by_key fun(_key: TriggerSpaceKey): TriggerSpace[]
---@field get_unit fun(_unit_id: UnitID): Unit
---@field get_unit_id_by_name fun(_name: string): UnitID
---@field get_vector3s_from_path fun(_path_id: PathID): Vector3[]
---@field get_weekday fun(_timestamp: Timestamp): integer
---@field get_year fun(_timestamp: Timestamp): integer
---@field has_global_kv fun(_var_name: string): boolean
---@field is_archives_enabled fun(): boolean
---@field is_env_time_running_enabled fun(): boolean
---@field is_point_in_customtriggerspace fun(_point: Vector3, _custom_trigger_space: CustomTriggerSpace): boolean
---@field is_role_friendship_type_match fun(_role_1: Role, _role_2: Role, _friendship_type: Enums.FriendshipType): boolean
---@field load_level fun(_level_key: LevelKey)
---@field modifier_prefab_get_desc fun(_modifier_key: ModifierKey): string
---@field modifier_prefab_get_name fun(_modifier_key: ModifierKey): string
---@field modifier_prefab_get_prop_by_type fun(_value_type: Enums.ValueType, _key: ModifierKey, _prop: string): any
---@field modifier_prefab_has_kv fun(_modifier_key: ModifierKey, _prop: string): boolean
---@field obstacle_prefab_get_kv_by_type fun(_value_type: Enums.ValueType, _key: ObstacleKey, _prop: string): any
---@field obstacle_prefab_get_prop_by_type fun(_value_type: Enums.ValueType, _key: ObstacleKey, _prop: string): any
---@field obstacle_prefab_has_kv fun(_key: ObstacleKey, _prop: string): boolean
---@field play_3d_sound fun(_position: Vector3, _sound_key: SoundKey, _duration: Fixed?, _volume: Fixed?): SoundID
---@field play_link_sfx fun(_sfx_key: SfxKey, _unit: Unit, _from_socket_name: string, _target_unit: Unit, _target_socket_name: string, _duration: Fixed?): SfxID
---@field play_sfx_by_key fun(_sfx_key: SfxKey, _pos: Vector3, _rot: Quaternion, _scale: Fixed, _duration: Fixed?, _rate: Fixed?, _with_sound: boolean?): SfxID
---@field random_color fun(): Color
---@field random_int fun(_min_value: integer, _max_value: integer): integer
---@field raycast_test fun(_start_pos: Vector3, _end_pos: Vector3, _collision_mask: integer, _find_closest: boolean, _callback: function)
---@field raycast_unit fun(_start_pos: Vector3, _end_pos: Vector3, _include_unit_types: Enums.UnitType[], _raycast_handler: function)
---@field register_geometry_box fun(_size: Fixed, _chamfer_radius: Fixed, _chamfer_level: integer, _use_box_collider: boolean, _preconf: table): string
---@field register_geometry_frustum fun(_height: Fixed, _inner_radius: Fixed, _outer_radius: Fixed, _inner_poly_count: integer, _outer_poly_count: integer, _chamfer_radius: Fixed, _angle: Fixed, _layer: integer, _bend: Fixed, _preconf: table): string
---@field register_geometry_ring fun(_height: Fixed, _inner_radius: Fixed, _outer_radius: Fixed, _inner_poly_count: integer, _outer_poly_count: integer, _chamfer_radius: Fixed, _angle: Fixed, _preconf: table): string
---@field register_geometry_spline fun(_is_rope: boolean, _pos_list: Vector3[], _normal_list: Vector3[], _radius_list: Fixed[], _dist_precision: Fixed, _normal_precision: Fixed, _depth: Fixed, _preconf: table): string
---@field remove_pathpoint fun(_path_id: PathID, _index: integer)
---@field set_all_scene_ui_visible fun(_role: Role, _visible: boolean)
---@field set_env_time fun(_target_time: Fixed, _duration: Fixed, _direction: boolean)
---@field set_env_time_ratio fun(_time_ratio: Fixed)
---@field set_env_time_running_enabled fun(_enabled: boolean)
---@field set_equipment_max_stock_count fun(_battle_shop_key: BattleShopKey, _equipment_key: EquipmentKey, _max_stock_count: integer)
---@field set_equipment_remaining_stock_count fun(_battle_shop_key: BattleShopKey, _equipment_key: EquipmentKey, _cur_stock_count: integer)
---@field set_global_wind_enabled fun(_bool_value: boolean)
---@field set_global_wind_force fun(_x_value: Fixed, _y_value: Fixed)
---@field set_global_wind_frequency fun(_fixed_value: Fixed)
---@field set_life_entity_survival_scene_boundary fun(_x: Fixed, _y: Fixed, _z: Fixed)
---@field set_scene_ui_position fun(_role: Role, _layer: E3DLayer, _position: Vector3)
---@field set_scene_ui_visible fun(_layer: E3DLayer, _role: Role, _visible: boolean)
---@field set_sheet_cell_value fun(_value_type: Enums.ValueType, _sheet_id: SheetID, _key1: integer, _key2: string, _val: any)
---@field set_unit_survival_scene_boundary fun(_x: Fixed, _y: Fixed, _z: Fixed)
---@field stop_sound fun(_assigned_id: SoundID)
---@field sweep_test fun(_body_unit: Unit, _test_dir: Vector3, _max_dist: Fixed, _collision_mask: integer, _find_closest: boolean, _callback: function)
---@field triggerspace_prefab_get_kv_by_type fun(_value_type: Enums.ValueType, _key: TriggerSpaceKey, _prop: string): any
---@field triggerspace_prefab_get_prop_by_type fun(_value_type: Enums.ValueType, _key: TriggerSpaceKey, _prop: string): any
---@field triggerspace_prefab_has_kv fun(_key: TriggerSpaceKey, _prop: string): boolean

---@class GoodsInfo
---@field goods_id UgcGoods 商品ID
---@field name string 商品名称
---@field commodity_infos CommodityInfo[] 商品项列表

---@class ItemBox: DisplayComp, ExprDeviceComp, SceneUI
---@field add_ability fun(_ability_key: AbilityKey, _weight: integer)
---@field add_equipment fun(_key: EquipmentKey, _weight: integer)
---@field remove_ability fun(_ability_key: AbilityKey)
---@field remove_equipment fun(_key: EquipmentKey)

---@class JointAssistantComp
---@field get_joint_assistant_primary_obstacle fun(): Character
---@field get_joint_assistant_target_obstacle fun(): Character
---@field get_joint_assistant_type fun(): JointAssistantType
---@field set_joint_assistant_enabled fun(_enable: boolean)
---@field set_joint_assistant_property fun(_property_type: Enums.JointAssistantProperty, _value: Fixed)
---@field set_joint_assistant_visible fun(_visible: boolean)

---@class JumpComp
---@field get_multi_jump_remaining_cooldown fun(): Fixed
---@field is_on_ground fun(): boolean
---@field set_multi_jump_remaining_cooldown fun(_cd: Fixed)

---@class KVBase
---@field add_tag fun(_tag: string)
---@field clear_kv fun()
---@field clear_tag fun()
---@field get_kv_by_type fun(_value_type: Enums.ValueType, _key: string): any
---@field has_kv fun(_key: string): boolean
---@field has_tag fun(_tag: string): boolean
---@field remove_kv fun(_key: string)
---@field remove_tag fun(_tag: string)
---@field set_kv_by_type fun(_value_type: Enums.ValueType, _key: string, _val: any)

---@class LevelComp
---@field gain_exp fun(_killed_exp: Fixed)
---@field get_exp fun(): Fixed
---@field get_killed_exp fun(): Fixed
---@field get_level fun(): integer
---@field level_up fun()
---@field set_killed_exp fun(_killed_exp: Fixed)

---@class LifeComp
---@field can_reborn fun(): boolean
---@field change_hp fun(_value: Fixed)
---@field die fun(_dmg_unit: Unit?)
---@field get_hp fun(): Fixed
---@field get_hp_max fun(): Fixed
---@field get_life fun(): integer
---@field get_life_max fun(): integer
---@field is_die_status fun(): boolean
---@field is_infinite_reborn fun(): boolean
---@field reborn fun(_immediate: boolean?)
---@field set_auto_reborn_enabled fun(_auto_reborn: boolean)
---@field set_hp_max fun(_value: Fixed)
---@field set_infinite_reborn_enabled fun(_enable_reborn: boolean)
---@field set_life_count fun(_value: integer)
---@field set_life_max fun(_value: integer)
---@field set_reborn_in_place fun(_reborn_in_place: boolean, _reset_camera: boolean)
---@field set_reborn_time fun(_reborn_time: Fixed)

---@class LifeEntity: AbilityComp, AttrComp, BuffStateComp, CharacterComp, DisplayComp, EquipmentComp, JumpComp, LevelComp, LifeComp, LiftComp, LiftedComp, ModifierComp, MoveStatusComp, RollComp, RushComp, SceneUI, Unit, UnitInteractVolumeComp
---@field activate_multi_animation fun(_anim_id: AnimKey, _acceptor_type: Enums.UnitType)
---@field ai_command_alert fun(_tagert_pos: Vector3, _target_dir: Vector3, _dalay_time: Fixed, _reject_time: Fixed, _move_mode: Enums.MoveMode)
---@field ai_command_chase_with_ability fun(_target: Unit, _chase_range: Fixed, _reject_time: Fixed, _action_distance: Fixed, _ability_key: AbilityKey, _move_mode: Enums.MoveMode, _action_count: integer)
---@field ai_command_chase_with_action fun(_target: Unit, _chase_range: Fixed, _reject_time: Fixed, _action_distance: Fixed, _action_mode: Enums.AIBasicCommand, _move_mode: Enums.MoveMode, _action_count: integer)
---@field ai_command_chase_with_equipment fun(_target: Unit, _chase_range: Fixed, _reject_time: Fixed, _action_distance: Fixed, _equipment_key: EquipmentKey, _move_mode: Enums.MoveMode, _action_count: integer)
---@field ai_command_follow fun(_target_unit: Unit, _follow_dis: Fixed, _tolerate_dis: Fixed, _reject_time: Fixed, _move_mode: Enums.MoveMode)
---@field ai_command_imitate fun(_target_unit: Character, _delay: Fixed, _disable_actions: Enums.AIBasicCommand[])
---@field ai_command_jump fun()
---@field ai_command_lift fun()
---@field ai_command_patrol fun(_waypoint: Vector3[], _reject_time: Fixed, _round_mode: Enums.PatrolType, _move_mode: Enums.MoveMode)
---@field ai_command_pick_up_equipment fun(_target_equipment: Equipment, _move_mode: Enums.MoveMode, _reject_time: Fixed)
---@field ai_command_roll fun()
---@field ai_command_rush fun()
---@field ai_command_start_move fun(_direction: Vector3, _t: Fixed)
---@field ai_command_start_move_high_priority fun(_target_position: Vector3[], _duration: Fixed?, _threshold: Fixed?)
---@field ai_command_stop_move fun(_duration: Fixed)
---@field disable_yaw_speed_limit fun()
---@field get_direction fun(): Vector3
---@field get_hard_punch_threshold fun()
---@field get_hpbar_scale_x fun(): Fixed
---@field get_hpbar_scale_y fun(): Fixed
---@field get_lifted_lifeentity fun(): LifeEntity
---@field get_lifted_obstacle fun(): Obstacle
---@field get_owner fun(): Role
---@field get_punch_threshold fun()
---@field interrupt_multi_animation fun()
---@field is_draggable fun(): boolean
---@field is_ghost_mode fun(): boolean
---@field is_jumping fun(): boolean
---@field is_moving fun(): boolean
---@field is_rushing fun(): boolean
---@field is_touchable fun(): boolean
---@field jump fun()
---@field play_face_expression fun(_emoji_key: EmojiKey, _show_time: Fixed)
---@field reset_model fun()
---@field set_ai_move_threshold fun(_threshold: Fixed)
---@field set_direction fun(_face_dir: Vector3)
---@field set_hard_punch_threshold fun(_punch_threshold: Fixed)
---@field set_hpbar_scale fun(_hpbar_scale_x: Fixed, _hpbar_scale_y: Fixed)
---@field set_mass_bar_visible fun(_visible: boolean)
---@field set_max_yaw_speed fun(_limit_yaw_speed: Fixed?)
---@field set_model_by_character fun(_character: Character, _include_ugc_model: boolean?, _inherit_scale: boolean?, _inherit_capsule_size: boolean?)
---@field set_model_by_creature fun(_creature: Creature, _include_custom_model: boolean?, _inherit_scale: boolean?, _inherit_capsule_size: boolean?)
---@field set_model_by_creature_key fun(_creature_key: CreatureKey, _include_custom_model: boolean?, _inherit_scale: boolean?, _inherit_capsule_size: boolean?)
---@field set_multi_animation_acceptor_enabled fun(_enable: boolean)
---@field set_multi_animation_acceptor_type fun(_acceptor_type: Enums.UnitType)
---@field set_punch_threshold fun(_punch_threshold: Fixed)
---@field set_search_enemy_focus_target fun(_target: Unit)
---@field set_search_enemy_priority_value_by_tag fun(_tag: string, _priority: integer)
---@field set_search_enemy_priority_value_by_unit fun(_unit: Unit, _priority: integer)
---@field set_search_enemy_priority_value_by_unit_key fun(_unit_key: CreatureKey, _priority: integer)
---@field set_search_enemy_priority_value_by_unit_type fun(_unit_prefab_type: Enums.UnitType, _priority: integer)
---@field set_skeleton_offset fun(_skeleton: Skeleton, _offset: Vector3)
---@field set_skeleton_scale fun(_skeleton: Skeleton, _scale: Vector3)
---@field start_ai fun()
---@field start_move_by_direction fun(_direction: Vector3, _duration: Fixed)
---@field start_move_to_pos_with_threshold fun(_target_pos: Vector3, _duration: Fixed, _threshold: Fixed)
---@field stop_ai fun()
---@field swap_equipment_slot fun(_equipment: Equipment, _slot_type: Enums.EquipmentSlotType?, _slot: EquipmentSlot?)
---@field try_enter_vehicle fun(_vehicle: Vehicle)
---@field try_exit_vehicle fun()

---@class LiftComp
---@field get_lift_cooldown fun(): Fixed
---@field get_lift_remaining_cooldown fun(): Fixed
---@field is_lift_status fun(): boolean
---@field lift_unit fun(_unit: Unit)
---@field set_lift_cooldown fun(_cd_time: Fixed)
---@field set_lift_remaining_cooldown fun(_time: Fixed)

---@class LiftedComp
---@field is_lifted_enabled fun(): boolean
---@field is_lifted_status fun(): boolean
---@field set_custom_thrown_force fun(_force: Fixed)
---@field set_custom_thrown_force_enabled fun(_enable: boolean)
---@field set_lifted_enabled fun(_enable: boolean)

---@class LuaAPI
---@field call_delay_frame fun(_interval: integer, _callback: function)
---@field call_delay_time fun(_interval: Fixed, _callback: function)
---@field dispatch_flush fun()
---@field dispatch_init fun(_count: integer)
---@field dispatch_queue fun(_i: integer, _name: string, _args: table): integer
---@field enable_developer_mode fun(): boolean
---@field enable_error_interruption_mode fun(_enable: boolean)
---@field get_component_list fun(_obj: Unit): string[]
---@field get_current_unit fun(): Unit
---@field get_dispatch_count fun(): integer
---@field get_global_var fun(_var_name: string): any
---@field get_unit_id fun(_unit: Unit): integer
---@field get_value_type fun(_value: any): string
---@field global_register_custom_event fun(_event_name: string, _callback: function): integer
---@field global_register_trigger_event fun(_event_desc: any[], _callback: function): integer
---@field global_send_custom_event fun(_event_name: string, _data: table)
---@field global_unregister_custom_event fun(_id: integer)
---@field global_unregister_trigger_event fun(_id: integer)
---@field has_component fun(_object: Unit, _name: string): boolean
---@field log fun(_content: string, _log_level: integer?)
---@field query_ui_node fun(_name: string): ENode
---@field query_ui_nodes fun(_name_list: string[]): ENode[]
---@field query_unit fun(_name: string): Unit
---@field query_units fun(_name_list: string[]): Unit[]
---@field query_units_by_type fun(_unit_type: Enums.UnitType, _unit_eid: integer): Unit[]
---@field rand fun(): integer
---@field set_deadloop_check_enabled fun(_enable: boolean, _max_instruction_count: integer): boolean
---@field set_tick_handler fun(_pre_handler: function?, _post_handler: function?)
---@field unit_register_creation_handler fun(_unit_type: Enums.UnitType, _unit_eid: integer, _callback: function)
---@field unit_register_custom_event fun(_unit: Unit, _event_name: string, _callback: function): integer
---@field unit_register_trigger_event fun(_unit: Unit, _event_desc: any[], _callback: function): integer
---@field unit_send_custom_event fun(_unit: Unit, _event_name: string, _data: table)
---@field unit_unregister_creation_handler fun(_unit_type: Enums.UnitType, _unit_eid: integer)
---@field unit_unregister_custom_event fun(_unit: Unit, _id: integer)
---@field unit_unregister_trigger_event fun(_unit: Unit, _id: integer)

---@class Modifier: Actor
---@field add_duration fun(_add_time: Fixed)
---@field add_stack_count fun(_stack_count_add: integer)
---@field change_shield_value fun(_shield_value: Fixed)
---@field get_desc fun(): string
---@field get_key fun(): ModifierKey
---@field get_max_stack_count fun(): string
---@field get_name fun(): string
---@field get_owner_ability fun(): Ability
---@field get_owner_character fun(): Character
---@field get_owner_creature fun(): Creature
---@field get_owner_life_entity fun(): LifeEntity
---@field get_owner_unit fun(): Unit
---@field get_releaser_unit fun(): Unit
---@field get_remain_duration fun(): Fixed
---@field get_shield_value fun(): Fixed
---@field get_stack_count fun(): string
---@field set_remain_duration fun(_remain_duration: Fixed)
---@field set_shield_value fun(_shield_value: Fixed)
---@field set_stack_count fun(_stack_count_add: integer)

---@class ModifierComp
---@field add_modifier fun(_modifier_id: ModifierKey): Modifier
---@field add_modifier_by_key fun(_modifier_id: ModifierKey, _params_dict: table): Modifier
---@field destroy_modifier fun(_modifier: Modifier)
---@field get_modifier_by_modifier_key fun(_modifier_id: ModifierKey): Modifier
---@field get_modifiers fun(): Modifier[]
---@field has_modifier_by_key fun(_modifier_key: ModifierKey): boolean
---@field remove_modifier_by_key fun(_modifier_id: ModifierKey)

---@class MoveStatusComp
---@field is_fling_status fun(): boolean
---@field is_lost_control_status fun(): boolean
---@field start_face_lock_target fun(_target_unit: Unit, _time: Fixed?)
---@field stop_face_lock_target fun()

---@class Obstacle: DisplayComp, ExprDeviceComp, LiftedComp, OwnerComp, SceneUI, Unit, UnitInteractVolumeComp
---@field get_billboard_font_size fun(): integer
---@field get_billboard_text fun(): string
---@field get_bound_equipment fun(): Equipment
---@field get_chess_rank fun(): integer
---@field get_chess_type fun(): ChessType
---@field is_draggable fun(): boolean
---@field is_touchable fun(): boolean
---@field reset_collision_limit fun(_limit_type: Enums.CollisionLimitType)
---@field set_billboard_font_size fun(_font_size: integer)
---@field set_billboard_text fun(_content: string)
---@field set_billboard_text_color fun(_color: Color, _gradient_color_1: Color?, _gradient_color_2: Color?, _gradient_color_3: Color?, _gradient_color_4: Color?)
---@field set_chess_type_and_rank fun(_card_type: ChessType, _card_rank: integer)
---@field set_climbable fun(_enable: boolean)
---@field set_collision_count_limit fun(_limit_type: Enums.CollisionLimitType, _value: integer)
---@field set_collision_interval_limit fun(_limit_type: Enums.CollisionLimitType, _value: Fixed)
---@field set_draggable fun(_enabled: boolean)
---@field set_ranklist_score fun(_role: Role, _score: integer)

---@class OwnerComp
---@field change_owner fun(_role: Role)
---@field get_owner_role fun(): Role

---@class Role: AttrComp, KVBase
---@field add_achievement_progress fun(_event_id: Achievement, _add_count: integer)
---@field add_score fun(_add_score: integer)
---@field consume_commodity fun(_commodity_id: UgcCommodity, _num: integer)
---@field disable_unit_fresnel fun(_unit: Unit)
---@field disable_unit_mask fun(_unit: Unit)
---@field disable_unit_outline fun(_unit: Unit)
---@field enter_watch_mode fun(_camp_limit: boolean?, _exit_visible: boolean?)
---@field exit_watch_mode fun()
---@field game_lose_and_show_result_panel fun()
---@field game_win_and_show_result_panel fun()
---@field get_achievement_progress fun(_event_id: Achievement): integer
---@field get_archive_by_type fun(_archive_type: Enums.ArchiveType, _key: Archive): any
---@field get_archive_sheetid fun(_key: Archive): SheetID
---@field get_camera_direction fun(): Vector3
---@field get_camera_rotation fun(): Quaternion
---@field get_camp fun(): Camp
---@field get_commodity_count fun(_commodity_id: UgcCommodity): integer
---@field get_ctrl_unit fun(): Character
---@field get_game_result fun(): Enums.GameResult
---@field get_head_icon fun(): ImageKey
---@field get_map_total_cost fun(): Fixed
---@field get_name fun(): string
---@field get_party_id fun(): string
---@field get_roleid fun(): RoleID
---@field get_score fun(): integer
---@field get_voice_volume fun(): Fixed
---@field has_commodity fun(_commodity_id: UgcCommodity): boolean
---@field has_saved_archive fun(): boolean
---@field is_achievement_completed fun(_event_id: Achievement): boolean
---@field is_gallery_vip fun(): boolean
---@field is_lost fun(): boolean
---@field is_map_favorited fun(): boolean
---@field is_map_liked fun(): boolean
---@field is_online fun(): boolean
---@field is_pass_premium_vip fun(): boolean
---@field is_subscribed_map_author fun(): boolean
---@field is_watch_mode fun(): boolean
---@field is_won fun(): boolean
---@field lose fun()
---@field pause_camera_motor fun()
---@field play_2d_sound_with_params fun(_event_id: SoundID, _duration: Fixed, _volume: Fixed, _speed: Fixed): SoundID
---@field play_advertisement_with_event fun(_success_event: string, _fail_event: string, _ad_tag: string?, _success_data: table?, _fail_data: table?)
---@field play_montage fun(_montage_key: MontageKey, _start_time: Fixed, _play_to_end: boolean, _play_time: Fixed)
---@field play_screen_sfx fun(_sfx_key: SfxKey, _duration: Fixed?, _rate: Fixed?): SfxID
---@field play_ui_effect fun(_effect_node: EEffectNode)
---@field reset_animation fun(_node: ENode)
---@field reset_camera fun(_reset_angle: boolean?, _reset_bind: boolean?, _reset_point: boolean?, _reset_prop_pitch: boolean?)
---@field resume_camera_motor fun()
---@field send_track_data_change fun(_track_data_key: string, _change_num: integer)
---@field send_ui_custom_event fun(_event_name: string, _data: table)
---@field set_achievement_progress fun(_event_id: Achievement, _count: integer)
---@field set_animation_state fun(_node: ENode, _animation_name: string, _state: EAnimationState)
---@field set_archive_by_type fun(_archive_type: Enums.ArchiveType, _key: Archive, _val: any)
---@field set_archive_point fun(_position: Vector3, _priority: integer, _direction: Vector3)
---@field set_archive_sheetid fun(_key: Archive, _val: SheetID)
---@field set_bagslot_related_lifeentity fun(_bag_slot: EBagSlot, _life_entity: LifeEntity)
---@field set_battle_shop_visible fun(_battle_shop_id: BattleShopKey, _visible: boolean)
---@field set_blind_corner fun(_enable: boolean, _strength: Fixed, _color: Color)
---@field set_button_enabled fun(_button: EButton, _enabled: boolean)
---@field set_button_font_size fun(_key: EButton, _font_size: Fixed)
---@field set_button_normal_image fun(_button: EButton, _image_key: ImageKey)
---@field set_button_pressed_image fun(_button: EButton, _image_key: ImageKey)
---@field set_button_text fun(_button: EButton, _text: string)
---@field set_button_text_color fun(_button: EButton, _text_color: Color)
---@field set_camera_bind_mode fun(_mode: Enums.CameraBindMode)
---@field set_camera_draggable fun(_draggable: boolean)
---@field set_camera_gyroscope_control_enabled fun(_is_control: boolean)
---@field set_camera_lock_position fun(_pos: Vector3)
---@field set_camera_projection_type fun(_projection_type: Enums.CameraProjectionType)
---@field set_camera_property fun(_property: Enums.CameraPropertyType, _value: Fixed)
---@field set_camera_rotation_by_direction fun(_target_dir: Vector3, _duration: Fixed)
---@field set_camera_rotation_sync_enabled fun(_enabled: boolean)
---@field set_goods_panel_visible fun(_visible: boolean)
---@field set_goods_visible fun(_goods_key: UgcGoods, _visible: boolean)
---@field set_gyroscope_control_unit fun(_is_control: boolean, _unit: Unit)
---@field set_gyroscope_sync_enabled fun(_enabled: boolean)
---@field set_image_color fun(_image: EImage, _image_color: Color, _transition_time: Fixed)
---@field set_image_texture_by_key_with_auto_resize fun(_image: EImage, _image_key: ImageKey, _reset_size: boolean?)
---@field set_image_texture_with_auto_resize fun(_image: EImage, _image_path: string, _reset_size: boolean?)
---@field set_input_field_text fun(_input_field: EInputField, _text: string)
---@field set_label_background_color fun(_label: ELabel, _color: Color, _transition_time: Fixed)
---@field set_label_background_opacity fun(_label: ELabel, _opacity: Fixed, _transition_time: Fixed)
---@field set_label_color fun(_label: ELabel, _color: Color, _transition_time: Fixed)
---@field set_label_font fun(_label: ELabel, _font_key: FontKey)
---@field set_label_font_size fun(_label: ELabel, _font_size: integer, _transition_time: Fixed)
---@field set_label_outline_color fun(_label: ELabel, _color: Color)
---@field set_label_outline_enabled fun(_label: ELabel, _enable: boolean)
---@field set_label_outline_opacity fun(_label: ELabel, _opacity: Fixed)
---@field set_label_outline_width fun(_label: ELabel, _width: Fixed)
---@field set_label_shadow_color fun(_label: ELabel, _color: Color)
---@field set_label_shadow_enabled fun(_label: ELabel, _enable: boolean)
---@field set_label_shadow_x_offset fun(_label: ELabel, _offset: Fixed)
---@field set_label_shadow_y_offset fun(_label: ELabel, _offset: Fixed)
---@field set_label_text fun(_label: ELabel, _text: string)
---@field set_name_visible fun(_visible: boolean)
---@field set_node_touch_enabled fun(_node: ENode, _touch_enabled: boolean)
---@field set_node_visible fun(_node: ENode, _visible: boolean)
---@field set_progressbar_current fun(_progress_bar: EProgressbar, _current: integer)
---@field set_progressbar_max fun(_progress_bar: EProgressbar, _max: integer)
---@field set_progressbar_min fun(_progress_bar: EProgressbar, _min: integer)
---@field set_progressbar_transition fun(_progress_bar: EProgressbar, _current: integer, _transition_time: Fixed)
---@field set_role_ctrl_enabled fun(_enable: boolean)
---@field set_score fun(_score: integer)
---@field set_ui_opacity fun(_node: ENode, _opacity: Fixed)
---@field set_uipreset_visible fun(_ui: UIPreset, _visible: boolean)
---@field set_unit_fresnel fun(_unit: Unit, _fresnel_scale: Fixed, _color: Color, _intensity: integer)
---@field set_unit_fresnel_gradual fun(_unit: Unit, _fresnel_scale: Fixed, _color: Color, _intensity: integer, _duration: Fixed)
---@field set_unit_mask fun(_unit: Unit, _color: Color)
---@field set_unit_outline fun(_unit: Unit, _width: integer, _color: Color)
---@field set_unit_see_through_enabled fun(_unit: Unit, _enabled: boolean)
---@field set_unit_visible fun(_unit: Unit, _is_visible: boolean)
---@field set_voice_volume_sync_enabled fun(_enabled: boolean)
---@field shake_camera fun(_shake_type: Enums.CameraShakeType, _shake_max_amplitude: Fixed, _shake_time: Fixed, _shake_source: Unit, _shake_frequency: Fixed, _shake_time_decay: Fixed, _shake_effect_scope: Fixed, _shake_undamped_scope: Fixed, _shake_distance_decay: Fixed)
---@field show_bag_panel fun(_visible: boolean)
---@field show_dynamic_text fun(_text: string, _pos: Vector3, _color: Color, _duration: Fixed, _anim_type: integer): DynamicTextID
---@field show_goods_purchase_panel fun(_raw_goods_id: UgcGoods, _show_time: Fixed)
---@field show_like_panel fun()
---@field show_map_share_panel fun()
---@field show_tips fun(_content: string, _duration: Fixed?)
---@field show_ultimate_ability_panel fun(_keep_time: integer)
---@field skip_current_montage fun(_has_black_screen: boolean)
---@field start_level_vote fun(_level_key: LevelKey)
---@field start_vibration fun(_vibrate_type: integer, _vibrate_count: integer, _vibrate_interval: Fixed)
---@field stop_2d_sound fun(_sound_instance_id: SoundID)
---@field stop_camera_motor fun()
---@field stop_montage fun(_montage_key: MontageKey, _has_black_screen: boolean)
---@field stop_ui_effect fun(_effect_node: EEffectNode)
---@field unbind_label_text fun(_label: ELabel)
---@field unbind_progressbar_current fun(_progress_bar: EProgressbar)
---@field unbind_progressbar_max fun(_progress_bar: EProgressbar)
---@field win fun()

---@class RollComp
---@field get_roll_cooldown fun(): Fixed
---@field get_roll_remaining_cooldown fun(): Fixed
---@field set_roll_cooldown fun(_time: Fixed)
---@field set_roll_remaining_cooldown fun(_remaining_time: Fixed)

---@class RushComp
---@field get_rush_cooldown fun(): Fixed
---@field get_rush_remaining_cooldown fun(): Fixed
---@field set_rush_cooldown fun(_time: Fixed)
---@field set_rush_remaining_cooldown fun(_time: Fixed)

---@class SceneUI
---@field create_scene_ui_bind_unit fun(_layer_key: E3DLayerKey, _socket_name: Enums.ModelSocket, _offset_pos: Vector3, _duration: Fixed?, _bind_event: boolean?, _inherit_visible: boolean?): E3DLayer

---@class TriggerSpace: ExprDeviceComp, OwnerComp, SceneUI, Unit, UnitInteractVolumeComp
---@field get_virtual_light_brightness fun(): Fixed
---@field set_virtual_light_brightness fun(_brightness: Fixed)

---@class TriggerSystem
---@field has_timer fun(_timer: Timer): boolean

---@class Unit: Actor
---@field add_child fun(_unit: Unit)
---@field add_circle_motor fun(_vel: Vector3, _time: Fixed, _is_local: boolean?): integer
---@field add_linear_motor fun(_vel: Vector3, _time: Fixed, _is_local: boolean?): integer
---@field add_surround_motor fun(_follow_target: Unit, _ang_vel: Vector3, _time: Fixed, _follow_rotate: boolean?)
---@field apply_force fun(_force: Vector3)
---@field apply_impact_force fun(_force: Vector3, _max_speed: Fixed?, _force_lost_control: boolean?, _lost_ctrl_time: Fixed?)
---@field disable_gravity fun()
---@field disable_interact fun()
---@field disable_motor fun(_index: integer)
---@field enable_gravity fun()
---@field enable_interact fun()
---@field enable_motor fun(_index: integer)
---@field get_angular_velocity fun(): Vector3
---@field get_camp fun(): Camp
---@field get_camp_id fun(): CampID
---@field get_child_by_name fun(_name: string): Unit
---@field get_child_customtriggerspaces fun(): CustomTriggerSpace[]
---@field get_child_obstacles fun(): Obstacle[]
---@field get_children fun(): Unit[]
---@field get_current_mass fun(): Fixed
---@field get_current_mass_center fun(): Vector3
---@field get_key fun(): UnitKey
---@field get_linear_velocity fun(): Vector3
---@field get_local_direction fun(_direction_type: Enums.DirectionType): Vector3
---@field get_local_offset_position fun(_offset: Vector3): Vector3
---@field get_local_quaternion fun(_direction_type: Enums.DirectionType): Quaternion
---@field get_max_linear_velocity fun(): Fixed
---@field get_name fun(): string
---@field get_orientation fun(): Quaternion
---@field get_parent fun(): Unit
---@field get_position fun(): Vector3
---@field get_rigid_body_type fun(): Enums.RigidBodyType
---@field get_role fun(): Role
---@field get_role_id fun(): RoleID
---@field get_scale fun(): Vector3
---@field get_unit_type fun(): Enums.UnitType
---@field hide_bubble_msg fun()
---@field is_character fun(): boolean
---@field is_creature fun(): boolean
---@field is_dynamic fun(): boolean
---@field is_dynamic_body fun(): boolean
---@field is_in_customtriggerspace fun(_custom_trigger_space: CustomTriggerSpace, _consider_mask: boolean?): boolean
---@field is_kinematic_body fun(): boolean
---@field is_model_visible fun(): boolean
---@field is_physics_active fun(): boolean
---@field is_static_body fun(): boolean
---@field is_valid_ability_target fun(_ability: Ability): boolean
---@field model_play_animation fun(_anim_name: string, _start_time: Fixed, _is_loop: boolean, _play_speed: Fixed)
---@field model_stop_animation fun()
---@field play_3d_sound fun(_sound_key: SoundKey, _duration: Fixed?, _volume: Fixed?): SoundID
---@field play_emoji fun(_emoji_key: EmojiKey)
---@field play_emoji_with_offset fun(_emoji_key: EmojiKey, _show_time: Fixed, _offset: Vector3)
---@field play_sound_with_dis_and_attenuation fun(_event_id: SoundKey, _vis_dis: Fixed, _sound_attenuation_curve: string): SoundID
---@field recover_max_linear_velocity fun()
---@field remove_from_parent fun()
---@field remove_surround_motor fun()
---@field set_acc_motor_init_velocity fun(_index: integer, _init_vel: Vector3)
---@field set_angular_velocity fun(_vel: Vector3)
---@field set_current_mass fun(_mass: Fixed)
---@field set_current_mass_center fun(_center: Vector3)
---@field set_linear_motor_velocity fun(_index: integer, _vel: Vector3, _is_local: boolean?)
---@field set_linear_velocity fun(_vel: Vector3)
---@field set_max_linear_velocity fun(_velocity: Fixed)
---@field set_mirror_reflect_enabled fun(_enable: boolean)
---@field set_model_visible fun(_v: boolean)
---@field set_orientation fun(_rot: Quaternion)
---@field set_orientation_smooth fun(_rot: Quaternion)
---@field set_paint_area_color fun(_paint_area: PaintArea, _color: Color)
---@field set_physics_active fun(_is_active: boolean)
---@field set_position fun(_pos: Vector3)
---@field set_position_smooth fun(_pos: Vector3)
---@field set_scale fun(_scale: Fixed, _time: Fixed)
---@field set_world_scale fun(_scale: Vector3)
---@field show_bubble_msg fun(_show_msg: string, _show_time: Fixed, _max_dis: Fixed?, _offset: Vector3?)
---@field stop_sound fun(_lres_id: SoundID)

---@class UnitInteractVolumeComp
---@field get_interact_id fun(_interact_index: integer, _interact_btn_type: Enums.InteractBtnType): InteractBtnID
---@field set_interact_button_icon fun(_interact_id: InteractBtnID, _icon: ImageKey)
---@field set_interact_button_text fun(_interact_id: InteractBtnID, _text: string)
---@field set_interact_button_text_by_index fun(_interact_index: integer, _text: string)
---@field set_interact_enabled fun(_enable: boolean)
---@field set_interact_enabled_by_index fun(_interact_index: integer, _enable: boolean)

---@class VehicleComp
---@field reset fun()
---@field start_move_by_direction fun(_direction: Vector3, _duration: Fixed)
---@field stop_move fun()

---@class VirtualEquipment

---@class EVENT

---@class Enums.AIBasicCommand

---@class Enums.AbilityLimitation

---@class Enums.AbilityPointerType

---@class Enums.AbilityTargetType

---@class Enums.ArchiveType

---@class Enums.AxisType

---@class Enums.BindType

---@class Enums.BuffState

---@class Enums.CameraBindMode

---@class Enums.CameraDragType

---@class Enums.CameraProjectionType

---@class Enums.CameraPropertyType

---@class Enums.CameraShakeCurve

---@class Enums.CameraShakeType

---@class Enums.CampRelationType

---@class Enums.CollisionLimitType

---@class Enums.ColorPaintAreaType

---@class Enums.CommonUnitType

---@class Enums.CoordinateSystemType

---@class Enums.DirectionType

---@class Enums.DropType

---@class Enums.EquipmentSlotType

---@class Enums.EquipmentType

---@class Enums.FixedRoundType

---@class Enums.FriendshipType

---@class Enums.GameResult

---@class Enums.HpBarDisplayMode

---@class Enums.InteractBtnType

---@class Enums.JointAssistantKey

---@class Enums.JointAssistantProperty

---@class Enums.ModelSocket

---@class Enums.MoveMode

---@class Enums.NavMode

---@class Enums.OrientationType

---@class Enums.PatrolType

---@class Enums.PlaneType

---@class Enums.QuestStatus

---@class Enums.RigidBodyType

---@class Enums.SearchEnemyPriority

---@class Enums.SkyBoxGradualType

---@class Enums.TriggerSpaceEventType

---@class Enums.UnitType

---@class Enums.ValueType

---@class Enums.WindFieldShapeType

---@type Vector3
Vector3 = Vector3

---@type Quaternion
Quaternion = Quaternion

---@type dict
dict = dict

---@type Damage
Damage = Damage

---@type Decoration
Decoration = Decoration

---@type JointAssistant
JointAssistant = JointAssistant

---@type Timer
Timer = Timer

---@type UnitGroup
UnitGroup = UnitGroup

---@type Vehicle
Vehicle = Vehicle

---@type Enums
Enums = Enums

---@type GlobalAPI
GlobalAPI = GlobalAPI

---@type Ability
Ability = Ability

---@type AbilityComp
AbilityComp = AbilityComp

---@type Actor
Actor = Actor

---@type AttrComp
AttrComp = AttrComp

---@type BuffStateComp
BuffStateComp = BuffStateComp

---@type Camp
Camp = Camp

---@type Character
Character = Character

---@type CharacterComp
CharacterComp = CharacterComp

---@type Creature
Creature = Creature

---@type CustomTriggerSpace
CustomTriggerSpace = CustomTriggerSpace

---@type DebugAPI
DebugAPI = DebugAPI

---@type DisplayComp
DisplayComp = DisplayComp

---@type Equipment
Equipment = Equipment

---@type EquipmentComp
EquipmentComp = EquipmentComp

---@type ExprDeviceComp
ExprDeviceComp = ExprDeviceComp

---@type GameAPI
GameAPI = GameAPI

---@type ItemBox
ItemBox = ItemBox

---@type JointAssistantComp
JointAssistantComp = JointAssistantComp

---@type JumpComp
JumpComp = JumpComp

---@type KVBase
KVBase = KVBase

---@type LevelComp
LevelComp = LevelComp

---@type LifeComp
LifeComp = LifeComp

---@type LifeEntity
LifeEntity = LifeEntity

---@type LiftComp
LiftComp = LiftComp

---@type LiftedComp
LiftedComp = LiftedComp

---@type LuaAPI
LuaAPI = LuaAPI

---@type Modifier
Modifier = Modifier

---@type ModifierComp
ModifierComp = ModifierComp

---@type MoveStatusComp
MoveStatusComp = MoveStatusComp

---@type Obstacle
Obstacle = Obstacle

---@type OwnerComp
OwnerComp = OwnerComp

---@type Role
Role = Role

---@type RollComp
RollComp = RollComp

---@type RushComp
RushComp = RushComp

---@type SceneUI
SceneUI = SceneUI

---@type TriggerSpace
TriggerSpace = TriggerSpace

---@type TriggerSystem
TriggerSystem = TriggerSystem

---@type Unit
Unit = Unit

---@type UnitInteractVolumeComp
UnitInteractVolumeComp = UnitInteractVolumeComp

---@type VehicleComp
VehicleComp = VehicleComp

---@type VirtualEquipment
VirtualEquipment = VirtualEquipment

---@type EVENT
EVENT = EVENT
