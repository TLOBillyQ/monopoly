local constants = require("Config.Generated.Constants")
local gameplay_rules = require("Config.GameplayRules")
local turn_dispatch = require("src.game.flow.turn.TurnDispatch")
local number_utils = require("src.core.NumberUtils")
local choice_auto_policy = require("src.game.flow.turn.TurnChoiceAutoPolicy")
local tick_ui_gate = require("src.game.flow.turn.TickUIGate")
local tick_choice_timeout = require("src.game.flow.turn.TickChoiceTimeout")

local tick_timeout = {}

local function _resolve_ports(state)
  local ports = state and state.gameplay_loop_ports or nil
  if not ports then
    return nil
  end
  local modal_ports = ports.modal
  if type(modal_ports) ~= "table" then
    return nil
  end
  if type(modal_ports.close_choice_modal) == "function" or type(modal_ports.close_popup) == "function" then
    return modal_ports
  end
  return nil
end

local function _dispatch_action_with_close_choice(game, state, action)
  local ports = _resolve_ports(state)
  if not ports then
    return turn_dispatch.dispatch_action(game, state, action)
  end
  return turn_dispatch.dispatch_action(game, state, action, {
    on_close_choice = function(ctx)
      ports.close_choice_modal(ctx)
    end,
  })
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
    build_action = opts.build_action,
    get_timeout_seconds = opts.get_timeout_seconds,
    get_min_visible_seconds = opts.get_min_visible_seconds,
    dispatch_action_with_close_choice = _dispatch_action_with_close_choice,
  })
end

function tick_timeout.step_modal_timeout(state, dt, opts)
  local timeout = constants.action_timeout_seconds or 0
  if opts and opts.get_timeout_seconds then
    local override = opts.get_timeout_seconds(state)
    if override ~= nil and number_utils.is_numeric(override) then
      timeout = override
    end
  end
  if timeout <= 0 then
    state.ui_modal_elapsed = 0
    state.ui_modal_ref = nil
    return
  end
  assert(opts ~= nil, "missing opts")
  assert(opts.is_active ~= nil, "missing opts.is_active")
  assert(opts.on_timeout ~= nil, "missing opts.on_timeout")
  assert(opts.get_ref ~= nil, "missing opts.get_ref")
  if not opts.is_active(state) then
    state.ui_modal_elapsed = 0
    state.ui_modal_ref = nil
    return
  end
  local ref = assert(opts.get_ref(state), "missing modal ref")
  if state.ui_modal_ref ~= ref then
    state.ui_modal_ref = ref
    state.ui_modal_elapsed = 0
  end
  state.ui_modal_elapsed = state.ui_modal_elapsed + (dt or 0)
  if state.ui_modal_elapsed >= timeout then
    state.ui_modal_elapsed = 0
    opts.on_timeout(state)
  end
end

local function _noop()
end

local default_policy = {
  choice = {
    get_timeout_seconds = function()
      return constants.action_timeout_seconds or 0
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
      local ports = _resolve_ports(ctx)
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
  tick_timeout.step_choice_timeout(game, state, dt, {
    on_pending_choice = _noop,
    is_choice_active = function(ctx)
      return ctx.pending_choice ~= nil
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
