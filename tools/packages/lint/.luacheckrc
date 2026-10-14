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
  "UnregisterTriggerEvent",
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
  "describe", "it", "before_each", "after_each", "setup", "teardown", "finally",
}

-- Genuine busted supplies its luassert object inside spec environments.
files["test/behavior/foundation/test_class.lua"] = { read_globals = { "assert" }, std = "+busted" }
files["test/behavior/foundation/test_scope.lua"] = { read_globals = { "assert" }, std = "+busted" }
files["test/fixtures/busted_backend/**/*.lua"] = { std = "+busted" }

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
    "UnregisterTriggerEvent",
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

-- tooling 单测(tools/**/test/)会 stub 宿主/运行时全局并改写 `arg`,名字随文件
-- 增长无法枚举白名单,放开 W111/W112。
files["tools/**/test/**/*.lua"] = {
  allow_defined = true,
  -- 测试夹具里内嵌 mock 方法 function(self) 遮蔽外层 self 是惯例
  -- (busted 的 it 回调无 self,不存在该告警),放开 W412/W432。
  ignore = { "412", "432" },
}

-- test/** 继承原 spec/** 的口径:测试与其 support helper 会 stub 宿主注入全局
-- (LuaAPI/GameAPI/Enums/SetFrameOut/TriggerCustomEvent/...)并在转调 vendor CLI 前
-- 改写 `arg`。这里按可写全局放行,避免上方 read_globals 默认值误报正常的测试搭建。
files["test/**/*.lua"] = {
  -- 测试会往 _G 上装 stub(宿主注入面与临时替换),名字随文件增长无法枚举
  -- 白名单;测试文件的全局定义由用例自身的 teardown 兜底,放开 W111/W112。
  allow_defined = true,
  -- 测试夹具里内嵌 mock 方法 function(self) 遮蔽外层 self 是惯例
  -- (busted 的 it 回调无 self,不存在该告警),放开 W412/W432。
  ignore = { "412", "432" },
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
