local landing_defs = require("src.rules.land.landing_defs")
local effect_pipeline = require("src.rules.effects.pipeline")
local effect_runner = require("src.rules.effects.runner")
local wait_callbacks = require("src.turn.waits.callback_registry")
local predicates = require("src.turn.phases.land.predicates")

local max_landing_depth = 10
local callback_keys = wait_callbacks.callback_keys
local _resolve_landing

local function _resolve_target_player(game, player, out)
  if not out.player_id then
    return player
  end
  return game:find_player_by_id(out.player_id)
end

local function _resolve_next_tile(game, target_player, out)
  if not target_player then
    return nil
  end
  local idx = out.board_index or target_player.position
  if not idx then
    return nil
  end
  return game.board:get_tile(idx)
end

local function _wait_for_move_followup(game, target_player, out)
  return {
    waiting = true,
    wait_action_anim = true,
    next_state = "move_followup",
    next_args = {
      mode = "resolve_landing",
      player_id = target_player.id,
      move_result = out.move_result,
    },
  }
end

local function _wait_for_move_anim_followup(game, target_player, out)
  return {
    waiting = true,
    wait_move_anim = true,
    next_state = "move_followup",
    next_args = {
      mode = "resolve_landing",
      player_id = target_player.id,
      move_result = out.move_result,
    },
  }
end

local function _register_action_anim_resume(game, next_state, next_args, callback)
  wait_callbacks.register(game, callback_keys.after_action_anim, callback)
  if next_state == "move_followup" then
    game.turn.move_followup_pending = true
  end
  return "wait_action_anim", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _register_landing_visual_resume(game, next_state, next_args, callback)
  wait_callbacks.register(game, callback_keys.after_landing_visual, callback)
  return "wait_landing_visual", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _resume_wait_choice(next_state, next_args)
  return "wait_choice", {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _wait_for_choice_via_action_anim(game, next_state, next_args)
  return _register_action_anim_resume(game, "wait_choice", {
    next_state = next_state,
    next_args = next_args,
  }, function()
    return _resume_wait_choice(next_state, next_args)
  end)
end

local function _wait_for_choice_via_landing_visual(game, next_state, next_args)
  return _register_landing_visual_resume(game, "wait_choice", {
    next_state = next_state,
    next_args = next_args,
  }, function()
    return _resume_wait_choice(next_state, next_args)
  end)
end

local function _wait_for_choice_via_landing_visual_then_action_anim(game, next_state, next_args)
  local action_anim_state, action_anim_args = _wait_for_choice_via_action_anim(game, next_state, next_args)
  return _register_landing_visual_resume(game, action_anim_state, action_anim_args, function()
    return _wait_for_choice_via_action_anim(game, next_state, next_args)
  end)
end

local function _resolve_wait_state(game, next_state, next_args, wait_action_anim, wait_move_anim)
  local wait_choice_args = {
    next_state = next_state,
    next_args = next_args,
  }

  local has_anim = predicates.has_action_anim(game)
  local has_hold = predicates.is_landing_visual_hold_active(game)
  local effects_pending = not predicates.is_effect_idle()

  if wait_move_anim == true then
    if next_state == "move_followup" then
      game.turn.move_followup_pending = true
    end
    local move_anim_args = {
      next_state = next_state,
      next_args = next_args,
    }
    local function _resume_wait_move_anim()
      return "wait_move_anim", move_anim_args
    end
    if has_anim then
      if has_hold or effects_pending then
        return _register_landing_visual_resume(game, "wait_action_anim", {
          next_state = "wait_move_anim",
          next_args = move_anim_args,
        }, function()
          return _register_action_anim_resume(game, "wait_move_anim", move_anim_args, _resume_wait_move_anim)
        end)
      end
      return _register_action_anim_resume(game, "wait_move_anim", move_anim_args, _resume_wait_move_anim)
    end
    if has_hold or effects_pending then
      return _register_landing_visual_resume(game, "wait_move_anim", move_anim_args, _resume_wait_move_anim)
    end
    return "wait_move_anim", move_anim_args
  end

  if wait_action_anim == true then
    if has_anim then
      if has_hold or effects_pending then
        return _register_landing_visual_resume(game, "wait_action_anim", {
          next_state = next_state,
          next_args = next_args,
        }, function()
          return _register_action_anim_resume(game, next_state, next_args, function()
            return next_state, next_args
          end)
        end)
      end
      return _register_action_anim_resume(game, next_state, next_args, function()
        return next_state, next_args
      end)
    end
    if has_hold or effects_pending then
      return _register_landing_visual_resume(game, next_state, next_args, function()
        return next_state, next_args
      end)
    end
    return next_state, next_args
  end
  if has_anim then
    if has_hold or effects_pending then
      return _wait_for_choice_via_landing_visual_then_action_anim(game, next_state, next_args)
    end
    return _wait_for_choice_via_action_anim(game, next_state, next_args)
  end
  if has_hold or effects_pending then
    return _wait_for_choice_via_landing_visual(game, next_state, next_args)
  end
  return "wait_choice", wait_choice_args
end

local function _resolve_finished_landing_state(game, player)
  local function _resume_post_action()
    return "post_action", { player = player }
  end

  local has_anim = predicates.has_action_anim(game)
  local has_hold = predicates.is_landing_visual_hold_active(game)
  local effects_pending = not predicates.is_effect_idle()

  if has_anim then
    if has_hold or effects_pending then
      return _register_landing_visual_resume(game, "wait_action_anim", {
        next_state = "post_action",
        next_args = { player = player },
      }, function()
        return _register_action_anim_resume(game, "post_action", { player = player }, _resume_post_action)
      end)
    end
    return _register_action_anim_resume(game, "post_action", { player = player }, _resume_post_action)
  end
  if has_hold or effects_pending then
    return _register_landing_visual_resume(game, "post_action", { player = player }, _resume_post_action)
  end
  return "post_action", { player = player }
end

local function _resolve_landing_wait_args(res, player, move_result)
  return res.next_state or "landing", res.next_args or { player = player, move_result = move_result }
end

local function _resolve_waiting_landing_result(game, res, player, move_result)
  local next_state, next_args = _resolve_landing_wait_args(res, player, move_result)
  return _resolve_wait_state(game, next_state, next_args, res.wait_action_anim, res.wait_move_anim)
end

local function _resolve_followup_landing(game, player, out, depth)
  local target_player = _resolve_target_player(game, player, out)
  local next_tile = _resolve_next_tile(game, target_player, out)
  if not next_tile then
    return out
  end
  if out.wait_move_anim == true then
    return _wait_for_move_anim_followup(game, target_player, out)
  end
  if predicates.has_pending_relocation_action_anim(game) then
    return _wait_for_move_followup(game, target_player, out)
  end
  return _resolve_landing(game, target_player, next_tile, out.move_result, depth + 1)
end

function _resolve_landing(game, player, tile, move_result, depth)
  depth = depth or 0
  local game_ctx = effect_runner.build_game_ctx(game, move_result, {
    phase_default = "landing",
    on_landing = true,
  })

  local function handle_need_landing(out)
    if depth >= max_landing_depth then
      return out
    end
    return _resolve_followup_landing(game, player, out, depth)
  end

  return effect_pipeline.run(landing_defs, player, tile, game_ctx, {
    next_state = "post_action",
    next_args = { player = player },
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
  local game = turn_mgr.game
  local tile = game.board:get_tile(player.position)

  local res = _resolve_landing(game, player, tile, move_result)
  if res and res.waiting then
    return _resolve_waiting_landing_result(game, res, player, move_result)
  end
  return _resolve_finished_landing_state(game, player)
end

return {
  resolve_wait_state = _resolve_wait_state,
  phase_land = _phase_land,
}
