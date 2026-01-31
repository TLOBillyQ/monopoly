local Agent = require("Manager.GameManager.Agent")
local constants = require("Config.Generated.Constants")
local items_cfg = require("Config.Generated.Items")
local EventHandlers = require("Manager.System.EventHandlers")
local RuntimeUI = require("Manager.System.RuntimeUI")
local logger = require("Library.Monopoly.Logger")

local RuntimeLoop = {}

local NEXT_TURN_COOLDOWN = 0.4

local function build_log_prefix()
  return "[EggyAdapter]"
end

local function get_timestamp_seconds()
  if not (GameAPI and GameAPI.get_timestamp) then
    return nil
  end
  local ts = GameAPI.get_timestamp()
  if type(ts) ~= "number" then
    return nil
  end
  if ts > 10000000000 then
    return ts / 1000
  end
  return ts
end

local function build_item_index(runtime)
  runtime.item_name_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    runtime.item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
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

function RuntimeLoop.set_game(runtime, game)
  runtime.game = game
  if runtime.game then
    runtime.game.ui_port = runtime
    EventHandlers.install(runtime.game, logger, runtime)
  end
  local pending = nil
  if runtime.game and runtime.game.pending_choice then
    pending = runtime.game:pending_choice()
  end
  runtime.pending_choice = pending
  if pending then
    runtime.pending_choice_elapsed = 0
    runtime.pending_choice_id = pending.id
    RuntimeUI.open_choice_modal(runtime, pending)
  end
  runtime.player_units = nil
  runtime.player_units_missing = false
end

function RuntimeLoop.new_game(runtime)
  logger.clear()
  assert(runtime.game_factory, "game_factory not set")
  local game = runtime.game_factory()
  build_item_index(runtime)
  if runtime.auto_runner and runtime.auto_runner.reset_timer then
    runtime.auto_runner:reset_timer()
  end
  game.logger.info("启动蛋仔大富翁，玩家数:", #game.players)
  return game
end

function RuntimeLoop.clear_choice(runtime, opts)
  runtime.pending_choice = nil
  runtime.pending_choice_elapsed = 0
  runtime.pending_choice_id = nil
  if opts and opts.on_close_choice then
    opts.on_close_choice(runtime)
  end
end

function RuntimeLoop.step_auto_runner(runtime, dt, context)
  if not (runtime.game and runtime.auto_runner) then
    return nil
  end
  local ctx = context or {}
  if ctx.game_finished == nil then
    ctx.game_finished = runtime.game and runtime.game.finished
  end
  local auto_action = runtime.auto_runner:next_action(dt, ctx)
  if auto_action then
    RuntimeLoop.dispatch_action(runtime, auto_action)
  end
  return auto_action
end

function RuntimeLoop.step_choice_timeout(runtime, dt, opts)
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    runtime.pending_choice_elapsed = 0
    runtime.pending_choice_id = nil
    return
  end

  if runtime.game and runtime.game.store then
    local pending = runtime.game.store:get({ "turn", "pending_choice" })
    if pending and (not runtime.pending_choice or runtime.pending_choice.id ~= pending.id) then
      runtime.pending_choice = pending
      runtime.pending_choice_elapsed = 0
      runtime.pending_choice_id = pending.id
      if opts and opts.on_pending_choice then
        opts.on_pending_choice(runtime, pending)
      end
    elseif not pending then
      runtime.pending_choice = nil
      runtime.pending_choice_elapsed = 0
      runtime.pending_choice_id = nil
    end
  end

  local active = false
  if opts and opts.is_choice_active then
    active = opts.is_choice_active(runtime)
  else
    active = runtime.pending_choice ~= nil
  end

  if not (active and runtime.pending_choice) then
    runtime.pending_choice_elapsed = 0
    runtime.pending_choice_id = nil
    return
  end

  if runtime.pending_choice_id ~= runtime.pending_choice.id then
    runtime.pending_choice_elapsed = 0
    runtime.pending_choice_id = runtime.pending_choice.id
  end

  runtime.pending_choice_elapsed = runtime.pending_choice_elapsed + dt
  if runtime.pending_choice_elapsed >= timeout then
    local choice = runtime.pending_choice
    runtime.pending_choice_elapsed = 0
    local action
    if opts and opts.build_action then
      action = opts.build_action(runtime, choice)
    else
      local first = choice.options and choice.options[1]
      if first then
        action = { type = "choice_select", choice_id = choice.id, option_id = first.id or first }
      elseif choice.allow_cancel ~= false then
        action = { type = "choice_cancel", choice_id = choice.id }
      end
    end
    if action then
      RuntimeLoop.dispatch_action(runtime, action)
    end
  end
end

function RuntimeLoop.step_modal_timeout(runtime, dt, opts)
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    runtime.ui_modal_elapsed = 0
    runtime.ui_modal_ref = nil
    return
  end
  if not (opts and opts.is_active and opts.on_timeout) then
    return
  end
  if not opts.is_active(runtime) then
    runtime.ui_modal_elapsed = 0
    runtime.ui_modal_ref = nil
    return
  end
  local ref = opts.get_ref and opts.get_ref(runtime) or true
  if runtime.ui_modal_ref ~= ref then
    runtime.ui_modal_ref = ref
    runtime.ui_modal_elapsed = 0
  end
  runtime.ui_modal_elapsed = runtime.ui_modal_elapsed + (dt or 0)
  if runtime.ui_modal_elapsed >= timeout then
    runtime.ui_modal_elapsed = 0
    opts.on_timeout(runtime)
  end
end

function RuntimeLoop.step_move_anim(runtime, opts)
  if not (runtime.wait_move_anim and runtime.game and runtime.game.store) then
    return
  end

  local anim = runtime.game.store:get({ "turn", "move_anim" })
  local phase = runtime.game.store:get({ "turn", "phase" })
  if not anim or not anim.seq then
    runtime.move_anim_seq = nil
    return
  end

  if phase ~= "wait_move_anim" then
    runtime.move_anim_seq = nil
    return
  end

  if runtime.move_anim_seq == anim.seq then
    return
  end

  runtime.move_anim_seq = anim.seq
  if opts and opts.on_move_anim then
    local ok, delay = pcall(opts.on_move_anim, runtime, anim)
    if ok and delay and delay > 0 then
      LuaAPI.call_delay_time(delay, function()
        if runtime.game and runtime.game.dispatch_action then
          runtime.game:dispatch_action({ type = "move_anim_done", seq = anim.seq })
        end
      end)
      return
    end
  end
  if runtime.game and runtime.game.dispatch_action then
    runtime.game:dispatch_action({ type = "move_anim_done", seq = anim.seq })
  end
end

function RuntimeLoop.step_action_anim(runtime, opts)
  if not (runtime.wait_action_anim and runtime.game and runtime.game.store) then
    return
  end

  local anim = runtime.game.store:get({ "turn", "action_anim" })
  local phase = runtime.game.store:get({ "turn", "phase" })
  if not anim or not anim.seq then
    runtime.action_anim_seq = nil
    return
  end

  if phase ~= "wait_action_anim" then
    runtime.action_anim_seq = nil
    return
  end

  if runtime.action_anim_seq == anim.seq then
    return
  end

  runtime.action_anim_seq = anim.seq
  if opts and opts.on_action_anim then
    local ok, delay = pcall(opts.on_action_anim, runtime, anim)
    if ok and delay and delay > 0 then
      LuaAPI.call_delay_time(delay, function()
        if runtime.game and runtime.game.dispatch_action then
          runtime.game:dispatch_action({ type = "action_anim_done", seq = anim.seq })
        end
      end)
      return
    end
  end
  if runtime.game and runtime.game.dispatch_action then
    runtime.game:dispatch_action({ type = "action_anim_done", seq = anim.seq })
  end
end

function RuntimeLoop.step_turn(runtime)
  if not runtime.game or runtime.game.finished then
    return
  end
  print("[debug] step_turn: advance_turn")
  runtime.game:advance_turn()
end

function RuntimeLoop.dispatch_action(runtime, action)
  if not action then
    return
  end
  if action.type == "ui_button" then
    local slot_index = action.id and string.match(action.id, "^item_slot_(%d+)$")
    if slot_index then
      slot_index = tonumber(slot_index)
      local choice = runtime.pending_choice
      if not (choice and choice.kind == "item_phase_choice") then
        return
      end
      local item_ids = runtime.ui and runtime.ui.item_slot_item_ids or nil
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
      RuntimeLoop.dispatch_action(runtime, { type = "choice_select", choice_id = choice.id, option_id = item_id })
      return
    end
    if action.id == "next" then
      print("[debug] dispatch ui_button next")
      local phase = nil
      local store = runtime.game and runtime.game.store
      if store and store.get then
        phase = store:get({ "turn", "phase" })
      end
      local now = get_timestamp_seconds()
      if runtime.next_turn_locked then
        local allow = false
        if runtime.next_turn_lock_phase and phase and phase ~= runtime.next_turn_lock_phase then
          allow = true
        elseif now and runtime.next_turn_last_click
            and (now - runtime.next_turn_last_click) >= NEXT_TURN_COOLDOWN then
          allow = true
        end
        if not allow then
          return
        end
      end
      runtime.next_turn_locked = true
      runtime.next_turn_last_click = now
      runtime.next_turn_lock_phase = phase
      RuntimeLoop.step_turn(runtime)
    elseif action.id == "auto" then
      runtime.ui.auto_play = not runtime.ui.auto_play
      runtime.auto_runner:set_enabled(runtime.ui.auto_play)
      runtime.auto_runner:reset_timer()
    elseif action.id == "restart" then
      local was_auto = runtime.ui.auto_play
      RuntimeLoop.set_game(runtime, RuntimeLoop.new_game(runtime))
      runtime.auto_runner:set_enabled(was_auto)
    end
  elseif action.type == "choice_select" or action.type == "choice_cancel" then
    RuntimeLoop.clear_choice(runtime, {
      on_close_choice = function(ctx)
        RuntimeUI.close_choice_modal(ctx)
      end,
    })
    if runtime.game then
      runtime.game:dispatch_action(action)
    end
  end
end

function RuntimeLoop.tick(runtime, dt)
  if not runtime.game then
    return
  end

  RuntimeLoop.step_auto_runner(runtime, dt, {
    modal_active = false,
    modal_buttons = nil,
    game_finished = runtime.game and runtime.game.finished,
  })

  RuntimeLoop.step_choice_timeout(runtime, dt, {
    build_action = function(ctx, choice)
      local auto_choice = Agent.auto_action_for_choice(ctx.game, choice)
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

  RuntimeLoop.step_modal_timeout(runtime, dt, {
    is_active = function(ctx)
      return ctx.ui and ctx.ui.popup_active
    end,
    get_ref = function(ctx)
      return ctx.ui and ctx.ui.popup_active and ctx.ui.popup_seq or nil
    end,
    on_timeout = function(ctx)
      RuntimeUI.close_popup(ctx)
    end,
  })

  RuntimeLoop.step_move_anim(runtime, {
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

  RuntimeLoop.step_action_anim(runtime, {
    on_action_anim = function(ctx, anim)
      local ActionAnim = require("Manager.BoardManager.GUI.ActionAnim")
      return ActionAnim.play(ctx, anim)
    end,
  })

  local store = runtime.game and runtime.game.store
  if store and store.get then
    local phase = store:get({ "turn", "phase" })
    if runtime.board_last_phase == "wait_move_anim" and phase ~= "wait_move_anim" then
      runtime.board_sync_pending = true
    end
    if runtime.next_turn_locked and runtime.next_turn_lock_phase and phase and phase ~= runtime.next_turn_lock_phase then
      runtime.next_turn_locked = false
      runtime.next_turn_lock_phase = phase
    end
    runtime.board_last_phase = phase
  end

  if runtime.pending_choice then
    RuntimeUI.open_choice_modal(runtime, runtime.pending_choice)
  end

  RuntimeUI.refresh_view(runtime)

  log_status(RuntimeUI.build_view(runtime))
end

return RuntimeLoop
