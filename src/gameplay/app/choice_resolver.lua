local Choice = require("src.gameplay.app.choice")
local Effect = require("src.gameplay.domain.effect")
local Inventory = require("src.gameplay.domain.item_inventory")
local Executor = require("src.gameplay.domain.item_executor")
local Strategy = require("src.gameplay.domain.item_strategy")
local Roadblock = require("src.gameplay.domain.item_roadblock")
local logger = require("src.util.logger")
local IntentDispatcher = require("src.gameplay.app.intent_dispatcher")
local MarketService = require("src.gameplay.app.services.market_service")
local TileService = require("src.gameplay.app.services.tile_service")
local constants = require("src.config.constants")

local Resolver = {}

local function as_number(v)
  if type(v) == "number" then
    return v
  end
  if type(v) == "string" then
    return tonumber(v)
  end
  return nil
end

local function is_cancel(action)
  return not action or action.type == "choice_cancel" or action.option_id == nil
end

local function use_item(game, player, item_id, context)
  context = context or {}
  context.services = context.services or (game and game.services)
  return Executor.use_item(game, player, item_id, context, { inventory = Inventory, strategy = Strategy })
end

local function contains(list, value)
  if type(list) ~= "table" then
    return false
  end
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

local function build_effect_ctx(game, player, tile, move_result)
  local phase = game and game.store and game.store:get({ "turn", "phase" }) or "wait_choice"
  return {
    game = game,
    store = game and game.store,
    rng = game and game.rng,
    services = game and game.services,
    phase = phase,
    player = player,
    tile = tile,
    move_result = move_result,
    on_landing = true,
  }
end

local function finish_post_action(game)
  if game and game.store then
    game.store:set({ "turn", "post_action" }, { done = true })
  end
end

local function get_container_defs_by_choice_kind(choice_kind)
  if choice_kind == "landing_optional_effect" or choice_kind == "land_optional_effect" then
    local landing_effects = require("src.gameplay.domain.landing")
    return landing_effects and landing_effects.defs or {}
  end
  return nil
end

local function find_effect_by_id(effect_defs, effect_id)
  for _, eff in ipairs(effect_defs or {}) do
    if eff.id == effect_id then
      return eff
    end
  end
  return nil
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

local handlers = {}

local function handle_optional_landing_effect(game, choice, action)
  local effect_id = action.option_id
  if not effect_id then
    Choice.clear(game)
    return { stay = false }
  end
  local meta = choice.meta or {}

  if meta.effect_ids and not contains(meta.effect_ids, effect_id) then
    logger.warn("landing_optional_effect: effect not in offered list:", tostring(effect_id))
    Choice.clear(game)
    return { stay = false }
  end

  local effect_defs = get_container_defs_by_choice_kind(choice.kind)
  local target_eff = find_effect_by_id(effect_defs, effect_id)
  if not target_eff then
    logger.warn("landing_optional_effect: effect id not found:", tostring(effect_id))
    Choice.clear(game)
    return { stay = false }
  end

  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  local tile = meta.tile_id and game.board:get_tile_by_id(meta.tile_id) or (player and game.board:get_tile(player.position))
  local move_result = meta.move_result or (game.last_turn and game.last_turn.move_result) or nil
  local ctx = build_effect_ctx(game, player, tile, move_result)

  local res = Effect.execute(target_eff, ctx)
  if res then
    IntentDispatcher.dispatch(game, res.result or res)
  end
  if not res or res.ok ~= true then
    logger.warn("landing_optional_effect execute blocked:", tostring(res and res.reason))
  end
  Choice.clear(game)
  return { stay = false }
end

handlers.landing_optional_effect = handle_optional_landing_effect
handlers.land_optional_effect = handle_optional_landing_effect

function Resolver.resolve(game, choice, action)
  if not game or not choice then
    return { stay = false }
  end

  if is_cancel(action) then
    if choice.kind == "post_action_item" then
      finish_post_action(game)
    end
    Choice.clear(game)
    return { stay = false }
  end

  local handler = handlers[choice.kind]
  if handler then
    return handler(game, choice, action)
  end

  local market_res = MarketService.handle_choice and MarketService.handle_choice(game, choice, action)
  if market_res then
    return market_res
  end

  local tile_res = TileService.handle_choice and TileService.handle_choice(game, choice, action)
  if tile_res then
    return tile_res
  end

  logger.warn("unknown choice kind:", tostring(choice.kind))
  Choice.clear(game)
  return { stay = false }
end

local function open_steal_item_choice(game, stealer, target)
  local lines = {}
  local options = {}
  for i, it in ipairs(target.inventory.items) do
    local label = Inventory.item_name(it.id)
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

  local res = use_item(game, player, item_id)
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
      Inventory.consume(player, meta.item_id)
    end
    local res = Executor.apply_missile(game, player, idx, { services = game and game.services })
    if res then
      IntentDispatcher.dispatch(game, res)
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
    if not Inventory.consume(player, meta.item_id) then
      Choice.clear(game)
      return { stay = false }
    end
  end
  local res = Roadblock.apply(game, player, idx)
  if res then
    IntentDispatcher.dispatch(game, res)
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
    local res = Executor.steal_item_at_index(game, stealer, target, 1, { inventory = Inventory })
    IntentDispatcher.dispatch(game, res)
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
    local res = Executor.steal_item_at_index(game, stealer, target, idx, { inventory = Inventory })
    IntentDispatcher.dispatch(game, res)
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
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  local item_id = meta.item_id
  if player and target_id and item_id then
    local res = use_item(game, player, item_id, { target_id = target_id })
    if res and res.waiting then return { stay = true } end
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
    if not Inventory.consume(player, meta.item_id) then
      Choice.clear(game)
      return { stay = false }
    end
  end
  Executor.apply_remote_dice(game, player, dice_count, value)
  finish_post_action(game)
  Choice.clear(game)
  return { stay = false }
end

handlers.post_action_item = handle_post_action_item
handlers.missile_target = handle_missile_target
handlers.roadblock_target = handle_roadblock_target
handlers.steal_target = handle_steal_target
handlers.steal_item = handle_steal_item
handlers.item_target_player = handle_item_target_player
handlers.remote_dice_value = handle_remote_dice_value

return Resolver
