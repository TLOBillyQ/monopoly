local item_phase = require("src.game.systems.items.ItemPhase")
local dirty_tracker = require("src.core.DirtyTracker")
local turn_start = require("src.game.flow.turn.TurnStart")
local turn_roll = require("src.game.flow.turn.TurnRoll")
local turn_move = require("src.game.flow.turn.TurnMove")
local turn_land = require("src.game.flow.turn.TurnLand")

local phase_registry = {}

local function _phase_post(turn_mgr, args)
  local player = args.player or turn_mgr.game:current_player()
  local phase_res = item_phase.run(turn_mgr, "post_action", {
    player = player,
    resume_state = "post_action",
    resume_args = { player = player },
  })
  if phase_res and phase_res.waiting then
    local resume_state = phase_res.resume_state or "post_action"
    local resume_args = phase_res.resume_args or { player = player }
    if phase_res.wait_action_anim then
      return "wait_action_anim", { resume_state = resume_state, resume_args = resume_args }
    end
    return "wait_choice", { resume_state = resume_state, resume_args = resume_args }
  end
  return "end_turn", { player = player }
end

local function _phase_end(turn_mgr, args)
  local player = args.player
  turn_mgr.game:tick_player_deity(player)
  turn_mgr.game:clear_player_temporal_flags(player)
  turn_mgr.game:stop_all_players_movement()
  local game = turn_mgr.game
  game.turn.market_prompt = nil
  game.turn.post_action = nil
  game.turn.item_phase = {}
  game.turn.item_phase_active = ""
  dirty_tracker.mark(game.dirty, "turn")
  turn_mgr:next_player()
  return nil
end

function phase_registry.build_default_phases()
  return {
    start = turn_start,
    roll = turn_roll,
    move = turn_move,
    landing = turn_land,
    post_action = _phase_post,
    end_turn = _phase_end,
  }
end

return phase_registry
