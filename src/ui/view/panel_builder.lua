local gameplay_read_port = require("src.ui.view.gameplay_read_port")
local number_utils = require("src.foundation.number")
local role_avatar = require("src.ui.view.role_avatar")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local panel = {}
local _ZERO = number_utils.to_integer("0")

local function _normalize_integer_value(value)
  local normalized = number_utils.to_integer(value)
  if normalized == nil then
    return _ZERO
  end
  return math.max(normalized, _ZERO)
end

local function _resolve_role(player)
  if not player or player.id == nil then
    return nil
  end
  return runtime_ports.resolve_role(player.id)
end

local function _valid_name(role_name)
  return role_name ~= nil and role_name ~= ""
end

local function _resolve_role_name(role)
  if not role or type(role.get_name) ~= "function" then
    return nil
  end
  local ok, role_name = pcall(role.get_name)
  if not ok or not _valid_name(role_name) then
    return nil
  end
  return role_name
end

local _empty_status = {
  name = "",
  avatar = nil,
  eliminated = false,
  cash_value = nil,
  total_assets_value = nil,
  cash = "",
  land_count = "",
  total_assets = "",
}

local _cached_statuses = {
  {},
  {},
  {},
  {},
}
local _cached_cash_values = {}
local _cached_land_values = {}
local _cached_total_values = {}

local function _read_player_cash(game, player)
  if game == nil or type(game.player_cash) ~= "function" then
    return _ZERO
  end
  return _normalize_integer_value(game:player_cash(player))
end

local function _tile_of(board, tile_id)
  return board and board.get_tile_by_id and board:get_tile_by_id(tile_id) or nil
end

-- 土地类地块按其等级累加投入;非土地或地块缺省时总额不变。
local function _accumulate_tile_invested(tile, total)
  if tile and tile.type == "land" then
    local level = tile.level or 0
    return total + gameplay_read_port.total_land_invested(tile, level)
  end
  return total
end

local function _accumulate_player_assets(game, player, board)
  local cash = _read_player_cash(game, player)
  local land_count = 0
  local total = cash
  for tile_id in pairs(player.properties or {}) do
    land_count = land_count + 1
    total = _accumulate_tile_invested(_tile_of(board, tile_id), total)
  end
  return cash, land_count, total
end

local function _build_player_label(player_name, eliminated)
  local display_name = player_name or ""
  if eliminated then
    return display_name .. " (出局)"
  end
  return display_name
end

local function _sync_cached_label(cache, index, value, prefix, current_label)
  if cache[index] == value then
    return current_label
  end
  cache[index] = value
  return prefix .. number_utils.format_integer_part(value)
end

local function _build_player_status(game, player, board, index)
  local status = _cached_statuses[index]
  local role = _resolve_role(player)
  local display_name = _resolve_role_name(role) or player.name
  status.name = _build_player_label(display_name, player.eliminated == true)
  status.avatar = role_avatar.resolve_from_role(role)
  status.eliminated = player.eliminated == true
  local cash, land_count, total = _accumulate_player_assets(game, player, board)
  status.cash_value = cash
  local normalized_total = _normalize_integer_value(total)
  status.total_assets_value = normalized_total
  local display_cash = cash
  status.cash = _sync_cached_label(_cached_cash_values, index, display_cash, "现金: ", status.cash)
  status.land_count = _sync_cached_label(_cached_land_values, index, land_count, "地块: ", status.land_count)
  local display_total = normalized_total
  status.total_assets = _sync_cached_label(_cached_total_values, index, display_total, "总资产: ", status.total_assets)
  return status
end

local _cached_turn_label_seconds
local _cached_turn_label

function panel.build_turn_label(_, countdown_seconds)
  local secs = countdown_seconds or 0
  if secs ~= _cached_turn_label_seconds then
    _cached_turn_label_seconds = secs
    _cached_turn_label = "倒计时:" .. tostring(secs)
  end
  return _cached_turn_label
end


local _status_out = {}

local function _build_status_row(game, player, board, index)
  if player then
    return _build_player_status(game, player, board, index)
  end
  return _empty_status
end

local function _fill_status_rows(game, players, board, count)
  for i = 1, count do
    _status_out[i] = _build_status_row(game, players[i], board, i)
  end
end

local function _trim_status_rows(count)
  for i = count + 1, #_status_out do
    _status_out[i] = nil
  end
end

local function _players_of(game)
  return game and game.players or {}
end

local function _board_of(game_obj)
  return game_obj and game_obj.board or nil
end

function panel.build_player_statuses(game, game_obj, max_players)
  local players = _players_of(game)
  local count = max_players or #players
  local board = _board_of(game_obj)
  _fill_status_rows(game, players, board, count)
  _trim_status_rows(count)
  return _status_out
end

function panel.build_auto_label(_auto_play)
  return "托管"
end

return panel

--[[ mutate4lua-manifest
version=4
projectHash=9cac1584e9ff5003
scope.0.id=chunk:src/ui/view/panel_builder.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=182
scope.0.semanticHash=9e09fbbc31ec2f47
scope.1.id=function:_normalize_integer_value
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=15
scope.1.semanticHash=9f0aa440b636a3e1
scope.2.id=function:_resolve_role
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=22
scope.2.semanticHash=197ede203bb292dc
scope.3.id=function:_valid_name
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=26
scope.3.semanticHash=1aa50cecf1c88116
scope.4.id=function:_resolve_role_name
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=37
scope.4.semanticHash=f6511c775cb31798
scope.5.id=function:_read_player_cash
scope.5.kind=function
scope.5.startLine=60
scope.5.endLine=65
scope.5.semanticHash=ad3e543b6987498b
scope.6.id=function:_tile_of
scope.6.kind=function
scope.6.startLine=67
scope.6.endLine=69
scope.6.semanticHash=bf6391145220f433
scope.7.id=function:_accumulate_tile_invested
scope.7.kind=function
scope.7.startLine=72
scope.7.endLine=78
scope.7.semanticHash=177975d918d3426c
scope.8.id=function:_accumulate_player_assets
scope.8.kind=function
scope.8.startLine=80
scope.8.endLine=89
scope.8.semanticHash=8879dc8a7e2683dd
scope.9.id=function:_build_player_label
scope.9.kind=function
scope.9.startLine=91
scope.9.endLine=97
scope.9.semanticHash=d0b0c9dda19fcabf
scope.10.id=function:_sync_cached_label
scope.10.kind=function
scope.10.startLine=99
scope.10.endLine=105
scope.10.semanticHash=9e15033e0af690bc
scope.11.id=function:_build_player_status
scope.11.kind=function
scope.11.startLine=107
scope.11.endLine=124
scope.11.semanticHash=64f6e325ddbdaaf3
scope.12.id=function:panel.build_turn_label
scope.12.kind=function
scope.12.startLine=129
scope.12.endLine=136
scope.12.semanticHash=aa2cef533d6e87f6
scope.13.id=function:_build_status_row
scope.13.kind=function
scope.13.startLine=141
scope.13.endLine=146
scope.13.semanticHash=b5a064c2ea818f6b
scope.14.id=function:_fill_status_rows
scope.14.kind=function
scope.14.startLine=148
scope.14.endLine=152
scope.14.semanticHash=157279c785b03591
scope.15.id=function:_trim_status_rows
scope.15.kind=function
scope.15.startLine=154
scope.15.endLine=158
scope.15.semanticHash=ee541f84469adc01
scope.16.id=function:_players_of
scope.16.kind=function
scope.16.startLine=160
scope.16.endLine=162
scope.16.semanticHash=80095546cf231a6e
scope.17.id=function:_board_of
scope.17.kind=function
scope.17.startLine=164
scope.17.endLine=166
scope.17.semanticHash=616a2ca60599c94f
scope.18.id=function:panel.build_player_statuses
scope.18.kind=function
scope.18.startLine=168
scope.18.endLine=175
scope.18.semanticHash=d7fbf58d1a41a4ef
scope.19.id=function:panel.build_auto_label
scope.19.kind=function
scope.19.startLine=177
scope.19.endLine=179
scope.19.semanticHash=769b9f209835d52a
]]
