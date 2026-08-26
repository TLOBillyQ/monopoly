-- int 档案读写默认实现(自 default_ports.lua 拆分,行为保持):经 defaults.resolve_role
-- 解析角色(调用时解析,须在 role_ports.install 之后安装),读失败统一回落 0,
-- 写失败返回 false。
local number_utils = require("src.foundation.number")

local archive_ports = {}

local function _current_env(runtime_context)
  local ctx = runtime_context.current and runtime_context.current() or nil
  return ctx and ctx.env or nil
end

local function _current_game_api(runtime_context)
  local env = _current_env(runtime_context)
  return env and env["Game" .. "API"] or nil
end

local function _int_archive_type()
  return Enums and Enums.ArchiveType and Enums.ArchiveType.Int or nil
end

function archive_ports.archives_enabled(runtime_context)
  local game_api = _current_game_api(runtime_context)
  if game_api and type(game_api.is_archives_enabled) == "function" then
    local ok, enabled = pcall(game_api.is_archives_enabled)
    if ok then
      return enabled == true
    end
  end
  return false
end

local function _has_archive_reader(role, archive_type)
  return role and archive_type ~= nil and type(role.get_archive_by_type) == "function"
end

local function _read_archive_int(role, archive_type, key)
  if not _has_archive_reader(role, archive_type) then
    return 0
  end
  local ok, value = pcall(role.get_archive_by_type, role, archive_type, key)
  if ok and number_utils.is_numeric(value) then
    return value
  end
  return 0
end

function archive_ports.install(defaults, runtime_context)
  defaults.archives_enabled = function()
    return archive_ports.archives_enabled(runtime_context)
  end

  defaults.get_archive_int = function(role_id, key)
    local role = defaults.resolve_role(role_id)
    local archive_type = _int_archive_type()
    return _read_archive_int(role, archive_type, key)
  end

  defaults.set_archive_int = function(role_id, key, value)
    local role = defaults.resolve_role(role_id)
    local archive_type = _int_archive_type()
    if not (role and archive_type ~= nil and type(role.set_archive_by_type) == "function") then
      return false
    end
    local ok = pcall(role.set_archive_by_type, role, archive_type, key, value)
    return ok == true
  end
end

return archive_ports

--[[ mutate4lua-manifest
version=4
projectHash=5cd3776d434380b4
scope.0.id=chunk:src/host/archive_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=71
scope.0.semanticHash=514d890d7f436527
scope.1.id=function:_current_env
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=11
scope.1.semanticHash=d08d43958f5bffa4
scope.2.id=function:_current_game_api
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=16
scope.2.semanticHash=c1a993e537c4d1c6
scope.3.id=function:_int_archive_type
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=20
scope.3.semanticHash=b509dfe52ef2592d
scope.4.id=function:archive_ports.archives_enabled
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=31
scope.4.semanticHash=4f6d0828c22cc4c0
scope.5.id=function:_has_archive_reader
scope.5.kind=function
scope.5.startLine=33
scope.5.endLine=35
scope.5.semanticHash=fc7e812addfe7bc8
scope.6.id=function:_read_archive_int
scope.6.kind=function
scope.6.startLine=37
scope.6.endLine=46
scope.6.semanticHash=91f69859315e3d26
scope.7.id=function:archive_ports.install
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=68
scope.7.semanticHash=6ba728f24baaa1c1
scope.8.id=function:defaults.archives_enabled
scope.8.kind=function
scope.8.startLine=49
scope.8.endLine=51
scope.8.semanticHash=7bbf31ab6751de78
scope.9.id=function:defaults.get_archive_int
scope.9.kind=function
scope.9.startLine=53
scope.9.endLine=57
scope.9.semanticHash=d5594729c526d32b
scope.10.id=function:defaults.set_archive_int
scope.10.kind=function
scope.10.startLine=59
scope.10.endLine=67
scope.10.semanticHash=2cd229143b01d4a4
]]
