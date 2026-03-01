local gameplay_read_port = require("src.presentation.read_model.GameplayReadPort")
local number_utils = require("src.core.NumberUtils")
local role_avatar = require("src.presentation.state.UIRoleAvatar")

local panel = {}

local function _normalize_display_amount(value)
  if type(value) ~= "number" then
    return value
  end
  if value < 0 then
    return 0
  end
  return value
end

local function _resolve_role(player)
  if not player or player.id == nil then
    return nil
  end
  if not (GameAPI and GameAPI.get_role) then
    return nil
  end
  local ok, role = pcall(GameAPI.get_role, player.id)
  if not ok then
    return nil
  end
  return role
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
      local profile = _resolve_player_profile(player)
      local cash = player.cash or 0
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
      out[i] = {
        name = profile.name,
        avatar = profile.avatar,
        cash = "现金: " .. number_utils.format_integer_part(_normalize_display_amount(cash)),
        land_count = "地块: " .. number_utils.format_integer_part(land_count),
        total_assets = "总资产: " .. number_utils.format_integer_part(_normalize_display_amount(total)),
      }
    else
      out[i] = { name = "", avatar = nil, cash = "", land_count = "", total_assets = "" }
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
