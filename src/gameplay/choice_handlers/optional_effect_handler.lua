local Effect = require("src.gameplay.effect")
local logger = require("src.util.logger")
local IntentDispatcher = require("src.util.intent_dispatcher")

local OptionalEffectHandler = {}

function OptionalEffectHandler.build(helpers)
  local clear_choice = helpers.clear_choice
  local contains = helpers.contains
  local build_effect_ctx = helpers.build_effect_ctx
  local get_container_defs_by_choice_kind = helpers.get_container_defs_by_choice_kind
  local find_effect_by_id = helpers.find_effect_by_id

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
    IntentDispatcher.dispatch(game, res.result or res)
    if res.ok ~= true then
      logger.warn("landing_optional_effect execute blocked:", tostring(res and res.reason))
    end
    clear_choice(game)
    return { stay = false }
  end

  return {
    landing_optional_effect = handle_optional_landing_effect,
    land_optional_effect = handle_optional_landing_effect,
  }
end

return OptionalEffectHandler
