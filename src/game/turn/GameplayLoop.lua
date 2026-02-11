local agent = require("src.game.game.Agent")
local items_cfg = require("Config.Generated.Items")
local constants = require("Config.Generated.Constants")
local gameplay_rules = require("Config.GameplayRules")
local event_handlers = require("src.ui.UIEventHandlers")
local logger = require("src.core.Logger")
local turn_dispatch = require("src.game.turn.TurnDispatch")
local turn_anim = require("src.game.turn.TurnAnim")
local gameplay_loop_ports = require("src.game.turn.GameplayLoopPorts")
local paid_currency_bridge = require("src.game.commerce.PaidCurrencyBridge")

local gameplay_loop = {}

local function _resolve_ports(state)
  local override = state and state.gameplay_loop_ports or nil
  return gameplay_loop_ports.resolve(override)
end

local function _dispatch_action_with_close_choice(game, state, action, ports)
  turn_dispatch.dispatch_action(game, state, action, {
    on_close_choice = function(ctx)
      ports.close_choice_modal(ctx)
    end,
  })
end

local function _is_phase_input_blocked(phase)
  return phase == "wait_move_anim" or phase == "wait_action_anim"
end

local function _sync_input_blocked(state, phase)
  if not state.ui then
    return false
  end
  local input_blocked = _is_phase_input_blocked(phase)
  if state.ui.input_blocked == input_blocked then
    return false
  end
  state.ui.input_blocked = input_blocked
  if not input_blocked then
    state.ui_dirty = true
  end
  return true
end

local function _build_item_index(state)
  state.item_name_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    state.item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
  end
end

local function _is_auto_popup_owner(game, state)
  if not (game and state and state.ui) then
    return false
  end
  local idx = state.ui.popup_owner_index
  if not idx or not game.players then
    return false
  end
  local actor = game.players[idx]
  return actor and agent.is_auto_player(actor) or false
end

local function _is_auto_player_turn(game)
  if not (game and game.turn and game.players) then
    return false
  end
  local idx = game.turn.current_player_index
  local player = idx and game.players[idx] or nil
  if not player then
    return false
  end
  return agent.is_auto_player(player) == true
end

local function _build_auto_context(game, context)
  local ctx = context or {}
  ctx.game_finished = game.finished
  local current_player_index = ctx.current_player_index
  if not current_player_index then
    current_player_index = game.turn and game.turn.current_player_index or nil
    ctx.current_player_index = current_player_index
  end
  if ctx.current_player_auto == nil then
    local player = current_player_index and game.players and game.players[current_player_index] or nil
    ctx.current_player_auto = player and player.auto == true or false
  end
  return ctx
end

local function _step_phase_animation(game, state, phase, ports)
  if phase == "wait_move_anim" then
    local anim_data = game.turn.move_anim
    if not anim_data then
      return
    end
    turn_anim.step_move_anim(game, state, {
      on_move_anim = function(_, anim_ctx)
        return ports.play_move_anim(state, anim_ctx)
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
        return ports.play_action_anim(ctx, anim_ctx)
      end,
    })
  end
end

local function _sync_phase_flags(state, phase)
  if state.board_last_phase == "wait_move_anim" and phase ~= "wait_move_anim" then
    state.board_sync_pending = true
  end
  if state.next_turn_locked and state.next_turn_lock_phase and phase and phase ~= state.next_turn_lock_phase then
    state.next_turn_locked = false
    state.next_turn_lock_phase = phase
  end
  state.board_last_phase = phase
end

local function _is_action_button_wait_active(game, state)
  if not (game and state and state.ui) then
    return false
  end
  if game.finished then
    return false
  end
  local ui = state.ui
  if ui.input_blocked then
    return false
  end
  if ui.choice_active or ui.market_active or ui.popup_active then
    return false
  end
  if game.turn and game.turn.pending_choice then
    return false
  end
  return true
end

local function _update_action_button_timer(ctx)
  local state = ctx.state
  if not state then
    return
  end
  if not _is_action_button_wait_active(ctx.game, state) then
    state.action_button_active = false
    state.action_button_elapsed = 0
    return
  end

  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    state.action_button_active = false
    state.action_button_elapsed = 0
    return
  end
  state.action_button_active = true

  local elapsed = (state.action_button_elapsed or 0) + (ctx.dt or 0)
  if elapsed < timeout then
    state.action_button_elapsed = elapsed
    return
  end

  state.action_button_elapsed = 0
  local current_index = ctx.game and ctx.game.turn and ctx.game.turn.current_player_index or nil
  if not current_index then
    return
  end
  _dispatch_action_with_close_choice(ctx.game, state, {
    type = "ui_button",
    id = "next",
    actor_role_id = current_index,
  }, ctx.ports)
end

function gameplay_loop.set_game(state, game)
  assert(game ~= nil, "missing game")
  local ports = _resolve_ports(state)
  ports.reset_status_3d(state)
  state.game = game
  game.ui_port = state
  if type(state.on_tile_owner_changed) == "function" then
    game.tile_owner_notifier = {
      notify_owner_changed = function(_, tile_id, owner_id)
        state:on_tile_owner_changed(tile_id, owner_id)
      end,
    }
  elseif type(state.notify_owner_changed) == "function" then
    game.tile_owner_notifier = {
      notify_owner_changed = function(_, tile_id, owner_id)
        state:notify_owner_changed(tile_id, owner_id)
      end,
    }
  end
  paid_currency_bridge.setup_for_game(game)
  event_handlers.install(game, logger, state)
  logger.set_info_per_turn_limit(gameplay_rules.info_log_per_turn_limit)
  logger.set_info_turn_provider(function()
    return game.turn and game.turn.turn_count
  end)
  assert(game.pending_choice ~= nil, "missing game.pending_choice")
  local pending = game:pending_choice()
  state.pending_choice = pending
  if pending then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = pending.id
    local model = ports.build_model(state, game)
    state.ui_model = model
    if model.choice then
      ports.open_choice_modal(state, model.choice, model.market)
    end
  end
  state.player_units = nil
  state.player_units_missing = false
  state.ui_dirty = true
  state.countdown_last = nil
  state.countdown_active_last = nil
  if state.ui then
    state.ui.input_blocked = false
  end
  if state.ai_turn_runner then
    state.ai_turn_runner:set_enabled(true)
    state.ai_turn_runner:reset_timer()
  end
  if state.auto_runner then
    state.auto_runner:set_enabled(true)
    state.auto_runner:reset_timer()
  end
  state.ai_turn_runner_active = false
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
  if state.ui and state.ui.input_blocked then
    return nil
  end
  local min_popup_visible = gameplay_rules.auto_popup_min_visible_seconds or 0
  if min_popup_visible > 0 and state.ui and state.ui.popup_active then
    if _is_auto_popup_owner(game, state) then
      local elapsed = state.ui_modal_elapsed or 0
      if elapsed < min_popup_visible then
        return nil
      end
    end
  end
  local ctx = _build_auto_context(game, context)
  local auto_action = state.auto_runner:next_action(dt, ctx)
  if auto_action and auto_action.type == "ui_button" and not auto_action.actor_role_id then
    auto_action.actor_role_id = ctx.current_player_index
  end
  if auto_action then
    _dispatch_action_with_close_choice(game, state, auto_action, ports)
  end
  return auto_action
end

function gameplay_loop.step_ai_turn_runner(game, state, dt, context)
  assert(game ~= nil, "missing game")
  local ports = _resolve_ports(state)
  local runner = state and state.ai_turn_runner or nil
  if not runner then
    return nil
  end
  if not runner.enabled then
    runner:set_enabled(true)
  end
  if state.ui and state.ui.input_blocked then
    if state.ai_turn_runner_active then
      runner:reset_timer()
      state.ai_turn_runner_active = false
    end
    return nil
  end
  if not _is_auto_player_turn(game) then
    if state.ai_turn_runner_active then
      runner:reset_timer()
      state.ai_turn_runner_active = false
    end
    return nil
  end
  if not state.ai_turn_runner_active then
    state.ai_turn_runner_active = true
    runner:reset_timer()
  end

  local min_popup_visible = gameplay_rules.auto_popup_min_visible_seconds or 0
  if min_popup_visible > 0 and state.ui and state.ui.popup_active then
    if _is_auto_popup_owner(game, state) then
      local elapsed = state.ui_modal_elapsed or 0
      if elapsed < min_popup_visible then
        return nil
      end
    end
  end

  local ctx = _build_auto_context(game, context)
  ctx.current_player_auto = true
  local ai_action = runner:next_action(dt, ctx)
  if ai_action and ai_action.type == "ui_button" and not ai_action.actor_role_id then
    ai_action.actor_role_id = ctx.current_player_index
  end
  if ai_action then
    _dispatch_action_with_close_choice(game, state, ai_action, ports)
  end
  return ai_action
end

function gameplay_loop.tick(game, state, dt)
  if not game then
    return
  end

  local ports = _resolve_ports(state)
  local phase = game.turn.phase
  local input_blocked_changed = _sync_input_blocked(state, phase)

  local auto_ctx = {
    modal_active = false,
    modal_buttons = nil,
    game_finished = game.finished,
    current_player_index = game.turn and game.turn.current_player_index or nil,
    current_player_auto = (function()
      local idx = game.turn and game.turn.current_player_index or nil
      local player = idx and game.players and game.players[idx] or nil
      return player and player.auto == true or false
    end)(),
  }
  gameplay_loop.step_auto_runner(game, state, dt, auto_ctx)
  gameplay_loop.step_ai_turn_runner(game, state, dt, auto_ctx)

  ports.step_choice_timeout(game, state, dt)
  ports.step_modal_timeout(game, state, dt)
  _update_action_button_timer({
    game = game,
    state = state,
    dt = dt,
    ports = ports,
  })

  phase = game.turn.phase
  if _sync_input_blocked(state, phase) then
    input_blocked_changed = true
  end
  _step_phase_animation(game, state, phase, ports)
  _sync_phase_flags(state, phase)

  ports.update_countdown(game, state)

  local dirty = game:consume_dirty()
  local ui_refreshed = ports.refresh_from_dirty(game, state, dirty)
  ports.sync_status_3d(game, state, dirty)

  if state.ui and (input_blocked_changed or (state.ui.input_blocked and ui_refreshed)) then
    ports.apply_input_lock(state)
  end

  if state.ui_model then
    ports.log_status(state.ui_model)
  end

  ports.sync_debug_log(state)
end

return gameplay_loop
