local logger = require("src.core.Logger")
local number_utils = require("src.core.NumberUtils")
local item_slot_data = require("src.game.flow.turn.ItemSlotData")
local validator = require("src.game.flow.turn.TurnDispatchValidator")
local gameplay_loop_ports = require("src.game.flow.turn.GameplayLoopPorts")
local runtime_state = require("src.core.RuntimeState")
local market_service = require("src.game.systems.market.MarketService")
local role_id_utils = require("src.core.RoleId")

local turn_dispatch = {}

local next_turn_cooldown = 0.4

local function _reset_afk_tracking(state, actor_role_id)
  if type(state) ~= "table" then
    return
  end
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  turn_runtime.afk_actor_role_id = role_id_utils.normalize(actor_role_id)
  turn_runtime.afk_elapsed_seconds = 0
  turn_runtime.afk_tracking_active = false
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
      print("[AutoProbe][TurnDispatch] actor not mapped:", tostring(actor_role_id))
    end
    return nil
  end
  return player
end

local function _maybe_reset_afk_for_current_player(game, state, action)
  if not (game and state and action) then
    return
  end
  local actor_role_id = role_id_utils.normalize(action.actor_role_id)
  if actor_role_id == nil then
    return
  end
  local current_index = game.turn and game.turn.current_player_index or nil
  local current_player = current_index and game.players and game.players[current_index] or nil
  local current_role_id = role_id_utils.normalize(current_player and current_player.id or nil)
  if current_role_id == nil or not role_id_utils.equals(actor_role_id, current_role_id) then
    return
  end
  _reset_afk_tracking(state, actor_role_id)
end

function turn_dispatch.step_turn(game)
  assert(game ~= nil, "missing game")
  assert(not game.finished, "game finished")
  game:advance_turn()
end

function turn_dispatch.clear_choice(state, opts)
  state.pending_choice = nil
  state.pending_choice_elapsed = 0
  state.pending_choice_id = nil
  if opts and opts.on_close_choice then
    opts.on_close_choice(state)
  end
end

local function _resolve_dispatch_context(state, context)
  if context then
    return context
  end
  local ports = gameplay_loop_ports.resolve(state and state.gameplay_loop_ports or nil)
  local ui_sync_ports = ports.ui_sync
  local ui_state = ui_sync_ports.get_ui_state and ui_sync_ports.get_ui_state(state) or nil
  local item_slot_source = item_slot_data.from_ui_state(ui_state)
  return {
    ports = ports,
    ui_sync_ports = ui_sync_ports,
    clock_ports = ports.clock,
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

local function _dispatch_action(game, state, action, opts, dispatch_ctx)
  assert(action ~= nil, "missing action")
  local ctx = _resolve_dispatch_context(state, dispatch_ctx)
  local gate_state = validator.resolve_gate_state(state, ctx.ui_sync_ports)
  if validator.should_block_action(gate_state, action) then
    return { status = "blocked" }
  end
  if action.type == "ui_button"
      or action.type == "choice_select"
      or action.type == "choice_cancel"
      or action.type == "market_page_prev"
      or action.type == "market_page_next"
      or action.type == "market_tab_select" then
    state.ui_dirty = true
  end
  if action.type == "ui_button" then
    if action.id == "auto" then
      local player = _resolve_actor_player(game, action)
      if not player then
        print("[AutoProbe][TurnDispatch] auto rejected: actor unresolved")
        return { status = "rejected" }
      end
      local before = player.auto == true
      player.auto = not (player.auto == true)
      _reset_afk_tracking(state, player.id)
      print(
        "[AutoProbe][TurnDispatch] auto toggled:",
        "before=" .. tostring(before),
        "after=" .. tostring(player.auto == true)
      )
      return { status = "applied" }
    end

    if not validator.validate_actor_role(game, action) then
      return { status = "rejected" }
    end
    local slot_result = validator.resolve_item_slot_action(ctx.item_slot_source, state, action)
    if slot_result ~= nil then
      if not slot_result.ok then
        return { status = "rejected" }
      end
      return _dispatch_action(game, state, slot_result.action, opts, ctx)
    end
    if action.id == "next" then
      assert(game ~= nil, "missing game")
      local turn_runtime = runtime_state.ensure_turn_runtime(state)
      local phase = game.turn.phase
      local now = _resolve_timestamp_now(ctx)
      if turn_runtime.next_turn_locked then
        local allow = false
        if turn_runtime.next_turn_lock_phase and phase and phase ~= turn_runtime.next_turn_lock_phase then
          allow = true
        elseif turn_runtime.next_turn_last_click == nil then
          allow = true
        else
          local diff = _resolve_timestamp_diff_seconds(ctx, now, turn_runtime.next_turn_last_click)
          if diff and diff >= next_turn_cooldown then
            allow = true
          end
        end
        if not allow then
          return { status = "rejected" }
        end
      end
      turn_runtime.next_turn_locked = true
      turn_runtime.next_turn_last_click = now
      turn_runtime.next_turn_lock_phase = phase
      _reset_afk_tracking(state, action.actor_role_id)
      turn_dispatch.step_turn(game)
      return { status = "applied" }
    end
    return { status = "rejected" }
  elseif action.type == "choice_select" or action.type == "choice_cancel" then
    local choice = state.pending_choice
    if not validator.validate_choice_action(game, action, choice) then
      return { status = "rejected" }
    end
    if game then
      assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
      game:dispatch_action(action)
    end
    _maybe_reset_afk_for_current_player(game, state, action)
    local pending = game and game.turn and game.turn.pending_choice or nil
    if not pending or not pending.id or pending.id ~= choice.id then
      turn_dispatch.clear_choice(state, opts)
    end
    return { status = "applied" }
  elseif action.type == "market_page_prev" or action.type == "market_page_next" or action.type == "market_tab_select" then
    local turn_choice = game and game.turn and game.turn.pending_choice or nil
    local choice = turn_choice or state.pending_choice
    logger.warn(
      "[MarketDebug] dispatch_market_nav received",
      "action_type=" .. tostring(action.type),
      "choice_id=" .. tostring(action.choice_id),
      "tab=" .. tostring(action.tab),
      "pending_choice_id=" .. tostring(choice and choice.id),
      "pending_kind=" .. tostring(choice and choice.kind),
      "choice_source=" .. tostring(turn_choice and "game.turn.pending_choice" or "state.pending_choice")
    )
    if not choice or choice.kind ~= "market_buy" then
      logger.warn("[MarketDebug] dispatch_market_nav rejected: pending_choice missing or kind not market_buy")
      return { status = "rejected" }
    end
    if not validator.validate_choice_action(game, action, choice) then
      logger.warn("[MarketDebug] dispatch_market_nav rejected: validate_choice_action failed")
      return { status = "rejected" }
    end
    if market_service.choice.apply_navigation(game, choice, action) then
      _maybe_reset_afk_for_current_player(game, state, action)
      state.pending_choice = choice
      state.pending_choice_id = choice.id
      state.pending_choice_elapsed = 0
      logger.warn(
        "[MarketDebug] dispatch_market_nav applied",
        "active_tab=" .. tostring(choice.active_tab),
        "page_index=" .. tostring(choice.page_index),
        "page_count=" .. tostring(choice.page_count),
        "options_count=" .. tostring(choice.options and #choice.options or 0)
      )
      return { status = "applied" }
    end
    logger.warn("[MarketDebug] dispatch_market_nav rejected: apply_navigation failed")
    return { status = "rejected" }
  end
  return { status = "rejected" }
end

function turn_dispatch.dispatch_action(game, state, action, opts)
  return _dispatch_action(game, state, action, opts, nil)
end

return turn_dispatch
