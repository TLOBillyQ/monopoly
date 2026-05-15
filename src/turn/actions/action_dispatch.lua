local ctx_mod = require("src.turn.actions.context")
local defaults = require("src.turn.actions.defaults")
local force_resolve = require("src.turn.deadlines")

local function build(deps)
  local logger = deps.logger
  local validator = deps.validator
  local runtime_state = deps.runtime_state
  local market_service = deps.market_service
  local turn_dispatch_ref = deps.turn_dispatch_ref

  local _dispatch_action

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

  local function _resolve_pending_choice(game, state, ctx)
    local turn = game and game.turn or nil
    local turn_choice = turn and turn.pending_choice or nil
    if turn_choice ~= nil then
      return turn_choice
    end
    return ctx.output_ports.get_pending_choice(state)
  end

  local function _handle_choice_action(game, state, action, opts, ctx)
    local choice = _resolve_pending_choice(game, state, ctx)
    if not validator.validate_choice_action(game, action, choice) then
      return { status = "rejected" }
    end
    if game then
      assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
      game:dispatch_action(action)
    end
    local pending = game and game.turn and game.turn.pending_choice or nil
    if choice and (not pending or not pending.id or pending.id ~= choice.id) then
      turn_dispatch_ref.clear_choice(state, opts)
    end
    return { status = "applied" }
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
    local choice = _resolve_pending_choice(game, state, ctx)
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
    local ctx = ctx_mod.resolve_dispatch_context(state, dispatch_ctx)
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
    if action.type == "choice_force_skip" then
      local choice = _resolve_pending_choice(game, state, ctx)
      force_resolve.force_skip(game, state, choice, action.reason or "dispatch")
      return { status = "applied" }
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
