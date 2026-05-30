local ctx_mod = require("src.turn.actions.context")
local defaults = require("src.turn.actions.defaults")
local force_resolve = require("src.turn.deadlines")

local INVALIDATING_ACTION_TYPES = {
  ui_button = true,
  choice_select = true,
  choice_cancel = true,
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

  local function _apply_market_navigation(game, state, action, ctx, choice)
    if not choice or choice.kind ~= "market_buy" then
      return false
    end
    if not validator.validate_choice_action(game, action, choice) then
      return false
    end
    if not market_service.choice.apply_navigation(game, choice, action) then
      return false
    end
    ctx.output_ports.sync_pending_choice(state, choice)
    return true
  end

  local function _handle_market_navigation(game, state, action, _, ctx)
    local choice = _resolve_pending_choice(game, state, ctx)
    if not _apply_market_navigation(game, state, action, ctx, choice) then
      return { status = "rejected" }
    end
    return { status = "applied" }
  end

  local function _handle_force_skip(game, state, action, _, ctx)
    local choice = _resolve_pending_choice(game, state, ctx)
    force_resolve.force_skip(game, state, choice, action.reason or "dispatch")
    return { status = "applied" }
  end

  local _ACTION_HANDLERS = {
    ui_button = _handle_ui_button,
    choice_select = _handle_choice_action,
    choice_cancel = _handle_choice_action,
    market_page_prev = _handle_market_navigation,
    market_page_next = _handle_market_navigation,
    market_tab_select = _handle_market_navigation,
    choice_force_skip = _handle_force_skip,
  }

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
    local handler = _ACTION_HANDLERS[action.type]
    if handler ~= nil then
      return handler(game, state, action, opts, ctx)
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
projectHash=3263a3deb8947bba
scope.0.id=chunk:src/turn/actions/action_dispatch.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=177
scope.0.semanticHash=527214d630f25159
scope.0.lastMutatedAt=2026-05-28T16:39:04Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:_should_invalidate_ui:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=21
scope.1.semanticHash=71c85239ee1178c3
scope.1.lastMutatedAt=2026-05-28T16:39:04Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=17
scope.1.lastMutationKilled=17
scope.2.id=function:_invalidate_ui_model:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=27
scope.2.semanticHash=2199bd698f895746
scope.2.lastMutatedAt=2026-05-28T16:39:04Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_handle_auto_toggle:29
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=36
scope.3.semanticHash=0436400f61800c7e
scope.3.lastMutatedAt=2026-05-28T16:39:04Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=6
scope.3.lastMutationKilled=6
scope.4.id=function:_allow_next_turn:38
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=50
scope.4.semanticHash=c2c8170d039ea768
scope.4.lastMutatedAt=2026-05-28T16:39:04Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=11
scope.4.lastMutationKilled=11
scope.5.id=function:_handle_next_turn:52
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=68
scope.5.semanticHash=935f0e355c626980
scope.5.lastMutatedAt=2026-05-28T16:39:04Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=11
scope.5.lastMutationKilled=11
scope.6.id=function:_handle_ui_button:70
scope.6.kind=function
scope.6.startLine=70
scope.6.endLine=88
scope.6.semanticHash=5f8e0f48a615602c
scope.6.lastMutatedAt=2026-05-28T16:39:04Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=15
scope.6.lastMutationKilled=15
scope.7.id=function:_resolve_pending_choice:90
scope.7.kind=function
scope.7.startLine=90
scope.7.endLine=97
scope.7.semanticHash=a3b657a5b4d5d4f2
scope.7.lastMutatedAt=2026-05-28T16:39:04Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=6
scope.7.lastMutationKilled=6
scope.8.id=function:_handle_choice_action:99
scope.8.kind=function
scope.8.startLine=99
scope.8.endLine=113
scope.8.semanticHash=6bb9e10a096f64bb
scope.8.lastMutatedAt=2026-05-28T16:39:04Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=17
scope.8.lastMutationKilled=17
scope.9.id=function:_resolve_market_navigation_failure:115
scope.9.kind=function
scope.9.startLine=115
scope.9.endLine=127
scope.9.semanticHash=e09e4101eb1db45b
scope.9.lastMutatedAt=2026-05-28T16:39:04Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=12
scope.9.lastMutationKilled=12
scope.10.id=function:_handle_market_navigation:129
scope.10.kind=function
scope.10.startLine=129
scope.10.endLine=137
scope.10.semanticHash=73ce49b4a5a6d616
scope.10.lastMutatedAt=2026-05-28T16:39:04Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=6
scope.10.lastMutationKilled=6
scope.11.id=function:anonymous@139:139
scope.11.kind=function
scope.11.startLine=139
scope.11.endLine=167
scope.11.semanticHash=7679ac2da06a7165
scope.11.lastMutatedAt=2026-05-28T16:39:04Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=33
scope.11.lastMutationKilled=33
scope.12.id=function:build:5
scope.12.kind=function
scope.12.startLine=5
scope.12.endLine=172
scope.12.semanticHash=ac2cb7a8b353a602
scope.12.lastMutatedAt=2026-05-28T16:39:04Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=no_sites
scope.12.lastMutationSites=0
scope.12.lastMutationKilled=0
]]
