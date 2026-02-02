local LandingDefs = require("Config.LandingEffects")
local EffectPipeline = require("Manager.EffectManager.Effect.EffectPipeline")
local Effect = require("Manager.EffectManager.Effect.Effect")

local MAX_LANDING_DEPTH = 10

local function resolve_landing(game, player, tile, move_result, depth)
  depth = depth or 0
  local game_ctx = Effect.build_game_ctx(game, move_result, {
    phase_default = "landing",
    on_landing = true,
  })

  local function handle_need_landing(out)
    if depth >= MAX_LANDING_DEPTH then
      return out
    end
    local target_player = player
    if out.player_id then
      target_player = game.players[out.player_id]
    end
    local next_tile = nil
    if target_player then
      local idx = out.board_index or target_player.position
      if idx then
        next_tile = game.board:get_tile(idx)
      end
    end
    if next_tile then
      return resolve_landing(game, target_player, next_tile, out.move_result, depth + 1)
    end
    return out
  end

  return EffectPipeline.run(LandingDefs, player, tile, game_ctx, {
    resume_state = "post_action",
    resume_args = { player = player },
    optional_choice_kind = "landing_optional_effect",
    optional_reason = "landing_optional",
    optional_allow_cancel = true,
    optional_cancel_label = "跳过",
    on_need_landing = handle_need_landing,
  })
end

local function phase_land(tm, args)
  local player = args.player
  local move_result = args.move_result
  local tile = tm.game.board:get_tile(player.position)

  local res = resolve_landing(tm.game, player, tile, move_result)
  if res and res.waiting then
    local resume_state = res.resume_state or "landing"
    local resume_args = res.resume_args or { player = player, move_result = move_result }
    return "wait_choice", { resume_state = resume_state, resume_args = resume_args }
  end

  return "post_action", { player = player }
end

return phase_land
