local Effect = require("Manager.GameManager.Effect.Effect")
local logger = require("Library.Monopoly.Logger")
local IntentDispatcher = require("Library.Monopoly.IntentDispatcher")

local OptionalEffectHandler = {}

function OptionalEffectHandler.build(helpers)
  local contains = helpers.contains
  local build_game_ctx = helpers.build_game_ctx
  local get_container_defs_by_choice_kind = helpers.get_container_defs_by_choice_kind
  local find_effect_by_id = helpers.find_effect_by_id
  local finish_choice = helpers.finish_choice

  local function handle_optional_landing_effect(game, choice, action)
    local effect_id = action.option_id
    if not effect_id then
      return finish_choice(game, false)
    end
    local meta = choice.meta

    if meta.effect_ids and not contains(meta.effect_ids, effect_id) then
      logger.warn("landing_optional_effect: effect not in offered list:", tostring(effect_id))
      return finish_choice(game, false)
    end

    local effect_defs = get_container_defs_by_choice_kind(choice.kind)
    local target_eff = find_effect_by_id(effect_defs, effect_id)
    if not target_eff then
      logger.warn("landing_optional_effect: effect id not found:", tostring(effect_id))
      return finish_choice(game, false)
    end

    local player = game.players[meta.player_id]
    local tile = game.board:get_tile_by_id(meta.tile_id)
    local move_result = meta.move_result
    local game_ctx = build_game_ctx(game, move_result)

    local res = Effect.execute(target_eff, player, tile, game_ctx)
    IntentDispatcher.dispatch(game, res.result or res)
    if res.ok ~= true then
      logger.warn("landing_optional_effect execute blocked:", tostring(res and res.reason))
    end
    return finish_choice(game, false)
  end

  return {
    landing_optional_effect = handle_optional_landing_effect,
    land_optional_effect = handle_optional_landing_effect,
  }
end

return OptionalEffectHandler
