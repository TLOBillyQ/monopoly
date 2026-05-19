local runtime_state = require("src.state.runtime")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local landing_defs = require("src.rules.land.landing_defs")
local effect_pipeline = require("src.rules.effects.pipeline")
local effect_runner = require("src.rules.effects.runner")
local land_actions = require("src.rules.land.actions")
local pricing = require("src.rules.land.pricing")
local wait_callbacks = require("src.turn.waits.callback_registry")

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

local function _is_relocation_action_anim(entry)
  return entry and (entry.kind == "move_effect" or entry.kind == "teleport_effect" or entry.kind == "forced_relocation")
end

local function _has_pending_relocation_action_anim(game)
  if not game or not game.turn then
    return false
  end
  local current = game.turn.action_anim
  if _is_relocation_action_anim(current) then
    return true
  end
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" then
    return false
  end
  for _, entry in ipairs(queue) do
    if _is_relocation_action_anim(entry) then
      return true
    end
  end
  return false
end

local function _is_landing_visual_hold_active(game)
  if not game then
    return false
  end
  local state = game.landing_visual_hold_state
  if state ~= nil and runtime_state.get_landing_visual_hold_source(state) ~= nil then
    return runtime_state.get_landing_visual_hold_active(state)
  end
  local turn = game.turn or nil
  return turn and turn.landing_visual_hold_active == true or false
end

local _is_effect_idle = runtime_ports.is_effect_idle

local function _landing_optional_cost(effect_id, tile, game)
  if effect_id ~= "upgrade_land" or tile == nil or game == nil then
    return nil
  end
  local st = land_actions.safe_tile_state(game, tile)
  return pricing.upgrade_cost(tile, (st and st.level) or 0)
end

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

local function _build_move_followup_result(target_player, out, wait_key)
  return {
    waiting = true,
    [wait_key] = true,
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

local function _resolve_wait_move_anim(game, next_state, next_args, has_anim, has_hold_or_pending)
  if next_state == "move_followup" then game.turn.move_followup_pending = true end
  local move_anim_args = { next_state = next_state, next_args = next_args }
  local function _resume() return "wait_move_anim", move_anim_args end
  if has_anim then
    if has_hold_or_pending then
      return _register_landing_visual_resume(game, "wait_action_anim", {
        next_state = "wait_move_anim",
        next_args = move_anim_args,
      }, function()
        return _register_action_anim_resume(game, "wait_move_anim", move_anim_args, _resume)
      end)
    end
    return _register_action_anim_resume(game, "wait_move_anim", move_anim_args, _resume)
  end
  if has_hold_or_pending then return _register_landing_visual_resume(game, "wait_move_anim", move_anim_args, _resume) end
  return "wait_move_anim", move_anim_args
end

local function _resolve_wait_action_anim_state(game, next_state, next_args, has_anim, has_hold_or_pending)
  if has_anim then
    if has_hold_or_pending then
      return _register_landing_visual_resume(game, "wait_action_anim", {
        next_state = next_state,
        next_args = next_args,
      }, function()
        return _register_action_anim_resume(game, next_state, next_args, function() return next_state, next_args end)
      end)
    end
    return _register_action_anim_resume(game, next_state, next_args, function() return next_state, next_args end)
  end
  if has_hold_or_pending then
    return _register_landing_visual_resume(game, next_state, next_args, function() return next_state, next_args end)
  end
  return next_state, next_args
end

local function _route_choice_wait_state(game, has_anim, has_hold_or_pending, next_state, next_args)
  if has_anim then
    if has_hold_or_pending then return _wait_for_choice_via_landing_visual_then_action_anim(game, next_state, next_args) end
    return _wait_for_choice_via_action_anim(game, next_state, next_args)
  end
  if has_hold_or_pending then return _wait_for_choice_via_landing_visual(game, next_state, next_args) end
  return "wait_choice", { next_state = next_state, next_args = next_args }
end

local function _resolve_wait_state(game, next_state, next_args, wait_action_anim, wait_move_anim)
  local has_anim = _has_action_anim(game)
  local has_hold_or_pending = _is_landing_visual_hold_active(game) or not _is_effect_idle()
  if wait_move_anim == true then
    return _resolve_wait_move_anim(game, next_state, next_args, has_anim, has_hold_or_pending)
  end
  if wait_action_anim == true then
    return _resolve_wait_action_anim_state(game, next_state, next_args, has_anim, has_hold_or_pending)
  end
  return _route_choice_wait_state(game, has_anim, has_hold_or_pending, next_state, next_args)
end

local function _resolve_finished_landing_state(game, player)
  local function _resume_post_action()
    return "post_action", { player = player }
  end

  local has_anim = _has_action_anim(game)
  local has_hold = _is_landing_visual_hold_active(game)
  local effects_pending = not _is_effect_idle()

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
    return _build_move_followup_result(target_player, out, "wait_move_anim")
  end
  if _has_pending_relocation_action_anim(game) then
    return _build_move_followup_result(target_player, out, "wait_action_anim")
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
    optional_cost_resolver = _landing_optional_cost,
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
  run = _phase_land,
  _resolve_wait_state = _resolve_wait_state,
  resolve_wait_state = _resolve_wait_state,
}
