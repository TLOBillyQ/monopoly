local Tile = require("Components.Tile")
local Roadblock = require("Manager.ItemManager.Item.ItemRoadblock")
local Demolish = require("Manager.ItemManager.Item.ItemDemolish")
local Pricing = require("Manager.LandManager.Land.LandPricing")
local gameplay_constants = require("Config.GameplayConstants")

local AgentTargeting = {}
local ITEM_IDS = gameplay_constants.item_ids

local tile_state = Tile.get_state

local function current_rent(tile, level)
  return Pricing.rent_for_level(tile, level or 0)
end

local function simulate_landing(game, player, steps)
  local board = game.board
  local current = player.position
  local facing = player.status.move_dir
  for step = 1, steps do
    local next_index, _, step_dir = board:step_forward_by_facing(current, facing, steps)
    current = next_index
    facing = step_dir or facing

    if board:has_roadblock(current) then
      break
    end

    if board:has_mine(current) then
      break
    end

    local tile = board:get_tile(current)
    if tile and tile.type == "market" and step < steps then
      break
    end
  end
  return { idx = current, tile = board:get_tile(current), steps = steps }
end

local function remote_priority(game, player, sim)
  local tile = sim.tile
  if not tile then
    return nil
  end
  local st = nil
  if tile.type == "land" then
    st = tile_state(game, tile)
  end
  local rank, score
  if tile.type == "item" then
    rank, score = 1, sim.steps
  elseif tile.type == "chance" then
    rank, score = 2, sim.steps
  elseif tile.type == "land" and st and not st.owner_id then
    rank, score = 3, sim.steps
  elseif tile.type == "land" and st and st.owner_id == player.id then
    rank, score = 4, sim.steps
  elseif tile.type == "start" then
    rank, score = 5, sim.steps
  elseif tile.type == "market" then
    rank, score = 6, sim.steps
  elseif tile.type == "mountain" then
    rank, score = 7, sim.steps
  elseif tile.type == "tax" then
    rank, score = 8, sim.steps
  elseif tile.type == "hospital" then
    rank, score = 9, sim.steps
  elseif tile.type == "land" and st and st.owner_id and st.owner_id ~= player.id then
    rank, score = 10, -current_rent(tile, st.level)
  end
  if not rank then
    return nil
  end
  return rank, score
end

function AgentTargeting.pick_remote_dice_value(game, player, dice_count)
  dice_count = dice_count or 1
  local best
  for value = 1, 6 do
    local steps = value * dice_count
    local sim = simulate_landing(game, player, steps)
    local rank, score = remote_priority(game, player, sim)
    if rank then
      local score_value = score or 0
      local best_score = best and best.score or -2147483647
      if not best
        or rank < best.rank
        or (rank == best.rank and score_value > best_score) then
        best = { rank = rank, score = score_value, value = value, tile = sim.tile }
      end
    end
  end
  if not best then
    return nil, nil
  end
  return best.value, best.tile
end

local function richest_other(game, player, allow_ids)
  local best, best_cash = nil, nil
  for _, p in ipairs(game.players) do
    if not p.eliminated and p.id ~= player.id then
      if not allow_ids or allow_ids[p.id] then
        if not best_cash or p.cash > best_cash then
          best = p
          best_cash = p.cash
        end
      end
    end
  end
  return best
end

local function is_richest(game, player)
  for _, p in ipairs(game.players) do
    if not p.eliminated and p.id ~= player.id and p.cash > player.cash then
      return false
    end
  end
  return true
end

local function allow_from_options(options)
  if not options then
    return nil
  end
  local allowed = {}
  for _, opt in ipairs(options) do
    allowed[opt.id] = true
  end
  return allowed
end

function AgentTargeting.pick_target_player(game, player, item_id, options)
  local allowed = allow_from_options(options)

  if item_id == ITEM_IDS.share_wealth then
    if not is_richest(game, player) then
      return richest_other(game, player, allowed)
    end
    return nil
  end

  if item_id == ITEM_IDS.exile or item_id == ITEM_IDS.tax or item_id == ITEM_IDS.poor then
    return richest_other(game, player, allowed)
  end

  if item_id == ITEM_IDS.invite_deity then
    local best = nil
    for _, p in ipairs(game.players) do
      if p.id ~= player.id and not p.eliminated and (not allowed or allowed[p.id]) then
        if p:has_deity("angel") then
          best = p
          break
        elseif p:has_deity("rich") and not best then
          best = p
        end
      end
    end
    return best
  end

  if item_id == ITEM_IDS.send_poor then
    if not player:has_deity("poor") then
      return nil
    end
    return richest_other(game, player, allowed)
  end

  return nil
end

function AgentTargeting.pick_roadblock_target(game, player)
  local candidates = Roadblock.candidates(game, player, 3)
  local best = Roadblock.pick_best(candidates)
  if not best then
    return nil
  end
  return best.idx
end

function AgentTargeting.pick_demolish_target(game, player, distance)
  return Demolish.find_target(game, player, distance)
end

return AgentTargeting
