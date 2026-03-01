local agent = require("src.game.core.runtime.Agent")
local items_cfg = require("Config.Generated.Items")
local gameplay_rules = require("Config.GameplayRules")
local logger = require("src.core.Logger")
local turn_dispatch = require("src.game.flow.turn.TurnDispatch")
local turn_anim = require("src.game.flow.turn.TurnAnim")
local gameplay_loop_ports = require("src.game.flow.turn.GameplayLoopPorts")
local gameplay_loop_runtime = require("src.game.flow.turn.GameplayLoopRuntime")
local auto_context = require("src.game.flow.turn.AutoContext")
local paid_currency_bridge = require("src.game.systems.commerce.PaidCurrencyBridge")

local gameplay_loop = {}

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

local function _dispatch_action_with_close_choice(game, state, action, ports)
  local modal_ports = ports.modal
  turn_dispatch.dispatch_action(game, state, action, {
    on_close_choice = function(ctx)
      modal_ports.close_choice_modal(ctx)
    end,
  })
end

local function _build_item_index(state)
  state.item_name_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    state.item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
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
  return actor and agent.is_auto_player(actor) or false
end

local function _step_phase_animation(game, state, phase, ports)
  local anim_ports = ports.anim
  if phase == "wait_move_anim" then
    local anim_data = game.turn.move_anim
    if not anim_data then
      return
    end
    turn_anim.step_move_anim(game, state, {
      on_move_anim = function(_, anim_ctx)
        return anim_ports.play_move_anim(state, anim_ctx)
      end,
    })
    return
  end
  if phase == "wait_action_anim" then
    local anim_data = game.turn.action_anim
    if not anim_data then
      return
    end
    turn_anim.step_action_anim(game, state, {
      on_action_anim = function(ctx, anim_ctx)
        return anim_ports.play_action_anim(ctx, anim_ctx)
      end,
    })
  end
end

local function _initialize_ports(state, game)
  local ports = _resolve_ports(state)
  state.game = game
  state.gameplay_loop_ports = ports
  game.ui_port = gameplay_loop_runtime.build_ui_runtime_port(state)
  game.gameplay_loop_ports = ports
  return ports
end

local function _configure_tile_owner_notifier(state, game)
  if type(state.on_tile_owner_changed) == "function" then
    game.tile_owner_notifier = {
      notify_owner_changed = function(_, tile_id, owner_id)
        state:on_tile_owner_changed(tile_id, owner_id)
      end,
    }
    return
  end
  if type(state.notify_owner_changed) == "function" then
    game.tile_owner_notifier = {
      notify_owner_changed = function(_, tile_id, owner_id)
        state:notify_owner_changed(tile_id, owner_id)
      end,
    }
  end
end

local function _configure_environment(state, game, ports)
  local anim_ports = ports.anim
  local state_ports = ports.state
  state_ports.apply_role_control_lock(state, false)
  state.role_control_lock_active = false
  state.role_control_lock_suppress = 0
  anim_ports.reset_status_3d(state)
  _configure_tile_owner_notifier(state, game)
  paid_currency_bridge.setup_for_game(game)
  state_ports.install_event_handlers(game, logger, state)
  logger.set_info_per_turn_limit(gameplay_rules.info_log_per_turn_limit)
  logger.set_info_turn_provider(function()
    return game.turn and game.turn.turn_count
  end)
end

local function _configure_pending_choice(state, game, ports)
  local ui_sync_ports = ports.ui_sync
  local modal_ports = ports.modal
  assert(game.pending_choice ~= nil, "missing game.pending_choice")
  local pending = game:pending_choice()
  state.pending_choice = pending
  if pending then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = pending.id
    local model = ui_sync_ports.build_model(state, game)
    state.ui_model = model
    if model.choice then
      modal_ports.open_choice_modal(state, model.choice, model.market)
    end
  end
end

local function _reset_runtime_state(state, ports)
  local ui_sync_ports = ports.ui_sync
  state.player_units = nil
  state.player_units_missing = false
  state.ui_dirty = true
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
  assert(state.auto_runner ~= nil, "missing auto_runner")
  assert(state.auto_runner.reset_timer ~= nil, "missing auto_runner.ResetTimer")
  if state.auto_runner.set_enabled then
    state.auto_runner:set_enabled(true)
  end
  state.auto_runner:reset_timer()
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
  local min_popup_visible = gameplay_rules.auto_popup_min_visible_seconds or 0
  if min_popup_visible > 0 and ui_sync_ports.is_popup_active and ui_sync_ports.is_popup_active(state) then
    if _is_auto_popup_owner(game, state) then
      local elapsed = state.ui_modal_elapsed or 0
      if elapsed < min_popup_visible then
        return nil
      end
    end
  end
  local ctx = auto_context.build(game, context)
  local auto_action = state.auto_runner:next_action(dt, ctx)
  if auto_action and auto_action.type == "ui_button" and not auto_action.actor_role_id then
    auto_action.actor_role_id = ctx.current_player_id
  end
  if auto_action then
    _dispatch_action_with_close_choice(game, state, auto_action, ports)
  end
  return auto_action
end

local function _step_tick_auto_runner(game, state, dt)
  gameplay_loop.step_auto_runner(game, state, dt, auto_context.build_tick(game))
end

local function _step_tick_timeouts(game, state, dt, ports)
  local ui_sync_ports = ports.ui_sync
  ui_sync_ports.step_choice_timeout(game, state, dt)
  ui_sync_ports.step_modal_timeout(game, state, dt)
  gameplay_loop_runtime.update_action_button_timer({
    game = game,
    state = state,
    dt = dt,
    ports = ports,
    dispatch_next = function(actor_role_id)
      _dispatch_action_with_close_choice(game, state, {
        type = "ui_button",
        id = "next",
        actor_role_id = actor_role_id,
      }, ports)
    end,
  })
  gameplay_loop_runtime.update_detained_wait_timer(game, state, dt, turn_dispatch.step_turn)
end

local function _sync_tick_phase(game, state, ports, input_blocked_changed)
  local phase = game.turn.phase
  if gameplay_loop_runtime.sync_input_blocked(state, phase, ports) then
    input_blocked_changed = true
  end
  _step_phase_animation(game, state, phase, ports)
  gameplay_loop_runtime.sync_phase_flags(state, phase)
  return input_blocked_changed
end

local function _refresh_tick_from_dirty(game, state, ports, input_blocked_changed)
  local ui_sync_ports = ports.ui_sync
  local anim_ports = ports.anim
  local debug_ports = ports.debug
  ui_sync_ports.update_countdown(game, state)

  local dirty = game:consume_dirty()
  local ui_refreshed = ui_sync_ports.refresh_from_dirty(game, state, dirty)
  gameplay_loop_runtime.sync_turn_camera_follow(game, state, ports, ui_refreshed)
  anim_ports.sync_status_3d(game, state, dirty)

  if ui_sync_ports.get_ui_state and ui_sync_ports.is_input_blocked then
    local ui = ui_sync_ports.get_ui_state(state)
    if ui and (input_blocked_changed or (ui_sync_ports.is_input_blocked(state) and ui_refreshed)) then
      ui_sync_ports.apply_input_lock(state)
    end
  end
  if state.ui_model then
    debug_ports.log_status(state.ui_model)
  end

  debug_ports.sync_debug_log(state)
end

function gameplay_loop.tick(game, state, dt)
  if not game then
    return
  end

  local ports = _resolve_ports(state)
  local phase = game.turn.phase
  local input_blocked_changed = gameplay_loop_runtime.sync_input_blocked(state, phase, ports)
  gameplay_loop_runtime.sync_role_control_lock(game, state, ports)

  _step_tick_auto_runner(game, state, dt)
  _step_tick_timeouts(game, state, dt, ports)
  input_blocked_changed = _sync_tick_phase(game, state, ports, input_blocked_changed)
  _refresh_tick_from_dirty(game, state, ports, input_blocked_changed)
end

return gameplay_loop
