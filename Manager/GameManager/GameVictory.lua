local Tile = require("Components.Tile")
local Pricing = require("Manager.LandManager.LandPricing")
local GameplayRules = require("Config.GameplayRules")

local GameVictory = {}

local tile_state = Tile.GetState

local function _TotalAssets(game, player)
  local total = player.cash
  assert(total ~= nil, "missing player cash")
  for tile_id in pairs(player.properties) do
    local tile = game.board:GetTileById(tile_id)
    assert(tile ~= nil and tile.type == "land", "invalid property tile: " .. tostring(tile_id))
    local st = tile_state(game, tile)
    local level = st.level
    total = total + Pricing.TotalInvested(tile, level)
  end
  return total
end

local function _WinnerNames(list)
  local names = {}
  assert(list ~= nil, "missing winner list")
  for _, player in ipairs(list) do
    table.insert(names, player.name)
  end
  return table.concat(names, "、")
end

local function _ApplyWinners(game, winners, message)
  game.winners = winners
  if #winners == 1 then
    game.winner = winners[1]
  else
    game.winner = nil
  end
  local names = _WinnerNames(winners)
  game.winner_names = names
  assert(message ~= nil, "missing victory message")
  game.logger.Event(message, game.winner_names)
  game.finished = true
  return true
end

function GameVictory.CheckVictory(self)
  if self.finished then
    return true
  end
  local alive = self:AlivePlayers()
  local turn_limit = GameplayRules.turn_limit
  assert(turn_limit ~= nil, "missing turn_limit")
  if turn_limit > 0 then
    local turn_count = self.store:Get({ "turn", "turn_count" })
    if turn_count >= turn_limit then
      if #alive == 0 then
        return _ApplyWinners(self, {}, "游戏结束，无人生还")
      end
      local winners = {}
      local best = -math.huge
      for _, player in ipairs(alive) do
        local assets = _TotalAssets(self, player)
        if assets > best then
          best = assets
          winners = { player }
        elseif assets == best then
          table.insert(winners, player)
        end
      end
      return _ApplyWinners(self, winners, "游戏结束，时间到，胜者:")
    end
  end
  if #alive <= 1 then
    if #alive == 1 then
      return _ApplyWinners(self, { alive[1] }, "游戏结束，胜者:")
    end
    return _ApplyWinners(self, {}, "游戏结束，无人生还")
  end
  return false
end

return GameVictory
