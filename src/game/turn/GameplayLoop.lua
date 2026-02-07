local agent = require("src.game.game.Agent")
local items_cfg = require("Config.Generated.Items")
local gameplay_rules = require("Config.GameplayRules")
local event_handlers = require("src.ui.UIEventHandlers")
local ui_view = require("src.ui.UIView")
local logger = require("src.core.Logger")
local turn_dispatch = require("src.game.turn.TurnDispatch")
local turn_anim = require("src.game.turn.TurnAnim")
local store_paths = require("src.core.StorePaths")
local tick_timeout = require("src.game.turn.TickTimeout")
local tick_ui_sync = require("src.game.turn.TickUISync")
local move_anim = require("src.ui.MoveAnim")

local gameplay_loop = {}

local function _dispatch_action_with_close_choice(game, state, action)
  turn_dispatch.dispatch_action(game, state, action, {
    on_close_choice = function(ctx)
      ui_view.close_choice_modal(ctx)
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

local function _step_phase_animation(game, state, store, phase)
  if phase == "wait_move_anim" then
    local anim_data = store:get(store_paths.turn.move_anim)
    if not anim_data then
      return
    end
    turn_anim.step_move_anim(game, state, {
      on_move_anim = function(_, anim_ctx)
        return move_anim.play_sequence(state.board_scene, anim_ctx)
      end,
    })
    return
  end
  if phase == "wait_action_anim" then
    local anim_data = store:get(store_paths.turn.action_anim)
    if not anim_data then
      return
    end
    turn_anim.step_action_anim(game, state, {
      on_action_anim = function(ctx, anim_ctx)
        local action_anim_player = require("src.ui.ActionAnim")
        return action_anim_player.play(ctx, anim_ctx)
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

function gameplay_loop.set_game(state, game)
  assert(game ~= nil, "missing game")
  state.game = game
  game.ui_port = state
  event_handlers.install(game, logger, state)
  logger.set_info_per_turn_limit(gameplay_rules.info_log_per_turn_limit)
  logger.set_info_turn_provider(function()
    return game.store and game.store.state and game.store.state.turn and game.store.state.turn.turn_count
  end)
  assert(game.pending_choice ~= nil, "missing game.pending_choice")
  local pending = game:pending_choice()
  state.pending_choice = pending
  if pending then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = pending.id
    local model = tick_ui_sync.build_model(state, game)
    state.ui_model = model
    if model.choice then
      ui_view.open_choice_modal(state, model.choice, model.market)
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
end

function gameplay_loop.new_game(state)
  logger.clear()
  assert(state.game_factory, "game_factory not set")
  local game = state.game_factory()
  _build_item_index(state)
  assert(state.auto_runner ~= nil, "missing auto_runner")
  assert(state.auto_runner.reset_timer ~= nil, "missing auto_runner.ResetTimer")
  state.auto_runner:reset_timer()
  game.logger.info("启动蛋仔大富翁，玩家数:", #game.players)
  return game
end

function gameplay_loop.restart_game(state, opts)
  local was_auto = state.ui.auto_play
  local new_game = gameplay_loop.new_game(state)
  gameplay_loop.set_game(state, new_game)
  if opts and opts.on_game_changed then
    opts.on_game_changed(new_game)
  end
  state.auto_runner:set_enabled(was_auto)
  return new_game
end

function gameplay_loop.step_auto_runner(game, state, dt, context)
  assert(game ~= nil, "missing game")
  assert(state.auto_runner ~= nil, "missing auto_runner")
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
  local ctx = context or {}
  ctx.game_finished = game.finished
  local auto_action = state.auto_runner:next_action(dt, ctx)
  if auto_action then
    _dispatch_action_with_close_choice(game, state, auto_action)
  end
  return auto_action
end

function gameplay_loop.dispatch_action(game, state, action, opts)
  local merged_opts = opts
  if not merged_opts or not merged_opts.on_restart then
    merged_opts = {}
    if opts then
      for key, value in pairs(opts) do
        merged_opts[key] = value
      end
    end
    merged_opts.on_restart = function(_, ctx_state, _, dispatch_opts)
      gameplay_loop.restart_game(ctx_state or state, dispatch_opts or merged_opts)
    end
  end
  turn_dispatch.dispatch_action(game, state, action, merged_opts)
end

function gameplay_loop.tick(game, state, dt)
  if not game then
    return
  end

  local store = assert(game.store, "missing game.store")
  assert(store.get ~= nil, "missing game.store.get")
  local phase = store:get(store_paths.turn.phase)
  local input_blocked_changed = _sync_input_blocked(state, phase)

  gameplay_loop.step_auto_runner(game, state, dt, {
    modal_active = false,
    modal_buttons = nil,
    game_finished = game.finished,
  })

  tick_timeout.step_default_choice(game, state, dt)
  tick_timeout.step_default_modal(game, state, dt)

  phase = store:get(store_paths.turn.phase)
  if _sync_input_blocked(state, phase) then
    input_blocked_changed = true
  end
  _step_phase_animation(game, state, store, phase)
  _sync_phase_flags(state, phase)

  tick_ui_sync.update_countdown(game, state)

  assert(store.consume_dirty ~= nil, "missing game.store.consume_dirty")
  local dirty = store:consume_dirty()
  local ui_refreshed = tick_ui_sync.refresh_from_dirty(game, state, store, dirty)

  if state.ui and (input_blocked_changed or (state.ui.input_blocked and ui_refreshed)) then
    ui_view.apply_input_lock(state)
  end

  if state.ui_model then
    tick_ui_sync.log_status(state.ui_model)
  end

  tick_ui_sync.sync_debug_log_panel(state)
end

return gameplay_loop
