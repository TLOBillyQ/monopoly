local tile = require("src.game.systems.board.Tile")
local roadblock = require("src.game.systems.items.ItemRoadblock")
local demolish = require("src.game.systems.items.ItemDemolish")
local pricing = require("src.game.systems.land.LandPricing")
local gameplay_rules = require("src.core.config.GameplayRules")
local facing_policy = require("src.game.systems.board.FacingPolicy")

-- Runtime sandbox contract (docs/eggy/lua_env.md):
-- 1) Release sandbox removes debug/io/os/package.
-- 2) Do not make runtime logic depend on developer-mode-only APIs.
-- 3) Any engine bridge should degrade via pcall-based fallback instead of debug introspection.

local agent = {}
local item_ids = gameplay_rules.item_ids
local tile_state = tile.get_state

local function _is_auto_player(player)
  return player.is_ai or player.auto
end

agent.is_auto_player = _is_auto_player

local function _current_rent(tile_ref, level)
  return pricing.rent_for_level(tile_ref, level or 0)
end

local function _simulate_landing(game, player, steps)
  local board = game.board
  local current = player.position
  local facing = facing_policy.resolve_initial_facing("fresh_forward", player)
  for step = 1, steps do
    local next_index, _, step_dir = board:step_forward_by_facing(current, facing, steps)
    current = next_index
    facing = step_dir

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

local function _remote_priority(game, player, sim)
  local tile_ref = sim.tile
  if not tile_ref then
    return nil
  end
  local st = nil
  if tile_ref.type == "land" then
    st = tile_state(game, tile_ref)
  end
  local rank, score
  if tile_ref.type == "item" then
    rank, score = 1, sim.steps
  elseif tile_ref.type == "chance" then
    rank, score = 2, sim.steps
  elseif tile_ref.type == "land" and st and not st.owner_id then
    rank, score = 3, sim.steps
  elseif tile_ref.type == "land" and st and st.owner_id == player.id then
    rank, score = 4, sim.steps
  elseif tile_ref.type == "start" then
    rank, score = 5, sim.steps
  elseif tile_ref.type == "market" then
    rank, score = 6, sim.steps
  elseif tile_ref.type == "mountain" then
    rank, score = 7, sim.steps
  elseif tile_ref.type == "tax" then
    rank, score = 8, sim.steps
  elseif tile_ref.type == "hospital" then
    rank, score = 9, sim.steps
  elseif tile_ref.type == "land" and st and st.owner_id and st.owner_id ~= player.id then
    rank, score = 10, -_current_rent(tile_ref, st.level)
  end
  if not rank then
    return nil
  end
  return rank, score
end

function agent.pick_remote_dice_value(game, player, dice_count)
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

function agent.pick_target_player(game, player, item_id, options)
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

function agent.pick_roadblock_target(game, player)
  local candidates = roadblock.auto_candidates(game, player, 3)
  if not candidates or #candidates == 0 then
    return nil
  end
  local best = roadblock.pick_best(candidates)
  if not best then
    return nil
  end
  return best.idx
end

function agent.pick_demolish_target(game, player, distance)
  return demolish.find_target(game, player, distance)
end

local function _first_option_id(options)
  if not options or #options == 0 then
    return nil
  end
  return options[1].id or options[1]
end

local function _choice_owner(game, choice)
  local meta = choice.meta or {}
  if meta.player_id and game.find_player_by_id then
    local player = game:find_player_by_id(meta.player_id)
    if player then
      return player
    end
  end
  return game:current_player()
end

function agent.auto_action_for_choice(game, choice)
  local actor = _choice_owner(game, choice)
  if not _is_auto_player(actor) then
    return nil
  end

  if choice.kind == "remote_dice_value" then
    local dice_count = choice.meta.dice_count
    local value = agent.pick_remote_dice_value(game, actor, dice_count)
    return { type = "choice_select", choice_id = choice.id, option_id = value or _first_option_id(choice.options), actor_role_id = actor.id }
  end

  if choice.kind == "roadblock_target" then
    local idx = agent.pick_roadblock_target(game, actor)
    return { type = "choice_select", choice_id = choice.id, option_id = idx or _first_option_id(choice.options), actor_role_id = actor.id }
  end

  if choice.kind == "demolish_target" or choice.kind == "missile_target" then
    local idx = agent.pick_demolish_target(game, actor, 3)
    return { type = "choice_select", choice_id = choice.id, option_id = idx or _first_option_id(choice.options), actor_role_id = actor.id }
  end

  if choice.kind == "item_target_player" then
    local item_id = choice.meta.item_id
    local target = agent.pick_target_player(game, actor, item_id, choice.options)
    if target then
      return { type = "choice_select", choice_id = choice.id, option_id = target.id, actor_role_id = actor.id }
    end
    return { type = "choice_cancel", choice_id = choice.id, actor_role_id = actor.id }
  end

  if choice.kind == "steal_item" then
    local id = _first_option_id(choice.options)
    if id then
      return { type = "choice_select", choice_id = choice.id, option_id = id, actor_role_id = actor.id }
    end
    return { type = "choice_cancel", choice_id = choice.id, actor_role_id = actor.id }
  end

  if choice.kind == "steal_prompt" then
    return { type = "choice_select", choice_id = choice.id, option_id = "use", actor_role_id = actor.id }
  end

  if choice.kind == "landing_optional_effect" or choice.kind == "land_optional_effect" then
    local options = choice.options or {}
    local target = nil
    for _, opt in ipairs(options) do
      local id = opt.id or opt
      if id == "buy_land" then
        target = id
        break
      end
    end
    if not target then
      for _, opt in ipairs(options) do
        local id = opt.id or opt
        if id == "upgrade_land" then
          target = id
          break
        end
      end
    end
    if not target then
      target = _first_option_id(options)
    end
    if target then
      return { type = "choice_select", choice_id = choice.id, option_id = target, actor_role_id = actor.id }
    end
    return { type = "choice_cancel", choice_id = choice.id, actor_role_id = actor.id }
  end

  if choice.kind == "rent_card_prompt" or choice.kind == "tax_card_prompt" then
    return { type = "choice_select", choice_id = choice.id, option_id = "use", actor_role_id = actor.id }
  end

  if choice.kind == "item_phase_choice" then
    return { type = "choice_cancel", choice_id = choice.id, actor_role_id = actor.id }
  end

  if choice.kind == "market_buy" then
    return { type = "choice_cancel", choice_id = choice.id, actor_role_id = actor.id }
  end

  return nil
end

return agent
