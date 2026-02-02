local Tile = require("Components.Tile")
local Pricing = require("Manager.LandManager.Land.LandPricing")
local gameplay_constants = require("Config.GameplayConstants")

local GameVictory = {}

local tile_state = Tile.get_state

local function total_assets(game, player)
  local total = player.cash
  assert(total ~= nil, "missing player cash")
  for tile_id in pairs(player.properties) do
    local tile = game.board:get_tile_by_id(tile_id)
    assert(tile ~= nil and tile.type == "land", "invalid property tile: " .. tostring(tile_id))
    local st = tile_state(game, tile)
    local level = st.level
    total = total + Pricing.total_invested(tile, level)
  end
  return total
end

local function winner_names(list)
  local names = {}
  assert(list ~= nil, "missing winner list")
  for _, player in ipairs(list) do
    table.insert(names, player.name)
  end
  return table.concat(names, "、")
end

local function apply_winners(game, winners, message)
  game.winners = winners
  if #winners == 1 then
    game.winner = winners[1]
  else
    game.winner = nil
  end
  local names = winner_names(winners)
  game.winner_names = names
  assert(message ~= nil, "missing victory message")
  game.logger.event(message, game.winner_names)
  game.finished = true
  return true
end

function GameVictory.check_victory(self)
  if self.finished then
    return true
  end
  local alive = self:alive_players()
  local turn_limit = gameplay_constants.turn_limit
  assert(turn_limit ~= nil, "missing turn_limit")
  if turn_limit > 0 then
    local turn_count = self.store:get({ "turn", "turn_count" })
    if turn_count >= turn_limit then
      if #alive == 0 then
        return apply_winners(self, {}, "游戏结束，无人生还")
      end
      local winners = {}
      local best = -math.huge
      for _, player in ipairs(alive) do
        local assets = total_assets(self, player)
        if assets > best then
          best = assets
          winners = { player }
        elseif assets == best then
          table.insert(winners, player)
        end
      end
      return apply_winners(self, winners, "游戏结束，时间到，胜者:")
    end
  end
  if #alive <= 1 then
    if #alive == 1 then
      return apply_winners(self, { alive[1] }, "游戏结束，胜者:")
    end
    return apply_winners(self, {}, "游戏结束，无人生还")
  end
  return false
end

return GameVictory
