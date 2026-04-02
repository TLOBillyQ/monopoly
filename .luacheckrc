std = "lua54"
codes = true
max_line_length = false
unused_args = false

exclude_files = {
  "vendor/**/*.lua",
  "Data/**/*.lua",
  "tmp/**/*.lua",
}

read_globals = {
  "arg",
  "GameAPI",
  "GlobalAPI",
  "UIManager",
  "LuaAPI",
  "SetTimeOut",
  "SetFrameOut",
  "RegisterCustomEvent",
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
}

files["src/host/global_aliases.lua"] = {
  globals = {
    "GameAPI",
    "LuaAPI",
    "SetTimeOut",
    "RegisterCustomEvent",
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
  },
}
