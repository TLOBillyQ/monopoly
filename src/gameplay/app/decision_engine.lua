local Agent = require("src.gameplay.ai.agent")
local Strategy = require("src.gameplay.domain.item_strategy")
local Inventory = require("src.gameplay.domain.item_inventory")
local Demolish = require("src.gameplay.domain.item_demolish")
local Executor = require("src.gameplay.domain.item_executor")

local DecisionEngine = {}

function DecisionEngine.should_auto_decide(player)
  return Agent.is_auto_player(player)
end

function DecisionEngine.get_pre_turn_action(game, player)
  if not DecisionEngine.should_auto_decide(player) then
    return nil
  end

  return Strategy.auto_pre_action(game, player, {
    inventory = Inventory,
    find_monster_target = Demolish.find_target,
    find_missile_target = Demolish.find_target,
    use_item = function(g, p, id, ctx)
      ctx = ctx or { by_ai = true }
      ctx.services = g.services
      return Executor.use_item(g, p, id, ctx, { inventory = Inventory, strategy = Strategy })
    end,
  })
end

function DecisionEngine.get_choice_action(game, choice)
  if not choice then
    return nil
  end

  local meta = choice.meta or {}
  local actor
  if meta.player_id and game.players[meta.player_id] then
    actor = game.players[meta.player_id]
  elseif meta.user_id and game.players[meta.user_id] then
    actor = game.players[meta.user_id]
  elseif meta.stealer_id and game.players[meta.stealer_id] then
    actor = game.players[meta.stealer_id]
  else
    actor = game:current_player()
  end

  if not DecisionEngine.should_auto_decide(actor) then
    return nil
  end

  return Agent.auto_action_for_choice(game, choice)
end

return DecisionEngine
