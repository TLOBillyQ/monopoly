---@meta

---@alias Fixed number

---@class Vector3
---@field x Fixed
---@field y Fixed
---@field z Fixed
---@field yaw Fixed
---@field pitch Fixed
---@field length fun(self: Vector3): Fixed
---@field dot fun(self: Vector3, other: Vector3): Fixed
---@field cross fun(self: Vector3, other: Vector3): Vector3
---@field normalize fun(self: Vector3): Fixed

---@class Quaternion
---@field x Fixed
---@field y Fixed
---@field z Fixed
---@field w Fixed
---@field yaw Fixed
---@field pitch Fixed
---@field roll Fixed
---@field inverse fun(self: Quaternion): Quaternion
---@field slerp fun(self: Quaternion, other: Quaternion, t: Fixed): Quaternion

---@class Creature
---@field id integer?
---@field start_ai fun(self: Creature)
---@field get_position fun(self: Creature): Vector3?
---@field create_scene_ui_bind_unit fun(self: Creature, layout_id: integer|string, socket: any, offset: Vector3, duration: Fixed, follow: boolean, visible: boolean): any

---@class Role
---@field id integer?
---@field get_ctrl_unit fun(self: Role): Creature?
---@field get_roleid fun(self: Role): integer?
---@field get_name fun(self: Role): string?
---@field get_head_icon fun(self: Role): integer?
---@field create_scene_ui_bind_unit fun(self: Role, layout_id: integer|string, socket: any, offset: Vector3, duration: Fixed, follow: boolean, visible: boolean): any
---@field send_ui_custom_event fun(self: Role, ...): boolean
---@field lose fun(self: Role): boolean
---@field game_win_and_show_result_panel fun(self: Role): boolean

---@class Frameout
---@field frame integer
---@field left_count integer
---@field status boolean
---@field destroy fun()
---@field pause fun()
---@field resume fun()

---@class UIManagerBuilder
---@field new fun(self: UIManagerBuilder, nodes: table): UIManagerBuilder

---@class UIManagerEvent
---@field CLICK string

---@class UIManager
---@field client_role Role?
---@field Builder UIManagerBuilder
---@field EVENT UIManagerEvent
---@field get_first_node_by_name fun(name: string): table?
---@field query_nodes_by_name fun(name: string): table[]
---@field query_node_by_id fun(id: integer): table?
---@field typeof fun(node: table?, type_name: string): boolean

---@class Utils
---@field choice fun(...): any
---@field choice_list fun(list: table, n: integer?, repeat_enable: boolean?): table
---@field deep_copy fun(orig: any): any
---@field array_find fun(array: table, predicate: fun(item: any): boolean): any

---@class GameAPI
---@field create_unit_group fun(group_id: integer|string, pos: Vector3, rotation: Quaternion): any
---@field create_unit_with_scale fun(unit_id: integer|string, pos: Vector3, rotation: Quaternion, scale: Fixed): any
---@field create_creature_fixed_scale fun(unit_key: integer|string, pos: Vector3, rotation: Quaternion, scale_ratio: Fixed, role: Role?): Creature?
---@field destroy_unit_with_children fun(handle: any, include_children: boolean)
---@field destroy_scene_ui fun(layer: any): boolean
---@field get_all_valid_roles fun(): Role[]
---@field get_goods_list fun(): table[]
---@field get_role fun(role_id: integer): Role?
---@field play_3d_sound fun(position: Vector3, sound_key: integer, duration: Fixed?, volume: number?): integer?
---@field play_sfx_by_key fun(sfx_key: integer, pos: Vector3, rot: Quaternion, scale: Fixed, duration: Fixed?, rate: Fixed?, with_sound: boolean?): integer?
---@field set_scene_ui_visible fun(layer: any, role: Role, visible: boolean): boolean
---@field stop_sound fun(sound_id: integer): boolean
---@field destroy_unit fun(unit: Creature): boolean

---@class GlobalAPI
---@field show_tips fun(text: string, duration: number?): boolean?
---@field bind_sfx_to_unit fun(sfx_id: integer, unit: Creature, socket_name: string?, pos: Vector3?, bind_type: integer|string?): boolean
---@field destroy_sfx fun(sfx_id: integer, fade_out: boolean): boolean

---@class SceneUI
---@field create_scene_ui_bind_unit fun(layout_id: integer|string, socket: any, offset: Vector3, duration: Fixed, follow: boolean, visible: boolean): any

---@class EVENT
---@field GAME_INIT string
---@field REPEAT_TIMEOUT string
---@field SPEC_ROLE_PURCHASE_GOODS string

---@class EnumsBuffState
---@field BUFF_FORBID_CONTROL integer|string

---@class EnumsModelSocket
---@field socket_head integer|string

---@class Enums
---@field BuffState EnumsBuffState
---@field ModelSocket EnumsModelSocket

---@type fun(class_name: string, ...): table
Class = function(class_name, ...) end

---@type UIManager
UIManager = UIManager

---@type Utils
Utils = Utils

---@type fun(interval: integer, callback: fun(frameout: Frameout), count: integer?, immediately: boolean?): Frameout
SetFrameOut = SetFrameOut

---@type fun(config: table, callback: fun(event_name: string?, actor: any?, data: any?)): any
RegisterTriggerEvent = RegisterTriggerEvent

---@type GameAPI
GameAPI = GameAPI

---@type GlobalAPI
GlobalAPI = GlobalAPI

---@type SceneUI
SceneUI = SceneUI

---@type EVENT
EVENT = EVENT

---@type Enums
Enums = Enums

---@type fun(thread: any?, message: string?, level: integer?): string
traceback = traceback

---@type fun(x: Fixed, y: Fixed, z: Fixed): Vector3
math.Vector3 = function(x, y, z) end

---@type fun(a: Fixed, b: Fixed, c: Fixed, d: Fixed?): Quaternion
math.Quaternion = function(a, b, c, d) end

---@type fun(value: number): Fixed
math.tofixed = function(value) end
