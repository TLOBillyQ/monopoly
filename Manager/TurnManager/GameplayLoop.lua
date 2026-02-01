local Agent = require("Manager.GameManager.Agent")
local constants = require("Config.Generated.Constants")
local items_cfg = require("Config.Generated.Items")
local EventHandlers = require("Manager.TurnManager.GUI.EventHandlers")
local MainView = require("Manager.TurnManager.GUI.MainView")
local Presenter = require("Manager.TurnManager.GUI.Presenter")
local logger = require("Components.Logger")

local GameplayLoop = {}

local NEXT_TURN_COOLDOWN = 0.4

local function build_log_prefix()
  return "[EggyAdapter]"
end

local function log_once(state, level, key, ...)
  if not state or not state._log_once or state._log_once[key] then
    return
  end
  state._log_once[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
end

local function log_status(view)
  if not view then
    return
  end
  logger.info(
    build_log_prefix(),
    "玩家:",
    tostring(view.current_player_name),
    "现金:",
    tostring(view.current_player_cash),
    "回合:",
    tostring(view.turn_count)
  )
end

local function get_timestamp()
  if not (GameAPI and GameAPI.get_timestamp) then
    return nil
  end
  local ts = GameAPI.get_timestamp()
  if type(ts) ~= "number" then
    return nil
  end
  return ts
end

local function get_timestamp_diff_seconds(timestamp_1, timestamp_2)
  if not (GameAPI and GameAPI.get_timestamp_diff) then
    return nil
  end
  if type(timestamp_1) ~= "number" or type(timestamp_2) ~= "number" then
    return nil
  end
  return GameAPI.get_timestamp_diff(timestamp_1, timestamp_2)
end

local function build_item_index(state)
  state.item_name_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    state.item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
  end
end

local function build_view(state, game)
  local store_state = game.store.state
  local winner_name = game.winner_names
  if not winner_name and game.winner then
    winner_name = game.winner.name
  end
  return Presenter.present(store_state, {
    game = game,
    last_turn = game.last_turn,
    finished = game.finished,
    winner_name = winner_name,
  })
end

local function refresh_view(state, game)
  local view = build_view(state, game)
  MainView.refresh_panel(state, view)
  MainView.refresh_board(state, view, log_once, build_log_prefix)

  local players = view and view.state and view.state.players or nil
  local turn = view and view.state and view.state.turn or nil
  local current_index = turn and turn.current_player_index or nil
  if players and current_index then
    local current = players[current_index]
    local current_id = current and (current.id or current_index) or nil
    if current_id then
      if state.camera_follow_player_id ~= current_id then
        state.camera_follow_player_id = current_id
        local role = GameAPI.get_role(current_id)
        role.set_camera_bind_mode(Enums.CameraBindMode.TRACK)
      end

      local target_pos = nil
      local unit = state.player_units and state.player_units[current_id] or nil
      if unit and unit.get_position then
        target_pos = unit.get_position()
      else
        local pos_idx = current and current.position or nil
        if pos_idx and state.tile_positions then
          target_pos = state.tile_positions[pos_idx]
        end
      end

      if target_pos and role and role.set_camera_lock_position then
        role.set_camera_lock_position(target_pos)
      end
    end
  end
end

function GameplayLoop.set_game(state, game)
  if game then
    game.ui_port = state
    EventHandlers.install(game, logger, state)
  end
  local pending = nil
  if game and game.pending_choice then
    pending = game:pending_choice()
  end
  state.pending_choice = pending
  if pending then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = pending.id
    MainView.open_choice_modal(state, pending)
  end
  state.player_units = nil
  state.player_units_missing = false
end

function GameplayLoop.new_game(state)
  logger.clear()
  assert(state.game_factory, "game_factory not set")
  local game = state.game_factory()
  build_item_index(state)
  if state.auto_runner and state.auto_runner.reset_timer then
    state.auto_runner:reset_timer()
  end
  game.logger.info("启动蛋仔大富翁，玩家数:", #game.players)
  return game
end

function GameplayLoop.clear_choice(state, opts)
  state.pending_choice = nil
  state.pending_choice_elapsed = 0
  state.pending_choice_id = nil
  if opts and opts.on_close_choice then
    opts.on_close_choice(state)
  end
end

function GameplayLoop.step_auto_runner(game, state, dt, context)
  if not (game and state.auto_runner) then
    return nil
  end
  local ctx = context or {}
  if ctx.game_finished == nil then
    ctx.game_finished = game and game.finished
  end
  local auto_action = state.auto_runner:next_action(dt, ctx)
  if auto_action then
    GameplayLoop.dispatch_action(game, state, auto_action)
  end
  return auto_action
end

function GameplayLoop.step_choice_timeout(game, state, dt, opts)
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = nil
    return
  end

  if game and game.store then
    local pending = game.store:get({ "turn", "pending_choice" })
    if pending and (not state.pending_choice or state.pending_choice.id ~= pending.id) then
      state.pending_choice = pending
      state.pending_choice_elapsed = 0
      state.pending_choice_id = pending.id
      if opts and opts.on_pending_choice then
        opts.on_pending_choice(state, pending)
      end
    elseif not pending then
      state.pending_choice = nil
      state.pending_choice_elapsed = 0
      state.pending_choice_id = nil
    end
  end

  local active = false
  if opts and opts.is_choice_active then
    active = opts.is_choice_active(state)
  else
    active = state.pending_choice ~= nil
  end

  if not (active and state.pending_choice) then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = nil
    return
  end

  if state.pending_choice_id ~= state.pending_choice.id then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = state.pending_choice.id
  end

  state.pending_choice_elapsed = state.pending_choice_elapsed + dt
  if state.pending_choice_elapsed >= timeout then
    local choice = state.pending_choice
    state.pending_choice_elapsed = 0
    local action
    if opts and opts.build_action then
      action = opts.build_action(game, state, choice)
    else
      local first = choice.options and choice.options[1]
      if first then
        action = { type = "choice_select", choice_id = choice.id, option_id = first.id or first }
      elseif choice.allow_cancel ~= false then
        action = { type = "choice_cancel", choice_id = choice.id }
      end
    end
    if action then
      GameplayLoop.dispatch_action(game, state, action)
    end
  end
end

function GameplayLoop.step_modal_timeout(state, dt, opts)
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    state.ui_modal_elapsed = 0
    state.ui_modal_ref = nil
    return
  end
  if not (opts and opts.is_active and opts.on_timeout) then
    return
  end
  if not opts.is_active(state) then
    state.ui_modal_elapsed = 0
    state.ui_modal_ref = nil
    return
  end
  local ref = opts.get_ref and opts.get_ref(state) or true
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

function GameplayLoop.step_move_anim(game, state, opts)
  if not (state.wait_move_anim and game and game.store) then
    return
  end

  local anim = game.store:get({ "turn", "move_anim" })
  local phase = game.store:get({ "turn", "phase" })
  if not anim or not anim.seq then
    state.move_anim_seq = nil
    return
  end

  if phase ~= "wait_move_anim" then
    state.move_anim_seq = nil
    return
  end

  if state.move_anim_seq == anim.seq then
    return
  end

  state.move_anim_seq = anim.seq
  if opts and opts.on_move_anim then
    local ok, delay = pcall(opts.on_move_anim, state, anim)
    if ok and delay and delay > 0 then
      SetTimeOut(delay, function()
        if game and game.dispatch_action then
          game:dispatch_action({ type = "move_anim_done", seq = anim.seq })
        end
      end)
      return
    end
  end
  if game and game.dispatch_action then
    game:dispatch_action({ type = "move_anim_done", seq = anim.seq })
  end
end

function GameplayLoop.step_action_anim(game, state, opts)
  if not (state.wait_action_anim and game and game.store) then
    return
  end

  local anim = game.store:get({ "turn", "action_anim" })
  local phase = game.store:get({ "turn", "phase" })
  if not anim or not anim.seq then
    state.action_anim_seq = nil
    return
  end

  if phase ~= "wait_action_anim" then
    state.action_anim_seq = nil
    return
  end

  if state.action_anim_seq == anim.seq then
    return
  end

  state.action_anim_seq = anim.seq
  if opts and opts.on_action_anim then
    local ok, delay = pcall(opts.on_action_anim, state, anim)
    if ok and delay and delay > 0 then
      SetTimeOut(delay, function()
        if game and game.dispatch_action then
          game:dispatch_action({ type = "action_anim_done", seq = anim.seq })
        end
      end)
      return
    end
  end
  if game and game.dispatch_action then
    game:dispatch_action({ type = "action_anim_done", seq = anim.seq })
  end
end

function GameplayLoop.step_turn(game, state)
  if not game or game.finished then
    return
  end
  print("[debug] step_turn: advance_turn")
  game:advance_turn()
end

function GameplayLoop.dispatch_action(game, state, action, opts)
  if not action then
    return
  end
  if action.type == "ui_button" then
    local slot_index = action.id and string.match(action.id, "^item_slot_(%d+)$")
    if slot_index then
      slot_index = tonumber(slot_index)
      local choice = state.pending_choice
      if not (choice and choice.kind == "item_phase_choice") then
        return
      end
      local item_ids = state.ui and state.ui.item_slot_item_ids or nil
      local item_id = item_ids and item_ids[slot_index] or nil
      if not item_id then
        return
      end
      local options = choice.options or {}
      local option_ok = false
      for _, opt in ipairs(options) do
        local opt_id = opt.id or opt
        if opt_id == item_id then
          option_ok = true
          break
        end
      end
      if not option_ok then
        return
      end
      GameplayLoop.dispatch_action(game, state, { type = "choice_select", choice_id = choice.id, option_id = item_id })
      return
    end
    if action.id == "next" then
      print("[debug] dispatch ui_button next")
      local phase = nil
      local store = game and game.store
      if store and store.get then
        phase = store:get({ "turn", "phase" })
      end
      local now = get_timestamp()
      if state.next_turn_locked then
        local allow = false
        if state.next_turn_lock_phase and phase and phase ~= state.next_turn_lock_phase then
          allow = true
        elseif now and state.next_turn_last_click then
          local diff = get_timestamp_diff_seconds(now, state.next_turn_last_click)
          if diff and diff >= NEXT_TURN_COOLDOWN then
            allow = true
          end
        end
        if not allow then
          return
        end
      end
      state.next_turn_locked = true
      state.next_turn_last_click = now
      state.next_turn_lock_phase = phase
      GameplayLoop.step_turn(game, state)
    elseif action.id == "auto" then
      state.ui.auto_play = not state.ui.auto_play
      state.auto_runner:set_enabled(state.ui.auto_play)
      state.auto_runner:reset_timer()
    elseif action.id == "restart" then
      local was_auto = state.ui.auto_play
      local new_game = GameplayLoop.new_game(state)
      GameplayLoop.set_game(state, new_game)
      if opts and opts.on_game_changed then
        opts.on_game_changed(new_game)
      end
      state.auto_runner:set_enabled(was_auto)
    end
  elseif action.type == "choice_select" or action.type == "choice_cancel" then
    GameplayLoop.clear_choice(state, {
      on_close_choice = function(ctx)
        MainView.close_choice_modal(ctx)
      end,
    })
    if game then
      game:dispatch_action(action)
    end
  end
end

function GameplayLoop.tick(game, state, dt)
  if not game then
    return
  end

  GameplayLoop.step_auto_runner(game, state, dt, {
    modal_active = false,
    modal_buttons = nil,
    game_finished = game and game.finished,
  })

  GameplayLoop.step_choice_timeout(game, state, dt, {
    build_action = function(game_ctx, ctx, choice)
      local auto_choice = Agent.auto_action_for_choice(game_ctx, choice)
      if auto_choice then
        return auto_choice
      end
      local first = choice.options and choice.options[1]
      if first then
        return {
          type = "choice_select",
          choice_id = choice.id,
          option_id = first.id or first,
        }
      end
      if choice.allow_cancel ~= false then
        return { type = "choice_cancel", choice_id = choice.id }
      end
      return nil
    end,
  })

  GameplayLoop.step_modal_timeout(state, dt, {
    is_active = function(ctx)
      return ctx.ui and ctx.ui.popup_active
    end,
    get_ref = function(ctx)
      return ctx.ui and ctx.ui.popup_active and ctx.ui.popup_seq or nil
    end,
    on_timeout = function(ctx)
      MainView.close_popup(ctx)
    end,
  })

  GameplayLoop.step_move_anim(game, state, {
    on_move_anim = function(_, anim)
      if not anim then
        return nil
      end
      local player_id = anim.player_id
      local from_index = anim.from_index
      local to_index = anim.to_index
      if not (player_id and from_index and to_index) then
        return nil
      end
      local dir = anim.direction
      if not dir and anim.steps then
        if anim.steps < 0 then
          dir = V3_RIGHT
        elseif anim.steps > 0 then
          dir = V3_LEFT
        end
      end
      local MoveAnim = require("Manager.BoardManager.GUI.MoveAnim")
      return MoveAnim.one_step(player_id, dir, from_index, to_index)
    end,
  })

  GameplayLoop.step_action_anim(game, state, {
    on_action_anim = function(ctx, anim)
      local ActionAnim = require("Manager.BoardManager.GUI.ActionAnim")
      return ActionAnim.play(ctx, anim)
    end,
  })

  local store = game and game.store
  if store and store.get then
    local phase = store:get({ "turn", "phase" })
    if state.board_last_phase == "wait_move_anim" and phase ~= "wait_move_anim" then
      state.board_sync_pending = true
    end
    if state.next_turn_locked and state.next_turn_lock_phase and phase and phase ~= state.next_turn_lock_phase then
      state.next_turn_locked = false
      state.next_turn_lock_phase = phase
    end
    state.board_last_phase = phase
  end

  if state.pending_choice then
    MainView.open_choice_modal(state, state.pending_choice)
  end

  refresh_view(state, game)

  log_status(build_view(state, game))
end

return GameplayLoop


