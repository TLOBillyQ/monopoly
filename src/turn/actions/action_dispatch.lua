local ctx_mod = require("src.turn.actions.context")
local choice_dispatch = require("src.turn.actions.choice_dispatch")
local ui_button_dispatch = require("src.turn.actions.ui_button_dispatch")

local INVALIDATING_ACTION_TYPES = {
  ui_button = true,
  choice_select = true,
  choice_cancel = true,
  complete_optional_action_phase = true,
  market_page_prev = true,
  market_page_next = true,
  market_tab_select = true,
}

local function build(deps)
  local validator = deps.validator
  local runtime_state = deps.runtime_state
  local market_service = deps.market_service
  local turn_dispatch_ref = deps.turn_dispatch_ref

  local _dispatch_action

  local function _should_invalidate_ui(action)
    return INVALIDATING_ACTION_TYPES[action.type] == true
  end

  local function _invalidate_ui_model(output_ports, state)
    if output_ports and type(output_ports.invalidate_ui_model) == "function" then
      output_ports.invalidate_ui_model(state)
    end
  end

  local function _allows_market_cancel_while_blocked(gate_state, game, state, action, ctx)
    if not gate_state or gate_state.input_blocked ~= true then
      return false
    end
    if not action or action.type ~= "choice_cancel" then
      return false
    end
    local choice = ctx_mod.resolve_pending_choice(game, state, ctx)
    if choice == nil or choice.kind ~= "market_buy" then
      return false
    end
    return action.choice_id ~= nil and choice.id ~= nil and action.choice_id == choice.id
  end

  local function _handle_ui_button(game, state, action, opts, ctx)
    return ui_button_dispatch.handle(
      game, state, action, opts, ctx,
      validator, runtime_state, turn_dispatch_ref,
      function(...) return _dispatch_action(...) end
    )
  end

  local function _invoke_choice_handler(fn, game, state, action, opts, ctx)
    return fn(game, state, action, opts, ctx, validator, _dispatch_action, turn_dispatch_ref)
  end

  local function _invoke_action_handler(handler, game, state, action, opts, ctx)
    if handler.kind == "choice" then
      return _invoke_choice_handler(handler.fn, game, state, action, opts, ctx)
    end
    if handler.kind == "market" then
      return handler.fn(game, state, action, ctx, validator, market_service)
    end
    if handler.kind == "force_skip" then
      return handler.fn(game, state, action, ctx)
    end
    return handler.fn(game, state, action, opts, ctx)
  end

  local _ACTION_HANDLERS = {
    ui_button = { fn = _handle_ui_button },
    choice_select = { fn = choice_dispatch.handle_choice_action, kind = "choice" },
    choice_cancel = { fn = choice_dispatch.handle_choice_action, kind = "choice" },
    complete_optional_action_phase = { fn = choice_dispatch.handle_optional_action_completion, kind = "choice" },
    market_page_prev = { fn = choice_dispatch.handle_market_navigation, kind = "market" },
    market_page_next = { fn = choice_dispatch.handle_market_navigation, kind = "market" },
    market_tab_select = { fn = choice_dispatch.handle_market_navigation, kind = "market" },
    choice_force_skip = { fn = choice_dispatch.handle_force_skip, kind = "force_skip" },
  }

  _dispatch_action = function(game, state, action, opts, dispatch_ctx)
    assert(action ~= nil, "missing action")
    if action.input_source == nil then
      action.input_source = "user"
    end
    local ctx = ctx_mod.resolve_dispatch_context(state, dispatch_ctx)
    local gate_state = validator.resolve_gate_state(state, ctx.ui_sync_ports)
    local blocked_by_gate = validator.should_block_action(gate_state, action)
    local allows_market_cancel = _allows_market_cancel_while_blocked(gate_state, game, state, action, ctx)
    if blocked_by_gate and not allows_market_cancel then
      return { status = "blocked" }
    end
    if _should_invalidate_ui(action) then
      _invalidate_ui_model(ctx.output_ports, state)
    end
    local handler = _ACTION_HANDLERS[action.type]
    if handler ~= nil then
      return _invoke_action_handler(handler, game, state, action, opts, ctx)
    end
    return { status = "rejected" }
  end

  return {
    dispatch_action = _dispatch_action,
  }
end

return {
  build = build,
}

--[[ mutate4lua-manifest
version=2
projectHash=0b1ef4faeabef45c
scope.0.id=chunk:src/turn/actions/action_dispatch.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=113
scope.0.semanticHash=3ad936294f285401
scope.1.id=function:_should_invalidate_ui:23
scope.1.kind=function
scope.1.startLine=23
scope.1.endLine=25
scope.1.semanticHash=cb5957ced08cf7d3
scope.2.id=function:_invalidate_ui_model:27
scope.2.kind=function
scope.2.startLine=27
scope.2.endLine=31
scope.2.semanticHash=2199bd698f895746
scope.3.id=function:_allows_market_cancel_while_blocked:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=45
scope.3.semanticHash=30a53c0cb57e69df
scope.4.id=function:anonymous@51:51
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=51
scope.4.semanticHash=8f42302a52f38a20
scope.5.id=function:_handle_ui_button:47
scope.5.kind=function
scope.5.startLine=47
scope.5.endLine=53
scope.5.semanticHash=2858865ab3de2240
scope.6.id=function:_invoke_choice_handler:55
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=57
scope.6.semanticHash=8471d9b91252d812
scope.7.id=function:_invoke_action_handler:59
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=70
scope.7.semanticHash=48d2f3eb767c2223
scope.8.id=function:anonymous@83:83
scope.8.kind=function
scope.8.startLine=83
scope.8.endLine=103
scope.8.semanticHash=e770c5b6dee93a64
scope.9.id=function:build:15
scope.9.kind=function
scope.9.startLine=15
scope.9.endLine=108
scope.9.semanticHash=48a3eafc6512b4b1
]]
