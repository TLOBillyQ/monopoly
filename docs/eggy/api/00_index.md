# EggyAPI 拆分索引

本目录用于按功能拆分 `EggyAPI.lua`，加速查询并保证 API 完整性。

## 目录

- 01_types.md：基础类型与方法清单（Vector3/Quaternion/dict/math）。
- 02_aliases.md：类型别名清单（`---@alias`）。
- 03_enums.md：枚举清单（`---@enum`）。
- 04_global_api.md：GlobalAPI 方法索引。
- 05_game_api.md：GameAPI 方法索引。
- 06_lua_api.md：LuaAPI 方法索引。
- 07_unit_entities.md：实体类方法索引（Unit/Role/Ability 等）。
- 08_components.md：组件类方法索引（*Comp）。
- 09_events.md：事件常量与示例。

校验方式：运行 `lua scripts/eggy_api.lua`，默认包含校验。
