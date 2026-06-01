local items_cfg = require("src.config.content.items")
local debug_flags = require("src.config.gameplay.debug_flags")
local timing = require("src.config.gameplay.timing")
local logger = require("src.foundation.log")
local auto_play_port = require("src.rules.ports.auto_play")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local gameplay_loop_ports = require("src.turn.loop.ports")
local gameplay_loop_runtime = require("src.turn.loop.runtime")
local intent_dispatcher = require("src.turn.output.intent_dispatcher")
local event_feed_adapter = require("src.turn.output.event_feed_adapter")
local auto_context = require("src.turn.policies.auto_context")
local tick_flow = require("src.turn.loop.tick_flow")
local paid_currency_bridge = require("src.rules.commerce.paid_currency_bridge")
local market_purchase = require("src.rules.market.purchase")
local runtime_state = require("src.state.runtime")
local landing_visual_hold = require("src.state.visual_hold")
local wait_callbacks = require("src.turn.waits.callback_registry")
local gameplay_loop = {}

local function _noop()
  return nil
end

local _default_is_auto_player = function(_, player)
  return player and (player.auto == true or player.is_ai == true or player.ai == true) or false
end

local _auto_play_defaults = {
  is_auto_player = _default_is_auto_player,
  choose_action = _noop,
  auto_action_for_choice = _noop,
  pick_target_player = _noop,
  pick_remote_dice_value = _noop,
  pick_roadblock_target = _noop,
}

local _bankruptcy_defaults = {
  eliminate = _noop,
}

local function _fill_defaults(port, defaults)
  for name, fallback in pairs(defaults) do
    if type(port[name]) ~= "function" then
      port[name] = fallback
    end
  end
end

local function _ensure_fallback_ports(game)
  if type(game.auto_play_port) ~= "table" then
    game.auto_play_port = {}
  end
  _fill_defaults(game.auto_play_port, _auto_play_defaults)
  if type(game.bankruptcy_port) ~= "table" then
    game.bankruptcy_port = {}
  end
  _fill_defaults(game.bankruptcy_port, _bankruptcy_defaults)
end

local function _ensure_runtime_ports(game)
  if not game then
    return
  end
  if type(game.intent_output_port) ~= "table" then
    game.intent_output_port = intent_dispatcher.build_port()
  end
  _ensure_fallback_ports(game)
end

local function _resolve_ports(state)
  if not state then
    return gameplay_loop_ports.resolve(nil)
  end
  local override = state.gameplay_loop_ports
  if state._resolved_gameplay_loop_ports and state._resolved_gameplay_loop_ports_source == override then
    return state._resolved_gameplay_loop_ports
  end
  local resolved = gameplay_loop_ports.resolve(override)
  state._resolved_gameplay_loop_ports = resolved
  state._resolved_gameplay_loop_ports_source = override
  state.gameplay_loop_ports = resolved
  return resolved
end
local _dispatch_opts = { on_close_choice = nil }
local _cached_modal_ports_ref = nil
local function _dispatch_action_with_close_choice(game, state, action, ports)
  local modal_ports = ports.modal
  if _cached_modal_ports_ref ~= modal_ports then
    _cached_modal_ports_ref = modal_ports
    _dispatch_opts.on_close_choice = function(ctx)
      modal_ports.close_choice_modal(ctx)
    end
  end
  turn_dispatch.dispatch_action(game, state, action, _dispatch_opts)
end
local function _build_item_index(state)
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.item_name_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    ui_runtime.item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
  end
end
local function _is_auto_popup_owner(game, state)
  local ports = _resolve_ports(state)
  local ui_sync_ports = ports.ui_sync
  if not (game and state and ui_sync_ports and ui_sync_ports.get_popup_owner_index) then
    return false
  end
  local idx = ui_sync_ports.get_popup_owner_index(state)
  if not idx or not game.players then
    return false
  end
  local actor = game.players[idx]
  return actor and auto_play_port.is_auto_player(game, actor) or false
end

local function _is_auto_popup_waiting(game, state, ui_sync_ports)
  local min_popup_visible = timing.auto_decision_delay_seconds or 0
  if min_popup_visible <= 0 then
    return false
  end
  if not (ui_sync_ports.is_popup_active and ui_sync_ports.is_popup_active(state)) then
    return false
  end
  if not _is_auto_popup_owner(game, state) then
    return false
  end
  local elapsed = runtime_state.get_modal_elapsed(state)
  return elapsed < min_popup_visible
end

local function _fill_auto_action_actor(auto_action, current_player_id)
  if auto_action and auto_action.type == "ui_button" and not auto_action.actor_role_id then
    auto_action.actor_role_id = current_player_id
  end
end

local function _log_missing_auto_choice_action(state, ctx)
  if not (ctx.pending_choice and ctx.current_player_auto == true) then
    return
  end
  if state.auto_runner.waiting_for_interval == true then
    return
  end
  runtime_state.log_once(
    state,
    "warn",
    "auto_runner_choice_no_action_" .. tostring(ctx.pending_choice.id),
    "[Eggy]",
    "auto runner produced no action for runtime pending choice",
    "choice_id=" .. tostring(ctx.pending_choice.id),
    "kind=" .. tostring(ctx.pending_choice.kind),
    "actor_role_id=" .. tostring(ctx.current_player_id)
  )
end
local function _initialize_ports(state, game)
  local ports = _resolve_ports(state)
  state.game = game
  game.state = game.state or {}
  state.gameplay_loop_ports = ports
  game.board_scene_port = gameplay_loop_runtime.build_board_scene_port(state)
  game.popup_port = gameplay_loop_runtime.build_popup_port(state)
  game.tip_output_port = gameplay_loop_runtime.build_tip_output_port(state)
  game.event_feed_port = event_feed_adapter.new(game)
  game.board_visual_feedback_port = gameplay_loop_runtime.build_board_visual_feedback_port(state)
  game.tile_feedback_port = gameplay_loop_runtime.build_tile_feedback_port(state)
  game.bankruptcy_feedback_port = {
    on_tiles_cleared = function(arg1, arg2, arg3, arg4)
      local game_ctx
      local owned_tile_ids
      if arg4 ~= nil then
        game_ctx = arg2
        owned_tile_ids = arg4
      else
        game_ctx = arg1
        owned_tile_ids = arg3
      end
      return game.board_visual_feedback_port.sync_many(game_ctx, {
        tile_ids = owned_tile_ids,
      })
    end,
  }
  game.anim_gate_port = gameplay_loop_runtime.build_anim_gate_port(state)
  game.intent_output_port = intent_dispatcher.build_port()
  _ensure_fallback_ports(game)
  return ports
end
local function _configure_tile_owner_notifier(game)
  game.tile_owner_notifier = {
    notify_owner_changed = function(_, tile_id)
      return game.board_visual_feedback_port.sync_many(game, {
        tile_ids = { tile_id },
      })
    end,
  }
end
local function _configure_environment(state, game, ports)
  local anim_ports = ports.anim
  local state_ports = ports.state
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  state_ports.apply_role_control_lock(state, false)
  turn_runtime.role_control_lock_active = false
  turn_runtime.role_control_lock_suppress = 0
  anim_ports.reset_status_3d(state)
  _configure_tile_owner_notifier(game)
  paid_currency_bridge.setup_for_game(game)
  market_purchase.setup_for_game(game)
  state_ports.install_event_handlers(game, logger, state)
  logger.set_info_per_turn_limit(debug_flags.info_log_per_turn_limit)
  logger.set_info_turn_provider(function() return game.turn and game.turn.turn_count end)
end
local function _configure_pending_choice(state, game, ports)
  local output_ports = ports.output
  local ui_sync_ports = ports.ui_sync
  local modal_ports = ports.modal
  assert(game.pending_choice ~= nil, "missing game.pending_choice")
  local pending = game:pending_choice()
  output_ports.sync_pending_choice(state, pending)
  if pending then
    local model = ui_sync_ports.build_model(state, game)
    output_ports.sync_ui_model(state, model)
    if model.choice then
      modal_ports.open_choice_modal(state, model.choice, model.market)
    end
  end
end
local function _reset_runtime_state(state, ports)
  local ui_sync_ports = ports.ui_sync
  state.player_units = nil
  state.player_units_missing = false
  ports.output.invalidate_ui_model(state)
  state.countdown_last = nil
  state.countdown_active_last = nil
  if ui_sync_ports.set_input_blocked then
    ui_sync_ports.set_input_blocked(state, false)
  end
  if state.auto_runner then
    state.auto_runner:set_enabled(true)
    state.auto_runner:reset_timer()
  end
end
function gameplay_loop.set_game(state, game)
  assert(game ~= nil, "missing game")
  runtime_state.ensure_all(state)
  landing_visual_hold.reset_state(state)
  wait_callbacks.reset_runtime(game)
  game.landing_visual_hold_state = state
  local ports = _initialize_ports(state, game)
  _configure_environment(state, game, ports)
  _configure_pending_choice(state, game, ports)
  _reset_runtime_state(state, ports)
end
function gameplay_loop.new_game(state)
  logger.clear()
  assert(state.game_factory, "game_factory not set")
  local game = state.game_factory()
  _build_item_index(state)
  local auto_runner = assert(state.auto_runner, "missing auto_runner")
  assert(auto_runner.reset_timer ~= nil, "missing auto_runner.ResetTimer")
  if auto_runner.set_enabled then
    auto_runner:set_enabled(true)
  end
  auto_runner:reset_timer()
  game.logger.info("启动蛋仔大富翁，玩家数:", #game.players)
  return game
end

function gameplay_loop.step_auto_runner(game, state, dt, context)
  assert(game ~= nil, "missing game")
  assert(state.auto_runner ~= nil, "missing auto_runner")
  local ports = _resolve_ports(state)
  local ui_sync_ports = ports.ui_sync
  if ui_sync_ports.is_input_blocked and ui_sync_ports.is_input_blocked(state) then
    return nil
  end
  if _is_auto_popup_waiting(game, state, ui_sync_ports) then
    return nil
  end
  local ctx = auto_context.build(game, context)
  local auto_action = state.auto_runner:next_action(dt, ctx)
  _fill_auto_action_actor(auto_action, ctx.current_player_id)
  if auto_action == nil then
    _log_missing_auto_choice_action(state, ctx)
  end
  if auto_action then
    _dispatch_action_with_close_choice(game, state, auto_action, ports)
  end
  return auto_action
end
local _tick_deps = {
  step_auto_runner = nil,
  dispatch_action_with_close_choice = _dispatch_action_with_close_choice,
}
function gameplay_loop.tick(game, state, dt)
  if not game then
    return
  end
  _ensure_runtime_ports(game)
  local ports = _resolve_ports(state)
  _tick_deps.step_auto_runner = gameplay_loop.step_auto_runner
  tick_flow.tick(game, state, dt, ports, _tick_deps)
end
gameplay_loop._log_missing_auto_choice_action = _log_missing_auto_choice_action
gameplay_loop._M_test = {
  ensure_fallback_ports = _ensure_fallback_ports,
}
return gameplay_loop

--[[ mutate4lua-manifest
version=2
projectHash=fd495466f7f5ac17
scope.0.id=chunk:src/turn/loop/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=308
scope.0.semanticHash=3afb17cee149fe0a
scope.0.lastMutatedAt=2026-06-01T07:44:11Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=25
scope.0.lastMutationKilled=23
scope.1.id=function:_noop:20
scope.1.kind=function
scope.1.startLine=20
scope.1.endLine=22
scope.1.semanticHash=0f1269e6a0ba4a61
scope.2.id=function:anonymous@24:24
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=26
scope.2.semanticHash=8010f4ec39a85407
scope.2.lastMutatedAt=2026-06-01T07:44:11Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=11
scope.2.lastMutationKilled=11
scope.3.id=function:_ensure_fallback_ports:49
scope.3.kind=function
scope.3.startLine=49
scope.3.endLine=58
scope.3.semanticHash=163135b7d4d61d96
scope.3.lastMutatedAt=2026-06-01T07:44:11Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=8
scope.3.lastMutationKilled=8
scope.4.id=function:_ensure_runtime_ports:60
scope.4.kind=function
scope.4.startLine=60
scope.4.endLine=68
scope.4.semanticHash=63d3e6e642bc6827
scope.4.lastMutatedAt=2026-06-01T07:44:11Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=6
scope.4.lastMutationKilled=6
scope.5.id=function:_resolve_ports:70
scope.5.kind=function
scope.5.startLine=70
scope.5.endLine=83
scope.5.semanticHash=b6e78a0705679ec8
scope.5.lastMutatedAt=2026-06-01T07:44:11Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=survived
scope.5.lastMutationSites=5
scope.5.lastMutationKilled=3
scope.6.id=function:anonymous@90:90
scope.6.kind=function
scope.6.startLine=90
scope.6.endLine=92
scope.6.semanticHash=66532c346ee9305e
scope.6.lastMutatedAt=2026-06-01T07:44:11Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:_dispatch_action_with_close_choice:86
scope.7.kind=function
scope.7.startLine=86
scope.7.endLine=95
scope.7.semanticHash=4a80ad8159ddd81b
scope.7.lastMutatedAt=2026-06-01T07:44:11Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=2
scope.7.lastMutationKilled=2
scope.8.id=function:_is_auto_popup_owner:103
scope.8.kind=function
scope.8.startLine=103
scope.8.endLine=115
scope.8.semanticHash=c6b167e121bab56f
scope.8.lastMutatedAt=2026-06-01T07:44:11Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=survived
scope.8.lastMutationSites=15
scope.8.lastMutationKilled=10
scope.9.id=function:_is_auto_popup_waiting:117
scope.9.kind=function
scope.9.startLine=117
scope.9.endLine=130
scope.9.semanticHash=76cc75eb81c74900
scope.9.lastMutatedAt=2026-06-01T07:44:11Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=survived
scope.9.lastMutationSites=14
scope.9.lastMutationKilled=13
scope.10.id=function:_fill_auto_action_actor:132
scope.10.kind=function
scope.10.startLine=132
scope.10.endLine=136
scope.10.semanticHash=9098f506fee5c9b2
scope.10.lastMutatedAt=2026-06-01T07:44:11Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=5
scope.10.lastMutationKilled=5
scope.11.id=function:_log_missing_auto_choice_action:138
scope.11.kind=function
scope.11.startLine=138
scope.11.endLine=155
scope.11.semanticHash=9b72e0b3eca8d6a8
scope.11.lastMutatedAt=2026-06-01T07:44:11Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=7
scope.11.lastMutationKilled=7
scope.12.id=function:anonymous@168:168
scope.12.kind=function
scope.12.startLine=168
scope.12.endLine=181
scope.12.semanticHash=5b8318e21437ce40
scope.12.lastMutatedAt=2026-06-01T07:44:11Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=2
scope.12.lastMutationKilled=2
scope.13.id=function:_initialize_ports:156
scope.13.kind=function
scope.13.startLine=156
scope.13.endLine=187
scope.13.semanticHash=0839b144092ac288
scope.13.lastMutatedAt=2026-06-01T07:44:11Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=11
scope.13.lastMutationKilled=11
scope.14.id=function:anonymous@190:190
scope.14.kind=function
scope.14.startLine=190
scope.14.endLine=194
scope.14.semanticHash=aef22eb086c6f52f
scope.14.lastMutatedAt=2026-06-01T07:44:11Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=1
scope.14.lastMutationKilled=1
scope.15.id=function:_configure_tile_owner_notifier:188
scope.15.kind=function
scope.15.startLine=188
scope.15.endLine=196
scope.15.semanticHash=ee4bbde5d5623da5
scope.15.lastMutatedAt=2026-06-01T07:39:36Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=no_sites
scope.15.lastMutationSites=0
scope.15.lastMutationKilled=0
scope.16.id=function:anonymous@210:210
scope.16.kind=function
scope.16.startLine=210
scope.16.endLine=210
scope.16.semanticHash=caa9b72256d4d9cf
scope.16.lastMutatedAt=2026-06-01T07:39:36Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=no_sites
scope.16.lastMutationSites=0
scope.16.lastMutationKilled=0
scope.17.id=function:_configure_environment:197
scope.17.kind=function
scope.17.startLine=197
scope.17.endLine=211
scope.17.semanticHash=261ceba6e86d2754
scope.17.lastMutatedAt=2026-06-01T07:44:11Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=11
scope.17.lastMutationKilled=11
scope.18.id=function:_configure_pending_choice:212
scope.18.kind=function
scope.18.startLine=212
scope.18.endLine=226
scope.18.semanticHash=7adc53ecbbfbf6d3
scope.18.lastMutatedAt=2026-06-01T07:44:11Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=survived
scope.18.lastMutationSites=6
scope.18.lastMutationKilled=4
scope.19.id=function:_reset_runtime_state:227
scope.19.kind=function
scope.19.startLine=227
scope.19.endLine=241
scope.19.semanticHash=6c1513da5d1a28be
scope.19.lastMutatedAt=2026-06-01T07:44:11Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=5
scope.19.lastMutationKilled=5
scope.20.id=function:gameplay_loop.set_game:242
scope.20.kind=function
scope.20.startLine=242
scope.20.endLine=252
scope.20.semanticHash=319b3afe0258c7cc
scope.20.lastMutatedAt=2026-06-01T07:44:11Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=8
scope.20.lastMutationKilled=8
scope.21.id=function:gameplay_loop.new_game:253
scope.21.kind=function
scope.21.startLine=253
scope.21.endLine=266
scope.21.semanticHash=3526430dd43ec442
scope.21.lastMutatedAt=2026-06-01T07:44:11Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=9
scope.21.lastMutationKilled=9
scope.22.id=function:gameplay_loop.step_auto_runner:268
scope.22.kind=function
scope.22.startLine=268
scope.22.endLine=289
scope.22.semanticHash=42566b1224cec07d
scope.22.lastMutatedAt=2026-06-01T07:44:11Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=survived
scope.22.lastMutationSites=12
scope.22.lastMutationKilled=11
scope.23.id=function:gameplay_loop.tick:294
scope.23.kind=function
scope.23.startLine=294
scope.23.endLine=302
scope.23.semanticHash=127672b713270019
scope.23.lastMutatedAt=2026-06-01T07:44:11Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=4
scope.23.lastMutationKilled=4
]]
