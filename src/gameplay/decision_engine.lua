local Agent = require("src.gameplay.agent")
local Strategy = require("src.gameplay.item_strategy")
local Inventory = require("src.gameplay.item_inventory")
local Demolish = require("src.gameplay.item_demolish")
local Executor = require("src.gameplay.item_executor")

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

local function first_option_id(options)
  if not options or #options == 0 then
    return nil
  end
  return options[1].id or options[1]
end

function DecisionEngine.get_choice_action(game, choice)
  return Agent.auto_action_for_choice(game, choice)
end

function DecisionEngine.get_fallback_choice_action(choice)
  if not choice then
    return nil
  end
  local first = first_option_id(choice.options)
  if first ~= nil then
    return { type = "choice_select", choice_id = choice.id, option_id = first }
  end
  if choice.allow_cancel ~= false then
    return { type = "choice_cancel", choice_id = choice.id }
  end
  return nil
end

return DecisionEngine
