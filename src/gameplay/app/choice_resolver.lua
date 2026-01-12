local Choice = require("src.gameplay.app.choice")
local Effect = require("src.gameplay.domain.effect")
local ItemEffects = require("src.gameplay.domain.item")
local logger = require("src.util.logger")

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
    phase = phase,
    player = player,
    tile = tile,
    move_result = move_result,
    on_landing = true,
  }
end

local function get_container_defs_by_choice_kind(choice_kind)
  if choice_kind == "land_optional_effect" then
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

local function get_service(game, key)
  return game and game.services and game.services[key]
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

function Resolver.resolve(game, choice, action)
  if not game or not choice then
    return { stay = false }
  end

  if is_cancel(action) then
    Choice.clear(game)
    return { stay = false }
  end

  if choice.kind == "land_optional_effect" then
    local effect_id = action.option_id
    if effect_id then
      local meta = choice.meta or {}

      -- Reject effects not present when the choice was opened.
      if meta.effect_ids and not contains(meta.effect_ids, effect_id) then
        logger.warn("land_optional_effect: effect not in offered list:", tostring(effect_id))
        Choice.clear(game)
        return { stay = false }
      end

      local effect_defs = get_container_defs_by_choice_kind(choice.kind)
      local target_eff = find_effect_by_id(effect_defs, effect_id)
      if not target_eff then
        logger.warn("land_optional_effect: effect id not found:", tostring(effect_id))
        Choice.clear(game)
        return { stay = false }
      end

      local player = meta.player_id and game.players[meta.player_id] or game:current_player()
      local tile = meta.tile_id and game.board:get_tile_by_id(meta.tile_id) or
      (player and game.board:get_tile(player.position))
      local move_result = meta.move_result or (game.last_turn and game.last_turn.move_result) or nil
      local ctx = build_effect_ctx(game, player, tile, move_result)

      local res = Effect.execute(target_eff, ctx)
      if not res or res.ok ~= true then
        logger.warn("land_optional_effect execute blocked:", tostring(res and res.reason))
      end
    end
    Choice.clear(game)
    return { stay = false }
  end

  -- Item-related choice kinds are resolved in app (domain must not depend on Choice).
  if choice.kind == "missile_target" then
    if is_cancel(action) then
      Choice.clear(game)
      return { stay = false }
    end

    local idx = as_number(action.option_id)
    local meta = choice.meta or {}
    local player = meta.player_id and game.players[meta.player_id] or game:current_player()
    if idx and player then
      ItemEffects.consume_item(player, 2013)
      ItemEffects.apply_missile(game, player, idx)
    end
    Choice.clear(game)
    return { stay = false }
  end

  if choice.kind == "steal_target" then
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
      ItemEffects.steal_item_at_index(game, stealer, target, 1)
      Choice.clear(game)
      return { stay = false }
    end

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
    return { stay = true }
  end

  if choice.kind == "steal_item" then
    if is_cancel(action) then
      Choice.clear(game)
      return { stay = false }
    end

    local idx = as_number(action.option_id)
    local meta = choice.meta or {}
    local stealer = meta.stealer_id and game.players[meta.stealer_id] or game:current_player()
    local target = meta.target_id and game.players[meta.target_id]
    if stealer and target and idx then
      ItemEffects.steal_item_at_index(game, stealer, target, idx)
    end
    Choice.clear(game)
    return { stay = false }
  end

  if choice.kind == "item_target_player" then
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

  logger.warn("unknown choice kind:", tostring(choice.kind))
  Choice.clear(game)
  return { stay = false }
end

return Resolver
