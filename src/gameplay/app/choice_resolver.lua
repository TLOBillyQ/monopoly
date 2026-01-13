local constants = require("src.config.constants")
local Choice = require("src.gameplay.app.choice")
local Effect = require("src.gameplay.domain.effect")
local ItemEffects = require("src.gameplay.domain.item")
local Roadblock = require("src.gameplay.domain.item_roadblock")
local logger = require("src.util.logger")
local IntentDispatcher = require("src.gameplay.app.intent_dispatcher")

local Resolver = {}

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
    IntentDispatcher.dispatch_from_result(game, res.result or res)
  end
  if not res or res.ok ~= true then
    logger.warn("landing_optional_effect execute blocked:", tostring(res and res.reason))
  end
  Choice.clear(game)
  return { stay = false }
end

handlers.landing_optional_effect = handle_optional_landing_effect
handlers.land_optional_effect = handle_optional_landing_effect

handlers.post_action_item = function(game, choice, action)
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
  IntentDispatcher.dispatch_from_result(game, res)
  if type(res) == "table" and res.waiting then
    return { stay = true }
  end
  Choice.clear(game)
  return { stay = false }
end

handlers.missile_target = function(game, choice, action)
  if is_cancel(action) then
    Choice.clear(game)
    return { stay = false }
  end
  local idx = as_number(action.option_id)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  if idx and player then
    ItemEffects.consume_item(player, 2013)
    local res = ItemEffects.apply_missile(game, player, idx, { services = game and game.services })
    IntentDispatcher.dispatch_from_result(game, res)
  end
  Choice.clear(game)
  return { stay = false }
end

handlers.roadblock_target = function(game, choice, action)
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
  Roadblock.apply(game, player, idx)
  Choice.clear(game)
  return { stay = false }
end

handlers.steal_target = function(game, choice, action)
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

handlers.steal_item = function(game, choice, action)
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

handlers.item_target_player = function(game, choice, action)
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
  Choice.clear(game)
  return { stay = false }
end

handlers.market_buy = function(game, choice, action)
  if is_cancel(action) then
    Choice.clear(game)
    return { stay = false }
  end

  local item_id = as_number(action.option_id)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  local market = game.services["market"]
  if player and market and market.buy and item_id then
    market.buy(game, player, item_id)
  end
  Choice.clear(game)
  return { stay = false }
end

handlers.rent_card_prompt = function(game, choice, action)
  local meta = choice.meta or {}
  local store = game and game.store
  if store and meta.player_id and meta.tile_id and meta.kind then
    local decision = (action and action.option_id == "use")
    if is_cancel(action) then
      decision = false
    end
    store:set({ "turn", "rent_prompt" }, {
      player_id = meta.player_id,
      tile_id = meta.tile_id,
      kind = meta.kind,
      decision = decision,
    })
  end
  Choice.clear(game)
  return { stay = false }
end

handlers.tax_card_prompt = function(game, choice, action)
  local meta = choice.meta or {}
  local store = game and game.store
  if store and meta.player_id then
    local decision = (action and action.option_id == "use")
    if is_cancel(action) then
      decision = false
    end
    store:set({ "turn", "tax_prompt" }, {
      player_id = meta.player_id,
      decision = decision,
    })
  end
  Choice.clear(game)
  return { stay = false }
end

handlers.remote_dice_value = function(game, choice, action)
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
  Choice.clear(game)
  return { stay = false }
end

function Resolver.resolve(game, choice, action)
  if not game or not choice then
    return { stay = false }
  end

  if is_cancel(action) then
    Choice.clear(game)
    return { stay = false }
  end

  local handler = handlers[choice.kind]
  if handler then
    return handler(game, choice, action)
  end

  logger.warn("unknown choice kind:", tostring(choice.kind))
  Choice.clear(game)
  return { stay = false }
end

return Resolver
