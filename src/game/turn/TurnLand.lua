local landing_defs = require("Config.LandingEffects")
local effect_pipeline = require("src.game.effect.EffectPipeline")
local effect = require("src.game.effect.Effect")

local max_landing_depth = 10

local function _has_action_anim(game)
  if not game or not game.turn then
    return false
  end
  if game.turn.action_anim then
    return true
  end
  local queue = game.turn.action_anim_queue
  return type(queue) == "table" and #queue > 0
end

local function _resolve_landing(game, player, tile, move_result, depth)
  depth = depth or 0
  local game_ctx = effect.build_game_ctx(game, move_result, {
    phase_default = "landing",
    on_landing = true,
  })

  local function handle_need_landing(out)
    if depth >= max_landing_depth then
      return out
    end
    local target_player = player
    if out.player_id then
      target_player = game:find_player_by_id(out.player_id)
    end
    local next_tile = nil
    if target_player then
      local idx = out.board_index or target_player.position
      if idx then
        next_tile = game.board:get_tile(idx)
      end
    end
    if next_tile then
      return _resolve_landing(game, target_player, next_tile, out.move_result, depth + 1)
    end
    return out
  end

  return effect_pipeline.run(landing_defs, player, tile, game_ctx, {
    resume_state = "post_action",
    resume_args = { player = player },
    optional_choice_kind = "landing_optional_effect",
    optional_reason = "landing_optional",
    optional_allow_cancel = true,
    optional_cancel_label = "跳过",
    on_need_landing = handle_need_landing,
  })
end

local function _phase_land(turn_mgr, args)
  local player = args.player
  local move_result = args.move_result
  local tile = turn_mgr.game.board:get_tile(player.position)

  local res = _resolve_landing(turn_mgr.game, player, tile, move_result)
  if res and res.waiting then
    local resume_state = res.resume_state or "landing"
    local resume_args = res.resume_args or { player = player, move_result = move_result }
    if _has_action_anim(turn_mgr.game) then
      return "wait_action_anim", {
        resume_state = "wait_choice",
        resume_args = { resume_state = resume_state, resume_args = resume_args },
      }
    end
    return "wait_choice", { resume_state = resume_state, resume_args = resume_args }
  end

  if _has_action_anim(turn_mgr.game) then
    return "wait_action_anim", {
      resume_state = "post_action",
      resume_args = { player = player },
    }
  end

  return "post_action", { player = player }
end

return _phase_land
