local tile = require("src.rules.board.tile")
local roadblock = require("src.rules.items.roadblock")
local demolish = require("src.rules.items.demolish")
local pricing = require("src.rules.land.pricing")
local item_ids = require("src.config.gameplay.item_ids")
local facing_policy = require("src.rules.board.facing_policy")

local agent = {}
local tile_state = tile.get_state

local function _is_auto_player(player)
  return player.is_ai or player.auto
end

agent.is_auto_player = _is_auto_player

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
  local rank = remote_step_rank_by_type[tile_type]
  if not rank then
    return nil
  end
  return rank, steps
end

local function _remote_priority_for_land(game, player, tile_ref, steps)
  local st = tile_state(game, tile_ref)
  if not st or not st.owner_id then
    return 3, steps
  end
  if st.owner_id == player.id then
    return 4, steps
  end
  return 10, -_current_rent(tile_ref, st.level)
end

local function _remote_priority(game, player, sim)
  local tile_ref = sim.tile
  if not tile_ref then
    return nil
  end
  if tile_ref.type == "land" then
    return _remote_priority_for_land(game, player, tile_ref, sim.steps)
  end
  return _remote_priority_for_tile_type(tile_ref.type, sim.steps)
end

local function _is_better_remote_choice(best, rank, score_value)
  local best_score = best and best.score or -2147483647
  return best == nil
    or rank < best.rank
    or (rank == best.rank and score_value > best_score)
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

local function _pick_share_wealth_target(game, player, allowed)
  if _is_richest(game, player) then
    return nil
  end
  return _richest_other(game, player, allowed)
end

local function _pick_deity_target(game, player, allowed)
  local best = nil
  for _, p in ipairs(game.players) do
    if p.id ~= player.id and not p.eliminated and (not allowed or allowed[p.id]) then
      if game:player_has_deity(p, "angel") then
        return p
      end
      if game:player_has_deity(p, "rich") and not best then
        best = p
      end
    end
  end
  return best
end

function agent.pick_target_player(game, player, item_id, options)
  local allowed = _allow_from_options(options)
  if item_id == item_ids.share_wealth then
    return _pick_share_wealth_target(game, player, allowed)
  end
  if item_id == item_ids.exile or item_id == item_ids.tax or item_id == item_ids.poor then
    return _richest_other(game, player, allowed)
  end
  if item_id == item_ids.invite_deity then
    return _pick_deity_target(game, player, allowed)
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

local function _build_choice_action(choice, actor, option_id, action_type)
  return {
    type = action_type or "choice_select",
    choice_id = choice.id,
    option_id = option_id,
    actor_role_id = actor.id,
  }
end

local function _resolve_target_option(options, preferred_ids)
  for _, preferred_id in ipairs(preferred_ids) do
    for _, opt in ipairs(options or {}) do
      local option_id = opt.id or opt
      if option_id == preferred_id then
        return option_id
      end
    end
  end
  return _first_option_id(options)
end

local function _handle_remote_dice_choice(game, actor, choice)
  local dice_count = choice.meta.dice_count
  local value = agent.pick_remote_dice_value(game, actor, dice_count)
  return _build_choice_action(choice, actor, value or _first_option_id(choice.options))
end

local function _handle_board_target_choice(game, actor, choice)
  local resolver = choice.kind == "roadblock_target" and agent.pick_roadblock_target or agent.pick_demolish_target
  local option_id = choice.kind == "roadblock_target"
    and resolver(game, actor)
    or resolver(game, actor, 3)
  return _build_choice_action(choice, actor, option_id or _first_option_id(choice.options))
end

local function _handle_target_player_choice(game, actor, choice)
  local target = agent.pick_target_player(game, actor, choice.meta.item_id, choice.options)
  if target then
    return _build_choice_action(choice, actor, target.id)
  end
  return _build_choice_action(choice, actor, nil, "choice_cancel")
end

local function _handle_simple_pick_or_cancel(choice, actor)
  local option_id = _first_option_id(choice.options)
  if option_id then
    return _build_choice_action(choice, actor, option_id)
  end
  return _build_choice_action(choice, actor, nil, "choice_cancel")
end

local function _handle_landing_optional_effect(choice, actor)
  local target = _resolve_target_option(choice.options or {}, { "buy_land", "upgrade_land" })
  if target then
    return _build_choice_action(choice, actor, target)
  end
  return _build_choice_action(choice, actor, nil, "choice_cancel")
end

function agent.auto_action_for_choice(game, choice)
  local actor = _choice_owner(game, choice)
  if not _is_auto_player(actor) then
    return nil
  end
  if choice.kind == "remote_dice_value" then
    return _handle_remote_dice_choice(game, actor, choice)
  end
  if choice.kind == "roadblock_target" or choice.kind == "demolish_target" or choice.kind == "missile_target" then
    return _handle_board_target_choice(game, actor, choice)
  end
  if choice.kind == "item_target_player" then
    return _handle_target_player_choice(game, actor, choice)
  end
  if choice.kind == "steal_item" then
    return _handle_simple_pick_or_cancel(choice, actor)
  end
  if choice.kind == "steal_prompt" then
    return _build_choice_action(choice, actor, "use")
  end
  if choice.kind == "landing_optional_effect" then
    return _handle_landing_optional_effect(choice, actor)
  end
  if choice.kind == "rent_card_prompt" or choice.kind == "tax_card_prompt" then
    return _build_choice_action(choice, actor, "use")
  end
  if choice.kind == "item_phase_choice" then
    return _build_choice_action(choice, actor, nil, "choice_cancel")
  end
  if choice.kind == "market_buy" then
    return _build_choice_action(choice, actor, nil, "choice_cancel")
  end
  return nil
end

return agent
