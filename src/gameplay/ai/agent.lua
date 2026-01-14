local GameState = require("src.util.game_state")
local Roadblock = require("src.gameplay.domain.item_roadblock")
local Missile = require("src.gameplay.domain.item_missile")

local Agent = {}

local tile_state = GameState.tile_state

local function is_auto_player(player)
  return player and (player.is_ai or player.auto)
end

Agent.is_auto_player = is_auto_player

local function current_rent(tile, level)
  local exponent = level or 0
  return (tile.price or 0) * (2 ^ exponent) * 0.5
end

local function simulate_landing(game, player, steps)
  local board = game.board
  local current = player.position
  local facing = player.status and player.status.move_dir or nil
  for _ = 1, steps do
    local next_index, _, step_dir = board:step_forward_by_facing(current, facing, steps)
    current = next_index
    facing = step_dir or facing
  end
  return { idx = current, tile = board:get_tile(current), steps = steps }
end

local function remote_priority(game, player, sim)
  local tile = sim.tile
  if not tile then
    return nil
  end
  local st = (tile.type == "land") and tile_state(game, tile) or nil
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

function Agent.pick_remote_dice_value(game, player, dice_count)
  dice_count = dice_count or 1
  local best_value, best_rank, best_score, best_tile
  for value = 1, 6 do
    local steps = value * dice_count
    local sim = simulate_landing(game, player, steps)
    local rank, score = remote_priority(game, player, sim)
    if rank then
      if (not best_rank)
        or rank < best_rank
        or (rank == best_rank and (score or 0) > (best_score or -math.huge)) then
        best_rank = rank
        best_score = score
        best_value = value
        best_tile = sim.tile
      end
    end
  end
  return best_value, best_tile
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

local function pick_target_player(game, player, item_id, options)
  local allowed = allow_from_options(options)

  if item_id == 2011 then
    if not is_richest(game, player) then
      return richest_other(game, player, allowed)
    end
    return nil
  end

  if item_id == 2012 or item_id == 2014 or item_id == 2018 then
    return richest_other(game, player, allowed)
  end

  if item_id == 2015 then
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

  if item_id == 2016 then
    if not player:has_deity("poor") then
      return nil
    end
    return richest_other(game, player, allowed)
  end

  return nil
end

Agent.pick_target_player = pick_target_player

function Agent.pick_roadblock_target(game, player)
  local candidates = Roadblock.candidates(game, player, 3)
  local best = Roadblock.pick_best(candidates)
  return best and best.idx or nil
end

function Agent.pick_missile_target(game, player, distance)
  return Missile.find_target(game, player, distance)
end

local function first_option_id(options)
  if not options or #options == 0 then
    return nil
  end
  return options[1].id or options[1]
end

local function choice_owner(game, choice)
  local meta = choice.meta or {}
  if meta.player_id and game.players[meta.player_id] then
    return game.players[meta.player_id]
  end
  if meta.user_id and game.players[meta.user_id] then
    return game.players[meta.user_id]
  end
  if meta.stealer_id and game.players[meta.stealer_id] then
    return game.players[meta.stealer_id]
  end
  return game:current_player()
end

function Agent.auto_action_for_choice(game, choice)
  local actor = choice_owner(game, choice)
  if not is_auto_player(actor) then
    return nil
  end

  if choice.kind == "remote_dice_value" then
    local dice_count = (choice.meta and choice.meta.dice_count) or 1
    local value = Agent.pick_remote_dice_value(game, actor, dice_count)
    return { type = "choice_select", choice_id = choice.id, option_id = value or first_option_id(choice.options) }
  end

  if choice.kind == "roadblock_target" then
    local idx = Agent.pick_roadblock_target(game, actor)
    return { type = "choice_select", choice_id = choice.id, option_id = idx or first_option_id(choice.options) }
  end

  if choice.kind == "missile_target" then
    local idx = Agent.pick_missile_target(game, actor, 3)
    return { type = "choice_select", choice_id = choice.id, option_id = idx or first_option_id(choice.options) }
  end

  if choice.kind == "item_target_player" then
    local item_id = choice.meta and choice.meta.item_id
    local target = item_id and pick_target_player(game, actor, item_id, choice.options) or nil
    local target_id = target and target.id or first_option_id(choice.options)
    if target_id then
      return { type = "choice_select", choice_id = choice.id, option_id = target_id }
    end
    return { type = "choice_cancel", choice_id = choice.id }
  end

  if choice.kind == "steal_target" or choice.kind == "steal_item" then
    local id = first_option_id(choice.options)
    if id then
      return { type = "choice_select", choice_id = choice.id, option_id = id }
    end
    return { type = "choice_cancel", choice_id = choice.id }
  end

  if choice.kind == "landing_optional_effect" or choice.kind == "land_optional_effect" then
    local id = first_option_id(choice.options)
    if id then
      return { type = "choice_select", choice_id = choice.id, option_id = id }
    end
    return { type = "choice_cancel", choice_id = choice.id }
  end

  if choice.kind == "rent_card_prompt" or choice.kind == "tax_card_prompt" then
    return { type = "choice_select", choice_id = choice.id, option_id = "use" }
  end

  if choice.kind == "post_action_item" then
    return { type = "choice_cancel", choice_id = choice.id }
  end

  if choice.kind == "market_buy" then
    return { type = "choice_cancel", choice_id = choice.id }
  end

  return nil
end

return Agent
