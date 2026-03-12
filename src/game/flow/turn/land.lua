local landing_defs = require("src.game.systems.land.specs.effects")
local effect_pipeline = require("src.game.systems.effects.effect_pipeline")
local effect_runner = require("src.game.systems.effects.effect_runner")
local landing_visual_hold = require("src.core.state_access.landing_visual_hold")

local max_landing_depth = 10
local _resolve_landing

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

local function _has_pending_move_action_anim(game)
  if not game or not game.turn then
    return false
  end
  local current = game.turn.action_anim
  if current and current.kind == "move_effect" then
    return true
  end
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" then
    return false
  end
  for _, entry in ipairs(queue) do
    if entry and entry.kind == "move_effect" then
      return true
    end
  end
  return false
end

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

local function _resolve_wait_state(game, next_state, next_args, wait_action_anim)
  if wait_action_anim == true then
    if _has_action_anim(game) then
      game.turn.move_followup_pending = next_state == "move_followup"
      return "wait_action_anim", {
        next_state = next_state,
        next_args = next_args,
      }
    end
    return next_state, next_args
  end
  if _has_action_anim(game) then
    return "wait_action_anim", {
      next_state = "wait_choice",
      next_args = { next_state = next_state, next_args = next_args },
    }
  end
  if landing_visual_hold.is_active_game(game) then
    return "wait_landing_visual", {
      next_state = "wait_choice",
      next_args = { next_state = next_state, next_args = next_args },
    }
  end
  return "wait_choice", { next_state = next_state, next_args = next_args }
end

local function _resolve_finished_landing_state(game, player)
  if _has_action_anim(game) then
    local next_args = {
      next_state = "post_action",
      next_args = { player = player },
    }
    if landing_visual_hold.is_active_game(game) then
      return "wait_landing_visual", {
        next_state = "wait_action_anim",
        next_args = next_args,
      }
    end
    return "wait_action_anim", next_args
  end
  if landing_visual_hold.is_active_game(game) then
    return "wait_landing_visual", {
      next_state = "post_action",
      next_args = { player = player },
    }
  end
  return "post_action", { player = player }
end

local function _resolve_landing_wait_args(res, player, move_result)
  return res.next_state or "landing", res.next_args or { player = player, move_result = move_result }
end

local function _resolve_waiting_landing_result(game, res, player, move_result)
  local next_state, next_args = _resolve_landing_wait_args(res, player, move_result)
  return _resolve_wait_state(game, next_state, next_args, res.wait_action_anim)
end

local function _resolve_followup_landing(game, player, out, depth)
  local target_player = _resolve_target_player(game, player, out)
  local next_tile = _resolve_next_tile(game, target_player, out)
  if not next_tile then
    return out
  end
  if _has_pending_move_action_anim(game) then
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
  local tile = turn_mgr.game.board:get_tile(player.position)

  local res = _resolve_landing(turn_mgr.game, player, tile, move_result)
  if res and res.waiting then
    return _resolve_waiting_landing_result(turn_mgr.game, res, player, move_result)
  end
  return _resolve_finished_landing_state(turn_mgr.game, player)
end

local _land = {
  _resolve_wait_state = _resolve_wait_state,
  _phase_land = _phase_land,
}

-- Make the table callable for backward compatibility
setmetatable(_land, {
  __call = function(_, turn_mgr, args)
    return _phase_land(turn_mgr, args)
  end,
})

return _land
