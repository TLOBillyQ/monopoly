local tile = require("src.game.board.Tile")
local roadblock = require("src.game.item.ItemRoadblock")
local demolish = require("src.game.item.ItemDemolish")
local pricing = require("src.game.land.LandPricing")
local gameplay_rules = require("Config.GameplayRules")

local agent_targeting = {}
local item_ids = gameplay_rules.item_ids

local tile_state = tile.get_state

local function _current_rent(tile, level)
  return pricing.rent_for_level(tile, level or 0)
end

local function _simulate_landing(game, player, steps)
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

local function _remote_priority(game, player, sim)
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
    rank, score = 10, -_current_rent(tile, st.level)
  end
  if not rank then
    return nil
  end
  return rank, score
end

function agent_targeting.pick_remote_dice_value(game, player, dice_count)
  dice_count = dice_count or 1
  local best
  for value = 1, 6 do
    local steps = value * dice_count
    local sim = _simulate_landing(game, player, steps)
    local rank, score = _remote_priority(game, player, sim)
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

local function _richest_other(game, player, allow_ids)
  local best, best_cash = nil, nil
  for _, p in ipairs(game.players) do
    if not p.eliminated and p.id ~= player.id then
      if not allow_ids or allow_ids[p.id] then
        local cash = game:player_balance(p, "金币")
        if not best_cash or cash > best_cash then
          best = p
          best_cash = cash
        end
      end
    end
  end
  return best
end

local function _is_richest(game, player)
  local player_cash = game:player_balance(player, "金币")
  for _, p in ipairs(game.players) do
    if not p.eliminated and p.id ~= player.id and game:player_balance(p, "金币") > player_cash then
      return false
    end
  end
  return true
end

local function _allow_from_options(options)
  if not options then
    return nil
  end
  local allowed = {}
  for _, opt in ipairs(options) do
    allowed[opt.id] = true
  end
  return allowed
end

function agent_targeting.pick_target_player(game, player, item_id, options)
  local allowed = _allow_from_options(options)

  if item_id == item_ids.share_wealth then
    if not _is_richest(game, player) then
      return _richest_other(game, player, allowed)
    end
    return nil
  end

  if item_id == item_ids.exile or item_id == item_ids.tax or item_id == item_ids.poor then
    return _richest_other(game, player, allowed)
  end

  if item_id == item_ids.invite_deity then
    local best = nil
    for _, p in ipairs(game.players) do
      if p.id ~= player.id and not p.eliminated and (not allowed or allowed[p.id]) then
        if game:player_has_deity(p, "angel") then
          best = p
          break
        elseif game:player_has_deity(p, "rich") and not best then
          best = p
        end
      end
    end
    return best
  end

  if item_id == item_ids.send_poor then
    if not game:player_has_deity(player, "poor") then
      return nil
    end
    return _richest_other(game, player, allowed)
  end

  return nil
end

function agent_targeting.pick_roadblock_target(game, player)
  local candidates = roadblock.candidates(game, player, 3)
  if not candidates or #candidates == 0 then
    return nil
  end
  local best = roadblock.pick_best(candidates)
  if not best then
    return nil
  end
  return best.idx
end

function agent_targeting.pick_demolish_target(game, player, distance)
  return demolish.find_target(game, player, distance)
end

return agent_targeting
