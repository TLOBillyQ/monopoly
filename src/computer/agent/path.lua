local tile = require("src.rules.board.tile")
local pricing = require("src.rules.land.pricing")
local facing_policy = require("src.rules.board.facing_policy")

local path_planner = {}

local tile_state = tile.get_state

local function _is_auto_player(player)
  return player.is_ai or player.auto
end

path_planner.is_auto_player = _is_auto_player

local function _current_rent(tile_ref, level)
  return pricing.rent_for_level(tile_ref, level or 0)
end

local remote_step_rank_by_type = {
  item = 1,
  chance = 2,
  start = 5,
  market = 6,
  mountain = 7,
  tax = 8,
  hospital = 9,
}

local remote_land_priority_rules = {
  unowned = function(_, _, _, steps)
    return 3, steps
  end,
  self_owned = function(_, _, _, steps)
    return 4, steps
  end,
  enemy_owned = function(_, _, tile_ref)
    return 10, -_current_rent(tile_ref, tile_ref.level)
  end,
}

local remote_priority_rules = {
  land = function(game, player, tile_ref, steps)
    local st = tile_state(game, tile_ref)
    local land_rule_key = "enemy_owned"
    if not st or not st.owner_id then
      land_rule_key = "unowned"
    elseif st.owner_id == player.id then
      land_rule_key = "self_owned"
    end
    return remote_land_priority_rules[land_rule_key](game, player, tile_ref, steps)
  end,
}

for tile_type, rank in pairs(remote_step_rank_by_type) do
  local current_rank = rank
  remote_priority_rules[tile_type] = function(_, _, _, steps)
    return current_rank, steps
  end
end

local function _simulate_landing(game, player, steps)
  local board = game.board
  local current = player.position
  local facing = facing_policy.resolve_initial_facing("fresh_forward", player)
  local entered_inner = false
  for step = 1, steps do
    local next_index, _, next_facing, step_entered_inner = board:step_forward_by_facing(current, facing, {
      parity = steps,
      entered_inner = entered_inner,
    })
    current = next_index
    facing = next_facing
    if step_entered_inner then
      entered_inner = true
    end

    if board:has_roadblock(current) then
      break
    end

    if board:has_mine(current) then
      break
    end

    local tile_ref = board:get_tile(current)
    if tile_ref and tile_ref.type == "market" and step < steps then
      break
    end
  end
  return { idx = current, tile = board:get_tile(current), steps = steps }
end

local function _remote_priority_for_tile_type(tile_type, steps)
  local rule = remote_priority_rules[tile_type]
  if not rule then
    return nil
  end
  return rule(nil, nil, nil, steps)
end

local function _remote_priority(game, player, sim)
  local tile_ref = sim.tile
  if not tile_ref then
    return nil
  end
  if tile_ref.type == "land" then
    return remote_priority_rules.land(game, player, tile_ref, sim.steps)
  end
  return _remote_priority_for_tile_type(tile_ref.type, sim.steps)
end

local function _is_better_remote_choice(best, rank, score_value)
  local best_score = best and best.score or -2147483647
  return best == nil
    or rank < best.rank
    or (rank == best.rank and score_value > best_score)
end

function path_planner.pick_remote_dice_value(game, player, dice_count)
  dice_count = dice_count or 1
  local best
  for value = 1, 6 do
    local steps = value * dice_count
    local sim = _simulate_landing(game, player, steps)
    local rank, score = _remote_priority(game, player, sim)
    if rank then
      local score_value = score or 0
      if _is_better_remote_choice(best, rank, score_value) then
        best = { rank = rank, score = score_value, value = value, tile = sim.tile }
      end
    end
  end
  if not best then
    return nil, nil
  end
  return best.value, best.tile
end

return path_planner
