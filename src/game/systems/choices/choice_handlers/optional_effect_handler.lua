local effect_runner = require("src.game.systems.effects.effect_runner")
local logger = require("src.core.utils.logger")
local intent_output_port = require("src.game.ports.intent_output_port")

local optional_effect_handler = {}

function optional_effect_handler.build(helpers)
  local contains = helpers.contains
  local build_game_ctx = helpers.build_game_ctx
  local get_container_defs_by_choice_kind = helpers.get_container_defs_by_choice_kind
  local find_effect_by_id = helpers.find_effect_by_id
  local finish_choice = helpers.finish_choice

  local function _handle_optional_landing_effect(game, choice, action)
    local effect_id = assert(action.option_id, "missing effect_id")
    local meta = choice.meta

    if meta.effect_ids and not contains(meta.effect_ids, effect_id) then
      logger.warn("landing_optional_effect: effect not in offered list:", tostring(effect_id))
      return finish_choice(game, false)
    end

    local effect_defs = get_container_defs_by_choice_kind(choice.kind)
    local target_effect = assert(find_effect_by_id(effect_defs, effect_id), "missing target effect: " .. tostring(effect_id))

    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    local tile = assert(game.board:get_tile_by_id(meta.tile_id), "missing tile: " .. tostring(meta.tile_id))
    local move_result = meta.move_result
    local game_ctx = build_game_ctx(game, move_result)

    local result = effect_runner.execute(target_effect, player, tile, game_ctx)
    intent_output_port.dispatch(game, result.result or result)
    if result.ok ~= true then
      logger.warn("landing_optional_effect execute blocked:", tostring(result and result.reason))
    end
    return finish_choice(game, false)
  end

  return {
    landing_optional_effect = {
      required_meta = { "player_id", "tile_id" },
      execute = _handle_optional_landing_effect,
    },
  }
end

return optional_effect_handler
