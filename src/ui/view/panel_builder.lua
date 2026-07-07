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

local function _resolve_role_name(role)
  if not role or type(role.get_name) ~= "function" then
    return nil
  end
  local ok, role_name = pcall(role.get_name)
  if not ok then
    return nil
  end
  if role_name == nil or role_name == "" then
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

local function _accumulate_player_assets(game, player, board)
  local cash = _read_player_cash(game, player)
  local land_count = 0
  local total = cash
  for tile_id in pairs(player.properties or {}) do
    land_count = land_count + 1
    local tile = board and board.get_tile_by_id and board:get_tile_by_id(tile_id) or nil
    if tile and tile.type == "land" then
      local level = tile.level or 0
      total = total + gameplay_read_port.total_land_invested(tile, level)
    end
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

function panel.build_player_statuses(game, game_obj, max_players)
  local players = game and game.players or {}
  local count = max_players or #players
  local board = game_obj and game_obj.board or nil
  _fill_status_rows(game, players, board, count)
  _trim_status_rows(count)
  return _status_out
end

function panel.build_auto_label(_auto_play)
  return "托管"
end

return panel

--[[ mutate4lua-manifest
version=2
projectHash=e346a47fa4ee8338
scope.0.id=chunk:src/ui/view/panel_builder.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=164
scope.0.semanticHash=a533f20c7502f4a9
scope.0.lastMutatedAt=2026-06-25T01:27:30Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=30
scope.0.lastMutationKilled=30
scope.1.id=function:_normalize_integer_value:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=15
scope.1.semanticHash=f8e79d9e3dc3de68
scope.1.lastMutatedAt=2026-06-25T01:27:30Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
scope.2.id=function:_resolve_role:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=22
scope.2.semanticHash=ad9c85fd22d074c3
scope.2.lastMutatedAt=2026-06-25T01:27:30Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_resolve_role_name:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=36
scope.3.semanticHash=1b9761b2e255b9eb
scope.3.lastMutatedAt=2026-06-25T01:27:30Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=11
scope.3.lastMutationKilled=11
scope.4.id=function:_read_player_cash:59
scope.4.kind=function
scope.4.startLine=59
scope.4.endLine=64
scope.4.semanticHash=864c78e32716fff0
scope.4.lastMutatedAt=2026-06-25T01:27:30Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=survived
scope.4.lastMutationSites=6
scope.4.lastMutationKilled=5
scope.5.id=function:_build_player_label:81
scope.5.kind=function
scope.5.startLine=81
scope.5.endLine=87
scope.5.semanticHash=2eac86e0f89cfa4c
scope.5.lastMutatedAt=2026-06-25T01:27:30Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:_sync_cached_label:89
scope.6.kind=function
scope.6.startLine=89
scope.6.endLine=95
scope.6.semanticHash=e03ddfc740ce180f
scope.6.lastMutatedAt=2026-06-25T01:27:30Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=2
scope.6.lastMutationKilled=2
scope.7.id=function:_build_player_status:97
scope.7.kind=function
scope.7.startLine=97
scope.7.endLine=114
scope.7.semanticHash=f015a30d8dcab884
scope.7.lastMutatedAt=2026-06-25T01:27:30Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=12
scope.7.lastMutationKilled=12
scope.8.id=function:panel.build_turn_label:119
scope.8.kind=function
scope.8.startLine=119
scope.8.endLine=126
scope.8.semanticHash=62d999a1c986e71c
scope.8.lastMutatedAt=2026-06-25T01:27:30Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=5
scope.8.lastMutationKilled=5
scope.9.id=function:_build_status_row:131
scope.9.kind=function
scope.9.startLine=131
scope.9.endLine=136
scope.9.semanticHash=7f8f159c3dfebe6a
scope.9.lastMutatedAt=2026-06-25T01:27:30Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=1
scope.10.id=function:panel.build_player_statuses:150
scope.10.kind=function
scope.10.startLine=150
scope.10.endLine=157
scope.10.semanticHash=cd9dc6995c6604e5
scope.10.lastMutatedAt=2026-06-25T01:27:30Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=7
scope.10.lastMutationKilled=7
scope.11.id=function:panel.build_auto_label:159
scope.11.kind=function
scope.11.startLine=159
scope.11.endLine=161
scope.11.semanticHash=fe2b41b44042defe
scope.11.lastMutatedAt=2026-06-25T01:27:30Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=1
scope.11.lastMutationKilled=1
]]
