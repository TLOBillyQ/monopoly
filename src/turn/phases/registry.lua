local item_phase = require("src.rules.items.phase")
local item_auto_play_context = require("src.turn.policies.item_play_context")
local dirty_tracker = require("src.state.dirty_tracker")
local landing_visual_hold = require("src.state.visual_hold")
local turn_start = require("src.turn.phases.start")
local turn_roll = require("src.turn.phases.roll")
local turn_pre_move = require("src.turn.phases.pre_move")
local turn_move = require("src.turn.phases.move")
local turn_land = require("src.turn.phases.land")
local move_followup = require("src.turn.phases.move_followup")
local timing = require("src.config.gameplay.timing")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")

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
  landing_visual_hold.clear_game(game)
  event_feed.publish(game, {
    kind = event_kinds.turn_end,
    text = "回合结束：" .. tostring(player.name) .. " 停在 " .. _resolve_tile_name(game, player),
    tip = false,
  })
  turn_mgr.game:tick_player_deity(player)
  turn_mgr.game:clear_player_temporal_flags(player)
  turn_mgr.game:stop_all_players_movement()
  game.turn.market_prompt = nil
  game.turn.post_action = nil
  game.turn.item_phase = {}
  game.turn.used_effect_groups = {}
  game.turn.item_phase_active = ""
  local inter_turn_wait_seconds = timing.inter_turn_wait_seconds or 1.0
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
    roll = turn_roll._phase_roll_with_pre_move,
    pre_move = turn_pre_move,
    move = turn_move,
    move_followup = move_followup.run,
    landing = turn_land.run,
    post_action = _phase_post,
    end_turn = _phase_end,
  }
end

return turn_phase_registry

--[[ mutate4lua-manifest
version=2
projectHash=7d9a1dd25a16d057
scope.0.id=chunk:src/turn/phases/registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=94
scope.0.semanticHash=ca34e45cba5321a1
scope.1.id=function:_resolve_tile_name:17
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=26
scope.1.semanticHash=f7ff6fe8266e4975
scope.2.id=function:_resolve_post_phase_wait:28
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=35
scope.2.semanticHash=87ff5ca09df68098
scope.3.id=function:_phase_post:37
scope.3.kind=function
scope.3.startLine=37
scope.3.endLine=49
scope.3.semanticHash=7ebf595fd380f2f2
scope.4.id=function:_phase_end:51
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=78
scope.4.semanticHash=2f1eb0ebb89a2492
scope.5.id=function:turn_phase_registry.build_default_phases:80
scope.5.kind=function
scope.5.startLine=80
scope.5.endLine=91
scope.5.semanticHash=568970ff52781e71
]]
