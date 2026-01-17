return require("src.gameplay.choice_service")
--[[
local Effect = require("src.gameplay.effect")
local Inventory = require("src.gameplay.item_inventory")
local Executor = require("src.gameplay.item_executor")
local Demolish = require("src.gameplay.item_demolish")
local Strategy = require("src.gameplay.item_strategy")
local Steal = require("src.gameplay.item_steal")
local Roadblock = require("src.gameplay.item_roadblock")
local logger = require("src.util.logger")
local MarketService = require("src.gameplay.market_service")
local ItemPhase = require("src.gameplay.item_phase")
local IntentDispatcher = require("src.util.intent_dispatcher")
local Convert = require("src.util.convert")

local Resolver = {}

local function is_cancel(action)
  return not action or action.type == "choice_cancel" or action.option_id == nil
end

local function clear_choice(game)
  if not (game and game.store) then
    return
  end
  game.store:set({ "turn", "pending_choice" }, nil)
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

local function finish_item_phase(game, phase)
  ItemPhase.finish(game, phase)
end
local function finish_active_item_phase(game)
  if not (game and game.store) then
    return
  end
  local phase = game.store:get({ "turn", "item_phase_active" })
  if phase then
    ItemPhase.finish(game, phase)
  end
end

local function get_container_defs_by_choice_kind(choice_kind)
  if choice_kind == "landing_optional_effect" or choice_kind == "land_optional_effect" then
    local landing_effects = require("src.gameplay.landing")
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
local handlers = {}

local function handle_optional_landing_effect(game, choice, action)
  local effect_id = action.option_id
  if not effect_id then
    clear_choice(game)
    return { stay = false }
  end
  local meta = choice.meta or {}

  if meta.effect_ids and not contains(meta.effect_ids, effect_id) then
    logger.warn("landing_optional_effect: effect not in offered list:", tostring(effect_id))
    clear_choice(game)
    return { stay = false }
  end

  local effect_defs = get_container_defs_by_choice_kind(choice.kind)
  local target_eff = find_effect_by_id(effect_defs, effect_id)
  if not target_eff then
    logger.warn("landing_optional_effect: effect id not found:", tostring(effect_id))
    clear_choice(game)
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
  clear_choice(game)
  return { stay = false }
end

handlers.landing_optional_effect = handle_optional_landing_effect
handlers.land_optional_effect = handle_optional_landing_effect

local function handle_rent_prompt(game, choice, action)
  local LandEffect = require("src.gameplay.land")
  local meta = choice.meta or {}
  local player_id = meta.player_id
  local tile_id = meta.tile_id
  local card_kind = meta.card_kind

  local use_card = (action and action.option_id == "use") and not is_cancel(action)

  if use_card and card_kind == "strong" then
    -- 使用强征卡
    LandEffect.execute_strong_card(game, player_id, tile_id)
  elseif use_card and card_kind == "free" then
    -- 使用免费卡（免租）
    LandEffect.execute_free_card(game, player_id, tile_id)
  else
    if card_kind == "strong" then
      local player = player_id and game.players[player_id] or nil
      local free_idx = player and player.inventory and player.inventory:find_index(function(it) return it.id == 2001 end)
      if free_idx then
        IntentDispatcher.dispatch(game, {
          kind = "need_choice",
          choice_spec = {
            kind = "rent_card_prompt",
            title = "是否使用免费卡",
            body_lines = { "免除本次租金" },
            options = {
              { id = "use", label = "使用" },
              { id = "skip", label = "放弃" },
            },
            allow_cancel = false,
            meta = { player_id = player_id, tile_id = tile_id, card_kind = "free" },
          },
        })
        return { stay = true }
      end
    end
    -- 跳过当前卡 → 直接支付租金
    LandEffect.execute_pay_rent(game, player_id, tile_id)
  end

  clear_choice(game)
  return { stay = false }
end

local function handle_tax_prompt(game, choice, action)
  local LandEffect = require("src.gameplay.land")
  local meta = choice.meta or {}
  local player_id = meta.player_id

  local use_card = (action and action.option_id == "use") and not is_cancel(action)

  if use_card then
    -- 使用免税卡
    LandEffect.execute_tax_free_card(game, player_id)
  else
    -- 跳过 → 直接支付税金
    LandEffect.execute_pay_tax(game, player_id)
  end

  clear_choice(game)
  return { stay = false }
end

handlers.rent_card_prompt = handle_rent_prompt
handlers.tax_card_prompt = handle_tax_prompt

function Resolver.resolve(game, choice, action)
  if not game or not choice then
    return { stay = false }
  end

  if is_cancel(action) then
    if choice.kind == "item_phase_choice" then
      local phase = choice.meta and choice.meta.phase
      finish_item_phase(game, phase)
    end
    clear_choice(game)
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

  logger.warn("unknown choice kind:", tostring(choice.kind))
  clear_choice(game)
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
  IntentDispatcher.dispatch(game, {
    kind = "need_choice",
    choice_spec = {
      kind = "steal_item",
      title = "选择要偷的道具",
      body_lines = lines,
      options = options,
      allow_cancel = true,
      cancel_label = "取消",
      meta = { stealer_id = stealer.id, target_id = target.id },
    },
  })
end

local function handle_demolish_target(game, choice, action)
  if is_cancel(action) then
    clear_choice(game)
    return { stay = false }
  end
  local idx = Convert.to_number(action.option_id)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  if idx and player then
    if meta.item_id then
      Inventory.consume(player, meta.item_id)
    end
    local res = Demolish.apply(game, player, idx, { 
      services = game and game.services,
      injure = meta.injure,
      title = meta.title
    })
    if res and res.intent then
      IntentDispatcher.dispatch(game, res.intent)
    end
  end
  finish_active_item_phase(game)
  clear_choice(game)
  return { stay = false }
end

local function handle_roadblock_target(game, choice, action)
  if is_cancel(action) then
    clear_choice(game)
    return { stay = false }
  end
  local idx = Convert.to_number(action.option_id)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  if not player or not idx then
    clear_choice(game)
    return { stay = false }
  end
  if meta.item_id then
    if not Inventory.consume(player, meta.item_id) then
      clear_choice(game)
      return { stay = false }
    end
  end
  local res = Roadblock.apply(game, player, idx)
  if res then
    IntentDispatcher.dispatch(game, res)
  end
  finish_active_item_phase(game)
  clear_choice(game)
  return { stay = false }
end

local function handle_steal_target(game, choice, action)
  if is_cancel(action) then
    clear_choice(game)
    return { stay = false }
  end
  local target_id = Convert.to_number(action.option_id)
  local meta = choice.meta or {}
  local stealer = meta.stealer_id and game.players[meta.stealer_id] or game:current_player()
  local target = target_id and game.players[target_id]
  if not stealer or not target or target.eliminated then
    clear_choice(game)
    return { stay = false }
  end

  if target.inventory:count() <= 1 then
    local res = Steal.steal_item_at_index(game, stealer, target, 1)
    logger.event("Steal choice result (single)", res)
    clear_choice(game)
    if res and res.intent then
      IntentDispatcher.dispatch(game, res.intent)
    end
    return { stay = false }
  end

  open_steal_item_choice(game, stealer, target)
  return { stay = true }
end

local function handle_steal_item(game, choice, action)
  if is_cancel(action) then
    clear_choice(game)
    return { stay = false }
  end
  local idx = Convert.to_number(action.option_id)
  local meta = choice.meta or {}
  local stealer = meta.stealer_id and game.players[meta.stealer_id] or game:current_player()
  local target = meta.target_id and game.players[meta.target_id]
  if stealer and target and idx then
    local res = Steal.steal_item_at_index(game, stealer, target, idx)
    logger.event("Steal choice result (multi)", res)
    clear_choice(game)
    if res and res.intent then
      IntentDispatcher.dispatch(game, res.intent)
    end
  end
  finish_active_item_phase(game)
  clear_choice(game)
  return { stay = false }
end

local function handle_item_target_player(game, choice, action)
  if is_cancel(action) then
    clear_choice(game)
    return { stay = false }
  end
  local target_id = Convert.to_number(action.option_id)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  local item_id = meta.item_id
  if player and target_id and item_id then
    local res = use_item(game, player, item_id, { target_id = target_id })
    if res and res.waiting then return { stay = true } end
  end
  finish_active_item_phase(game)
  clear_choice(game)
  return { stay = false }
end

local function handle_remote_dice_value(game, choice, action)
  if is_cancel(action) then
    clear_choice(game)
    return { stay = false }
  end
  local value = Convert.to_number(action.option_id)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  local dice_count = meta.dice_count or (player and player.dice_count and player:dice_count()) or 1
  if not player or not value then
    clear_choice(game)
    return { stay = false }
  end
  if meta.item_id then
    if not Inventory.consume(player, meta.item_id) then
      clear_choice(game)
      return { stay = false }
    end
  end
  Executor.apply_remote_dice(game, player, dice_count, value)
  finish_active_item_phase(game)
  clear_choice(game)
  return { stay = false }
end

local function handle_item_phase_choice(game, choice, action)
  local meta = choice.meta or {}
  local player = meta.player_id and game.players[meta.player_id] or game:current_player()
  local phase = meta.phase
  if is_cancel(action) then
    finish_item_phase(game, phase)
    clear_choice(game)
    return { stay = false }
  end
  if not player then
    clear_choice(game)
    return { stay = false }
  end
  local item_id = Convert.to_number(action.option_id)
  if not item_id then
    clear_choice(game)
    return { stay = false }
  end

  local res = use_item(game, player, item_id)
  if type(res) == "table" and res.waiting then
    if res.intent then
      IntentDispatcher.dispatch(game, res.intent)
    end
    return { stay = true }
  end
  finish_item_phase(game, phase)
  clear_choice(game)
  return { stay = false }
end

handlers.item_phase_choice = handle_item_phase_choice
handlers.demolish_target = handle_demolish_target
handlers.roadblock_target = handle_roadblock_target
handlers.steal_target = handle_steal_target
handlers.steal_item = handle_steal_item
handlers.item_target_player = handle_item_target_player
handlers.remote_dice_value = handle_remote_dice_value

return Resolver
]]
