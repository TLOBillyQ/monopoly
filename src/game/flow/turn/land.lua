local landing_defs = require("src.game.systems.land.specs.effects")
local effect_pipeline = require("src.game.systems.effects.effect_pipeline")
local effect_runner = require("src.game.systems.effects.effect_runner")

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

local function _resolve_landing(game, player, tile, move_result, depth)
  depth = depth or 0
  local game_ctx = effect_runner.build_game_ctx(game, move_result, {
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
      if _has_pending_move_action_anim(game) then
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
      return _resolve_landing(game, target_player, next_tile, out.move_result, depth + 1)
    end
    return out
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
    local next_state = res.next_state or "landing"
    local next_args = res.next_args or { player = player, move_result = move_result }
    if res.wait_action_anim == true then
      if _has_action_anim(turn_mgr.game) then
        turn_mgr.game.turn.move_followup_pending = next_state == "move_followup"
        return "wait_action_anim", {
          next_state = next_state,
          next_args = next_args,
        }
      end
      return next_state, next_args
    end
    if _has_action_anim(turn_mgr.game) then
      return "wait_action_anim", {
        next_state = "wait_choice",
        next_args = { next_state = next_state, next_args = next_args },
      }
    end
    return "wait_choice", { next_state = next_state, next_args = next_args }
  end

  if _has_action_anim(turn_mgr.game) then
    return "wait_action_anim", {
      next_state = "post_action",
      next_args = { player = player },
    }
  end

  return "post_action", { player = player }
end

return _phase_land
