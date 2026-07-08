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

local phase_wait = require("src.turn.phases.phase_wait")

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
  return phase_wait.resolve_result(phase_res, "post_action", player)
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
projectHash=513dd026d9c9e739
scope.0.id=chunk:src/turn/phases/registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=91
scope.0.semanticHash=641e37a87607ac9c
scope.1.id=function:_resolve_tile_name:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=28
scope.1.semanticHash=f7ff6fe8266e4975
scope.2.id=function:_resolve_post_phase_wait:30
scope.2.kind=function
scope.2.startLine=30
scope.2.endLine=32
scope.2.semanticHash=d99751109d3bb3e6
scope.3.id=function:_phase_post:34
scope.3.kind=function
scope.3.startLine=34
scope.3.endLine=46
scope.3.semanticHash=7ebf595fd380f2f2
scope.4.id=function:_phase_end:48
scope.4.kind=function
scope.4.startLine=48
scope.4.endLine=75
scope.4.semanticHash=2f1eb0ebb89a2492
scope.5.id=function:turn_phase_registry.build_default_phases:77
scope.5.kind=function
scope.5.startLine=77
scope.5.endLine=88
scope.5.semanticHash=568970ff52781e71
]]
