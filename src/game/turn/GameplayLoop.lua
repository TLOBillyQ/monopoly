local agent = require("src.game.game.Agent")
local constants = require("Config.Generated.Constants")
local items_cfg = require("Config.Generated.Items")
local event_handlers = require("src.ui.UIEventHandlers")
local ui_view = require("src.ui.UIView")
local ui_model = require("src.ui.UIModel")
local logger = require("src.core.Logger")

local gameplay_loop = {}

local next_turn_cooldown = 0.4

local function _build_log_prefix()
  return "[EggyAdapter]"
end

local function _log_once(state, level, key, ...)
  assert(state ~= nil, "missing state")
  assert(state._log_once ~= nil, "missing state._log_once")
  if state._log_once[key] then
    return
  end
  state._log_once[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
end

local function _log_status(view)
  assert(view ~= nil, "missing view")
  logger.info(
    _build_log_prefix(),
    "玩家:",
    tostring(view.current_player_name),
    "现金:",
    tostring(view.current_player_cash),
    "回合:",
    tostring(view.turn_count)
  )
end

local function _get_timestamp()
  assert(GameAPI ~= nil and GameAPI.get_timestamp ~= nil, "missing GameAPI.get_timestamp")
  local ts = GameAPI.get_timestamp()
  assert(type(ts) == "number", "invalid timestamp")
  return ts
end

local function _get_timestamp_diff_seconds(timestamp_1, timestamp_2)
  assert(GameAPI ~= nil and GameAPI.get_timestamp_diff ~= nil, "missing GameAPI.get_timestamp_diff")
  assert(type(timestamp_1) == "number" and type(timestamp_2) == "number", "invalid timestamps")
  return GameAPI.get_timestamp_diff(timestamp_1, timestamp_2)
end

local function _update_countdown(game, state)
  local timeout = constants.action_timeout_seconds or 0
  local seconds = 0
  if timeout > 0 then
    if state.pending_choice and state.pending_choice_elapsed then
      local remaining = timeout - state.pending_choice_elapsed
      if remaining < 0 then
        remaining = 0
      end
      seconds = math.ceil(remaining)
    elseif state.ui and state.ui.popup_active then
      local remaining = timeout - (state.ui_modal_elapsed or 0)
      if remaining < 0 then
        remaining = 0
      end
      seconds = math.ceil(remaining)
    end
  end
  if seconds ~= state.countdown_last then
    state.countdown_last = seconds
    assert(game.store ~= nil and game.store.set ~= nil, "missing game.store.set")
    game.store:set({ "turn", "countdown_seconds" }, seconds)
  end
end

local function _is_only_turn_countdown(dirty)
  if not dirty or dirty.turn_countdown ~= true then
    return false
  end
  if dirty.players or dirty.board_tiles or dirty.turn or dirty.market or dirty.ui then
    return false
  end
  if dirty.inventory_ids then
    for _ in pairs(dirty.inventory_ids) do
      return false
    end
  end
  return true
end

local function _build_item_index(state)
  state.item_name_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    state.item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
  end
end

local function _build_ui_env(state, game)
  local winner = game.winner
  local winner_name = game.winner_names or (winner and assert(winner.name, "missing winner name"))
  return {
    game = game,
    ui_state = state,
    last_turn = game.last_turn,
    finished = game.finished,
    winner_name = winner_name,
  }
end

local function _build_ui_model(state, game)
  local store_state = game.store.state
  return ui_model.build(store_state, _build_ui_env(state, game))
end

local function _refresh_view(state, game, next_model)
  local store_state = game.store.state
  local ui_model = next_model
  state.ui_model = ui_model
  ui_view.render(state, ui_model, _log_once, _build_log_prefix)

  assert(ui_model ~= nil, "missing ui_model")
  local players = assert(store_state.players, "missing store_state.players")
  local turn = assert(store_state.turn, "missing store_state.turn")
  local current_index = assert(turn.current_player_index, "missing current_player_index")
  local current = assert(players[current_index], "missing current player: " .. tostring(current_index))
  local current_id = assert(current.id, "missing current player id")
  assert(GameAPI ~= nil and GameAPI.get_role ~= nil, "missing GameAPI.get_role")
  local role = assert(GameAPI.get_role(current_id), "missing role: " .. tostring(current_id))
  if state.camera_follow_player_id ~= current_id then
    state.camera_follow_player_id = current_id
    assert(role.set_camera_bind_mode ~= nil, "missing role.set_camera_bind_mode")
    role.set_camera_bind_mode(Enums.CameraBindMode.TRACK)
  end

  assert(state.player_units ~= nil, "missing state.player_units")
  local unit = assert(state.player_units[current_id], "missing player unit: " .. tostring(current_id))
  assert(unit.get_position ~= nil, "missing unit.get_position: " .. tostring(current_id))
  local target_pos = assert(unit.get_position(), "missing target position: " .. tostring(current_id))
  assert(role.set_camera_lock_position ~= nil, "missing role.set_camera_lock_position")
  role.set_camera_lock_position(target_pos)
  return ui_model
end

function gameplay_loop.set_game(state, game)
  assert(game ~= nil, "missing game")
  game.ui_port = state
  event_handlers.install(game, logger, state)
  assert(game.pending_choice ~= nil, "missing game.pending_choice")
  local pending = game:pending_choice()
  state.pending_choice = pending
  if pending then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = pending.id
    local ui_model = _build_ui_model(state, game)
    state.ui_model = ui_model
    if ui_model.choice then
      ui_view.open_choice_modal(state, ui_model.choice, ui_model.market)
    end
  end
  state.player_units = nil
  state.player_units_missing = false
  state.ui_dirty = true
  state.countdown_last = nil
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

function gameplay_loop.clear_choice(state, opts)
  state.pending_choice = nil
  state.pending_choice_elapsed = 0
  state.pending_choice_id = nil
  assert(opts ~= nil and opts.on_close_choice ~= nil, "missing opts.on_close_choice")
  opts.on_close_choice(state)
end

function gameplay_loop.step_auto_runner(game, state, dt, context)
  assert(game ~= nil, "missing game")
  assert(state.auto_runner ~= nil, "missing auto_runner")
  local ctx = context or {}
  ctx.game_finished = game.finished
  local auto_action = state.auto_runner:next_action(dt, ctx)
  if auto_action then
    gameplay_loop.dispatch_action(game, state, auto_action)
  end
  return auto_action
end

function gameplay_loop.step_choice_timeout(game, state, dt, opts)
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    state.pending_choice_elapsed = 0
    state.pending_choice_id = nil
    return
  end

  assert(game ~= nil, "missing game")
  assert(game.store ~= nil, "missing game.store")
  assert(opts ~= nil, "missing opts")
  assert(opts.on_pending_choice ~= nil, "missing opts.on_pending_choice")
  assert(opts.is_choice_active ~= nil, "missing opts.is_choice_active")
  local pending = game.store:get({ "turn", "pending_choice" })
  if pending and (not state.pending_choice or state.pending_choice.id ~= pending.id) then
    state.pending_choice = pending
    state.pending_choice_elapsed = 0
    state.pending_choice_id = pending.id
    opts.on_pending_choice(state, pending)
  elseif not pending then
    state.pending_choice = nil
    state.pending_choice_elapsed = 0
    state.pending_choice_id = nil
  end

  local active = false
  active = opts.is_choice_active(state)

  if active and state.pending_choice then
  else
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
    assert(opts.build_action ~= nil, "missing opts.build_action")
    action = opts.build_action(game, state, choice)
    assert(action ~= nil, "missing timeout action")
    gameplay_loop.dispatch_action(game, state, action)
  end
end

function gameplay_loop.step_modal_timeout(state, dt, opts)
  local timeout = constants.action_timeout_seconds or 0
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

function gameplay_loop.step_move_anim(game, state, opts)
  assert(state.wait_move_anim == true, "move anim disabled")
  assert(game ~= nil, "missing game")
  assert(game.store ~= nil, "missing game.store")
  assert(opts ~= nil and opts.on_move_anim ~= nil, "missing opts.on_move_anim")

  local anim = game.store:get({ "turn", "move_anim" })
  local phase = game.store:get({ "turn", "phase" })
  assert(anim ~= nil and anim.seq ~= nil, "missing move_anim")

  assert(phase == "wait_move_anim", "unexpected move anim phase: " .. tostring(phase))

  if state.move_anim_seq == anim.seq then
    return
  end

  state.move_anim_seq = anim.seq
  local ok, delay = pcall(opts.on_move_anim, state, anim)
  if ok and delay and delay > 0 then
    SetTimeOut(delay, function()
      assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
      game:dispatch_action({ type = "move_anim_done", seq = anim.seq })
    end)
    return
  end
  assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
  game:dispatch_action({ type = "move_anim_done", seq = anim.seq })
end

function gameplay_loop.step_action_anim(game, state, opts)
  assert(state.wait_action_anim == true, "action anim disabled")
  assert(game ~= nil, "missing game")
  assert(game.store ~= nil, "missing game.store")
  assert(opts ~= nil and opts.on_action_anim ~= nil, "missing opts.on_action_anim")

  local anim = game.store:get({ "turn", "action_anim" })
  local phase = game.store:get({ "turn", "phase" })
  assert(anim ~= nil and anim.seq ~= nil, "missing action_anim")

  assert(phase == "wait_action_anim", "unexpected action anim phase: " .. tostring(phase))

  if state.action_anim_seq == anim.seq then
    return
  end

  state.action_anim_seq = anim.seq
  local ok, delay = pcall(opts.on_action_anim, state, anim)
  if ok and delay and delay > 0 then
    SetTimeOut(delay, function()
      assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
      game:dispatch_action({ type = "action_anim_done", seq = anim.seq })
    end)
    return
  end
  assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
  game:dispatch_action({ type = "action_anim_done", seq = anim.seq })
end

function gameplay_loop.step_turn(game, state)
  assert(game ~= nil, "missing game")
  assert(not game.finished, "game finished")
  game:advance_turn()
end

function gameplay_loop.dispatch_action(game, state, action, opts)
  assert(action ~= nil, "missing action")
  if action.type == "ui_button"
      or action.type == "choice_select"
      or action.type == "choice_cancel" then
    state.ui_dirty = true
  end
  if action.type == "ui_button" then
    local slot_index = action.id and string.match(action.id, "^item_slot_(%d+)$")
    if slot_index then
      slot_index = tonumber(slot_index)
      local choice = state.pending_choice
      assert(choice ~= nil and choice.kind == "item_phase_choice", "invalid item phase choice")
      assert(state.ui ~= nil, "missing state.ui")
      assert(state.ui.item_slot_item_ids ~= nil, "missing item_slot_item_ids")
      local item_id = assert(state.ui.item_slot_item_ids[slot_index], "missing item_id: " .. tostring(slot_index))
      local options = assert(choice.options, "missing choice options")
      local option_ok = false
      for _, opt in ipairs(options) do
        local opt_id = opt.id or opt
        if opt_id == item_id then
          option_ok = true
          break
        end
      end
      assert(option_ok, "invalid item option: " .. tostring(item_id))
      gameplay_loop.dispatch_action(game, state, { type = "choice_select", choice_id = choice.id, option_id = item_id })
      return
    end
    if action.id == "next" then
      local phase = nil
      assert(game ~= nil and game.store ~= nil, "missing game.store")
      assert(game.store.get ~= nil, "missing store.Get")
      phase = game.store:get({ "turn", "phase" })
      local now = _get_timestamp()
      if state.next_turn_locked then
        local allow = false
        if state.next_turn_lock_phase and phase and phase ~= state.next_turn_lock_phase then
          allow = true
        else
          assert(state.next_turn_last_click ~= nil, "missing next_turn_last_click")
          local diff = _get_timestamp_diff_seconds(now, state.next_turn_last_click)
          if diff and diff >= next_turn_cooldown then
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
      gameplay_loop.step_turn(game, state)
    elseif action.id == "auto" then
      state.ui.auto_play = not state.ui.auto_play
      state.auto_runner:set_enabled(state.ui.auto_play)
      state.auto_runner:reset_timer()
    elseif action.id == "restart" then
      local was_auto = state.ui.auto_play
      local new_game = gameplay_loop.new_game(state)
      gameplay_loop.set_game(state, new_game)
      if opts and opts.on_game_changed then
        opts.on_game_changed(new_game)
      end
      state.auto_runner:set_enabled(was_auto)
    end
  elseif action.type == "choice_select" or action.type == "choice_cancel" then
    gameplay_loop.clear_choice(state, {
      on_close_choice = function(ctx)
        ui_view.close_choice_modal(ctx)
      end,
    })
    if game then
      assert(game.dispatch_action ~= nil, "missing game.dispatch_action")
      game:dispatch_action(action)
    end
  end
end

function gameplay_loop.tick(game, state, dt)
  if not game then
    return
  end

  gameplay_loop.step_auto_runner(game, state, dt, {
    modal_active = false,
    modal_buttons = nil,
    game_finished = game.finished,
  })

  gameplay_loop.step_choice_timeout(game, state, dt, {
    on_pending_choice = function() end,
    is_choice_active = function(ctx)
      return ctx.pending_choice and true or false
    end,
    build_action = function(game_ctx, ctx, choice)
      local auto_choice = agent.auto_action_for_choice(game_ctx, choice)
      if auto_choice then
        return auto_choice
      end
      local options = assert(choice.options, "missing choice.options")
      local first = assert(options[1], "missing choice option")
      return {
        type = "choice_select",
        choice_id = choice.id,
        option_id = first.id or first,
      }
    end,
  })

  gameplay_loop.step_modal_timeout(state, dt, {
    is_active = function(ctx)
      return ctx.ui and ctx.ui.popup_active
    end,
    get_ref = function(ctx)
      assert(ctx.ui ~= nil, "missing ui")
      assert(ctx.ui.popup_active, "popup not active")
      return assert(ctx.ui.popup_seq, "missing popup_seq")
    end,
    on_timeout = function(ctx)
      ui_view.close_popup(ctx)
    end,
  })

  assert(game.store ~= nil and game.store.get ~= nil, "missing game.store.Get")
  local phase = game.store:get({ "turn", "phase" })
  if phase == "wait_move_anim" then
    local anim = game.store:get({ "turn", "move_anim" })
    if anim then
      gameplay_loop.step_move_anim(game, state, {
        on_move_anim = function(_, anim_ctx)
          assert(anim_ctx ~= nil, "missing anim")
          local player_id = assert(anim_ctx.player_id, "missing player_id")
          local from_index = assert(anim_ctx.from_index, "missing from_index")
          local to_index = assert(anim_ctx.to_index, "missing to_index")
          local dir = anim_ctx.direction
          if dir then
          elseif anim_ctx.steps and anim_ctx.steps < 0 then
            dir = v3_right
          elseif anim_ctx.steps and anim_ctx.steps > 0 then
            dir = v3_left
          end
          assert(dir, "missing anim.direction")
          local move_anim = require("src.ui.MoveAnim")
          return move_anim.one_step(state.board_scene, player_id, dir, from_index, to_index)
        end,
      })
    end
  elseif phase == "wait_action_anim" then
    local anim = game.store:get({ "turn", "action_anim" })
    if anim then
      gameplay_loop.step_action_anim(game, state, {
        on_action_anim = function(ctx, anim_ctx)
          local action_anim = require("src.ui.ActionAnim")
          return action_anim.play(ctx, anim_ctx)
        end,
      })
    end
  end

  if state.board_last_phase == "wait_move_anim" and phase ~= "wait_move_anim" then
    state.board_sync_pending = true
  end
  if state.next_turn_locked and state.next_turn_lock_phase and phase and phase ~= state.next_turn_lock_phase then
    state.next_turn_locked = false
    state.next_turn_lock_phase = phase
  end
  state.board_last_phase = phase

  _update_countdown(game, state)

  assert(game.store ~= nil and game.store.consume_dirty ~= nil, "missing game.store.consume_dirty")
  local dirty = game.store:consume_dirty()
  if state.ui_dirty then
    dirty.ui = true
  end
  local only_countdown = _is_only_turn_countdown(dirty)
  if dirty.any or dirty.ui then
    local store_state = game.store.state
    local env = _build_ui_env(state, game)
    local next_model = ui_model.update(state.ui_model, store_state, env, dirty)
    state.ui_model = next_model
    if only_countdown then
      ui_view.refresh_turn_label(state, next_model.panel and next_model.panel.turn_label or "")
    else
      _refresh_view(state, game, next_model)
      if next_model.choice then
        ui_view.open_choice_modal(state, next_model.choice, next_model.market)
      end
    end
    state.ui_dirty = false
  end

  if state.ui_model then
    _log_status(state.ui_model)
  end
end

return gameplay_loop

