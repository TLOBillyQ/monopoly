local pricing = require("src.game.land.LandPricing")

local panel = {}

function panel.build_turn_label(turn_count, countdown_seconds, countdown_active)
  if countdown_active then
    return "回合: " .. tostring(turn_count) .. " | 倒计时: " .. tostring(countdown_seconds or 0)
  end
  return "回合: " .. tostring(turn_count)
end

function panel.build_player_label(player)
  if player.eliminated then
    return player.name .. " (出局)"
  end
  return player.name .. " $" .. player.cash
end

function panel.build_player_statuses(game, game_obj, max_players)
  local players = game and game.players or {}
  local count = max_players or #players
  local out = {}
  local board = game_obj and game_obj.board or nil
  for i = 1, count do
    local player = players[i]
    if player then
      local cash = player.cash or 0
      local land_count = 0
      local total = cash
      for tile_id in pairs(player.properties or {}) do
        land_count = land_count + 1
        local tile = board and board.get_tile_by_id and board:get_tile_by_id(tile_id) or nil
        if tile and tile.type == "land" then
          local level = tile.level or 0
          total = total + pricing.total_invested(tile, level)
        end
      end
      out[i] = {
        name = panel.build_player_label(player),
        cash = "现金: " .. tostring(cash),
        land_count = "地块: " .. tostring(land_count),
        total_assets = "总资产: " .. tostring(total),
      }
    else
      out[i] = { name = "", cash = "", land_count = "", total_assets = "" }
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
