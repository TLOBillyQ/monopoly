local logger = require("src.core.utils.logger")
local number_utils = require("src.core.utils.number_utils")
local item_slot_data = require("src.turn.actions.item_slot_data")
local validator = require("src.turn.actions.validator")
local runtime_state = require("src.state.state_access.runtime_state")
local market_service = require("src.rules.market")
local role_id_utils = require("src.core.utils.role_id")
local output_state_adapter = require("src.turn.output.state_adapter")

local turn_dispatch = {}
local _dispatch_action

local next_turn_cooldown = 0.4
local default_ui_sync_ports = {
  get_ui_state = function(state)
    return state and state.ui or nil
  end,
  resolve_ui_gate = function()
    return nil
  end,
}

local default_clock_ports = {
  wall_now_seconds = function()
    return 0
  end,
  wall_diff_seconds = function(timestamp_1, timestamp_2)
    if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
      return timestamp_1 - timestamp_2
    end
    return 0
  end,
}

local function _resolve_port_group(state, key)
  local resolved = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  local group = type(resolved) == "table" and resolved[key] or nil
  if type(group) == "table" then
    return group
  end
  return nil
end

local function _resolve_actor_player(game, action)
  assert(game ~= nil and game.players ~= nil, "missing game.players")
  local actor_role_id = role_id_utils.normalize(action and action.actor_role_id or nil)
  if actor_role_id == nil then
    logger.warn("ui_button missing actor_role_id:", tostring(action and action.id))
    return nil
  end
  local player = game:find_player_by_id(actor_role_id)
  if not player then
    logger.warn("ui_button actor_role_id not mapped:", tostring(action and action.id), tostring(actor_role_id))
    if action and action.id == "auto" then
    end
    return nil
  end
  return player
end

function turn_dispatch.step_turn(game)
  assert(game ~= nil, "missing game")
  if game.finished then
    return
  end
  game:advance_turn()
end

function turn_dispatch.clear_choice(state, opts)
  local output_ports = _resolve_port_group(state, "output") or output_state_adapter
  output_ports.clear_pending_choice(state)
  if opts and opts.on_close_choice then
    opts.on_close_choice(state)
  end
end

local function _resolve_dispatch_context(state, context)
  if context then
    return context
  end
  local output_ports = _resolve_port_group(state, "output") or output_state_adapter
  local ui_sync_ports = _resolve_port_group(state, "ui_sync") or default_ui_sync_ports
  local clock_ports = _resolve_port_group(state, "clock") or default_clock_ports
  local ui_state = ui_sync_ports.get_ui_state and ui_sync_ports.get_ui_state(state) or nil
  local item_slot_source = item_slot_data.from_ui_state(ui_state)
  return {
    output_ports = output_ports,
    ui_sync_ports = ui_sync_ports,
    clock_ports = clock_ports,
    item_slot_source = item_slot_source,
  }
end

local function _resolve_timestamp_now(dispatch_ctx)
  local clock_ports = dispatch_ctx and dispatch_ctx.clock_ports or nil
  if clock_ports and type(clock_ports.wall_now_seconds) == "function" then
    local ok, ts = pcall(clock_ports.wall_now_seconds)
    if ok and number_utils.is_numeric(ts) then
      return ts
    end
  end
  return 0
end

local function _resolve_timestamp_diff_seconds(dispatch_ctx, timestamp_1, timestamp_2)
  local clock_ports = dispatch_ctx and dispatch_ctx.clock_ports or nil
  if clock_ports and type(clock_ports.wall_diff_seconds) == "function" then
    local ok, diff = pcall(clock_ports.wall_diff_seconds, timestamp_1, timestamp_2)
    if ok and number_utils.is_numeric(diff) then
      return diff
    end
  end
  if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
    return timestamp_1 - timestamp_2
  end
  return 0
end

function turn_dispatch.should_block_action(state, action_or_type)
  local dispatch_ctx = _resolve_dispatch_context(state)
  local gate_state = validator.resolve_gate_state(state, dispatch_ctx.ui_sync_ports)
  return validator.should_block_action(gate_state, action_or_type)
end

local function _should_invalidate_ui(action)
  return action.type == "ui_button"
    or action.type == "choice_select"
    or action.type == "choice_cancel"
    or action.type == "market_page_prev"
    or action.type == "market_page_next"
    or action.type == "market_tab_select"
end

local function _invalidate_ui_model(output_ports, state)
  if not output_ports then
    return false
  end
  if type(output_ports.invalidate_ui_model) == "function" then
    return output_ports.invalidate_ui_model(state)
  end
  return false
end

local function _handle_auto_toggle(game, state, action)
  local player = _resolve_actor_player(game, action)
  if not player then
    return { status = "rejected" }
  end
  player.auto = not (player.auto == true)
  return { status = "applied" }
end

local function _allow_next_turn(turn_runtime, phase, now, ctx)
  if not turn_runtime.next_turn_locked then
    return true
  end
  if turn_runtime.next_turn_lock_phase and phase and phase ~= turn_runtime.next_turn_lock_phase then
    return true
  end
  if turn_runtime.next_turn_last_click == nil then
    return true
  end
  local diff = _resolve_timestamp_diff_seconds(ctx, now, turn_runtime.next_turn_last_click)
  return diff and diff >= next_turn_cooldown
end

local function _handle_next_turn(game, state, action, ctx)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local phase = game.turn.phase
  local now = _resolve_timestamp_now(ctx)
  if not _allow_next_turn(turn_runtime, phase, now, ctx) then
    return { status = "rejected" }
  end
  turn_runtime.next_turn_locked = true
  turn_runtime.next_turn_last_click = now
  turn_runtime.next_turn_lock_phase = phase
  if phase == "wait_action" then
    game:dispatch_action(action)
  else
    turn_dispatch.step_turn(game)
  end
  return { status = "applied" }
end

local function _handle_ui_button(game, state, action, opts, ctx)
  if action.id == "auto" then
    return _handle_auto_toggle(game, state, action)
  end
  if not validator.validate_actor_role(game, action) then
    return { status = "rejected" }
  end
  local slot_result = validator.resolve_item_slot_action(ctx.item_slot_source, state, action, game)
  if slot_result ~= nil then
    if not slot_result.ok then
      return { status = "rejected" }
    end
    return _dispatch_action(game, state, slot_result.action, opts, ctx)
  end
  if action.id == "next" then
    return _handle_next_turn(game, state, action, ctx)
  end
  return { status = "rejected" }
end

local function _handle_choice_action(game, state, action, opts, ctx)
  local choice = ctx.output_ports.get_pending_choice(state)
  if not validator.validate_choice_action(game, action, choice) then
    return { status = "rejected" }
  end
  if game then
    assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
    game:dispatch_action(action)
  end
  local pending = game and game.turn and game.turn.pending_choice or nil
  if not pending or not pending.id or pending.id ~= choice.id then
    turn_dispatch.clear_choice(state, opts)
  end
  return { status = "applied" }
end

local function _resolve_turn_pending_choice(game)
  local turn = game and game.turn or nil
  if not turn then
    return nil
  end
  return turn.pending_choice
end

local function _resolve_market_choice(game, state, ctx)
  local turn_choice = _resolve_turn_pending_choice(game)
  if turn_choice ~= nil then
    return turn_choice
  end
  return ctx.output_ports.get_pending_choice(state)
end

local function _resolve_market_navigation_failure(game, state, action, ctx, choice)
  if not choice or choice.kind ~= "market_buy" then
    return "[MarketDebug] dispatch_market_nav rejected: pending_choice missing or kind not market_buy"
  end
  if not validator.validate_choice_action(game, action, choice) then
    return "[MarketDebug] dispatch_market_nav rejected: validate_choice_action failed"
  end
  if not market_service.choice.apply_navigation(game, choice, action) then
    return "[MarketDebug] dispatch_market_nav rejected: apply_navigation failed"
  end
  ctx.output_ports.sync_pending_choice(state, choice)
  return nil
end

local function _handle_market_navigation(game, state, action, ctx)
  local choice = _resolve_market_choice(game, state, ctx)
  local failure = _resolve_market_navigation_failure(game, state, action, ctx, choice)
  if failure ~= nil then
    logger.warn(failure)
    return { status = "rejected" }
  end
  return { status = "applied" }
end

_dispatch_action = function(game, state, action, opts, dispatch_ctx)
  assert(action ~= nil, "missing action")
  if action.input_source == nil then
    action.input_source = "user"
end
  local ctx = _resolve_dispatch_context(state, dispatch_ctx)
  local gate_state = validator.resolve_gate_state(state, ctx.ui_sync_ports)
  if validator.should_block_action(gate_state, action) then
    return { status = "blocked" }
  end
  if _should_invalidate_ui(action) then
    _invalidate_ui_model(ctx.output_ports, state)
  end
  if action.type == "ui_button" then
    return _handle_ui_button(game, state, action, opts, ctx)
  end
  if action.type == "choice_select" or action.type == "choice_cancel" then
    return _handle_choice_action(game, state, action, opts, ctx)
  end
  if action.type == "market_page_prev" or action.type == "market_page_next" or action.type == "market_tab_select" then
    return _handle_market_navigation(game, state, action, ctx)
  end
  return { status = "rejected" }
end

function turn_dispatch.dispatch_action(game, state, action, opts)
  return _dispatch_action(game, state, action, opts, nil)
end

return turn_dispatch
