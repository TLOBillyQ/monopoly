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

--[[ mutate4lua-manifest
version=2
projectHash=03be57aac76006a0
scope.0.id=chunk:src/computer/agent/path.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=140
scope.0.semanticHash=76fbd167d9ffd70c
scope.1.id=function:_is_auto_player:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=9133db1e9df0f88c
scope.2.id=function:_current_rent:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=17
scope.2.semanticHash=2c53043f5ffd83d7
scope.3.id=function:anonymous@30:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=32
scope.3.semanticHash=105c15c80cb86bb1
scope.4.id=function:anonymous@33:33
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=35
scope.4.semanticHash=1a9d67e05867bbf8
scope.5.id=function:anonymous@36:36
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=38
scope.5.semanticHash=714cf053fb506728
scope.6.id=function:anonymous@42:42
scope.6.kind=function
scope.6.startLine=42
scope.6.endLine=51
scope.6.semanticHash=d2b98167b8089e4b
scope.7.id=function:anonymous@56:56
scope.7.kind=function
scope.7.startLine=56
scope.7.endLine=58
scope.7.semanticHash=013b4b9b51abb9d0
scope.8.id=function:_remote_priority_for_tile_type:93
scope.8.kind=function
scope.8.startLine=93
scope.8.endLine=99
scope.8.semanticHash=2408c48a930a5acf
scope.9.id=function:_remote_priority:101
scope.9.kind=function
scope.9.startLine=101
scope.9.endLine=110
scope.9.semanticHash=3ec68696d1d7cc1e
scope.10.id=function:_is_better_remote_choice:112
scope.10.kind=function
scope.10.startLine=112
scope.10.endLine=117
scope.10.semanticHash=94e6921b4458bb04
]]
