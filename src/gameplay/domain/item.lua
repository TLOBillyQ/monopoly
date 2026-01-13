local Inventory = require("src.gameplay.domain.item_inventory")
local Strategy = require("src.gameplay.domain.item_strategy")
local Executor = require("src.gameplay.domain.item_executor")

local ItemEffects = {}

ItemEffects.item_name = Inventory.item_name
ItemEffects.consume_item = Inventory.consume
ItemEffects.draw_random_item = Inventory.draw_random
ItemEffects.give_item = Inventory.give
ItemEffects.draw_and_give = Inventory.draw_and_give

ItemEffects.apply_remote_dice = Executor.apply_remote_dice
ItemEffects.find_monster_target = Executor.find_monster_target
ItemEffects.use_monster = Executor.use_monster
ItemEffects.find_missile_target = Executor.find_missile_target
ItemEffects.apply_missile = Executor.apply_missile
ItemEffects.use_missile = function(game, player, distance, context)
  local deps = context or {}
  deps.inventory = Inventory
  return Executor.use_missile(game, player, distance, deps)
end
ItemEffects.apply_target_item_effect = Executor.apply_target_item_effect

function ItemEffects.use_item(game, player, item_id, context)
  context = context or {}
  context.services = context.services or (game and game.services)
  return Executor.use_item(game, player, item_id, context, { inventory = Inventory, strategy = Strategy })
end

function ItemEffects.has_obstacles_ahead(game, player, distance)
  return Strategy.has_obstacles_ahead(game, player, distance)
end

function ItemEffects.auto_pre_action(game, player)
  return Strategy.auto_pre_action(game, player, {
    inventory = Inventory,
    use_item = function(g, p, id, ctx)
      return ItemEffects.use_item(g, p, id, ctx or { by_ai = true })
    end,
    find_monster_target = Executor.find_monster_target,
    find_missile_target = Executor.find_missile_target,
  })
end

function ItemEffects.steal_item_at_index(game, player, target, item_idx)
  return Executor.steal_item_at_index(game, player, target, item_idx, { inventory = Inventory })
end

function ItemEffects.handle_pass_players(game, player, encountered_ids, context)
  return Executor.handle_pass_players(game, player, encountered_ids, {
    inventory = Inventory,
    services = (context and context.services) or (game and game.services),
  })
end

return ItemEffects
