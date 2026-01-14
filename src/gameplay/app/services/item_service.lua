local constants = require("src.config.constants")
local Inventory = require("src.gameplay.domain.item_inventory")
local Strategy = require("src.gameplay.domain.item_strategy")
local Executor = require("src.gameplay.domain.item_executor")
local IntentDispatcher = require("src.gameplay.app.intent_dispatcher")
local Choice = require("src.gameplay.app.choice")

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

local function finish_post_action(game)
  if game and game.store then
    game.store:set({ "turn", "post_action" }, { done = true })
  end
end

local function as_number(v)
  if type(v) == "number" then
    return v
  end
  if type(v) == "string" then
    local n = tonumber(v)
    return n
  end
  return nil
end

local function is_cancel(action)
  return not action or action.type == "choice_cancel" or action.option_id == nil
end

local function open_steal_item_choice(game, stealer, target)
  local lines = {}
  local options = {}
  for i, it in ipairs(target.inventory.items) do
    local label = ItemEffects.item_name(it.id)
    table.insert(lines, i .. ". " .. label)
    table.insert(options, { id = i, label = label })
  end
  Choice.open(game, {
    kind = "steal_item",
    title = "选择要偷的道具",
    body_lines = lines,
    options = options,
    allow_cancel = true,
    cancel_label = "取消",
    meta = { stealer_id = stealer.id, target_id = target.id },
  })
end

local function handle_post_action_item(game, choice, action)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  if is_cancel(action) then
    finish_post_action(game)
    Choice.clear(game)
    return { stay = false }
  end
  if not player then
    Choice.clear(game)
    return { stay = false }
  end
  local item_id = as_number(action.option_id)
  if not item_id then
    Choice.clear(game)
    return { stay = false }
  end

  local res = ItemEffects.use_item(game, player, item_id)
  if type(res) == "table" and res.waiting then
    return { stay = true }
  end
  finish_post_action(game)
  Choice.clear(game)
  return { stay = false }
end

local function handle_missile_target(game, choice, action)
  if is_cancel(action) then
    Choice.clear(game)
    return { stay = false }
  end
  local idx = as_number(action.option_id)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  if idx and player then
    if meta.item_id then
      ItemEffects.consume_item(player, meta.item_id)
    end
    local res = ItemEffects.apply_missile(game, player, idx, { services = game and game.services })
    if res then
      IntentDispatcher.dispatch_from_result(game, res)
    end
  end
  finish_post_action(game)
  Choice.clear(game)
  return { stay = false }
end

local function handle_roadblock_target(game, choice, action)
  if is_cancel(action) then
    Choice.clear(game)
    return { stay = false }
  end
  local idx = as_number(action.option_id)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  if not player or not idx then
    Choice.clear(game)
    return { stay = false }
  end
  if meta.item_id then
    if not ItemEffects.consume_item(player, meta.item_id) then
      Choice.clear(game)
      return { stay = false }
    end
  end
  local res = require("src.gameplay.domain.item_roadblock").apply(game, player, idx)
  if res then
    IntentDispatcher.dispatch_from_result(game, res)
  end
  finish_post_action(game)
  Choice.clear(game)
  return { stay = false }
end

local function handle_steal_target(game, choice, action)
  if is_cancel(action) then
    Choice.clear(game)
    return { stay = false }
  end
  local target_id = as_number(action.option_id)
  local meta = choice.meta or {}
  local stealer = meta.stealer_id and game.players[meta.stealer_id] or game:current_player()
  local target = target_id and game.players[target_id]
  if not stealer or not target or target.eliminated then
    Choice.clear(game)
    return { stay = false }
  end

  if target.inventory:count() <= 1 then
    local res = ItemEffects.steal_item_at_index(game, stealer, target, 1)
    IntentDispatcher.dispatch_from_result(game, res)
    Choice.clear(game)
    return { stay = false }
  end

  open_steal_item_choice(game, stealer, target)
  return { stay = true }
end

local function handle_steal_item(game, choice, action)
  if is_cancel(action) then
    Choice.clear(game)
    return { stay = false }
  end
  local idx = as_number(action.option_id)
  local meta = choice.meta or {}
  local stealer = meta.stealer_id and game.players[meta.stealer_id] or game:current_player()
  local target = meta.target_id and game.players[meta.target_id]
  if stealer and target and idx then
    local res = ItemEffects.steal_item_at_index(game, stealer, target, idx)
    IntentDispatcher.dispatch_from_result(game, res)
  end
  Choice.clear(game)
  return { stay = false }
end

local function handle_item_target_player(game, choice, action)
  if is_cancel(action) then
    Choice.clear(game)
    return { stay = false }
  end
  local target_id = as_number(action.option_id)
  local meta = choice.meta or {}
  local item_id = meta.item_id
  local user = meta.user_id and game.players[meta.user_id] or game:current_player()
  local target = target_id and game.players[target_id]
  if user and target and item_id then
    local ok = ItemEffects.apply_target_item_effect(game, user, item_id, target)
    if ok then
      ItemEffects.consume_item(user, item_id)
    end
  end
  finish_post_action(game)
  Choice.clear(game)
  return { stay = false }
end

local function handle_remote_dice_value(game, choice, action)
  if is_cancel(action) then
    Choice.clear(game)
    return { stay = false }
  end
  local value = as_number(action.option_id)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  local dice_count = meta.dice_count or (player and (player.seat_id and constants.dice_with_vehicle or constants.default_dice_count)) or 1
  if not player or not value then
    Choice.clear(game)
    return { stay = false }
  end
  if meta.item_id then
    if not ItemEffects.consume_item(player, meta.item_id) then
      Choice.clear(game)
      return { stay = false }
    end
  end
  ItemEffects.apply_remote_dice(game, player, dice_count, value)
  finish_post_action(game)
  Choice.clear(game)
  return { stay = false }
end

function ItemEffects.handle_choice(game, choice, action)
  if not choice then
    return nil
  end
  local kind = choice.kind
  if kind == "post_action_item" then
    return handle_post_action_item(game, choice, action)
  end
  if kind == "missile_target" then
    return handle_missile_target(game, choice, action)
  end
  if kind == "roadblock_target" then
    return handle_roadblock_target(game, choice, action)
  end
  if kind == "steal_target" then
    return handle_steal_target(game, choice, action)
  end
  if kind == "steal_item" then
    return handle_steal_item(game, choice, action)
  end
  if kind == "item_target_player" then
    return handle_item_target_player(game, choice, action)
  end
  if kind == "remote_dice_value" then
    return handle_remote_dice_value(game, choice, action)
  end
  return nil
end

return ItemEffects
