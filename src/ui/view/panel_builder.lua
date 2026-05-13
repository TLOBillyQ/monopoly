local gameplay_read_port = require("src.ui.view.gameplay_read_port")
local number_utils = require("src.foundation.lang.number")
local role_avatar = require("src.ui.view.role_avatar")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local panel = {}

local function _normalize_display_amount(value)
  if not number_utils.is_numeric(value) then
    return value
  end
  if value < 0 then
    return 0
  end
  return value
end

local function _normalize_integer_value(value)
  local normalized = number_utils.to_integer(value)
  if normalized == nil then
    return 0
  end
  if normalized < 0 then
    return 0
  end
  return normalized
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

local _cached_statuses = {}
local _cached_cash_values = {}
local _cached_land_values = {}
local _cached_total_values = {}
for _i = 1, 4 do
  _cached_statuses[_i] = {
    name = "",
    avatar = nil,
    eliminated = false,
    cash_value = nil,
    total_assets_value = nil,
    cash = "",
    land_count = "",
    total_assets = "",
  }
end

local function _accumulate_player_assets(player, board)
  local cash = _normalize_integer_value(player.cash)
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

local function _build_player_status(player, board, index)
  local status = _cached_statuses[index]
  local role = _resolve_role(player)
  local display_name = _resolve_role_name(role) or player.name
  status.name = panel.build_player_label(display_name, player.eliminated == true)
  status.avatar = role_avatar.resolve_from_role(role)
  status.eliminated = player.eliminated == true
  local cash, land_count, total = _accumulate_player_assets(player, board)
  status.cash_value = cash
  local normalized_total = _normalize_integer_value(total)
  status.total_assets_value = normalized_total
  local display_cash = _normalize_display_amount(cash)
  if _cached_cash_values[index] ~= display_cash then
    _cached_cash_values[index] = display_cash
    status.cash = "现金: " .. number_utils.format_integer_part(display_cash)
  end
  if _cached_land_values[index] ~= land_count then
    _cached_land_values[index] = land_count
    status.land_count = "地块: " .. number_utils.format_integer_part(land_count)
  end
  local display_total = _normalize_display_amount(normalized_total)
  if _cached_total_values[index] ~= display_total then
    _cached_total_values[index] = display_total
    status.total_assets = "总资产: " .. number_utils.format_integer_part(display_total)
  end
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

function panel.build_player_label(player_name, eliminated)
  local display_name = player_name or ""
  if eliminated then
    return display_name .. " (出局)"
  end
  return display_name
end

local _status_out = {}

function panel.build_player_statuses(game, game_obj, max_players)
  local players = game and game.players or {}
  local count = max_players or #players
  local board = game_obj and game_obj.board or nil
  for i = 1, count do
    local player = players[i]
    if player then
      _status_out[i] = _build_player_status(player, board, i)
    else
      _status_out[i] = _empty_status
    end
  end
  for i = count + 1, #_status_out do
    _status_out[i] = nil
  end
  return _status_out
end

function panel.build_auto_label(auto_play)
  if auto_play then
    return "自动：开"
  end
  return "自动：关"
end

return panel
