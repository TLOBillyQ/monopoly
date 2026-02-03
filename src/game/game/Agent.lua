local AgentTargeting = require("src.game.game.AgentTargeting")

local Agent = {}

local function _IsAutoPlayer(player)
  return player.is_ai or player.auto
end

Agent.IsAutoPlayer = _IsAutoPlayer

function Agent.PickRemoteDiceValue(game, player, dice_count)
  return AgentTargeting.PickRemoteDiceValue(game, player, dice_count)
end
function Agent.PickTargetPlayer(game, player, item_id, options)
  return AgentTargeting.PickTargetPlayer(game, player, item_id, options)
end

function Agent.PickRoadblockTarget(game, player)
  return AgentTargeting.PickRoadblockTarget(game, player)
end

function Agent.PickDemolishTarget(game, player, distance)
  return AgentTargeting.PickDemolishTarget(game, player, distance)
end

local function _FirstOptionId(options)
  if not options or #options == 0 then
    return nil
  end
  return options[1].id or options[1]
end

local function _ChoiceOwner(game, choice)
  local meta = choice.meta or {}
  if meta.player_id and game.players[meta.player_id] then
    return game.players[meta.player_id]
  end
  return game:CurrentPlayer()
end

function Agent.AutoActionForChoice(game, choice)
  local actor = _ChoiceOwner(game, choice)
  if not _IsAutoPlayer(actor) then
    return nil
  end

  if choice.kind == "remote_dice_value" then
    local dice_count = choice.meta.dice_count
    local value = AgentTargeting.PickRemoteDiceValue(game, actor, dice_count)
    return { type = "choice_select", choice_id = choice.id, option_id = value or _FirstOptionId(choice.options) }
  end

  if choice.kind == "roadblock_target" then
    local idx = AgentTargeting.PickRoadblockTarget(game, actor)
    return { type = "choice_select", choice_id = choice.id, option_id = idx or _FirstOptionId(choice.options) }
  end

  if choice.kind == "demolish_target" or choice.kind == "missile_target" then
    local idx = AgentTargeting.PickDemolishTarget(game, actor, 3)
    return { type = "choice_select", choice_id = choice.id, option_id = idx or _FirstOptionId(choice.options) }
  end

  if choice.kind == "item_target_player" then
    local item_id = choice.meta.item_id
    local target = AgentTargeting.PickTargetPlayer(game, actor, item_id, choice.options)
    if target then
      return { type = "choice_select", choice_id = choice.id, option_id = target.id }
    end
    return { type = "choice_cancel", choice_id = choice.id }
  end

  if choice.kind == "steal_item" then
    local id = _FirstOptionId(choice.options)
    if id then
      return { type = "choice_select", choice_id = choice.id, option_id = id }
    end
    return { type = "choice_cancel", choice_id = choice.id }
  end

  if choice.kind == "steal_prompt" then
    return { type = "choice_select", choice_id = choice.id, option_id = "use" }
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
      target = _FirstOptionId(options)
    end
    if target then
      return { type = "choice_select", choice_id = choice.id, option_id = target }
    end
    return { type = "choice_cancel", choice_id = choice.id }
  end

  if choice.kind == "rent_card_prompt" or choice.kind == "tax_card_prompt" then
    return { type = "choice_select", choice_id = choice.id, option_id = "use" }
  end

  if choice.kind == "item_phase_choice" then
    return { type = "choice_cancel", choice_id = choice.id }
  end

  if choice.kind == "market_buy" then
    return { type = "choice_cancel", choice_id = choice.id }
  end

  return nil
end

return Agent

