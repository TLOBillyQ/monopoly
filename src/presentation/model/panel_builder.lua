local gameplay_read_port = require("src.presentation.model.gameplay_read_port")
local number_utils = require("src.core.utils.number_utils")
local role_avatar = require("src.presentation.model.role_avatar")
local runtime_ports = require("src.core.ports.runtime_ports")

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

local function _normalize_cash_value(value)
  local normalized = number_utils.to_integer(value)
  if normalized == nil then
    return 0
  end
  if normalized < 0 then
    return 0
  end
  return normalized
end

local function _normalize_total_assets_value(value)
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

local function _resolve_role_avatar(role)
  return role_avatar.resolve_from_role(role)
end

local function _resolve_player_profile(player)
  local role = _resolve_role(player)
  local display_name = _resolve_role_name(role) or player.name
  return {
    name = panel.build_player_label(display_name, player.eliminated == true),
    avatar = _resolve_role_avatar(role),
  }
end

local function _build_empty_player_status()
  return {
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
  local cash = _normalize_cash_value(player.cash)
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

local function _build_player_status(player, board)
  local profile = _resolve_player_profile(player)
  local cash, land_count, total = _accumulate_player_assets(player, board)
  return {
    name = profile.name,
    avatar = profile.avatar,
    eliminated = player.eliminated == true,
    cash_value = cash,
    total_assets_value = _normalize_total_assets_value(total),
    cash = "现金: " .. number_utils.format_integer_part(_normalize_display_amount(cash)),
    land_count = "地块: " .. number_utils.format_integer_part(land_count),
    total_assets = "总资产: " .. number_utils.format_integer_part(_normalize_display_amount(total)),
  }
end

function panel.build_turn_label(_, countdown_seconds)
  return "倒计时:" .. tostring(countdown_seconds or 0)
end

function panel.build_player_label(player_name, eliminated)
  local display_name = player_name or ""
  if eliminated then
    return display_name .. " (出局)"
  end
  return display_name
end

function panel.build_player_statuses(game, game_obj, max_players)
  local players = game and game.players or {}
  local count = max_players or #players
  local out = {}
  local board = game_obj and game_obj.board or nil
  for i = 1, count do
    local player = players[i]
    if player then
      out[i] = _build_player_status(player, board)
    else
      out[i] = _build_empty_player_status()
    end
  end
  return out
end

function panel.build_auto_label(auto_play)
  if auto_play then
    return "自动：开"
  end
  return "自动：关"
end

return panel
