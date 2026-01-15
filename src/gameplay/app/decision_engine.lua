local Agent = require("src.gameplay.ai.agent")
local Strategy = require("src.gameplay.domain.item_strategy")
local Inventory = require("src.gameplay.domain.item_inventory")
local Demolish = require("src.gameplay.domain.item_demolish")
local Executor = require("src.gameplay.domain.item_executor")

local DecisionEngine = {}

function DecisionEngine.get_pre_turn_action(game, player)
  if not Agent.is_auto_player(player) then
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
  return Agent.auto_action_for_choice(game, choice)
end

return DecisionEngine
