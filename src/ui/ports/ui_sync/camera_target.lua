-- 相机目标解析:follow 目标位置与「本机 role」身份链。
-- 原 ui_sync/camera.lua 的解析链;camera.lua 保留编排与公共面。
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_state = require("src.ui.state.runtime")
local unit_position = require("src.ui.render.support.unit_position")
local runtime_ui = require("src.ui.render.support.runtime_ui")

local M = {}

local function _safe_call_method(state, obj, key, log_key, log_prefix)
  if type(obj[key]) ~= "function" then return nil end
  local ok, result = pcall(obj[key])
  if not ok then
    runtime_state.log_once(state, "warn", log_key, "camera_sync", log_prefix, tostring(result))
    return nil
  end
  return result
end

local function _resolve_unit_position(state, role)
  if role == nil then return nil end
  local unit = _safe_call_method(state, role, "get_ctrl_unit", "camera_sync:get_ctrl_unit_failed", "resolve unit failed:")
  if unit == nil then return nil end
  return _safe_call_method(state, unit, "get_position", "camera_sync:get_position_failed", "resolve unit position failed:")
end

local function _resolve_followed_unit_live_position(state, player_id)
  local board_scene = state and state.board_scene or nil
  if board_scene == nil then
    return nil
  end
  local units_by_player_id = board_scene.units_by_player_id
  if type(units_by_player_id) ~= "table" then
    return nil
  end
  return unit_position.read_unit_position(units_by_player_id[player_id])
end

function M.resolve_follow_target_position(state, player_id)
  local live_pos = _resolve_followed_unit_live_position(state, player_id)
  if live_pos ~= nil then
    return live_pos
  end
  local followed_pos = runtime_state.get_follow_target_position(state, player_id)
  if followed_pos ~= nil then
    return followed_pos
  end
  local target_role = runtime_ports.resolve_role(player_id)
  if target_role == nil then
    return nil
  end
  return _resolve_unit_position(state, target_role)
end

local function _current_player_index(turn)
  return turn and turn.current_player_index or nil
end

local function _player_at_index(players, current_index)
  return current_index and players and players[current_index] or nil
end

local function _current_player(game)
  local players = game and game.players or nil
  return _player_at_index(players, _current_player_index(game and game.turn or nil))
end

local function _resolve_current_player_id(state)
  local game = state and state.game or nil
  local current_player = _current_player(game)
  return current_player and current_player.id or nil
end

-- 单 role 兜底链路的「本机角色」(#601):client_role 优先(多席位局跟本机
-- 角色),client_role 缺位才兜底当前行动玩家。「上一次点击者缓存」已整体退役,
-- 不再参与相机身份解析。
local function _resolve_camera_local_role_id(state)
  return runtime_ui.resolve_role_id(runtime_ui.get_client_role())
    or _resolve_current_player_id(state)
end

function M.resolve_local_role(state)
  local role_id = _resolve_camera_local_role_id(state)
  if role_id == nil then return nil, nil end
  return runtime_ports.resolve_role(role_id), role_id
end

-- 目标位置惰性解析并记忆:全场都在看自己时一次宿主查询都不做,多 role 时也只查一次。
function M.make_target_pos_reader(state, player_id)
  local resolved = false
  local pos = nil
  return function()
    if not resolved then
      resolved = true
      pos = M.resolve_follow_target_position(state, player_id)
    end
    return pos
  end
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=1f07fc4d906aaf71
scope.0.id=chunk:src/ui/ports/ui_sync/camera_target.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=102
scope.0.semanticHash=ccd875813d52048a
scope.1.id=function:_safe_call_method
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=18
scope.1.semanticHash=4c1f1820ba4a5e92
scope.2.id=function:_resolve_unit_position
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=25
scope.2.semanticHash=45459e2422916572
scope.3.id=function:_resolve_followed_unit_live_position
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=37
scope.3.semanticHash=9ff14ff6e6518ea0
scope.4.id=function:M.resolve_follow_target_position
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=53
scope.4.semanticHash=2874b841fa8f8e15
scope.5.id=function:_current_player_index
scope.5.kind=function
scope.5.startLine=55
scope.5.endLine=57
scope.5.semanticHash=616a2ca60599c94f
scope.6.id=function:_player_at_index
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=61
scope.6.semanticHash=d96099a83457134a
scope.7.id=function:_current_player
scope.7.kind=function
scope.7.startLine=63
scope.7.endLine=66
scope.7.semanticHash=296c0613dd8c8b10
scope.8.id=function:_resolve_current_player_id
scope.8.kind=function
scope.8.startLine=68
scope.8.endLine=72
scope.8.semanticHash=d81e1eb2c2ac7149
scope.9.id=function:_resolve_camera_local_role_id
scope.9.kind=function
scope.9.startLine=77
scope.9.endLine=80
scope.9.semanticHash=f79031f511958b57
scope.10.id=function:M.resolve_local_role
scope.10.kind=function
scope.10.startLine=82
scope.10.endLine=86
scope.10.semanticHash=16a1070c8ec1b8ce
scope.11.id=function:M.make_target_pos_reader
scope.11.kind=function
scope.11.startLine=89
scope.11.endLine=99
scope.11.semanticHash=35b68811bcaaafe0
scope.12.id=function:<anonymous>
scope.12.kind=function
scope.12.startLine=92
scope.12.endLine=98
scope.12.semanticHash=65cf45adcdeebf0f
]]
