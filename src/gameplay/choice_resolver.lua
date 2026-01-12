local Choice = require("src.gameplay.choice")
local Effect = require("src.gameplay.effect")
local ItemEffects = require("src.gameplay.effects.item")
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
    local landing_effects = require("src.gameplay.effects.landing")
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
      local tile = meta.tile_id and game.board:get_tile_by_id(meta.tile_id) or (player and game.board:get_tile(player.position))
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

  -- PR4 (items): delegate item-related choice kinds to ItemEffects.
  local item_res = ItemEffects.resolve_choice(game, choice, action)
  if item_res and item_res.handled then
    return { stay = item_res.stay == true }
  end

  logger.warn("unknown choice kind:", tostring(choice.kind))
  Choice.clear(game)
  return { stay = false }
end

return Resolver
