local logger = require("src.util.logger")
local constants = require("src.config.constants")
local items_cfg = require("src.config.items")
local IntentDispatcher = require("src.util.intent_dispatcher")

local AdapterLayer = {}

function AdapterLayer.attach(layer, opts)
  opts = opts or {}
  layer.ui = opts.ui or layer.ui
  layer.game = nil
  layer.pending_choice = nil
  layer.pending_choice_elapsed = 0
  layer.pending_choice_id = nil
  layer.wait_move_anim = true
  layer.move_anim_seq = nil
  layer.move_anim_log_phase = nil
  layer.move_anim_log_seq = nil
  layer._tickables = nil
  layer._tickables_game = nil
  layer.item_name_by_id = {}
  layer.game_factory = opts.game_factory or layer.game_factory
  layer.auto_runner = opts.auto_runner or layer.auto_runner

  IntentDispatcher.on("need_choice", function(payload)
    if payload and payload.game == layer.game then
      layer.pending_choice = payload.choice
      layer.pending_choice_elapsed = 0
      layer.pending_choice_id = payload.choice.id
      if opts.on_need_choice then
        opts.on_need_choice(layer, payload.choice)
      end
    end
  end)
end

function AdapterLayer.set_game(layer, game, opts)
  layer.game = game
  if layer.game then
    layer.game.ui_port = layer
  end
  if opts and opts.on_set_game then
    opts.on_set_game(layer, game)
  end

  layer.pending_choice = layer.game:pending_choice()
  if layer.pending_choice then
    layer.pending_choice_elapsed = 0
    layer.pending_choice_id = layer.pending_choice.id
    if opts and opts.on_pending_choice then
      opts.on_pending_choice(layer, layer.pending_choice)
    end
  end
end

function AdapterLayer.build_item_index(layer)
  layer.item_name_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    layer.item_name_by_id[cfg.id] = cfg.name or tostring(cfg.id)
  end
end

function AdapterLayer.register_tickables(layer, tickables)
  if not (layer and layer.game and layer.game.add_tickable) then
    return
  end
  if layer._tickables_game == layer.game then
    return
  end
  layer._tickables_game = layer.game
  layer._tickables = tickables or {}
  for _, tickable in ipairs(layer._tickables) do
    layer.game:add_tickable(tickable)
  end
end

function AdapterLayer.new_game(layer, opts)
  logger.clear()
  assert(layer.game_factory, "game_factory not set")
  local g = layer.game_factory()
  AdapterLayer.build_item_index(layer)
  if layer.auto_runner and layer.auto_runner.reset_timer then
    layer.auto_runner:reset_timer()
  end
  g.logger.info("启动蛋仔大富翁，玩家数:", #g.players)
  if opts and opts.on_new_game then
    opts.on_new_game(layer, g)
  end
  return g
end

function AdapterLayer.step_auto_runner(layer, dt, context)
  if not (layer.game and layer.auto_runner) then
    return nil
  end
  local ctx = context or {}
  if ctx.game_finished == nil then
    ctx.game_finished = layer.game and layer.game.finished
  end
  local auto_action = layer.auto_runner:next_action(dt, ctx)
  if auto_action then
    layer:dispatch_action(auto_action)
  end
  return auto_action
end

function AdapterLayer.step_choice_timeout(layer, dt, opts)
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    layer.pending_choice_elapsed = 0
    layer.pending_choice_id = nil
    return
  end

  if layer.game and layer.game.store then
    local pending = layer.game.store:get({ "turn", "pending_choice" })
    if pending and (not layer.pending_choice or layer.pending_choice.id ~= pending.id) then
      layer.pending_choice = pending
      layer.pending_choice_elapsed = 0
      layer.pending_choice_id = pending.id
      if opts and opts.on_pending_choice then
        opts.on_pending_choice(layer, pending)
      end
    elseif not pending then
      layer.pending_choice = nil
      layer.pending_choice_elapsed = 0
      layer.pending_choice_id = nil
    end
  end

  local active = false
  if opts and opts.is_choice_active then
    active = opts.is_choice_active(layer)
  else
    active = layer.pending_choice ~= nil
  end

  if not (active and layer.pending_choice) then
    layer.pending_choice_elapsed = 0
    layer.pending_choice_id = nil
    return
  end

  if layer.pending_choice_id ~= layer.pending_choice.id then
    layer.pending_choice_elapsed = 0
    layer.pending_choice_id = layer.pending_choice.id
  end

  layer.pending_choice_elapsed = layer.pending_choice_elapsed + dt
  if layer.pending_choice_elapsed >= timeout then
    local choice = layer.pending_choice
    layer.pending_choice_elapsed = 0
    local action
    if opts and opts.build_action then
      action = opts.build_action(layer, choice)
    else
      local first = choice.options and choice.options[1]
      if first then
        action = { type = "choice_select", choice_id = choice.id, option_id = first.id or first }
      elseif choice.allow_cancel ~= false then
        action = { type = "choice_cancel", choice_id = choice.id }
      end
    end
    if action then
      layer:dispatch_action(action)
    end
  end
end

function AdapterLayer.clear_choice(layer, opts)
  layer.pending_choice = nil
  layer.pending_choice_elapsed = 0
  layer.pending_choice_id = nil
  if opts and opts.on_close_choice then
    opts.on_close_choice(layer)
  end
end

function AdapterLayer.step_move_anim(layer)
  if not (layer and layer.wait_move_anim and layer.game and layer.game.store) then
    return
  end

  local anim = layer.game.store:get({ "turn", "move_anim" })
  local phase = layer.game.store:get({ "turn", "phase" })
  local seq = anim and anim.seq or nil
  if phase ~= layer.move_anim_log_phase or seq ~= layer.move_anim_log_seq then
    logger.info("move_anim 观察 phase=", tostring(phase), " seq=", tostring(seq))
    layer.move_anim_log_phase = phase
    layer.move_anim_log_seq = seq
  end
  if not anim or not anim.seq then
    layer.move_anim_seq = nil
    return
  end

  if phase ~= "wait_move_anim" then
    layer.move_anim_seq = nil
    return
  end

  if layer.move_anim_seq == anim.seq then
    return
  end

  layer.move_anim_seq = anim.seq
  if layer.game and layer.game.dispatch_action then
    layer.game:dispatch_action({ type = "move_anim_done", seq = anim.seq })
  end
end

return AdapterLayer
