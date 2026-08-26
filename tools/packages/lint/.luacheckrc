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

-- tooling 单测(tools/**/test/)同样迁 LuaUnit 原生风格,TestXxx 类全局同上人肉
-- 白名单不可枚举,放开 W111/W112。
files["tools/**/test/**/*.lua"] = {
  allow_defined = true,
  -- LuaUnit 方法带 self 参数,内嵌 mock 方法 function(self) 遮蔽外层 self
  -- 是测试夹具惯例(busted 时代 it 回调无 self,不存在该告警),放开 W412/W432。
  ignore = { "412", "432" },
}

-- test/** 继承原 spec/** 的口径:测试与其 support helper 会 stub 宿主注入全局
-- (LuaAPI/GameAPI/Enums/SetFrameOut/TriggerCustomEvent/...)并在转调 vendor CLI 前
-- 改写 `arg`。这里按可写全局放行,避免上方 read_globals 默认值误报正常的测试搭建。
files["test/**/*.lua"] = {
  -- LuaUnit 原生测试以 TestXxx 全局表注册测试类(迁移后约 400+ 个),名字
  -- 随文件无限增长,无法枚举白名单;测试文件的全局定义本就由 runner 注册
  -- 语义兜底,放开 W111/W112。
  allow_defined = true,
  -- LuaUnit 方法带 self 参数,内嵌 mock 方法 function(self) 遮蔽外层 self
  -- 是测试夹具惯例(busted 时代 it 回调无 self,不存在该告警),放开 W412/W432。
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
