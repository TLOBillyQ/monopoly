local ctx_mod = require("src.turn.actions.context")
local defaults = require("src.turn.actions.defaults")
local choice_dispatch = require("src.turn.actions.choice_dispatch")

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

  local function _resolve_pending_choice(game, state, ctx)
    local turn_choice = game and game.turn and game.turn.pending_choice or nil
    if turn_choice ~= nil then
      return turn_choice
    end
    local output_ports = ctx and ctx.output_ports or nil
    if output_ports and type(output_ports.get_pending_choice) == "function" then
      return output_ports.get_pending_choice(state)
    end
    return nil
  end

  local function _allows_market_cancel_while_blocked(gate_state, game, state, action, ctx)
    if not gate_state or gate_state.input_blocked ~= true then
      return false
    end
    if not action or action.type ~= "choice_cancel" then
      return false
    end
    local choice = _resolve_pending_choice(game, state, ctx)
    if choice == nil or choice.kind ~= "market_buy" then
      return false
    end
    return action.choice_id ~= nil and choice.id ~= nil and action.choice_id == choice.id
  end

  local function _handle_auto_toggle(game, _, action)
    local player = ctx_mod.resolve_actor_player(game, action)
    if not player then
      return { status = "rejected" }
    end
    player.auto = player.auto ~= true
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
    local diff = ctx_mod.resolve_timestamp_diff_seconds(ctx, now, turn_runtime.next_turn_last_click)
    return diff and diff >= defaults.next_turn_cooldown
  end

  local function _handle_next_turn(game, state, action, ctx)
    local turn_runtime = runtime_state.ensure_turn_runtime(state)
    local phase = game.turn.phase
    local now = ctx_mod.resolve_timestamp_now(ctx)
    if not _allow_next_turn(turn_runtime, phase, now, ctx) then
      return { status = "rejected" }
    end
    turn_runtime.next_turn_locked = true
    turn_runtime.next_turn_last_click = now
    turn_runtime.next_turn_lock_phase = phase
    if phase == "wait_action" then
      game:dispatch_action(action)
    else
      turn_dispatch_ref.step_turn(game)
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
projectHash=c1842895b595f10b
scope.0.id=chunk:src/turn/actions/action_dispatch.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=150
scope.0.semanticHash=b583efa225e63a5c
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
scope.3.id=function:_handle_auto_toggle:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=40
scope.3.semanticHash=0436400f61800c7e
scope.4.id=function:_allow_next_turn:42
scope.4.kind=function
scope.4.startLine=42
scope.4.endLine=54
scope.4.semanticHash=c2c8170d039ea768
scope.5.id=function:_handle_next_turn:56
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=72
scope.5.semanticHash=935f0e355c626980
scope.6.id=function:_handle_ui_button:74
scope.6.kind=function
scope.6.startLine=74
scope.6.endLine=92
scope.6.semanticHash=5f8e0f48a615602c
scope.7.id=function:_invoke_choice_handler:94
scope.7.kind=function
scope.7.startLine=94
scope.7.endLine=96
scope.7.semanticHash=8471d9b91252d812
scope.8.id=function:_invoke_action_handler:98
scope.8.kind=function
scope.8.startLine=98
scope.8.endLine=109
scope.8.semanticHash=48d2f3eb767c2223
scope.9.id=function:anonymous@122:122
scope.9.kind=function
scope.9.startLine=122
scope.9.endLine=140
scope.9.semanticHash=538044647eaeca48
scope.10.id=function:build:15
scope.10.kind=function
scope.10.startLine=15
scope.10.endLine=145
scope.10.semanticHash=ba37b816b5a0e096
]]
