-- luacheck 1.2.0 不识别 lua55；5.5 是 5.4 的语法+stdlib 超集，lua54 std 检查仍准确。等 luacheck 升级后再切。
std = "lua54"
codes = true
max_line_length = false
unused_args = false

exclude_files = {
  "vendor/**/*.lua",
  "Data/**/*.lua",
  "tmp/**/*.lua",
}

-- Eggy host-injected globals (read-only by default)
read_globals = {
  "arg",
  "Class",
  "Utils",
  "GameAPI",
  "GlobalAPI",
  "LuaAPI",
  "SetTimeOut",
  "SetFrameOut",
  "RegisterCustomEvent",
  "UnregisterCustomEvent",
  "RegisterTriggerEvent",
  "TriggerCustomEvent",
  "UnitCustomEvent",
  "UnitTriggerEvent",
  "EVENT",
  "Enums",
  "ALLROLES",
  "all_roles",
  "vehicle_helper",
  "camera_helper",
  "change_skin_helper",
  "Prefab",
  "traceback",
  "newproxy",
  "unpack",
}

globals = {
  "UIManager",
  "SceneUI",
  math = { fields = { "Vector3", "Quaternion", "tofixed" } },
}

files["src/host/global_aliases.lua"] = {
  globals = {
    "GameAPI",
    "LuaAPI",
    "SetTimeOut",
    "RegisterCustomEvent",
    "UnregisterCustomEvent",
    "RegisterTriggerEvent",
    "UnitCustomEvent",
    "UnitTriggerEvent",
    "TriggerCustomEvent",
  },
}

files["src/host/context.lua"] = {
  globals = {
    "vehicle_helper",
    "camera_helper",
    "change_skin_helper",
    "all_roles",
    "ALLROLES",
  },
}

files["tests/**/*.lua"] = {
  globals = {
    "GameAPI",
    "GlobalAPI",
    "UIManager",
    "LuaAPI",
    "SetTimeOut",
    "SetFrameOut",
    "RegisterCustomEvent",
    "UnregisterCustomEvent",
    "RegisterTriggerEvent",
    "TriggerCustomEvent",
    "UnitCustomEvent",
    "UnitTriggerEvent",
    "EVENT",
    "Enums",
    "ALLROLES",
    "all_roles",
    "vehicle_helper",
    "camera_helper",
    "change_skin_helper",
    "SceneUI",
    "print",
  },
}

-- gameplay_cases_*.lua use `local _ENV = helpers` which injects all helpers
-- table fields into the function scope; luacheck cannot resolve dynamic _ENV.
files["tests/suites/gameplay/gameplay_cases_*.lua"] = {
  globals = {
    "GameAPI", "GlobalAPI", "UIManager", "LuaAPI",
    "SetTimeOut", "SetFrameOut",
    "RegisterCustomEvent", "UnregisterCustomEvent",
    "RegisterTriggerEvent", "TriggerCustomEvent",
    "UnitCustomEvent", "UnitTriggerEvent",
    "EVENT", "Enums", "ALLROLES", "all_roles",
    "vehicle_helper", "camera_helper", "change_skin_helper",
    "SceneUI", "print",
    -- shared_support helpers
    "support", "app", "movement", "turn_move", "inventory",
    "steal", "choice_resolver", "gameplay_loop", "turn_anim",
    "tick_timeout", "constants", "bankruptcy", "map_cfg", "tiles_cfg",
    "number_utils", "logger", "tip_queue", "runtime_context",
    "runtime_ports", "runtime_state", "landing_visual_hold",
    "host_runtime_ports", "monopoly_event",
    -- gameplay_cases_helpers locals
    "gameplay_loop_ports", "turn_dispatch", "item_ids", "timing",
    "dispatch_validator", "tick_ui_sync", "tick_choice_timeout",
    "choice_auto_policy", "turn_timer_policy",
    "turn_role_control_policy", "turn_camera_policy",
    "gameplay_loop_runtime", "move_followup", "intent_dispatcher",
    "game_startup_event_bridge", "market_service",
    "phase_registry", "turn_decision", "item_effects",
    "item_strategy", "facing_policy", "turn_start", "turn_script",
    "roll", "item_slot_data", "default_ports",
    "_t2_cases_module", "_t2_case_groups",
    "_with_reloaded_move_module",
    "_new_game", "_build_ui_port", "_bind_ui_runtime",
    "_resolve_landing", "_resolve_landing_with_choices",
    "_resolve_choice_first", "_get_choice", "_open_choice",
    "_first_land_tile", "_first_tile_by_type", "_tile_state",
    "_build_startup_state", "_mock_lua_api",
    "_with_runtime_context_globals", "_install_global_aliases",
    "_build_test_ports", "_build_loop_state", "_with_timestamp_stub",
  },
}

files["tools/quality/scrap/config.lua"] = {
  read_globals = { "REPO_ROOT" },
}

-- spec/** mirrors tests/**: busted specs and their support helpers stub host-injected
-- globals (LuaAPI/GameAPI/Enums/SetFrameOut/TriggerCustomEvent/...) and rewrite `arg`
-- before delegating to vendor CLIs. Treat these as writeable globals here so the
-- read_globals defaults above don't flag legitimate test setup.
files["spec/**/*.lua"] = {
  globals = {
    "arg",
    "GameAPI",
    "GlobalAPI",
    "UIManager",
    "LuaAPI",
    "SetTimeOut",
    "SetFrameOut",
    "RegisterCustomEvent",
    "UnregisterCustomEvent",
    "RegisterTriggerEvent",
    "TriggerCustomEvent",
    "UnitCustomEvent",
    "UnitTriggerEvent",
    "EVENT",
    "Enums",
    "ALLROLES",
    "all_roles",
    "vehicle_helper",
    "camera_helper",
    "change_skin_helper",
    "SceneUI",
    "print",
  },
}
