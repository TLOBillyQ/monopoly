local tile = require("src.game.board.Tile")
local pricing = require("src.game.land.LandPricing")
local gameplay_rules = require("Config.GameplayRules")

local game_victory = {}

local tile_state = tile.get_state

local function _total_assets(game, player)
  local total = player.cash
  assert(total ~= nil, "missing player cash")
  for tile_id in pairs(player.properties) do
    local tile = game.board:get_tile_by_id(tile_id)
    assert(tile ~= nil and tile.type == "land", "invalid property tile: " .. tostring(tile_id))
    local st = tile_state(game, tile)
    local level = st.level
    total = total + pricing.total_invested(tile, level)
  end
  return total
end

local function _winner_names(list)
  local names = {}
  assert(list ~= nil, "missing winner list")
  for _, player in ipairs(list) do
    table.insert(names, player.name)
  end
  return table.concat(names, "、")
end

local function _apply_winners(game, winners, message)
  game.winners = winners
  if #winners == 1 then
    game.winner = winners[1]
  else
    game.winner = nil
  end
  local names = _winner_names(winners)
  game.winner_names = names
  assert(message ~= nil, "missing victory message")
  game.logger.event(message, game.winner_names)
  if GameAPI and GameAPI.get_role then
    local winner_ids = {}
    for _, player in ipairs(winners) do
      winner_ids[player.id] = true
    end
    for _, player in ipairs(game.players) do
      local role = GameAPI.get_role(player.id)
      if role then
        if winner_ids[player.id] then
          if role.game_win_and_show_result_panel then
            role.game_win_and_show_result_panel()
          end
        else
          if role.lose then
            role.lose()
          end
        end
      end
    end
  end
  game.finished = true
  return true
end

function game_victory.check_victory(self)
  if self.finished then
    return true
  end
  local alive = self:alive_players()
  local turn_limit = gameplay_rules.turn_limit
  assert(turn_limit ~= nil, "missing turn_limit")
  if turn_limit > 0 then
    local turn_count = self.store:get({ "turn", "turn_count" })
    if turn_count >= turn_limit then
      if #alive == 0 then
        return _apply_winners(self, {}, "游戏结束，无人生还")
      end
      local winners = {}
      local best = -math.huge
      for _, player in ipairs(alive) do
        local assets = _total_assets(self, player)
        if assets > best then
          best = assets
          winners = { player }
        elseif assets == best then
          table.insert(winners, player)
        end
      end
      return _apply_winners(self, winners, "游戏结束，时间到，胜者:")
    end
  end
  if #alive <= 1 then
    if #alive == 1 then
      return _apply_winners(self, { alive[1] }, "游戏结束，胜者:")
    end
    return _apply_winners(self, {}, "游戏结束，无人生还")
  end
  return false
end

return game_victory
