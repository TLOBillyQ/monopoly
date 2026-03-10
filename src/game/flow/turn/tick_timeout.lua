local constants = require("Config.generated.constants")
local gameplay_rules = require("src.core.config.gameplay_rules")
local turn_dispatch = require("src.game.flow.turn.dispatch")
local number_utils = require("src.core.utils.number_utils")
local choice_auto_policy = require("src.game.flow.turn.choice_auto_policy")
local tick_ui_gate = require("src.game.flow.turn.tick_ui_gate")
local tick_choice_timeout = require("src.game.flow.turn.tick_choice_timeout")
local output_state_adapter = require("src.game.flow.output_adapters.output_state_adapter")
local runtime_state = require("src.core.state_access.runtime_state")

local tick_timeout = {}

function tick_timeout.resolve_choice_timeout_seconds(game, state, choice)
  local timeout = constants.action_timeout_seconds or 0
  local pending_choice = choice or (game and game.turn and game.turn.pending_choice) or (state and runtime_state.get_pending_choice(state)) or nil
  if pending_choice and pending_choice.kind == "market_buy" then
    return timeout * 2
  end
  return timeout
end

local function _resolve_modal_ports(state)
  local modal_ports = state and state.gameplay_loop_ports and state.gameplay_loop_ports.modal or nil
  if type(modal_ports) ~= "table" then
    return nil
  end
  return (type(modal_ports.close_choice_modal) == "function" or type(modal_ports.close_popup) == "function") and modal_ports or nil
end

local function _dispatch_action_with_close_choice(game, state, action)
  local modal_ports = _resolve_modal_ports(state)
  return turn_dispatch.dispatch_action(game, state, action, modal_ports and {
    on_close_choice = function(ctx)
      modal_ports.close_choice_modal(ctx)
    end,
  } or nil)
end

function tick_timeout.resolve_modal_timeout_seconds(_, state, ui_sync_ports)
  return tick_ui_gate.resolve_modal_timeout_seconds(state, ui_sync_ports)
end

function tick_timeout.resolve_modal_gate(state, ui_sync_ports)
  return tick_ui_gate.resolve_ui_gate(state, ui_sync_ports)
end

function tick_timeout.step_choice_timeout(game, state, dt, opts)
  return tick_choice_timeout.step(game, state, dt, {
    on_pending_choice = opts.on_pending_choice,
    is_choice_active = opts.is_choice_active,
    resolve_choice_ui_state = opts.resolve_choice_ui_state,
    build_action = opts.build_action,
    get_timeout_seconds = opts.get_timeout_seconds,
    get_min_visible_seconds = opts.get_min_visible_seconds,
    dispatch_action_with_close_choice = _dispatch_action_with_close_choice,
  })
end

function tick_timeout.step_modal_timeout(state, dt, opts)
  local ports = state and state.gameplay_loop_ports or nil
  local output_ports = ports and ports.output or output_state_adapter
  local timeout = constants.action_timeout_seconds or 0
  if opts and opts.get_timeout_seconds then
    local override = opts.get_timeout_seconds(state)
    if override ~= nil and number_utils.is_numeric(override) then
      timeout = override
    end
  end
  if timeout <= 0 then
    output_ports.sync_modal_timer(state, {})
    return
  end
  assert(opts ~= nil, "missing opts")
  assert(opts.is_active ~= nil, "missing opts.is_active")
  assert(opts.on_timeout ~= nil, "missing opts.on_timeout")
  assert(opts.get_ref ~= nil, "missing opts.get_ref")
  if not opts.is_active(state) then
    output_ports.sync_modal_timer(state, {})
    return
  end
  local ref = assert(opts.get_ref(state), "missing modal ref")
  if output_ports.get_modal_ref(state) ~= ref then
    output_ports.sync_modal_timer(state, { ref = ref, elapsed_seconds = 0 })
  end
  local next_elapsed = output_ports.get_modal_elapsed(state) + (dt or 0)
  output_ports.sync_modal_timer(state, { ref = ref, elapsed_seconds = next_elapsed })
  if next_elapsed >= timeout then
    output_ports.sync_modal_timer(state, { ref = ref, elapsed_seconds = 0 })
    opts.on_timeout(state)
  end
end

local function _noop() end

local function _resolve_ui_sync_ports(state)
  local resolved = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  local ui_sync_ports = type(resolved) == "table" and resolved.ui_sync or nil
  if type(ui_sync_ports) == "table" then
    return ui_sync_ports
  end
  return nil
end

local default_policy = {
  choice = {
    get_timeout_seconds = function(game, state)
      return tick_timeout.resolve_choice_timeout_seconds(game, state)
    end,
    get_min_visible_seconds = function()
      return gameplay_rules.auto_choice_min_visible_seconds or 0
    end,
    build_action = function(game_ctx, state_ctx, choice, action_ctx)
      return choice_auto_policy.decide(game_ctx, state_ctx, choice, action_ctx)
    end,
  },
  modal = {
    get_timeout_seconds = function(game, state)
      return tick_timeout.resolve_modal_timeout_seconds(game, state)
    end,
    on_timeout = function(ctx)
      local ports = _resolve_modal_ports(ctx)
      if ports and ports.close_popup then
        ports.close_popup(ctx)
        return
      end
    end,
  },
}

local function _clone_policy(policy)
  local copied = {}
  for key, value in pairs(policy) do
    if type(value) == "table" then
      local item = {}
      for sub_key, sub_value in pairs(value) do
        item[sub_key] = sub_value
      end
      copied[key] = item
    else
      copied[key] = value
    end
  end
  return copied
end

function tick_timeout.default_policy()
  return _clone_policy(default_policy)
end

function tick_timeout.step_default_choice(game, state, dt)
  local policy = tick_timeout.default_policy()
  local ui_sync_ports = _resolve_ui_sync_ports(state)
  tick_timeout.step_choice_timeout(game, state, dt, {
    on_pending_choice = function(state_ctx, pending)
      if ui_sync_ports and type(ui_sync_ports.on_pending_choice) == "function" then
        return ui_sync_ports.on_pending_choice(game, state_ctx, pending)
      end
      return _noop()
    end,
    is_choice_active = function(ctx)
      if ui_sync_ports and type(ui_sync_ports.is_choice_active) == "function" then
        return ui_sync_ports.is_choice_active(ctx)
      end
      return ctx.pending_choice ~= nil
    end,
    resolve_choice_ui_state = function(game_ctx, state_ctx, choice)
      if ui_sync_ports and type(ui_sync_ports.resolve_choice_ui_state) == "function" then
        return ui_sync_ports.resolve_choice_ui_state(game_ctx, state_ctx, choice)
      end
      return {
        route_key = choice and choice.route_key or nil,
        should_warn = false,
      }
    end,
    build_action = policy.choice.build_action,
    get_timeout_seconds = policy.choice.get_timeout_seconds,
    get_min_visible_seconds = policy.choice.get_min_visible_seconds,
  })
end

function tick_timeout.step_default_modal(game, state, dt)
  local policy = tick_timeout.default_policy()
  tick_timeout.step_modal_timeout(state, dt, {
    is_active = function(ctx)
      local gate = tick_ui_gate.resolve_ui_gate(ctx)
      return gate.popup_active == true
    end,
    get_ref = function(ctx)
      local gate = tick_ui_gate.resolve_ui_gate(ctx)
      assert(gate.popup_active, "popup not active")
      return assert(gate.popup_seq, "missing popup_seq")
    end,
    get_timeout_seconds = function(state_ctx)
      return policy.modal.get_timeout_seconds(game, state_ctx, state_ctx and state_ctx.gameplay_loop_ports and state_ctx.gameplay_loop_ports.ui_sync or nil)
    end,
    on_timeout = policy.modal.on_timeout,
  })
end

return tick_timeout
