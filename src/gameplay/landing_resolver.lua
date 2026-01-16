local landing_effects = require("src.gameplay.landing")
local EffectPipeline = require("src.gameplay.effect_pipeline")

local LandingResolver = {}

local MAX_LANDING_DEPTH = 10

local function build_ctx(game, player, tile, move_result)
  local phase = game and game.store and game.store:get({ "turn", "phase" }) or "landing"
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



function LandingResolver.resolve(game, player, tile, move_result, depth)
  depth = depth or 0
  local ctx = build_ctx(game, player, tile, move_result)

  local function handle_need_landing(out)
    if depth >= MAX_LANDING_DEPTH then
      return out
    end
    local target_player = (out.player_id and game and game.players and game.players[out.player_id]) or player
    local next_tile = nil
    if target_player then
      local idx = out.board_index or target_player.position
      next_tile = idx and game and game.board and game.board:get_tile(idx) or nil
    end
    if next_tile then
      return LandingResolver.resolve(game, target_player, next_tile, out.move_result, depth + 1)
    end
    return out
  end

  return EffectPipeline.run(landing_effects.defs, ctx, {
    resume_state = "post_action",
    resume_args = { player = player },
    optional_choice_kind = "landing_optional_effect",
    optional_reason = "landing_optional",
    optional_allow_cancel = true,
    optional_cancel_label = "跳过",
    on_need_landing = handle_need_landing,
  })
end

return LandingResolver
