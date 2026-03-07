local item_phase = require("src.game.systems.items.ItemPhase")
local item_auto_play_context = require("src.game.flow.turn.ItemAutoPlayContext")
local dirty_tracker = require("src.core.DirtyTracker")
local logger = require("src.core.Logger")
local turn_start = require("src.game.flow.turn.TurnStart")
local turn_roll = require("src.game.flow.turn.TurnRoll")
local turn_move = require("src.game.flow.turn.TurnMove")
local turn_land = require("src.game.flow.turn.TurnLand")

local phase_registry = {}

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

local function _phase_post(turn_mgr, args)
  local player = args.player or turn_mgr.game:current_player()
  local phase_res = item_phase.run(turn_mgr, "post_action", {
    player = player,
    auto_play = item_auto_play_context.build(turn_mgr.game, player),
    next_state = "post_action",
    next_args = { player = player },
  })
  if phase_res and phase_res.waiting then
    local next_state = phase_res.next_state or "post_action"
    local next_args = phase_res.next_args or { player = player }
    if phase_res.wait_action_anim then
      return "wait_action_anim", { next_state = next_state, next_args = next_args }
    end
    return "wait_choice", { next_state = next_state, next_args = next_args }
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
