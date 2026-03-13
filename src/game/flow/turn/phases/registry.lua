local item_phase = require("src.game.systems.items.phase")
local item_auto_play_context = require("src.game.flow.turn.item_auto_play_context")
local dirty_tracker = require("src.core.utils.dirty_tracker")
local logger = require("src.core.utils.logger")
local turn_start = require("src.game.flow.turn.start")
local turn_roll = require("src.game.flow.turn.roll")
local turn_move = require("src.game.flow.turn.move")
local turn_land = require("src.game.flow.turn.land")
local move_followup = require("src.game.flow.turn.move_followup")
local gameplay_rules = require("src.core.config.gameplay_rules")

local turn_phase_registry = {}

local function _resolve_tile_name(game, player)
  if not (game and game.board and player and player.position) then
    return "未知地块"
  end
  local tile = game.board:get_tile(player.position)
  if not tile or not tile.name then
    return "未知地块"
  end
  return tile.name
end

local function _resolve_post_phase_wait(player, phase_res)
  local next_state = phase_res.next_state or "post_action"
  local next_args = phase_res.next_args or { player = player }
  if phase_res.wait_action_anim then
    return "wait_action_anim", { next_state = next_state, next_args = next_args }
  end
  return "wait_choice", { next_state = next_state, next_args = next_args }
end

local function _phase_post(turn_mgr, args)
  local player = args.player or turn_mgr.game:current_player()
  local phase_res = item_phase.run(turn_mgr, "post_action", {
    player = player,
    auto_play = item_auto_play_context.build(turn_mgr.game, player),
    next_state = "post_action",
    next_args = { player = player },
  })
  if phase_res and phase_res.waiting then
    return _resolve_post_phase_wait(player, phase_res)
  end
  return "end_turn", { player = player }
end

local function _phase_end(turn_mgr, args)
  local player = args.player
  local game = turn_mgr.game
  logger.event_no_tips("回合结束：" .. tostring(player.name) .. " 停在 " .. _resolve_tile_name(game, player))
  turn_mgr.game:tick_player_deity(player)
  turn_mgr.game:clear_player_temporal_flags(player)
  turn_mgr.game:stop_all_players_movement()
  game.turn.market_prompt = nil
  game.turn.post_action = nil
  game.turn.item_phase = {}
  game.turn.item_phase_active = ""
  local inter_turn_wait_seconds = gameplay_rules.inter_turn_wait_seconds or 1.0
  if inter_turn_wait_seconds <= 0 then
    turn_mgr:next_player()
    return nil
  end
  game.turn.inter_turn_wait_active = true
  game.turn.inter_turn_wait_elapsed = 0
  game.turn.inter_turn_wait_seconds = inter_turn_wait_seconds
  dirty_tracker.mark(game.dirty, "turn")
  return "inter_turn_wait", {}
end

function turn_phase_registry.build_default_phases()
  return {
    start = turn_start,
    roll = turn_roll._phase_roll,
    move = turn_move,
    move_followup = move_followup.run,
    landing = turn_land,
    post_action = _phase_post,
    end_turn = _phase_end,
  }
end

return turn_phase_registry
