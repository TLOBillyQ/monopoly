local runtime_state = require("src.state.runtime")
local deferred_dirty = require("src.state.visual_hold.deferred_dirty")
local release_scheduler = require("src.state.visual_hold.release_scheduler")
local event_log = require("src.state.event_log")

local landing_visual_hold = {}

local post_release_hook = nil

local function _ensure_hold(state)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local hold = turn_runtime.landing_visual_hold
  if type(hold) ~= "table" then
    hold = {
      active = false,
      release_pending = false,
      flushing = false,
      frozen_ui_model = nil,
      deferred_dirty = deferred_dirty.new_bucket(),
      release_callbacks = {},
    }
    turn_runtime.landing_visual_hold = hold
  end
  deferred_dirty.ensure_inventory_ids(hold)
  release_scheduler.ensure_buffers(hold)
  return hold
end

local function _mark_turn_dirty(game)
  if not (game and game.dirty) then
    return
  end
  game.dirty.turn = true
  game.dirty.any = true
end

local function _ensure_event_log_for_game(game)
  if type(game) ~= "table" then
    return nil
  end
  game.state = game.state or {}
  game.state.event_log = game.state.event_log or event_log.new()
  return game.state.event_log
end

local function _reset_deferred_buffers(hold)
  deferred_dirty.reset(hold)
  release_scheduler.reset(hold)
end

local function _game_turn(game)
  return game and game.turn or nil
end

local function _game_turn_active(game)
  local turn = _game_turn(game)
  return turn and turn.landing_visual_hold_active == true or false
end

local function _game_turn_release_pending(game)
  local turn = _game_turn(game)
  return turn and turn.landing_visual_release_pending == true or false
end

local function _project_hold_to_game(game, hold)
  local turn = _game_turn(game)
  if turn == nil then
    return
  end
  turn.landing_visual_hold_active = hold.active == true
  turn.landing_visual_release_pending = hold.release_pending == true
end

local function _hold_is_state_source(hold)
  return hold.source == "state"
end

local function _set_hold_state(state, active, release_pending, source)
  runtime_state.set_landing_visual_hold_active(state, active)
  runtime_state.set_landing_visual_release_pending(state, release_pending)
  runtime_state.set_landing_visual_hold_source(state, source)
  return _ensure_hold(state)
end

function landing_visual_hold.start(game, opts)
  local _ = opts
  if not (game and game.turn) then
    return false
  end
  local state = game.landing_visual_hold_state
  if landing_visual_hold.is_active_game(game) == true then
    if type(state) == "table" then
      local hold = _ensure_hold(state)
      local was_active = hold.active == true
      hold = _set_hold_state(state, true, false, "state")
      _project_hold_to_game(game, hold)
      if was_active ~= true then
        _ensure_event_log_for_game(game)
        event_log.push_buffer(game.state.event_log, hold)
      end
    end
    return false
  end
  if type(state) == "table" then
    local hold = _set_hold_state(state, true, false, "state")
    _project_hold_to_game(game, hold)
    _ensure_event_log_for_game(game)
    event_log.push_buffer(game.state.event_log, hold)
  else
    game.turn.landing_visual_hold_active = true
    game.turn.landing_visual_release_pending = false
  end
  _mark_turn_dirty(game)
  return true
end

landing_visual_hold.hold_state_for_game = landing_visual_hold.start

function landing_visual_hold.is_active_game(game)
  local state = game and game.landing_visual_hold_state or nil
  if type(state) == "table" then
    local hold = _ensure_hold(state)
    if _hold_is_state_source(hold) then
      return hold.active == true
    end
  end
  return _game_turn_active(game)
end

function landing_visual_hold.is_release_pending_game(game)
  local state = game and game.landing_visual_hold_state or nil
  if type(state) == "table" then
    local hold = _ensure_hold(state)
    if _hold_is_state_source(hold) then
      return hold.release_pending == true
    end
  end
  return _game_turn_release_pending(game)
end

function landing_visual_hold.mark_release_pending(game)
  if not (game and game.turn) then
    return false
  end
  if landing_visual_hold.is_active_game(game) ~= true then
    return false
  end
  local state = game.landing_visual_hold_state
  if type(state) == "table" then
    local hold = _set_hold_state(state, true, true, "state")
    _project_hold_to_game(game, hold)
  else
    game.turn.landing_visual_release_pending = true
  end
  _mark_turn_dirty(game)
  return true
end

function landing_visual_hold.clear_game(game)
  if not (game and game.turn) then
    return false
  end
  local changed = landing_visual_hold.is_active_game(game) == true
    or landing_visual_hold.is_release_pending_game(game) == true
  local state = game.landing_visual_hold_state
  if type(state) == "table" then
    local hold = _set_hold_state(state, false, false, "state")
    _project_hold_to_game(game, hold)
  else
    game.turn.landing_visual_hold_active = false
    game.turn.landing_visual_release_pending = false
  end
  if changed then
    _mark_turn_dirty(game)
  end
  return changed
end

landing_visual_hold.is_active_state = runtime_state.get_landing_visual_hold_active

function landing_visual_hold.is_flushing_state(state)
  local hold = _ensure_hold(state)
  return hold.flushing == true
end

function landing_visual_hold.sync_state_from_game(state, game)
  local hold = _ensure_hold(state)
  local was_active = hold.active == true
  if _hold_is_state_source(hold) then
    _project_hold_to_game(game, hold)
    if hold.active == true and was_active ~= true then
      _ensure_event_log_for_game(game)
      event_log.push_buffer(game.state.event_log, hold)
    end
    return hold
  end
  runtime_state.set_landing_visual_hold_active(state, _game_turn_active(game))
  runtime_state.set_landing_visual_release_pending(state, _game_turn_release_pending(game))
  runtime_state.set_landing_visual_hold_source(state, "game")
  if hold.active == true and was_active ~= true then
    _ensure_event_log_for_game(game)
    event_log.push_buffer(game.state.event_log, hold)
  end
  return hold
end

function landing_visual_hold.should_defer(state, game)
  if state == nil then
    return false
  end
  if game ~= nil then
    landing_visual_hold.sync_state_from_game(state, game)
  end
  return landing_visual_hold.is_active_state(state) and not landing_visual_hold.is_flushing_state(state)
end

function landing_visual_hold.capture_frozen_ui_model(state)
  local hold = _ensure_hold(state)
  if hold.frozen_ui_model ~= nil then
    return hold.frozen_ui_model
  end
  hold.frozen_ui_model = runtime_state.get_ui_model(state)
  return hold.frozen_ui_model
end

function landing_visual_hold.freeze_active_ui(state)
  local hold = _ensure_hold(state)
  if hold.active ~= true then
    return nil
  end
  return landing_visual_hold.capture_frozen_ui_model(state)
end

function landing_visual_hold.defer_dirty(state, dirty)
  local hold = _ensure_hold(state)
  return deferred_dirty.defer(hold, dirty)
end

function landing_visual_hold.register_release_callback(state, key, fn, opts)
  local hold = _ensure_hold(state)
  return release_scheduler.register(hold, key, fn, opts)
end

function landing_visual_hold.run_or_defer(state, game, key, fn, opts)
  if landing_visual_hold.should_defer(state, game) then
    landing_visual_hold.register_release_callback(state, key, fn, opts)
    return true
  end
  return fn()
end

function landing_visual_hold.defer_popup(state, payload, opts, replay)
  local hold = _ensure_hold(state)
  return release_scheduler.register_deferred_replay(hold, "popup", replay, payload, opts)
end

function landing_visual_hold.defer_runtime_event(state, event_name, payload, replay)
  local _ = event_name
  local hold = _ensure_hold(state)
  return release_scheduler.register_deferred_replay(hold, "runtime_event", replay, payload)
end

function landing_visual_hold.defer_board_visual_sync(state, payload, replay)
  local hold = _ensure_hold(state)
  return release_scheduler.register_deferred_replay(hold, "board_visual_sync", replay, payload)
end

function landing_visual_hold.defer_tile_update(state, tile_id, level, replay)
  local hold = _ensure_hold(state)
  return release_scheduler.register_deferred_replay(hold, "tile_update", replay, tile_id, level)
end

function landing_visual_hold.defer_owner_change(state, tile_id, owner_id, replay)
  local hold = _ensure_hold(state)
  return release_scheduler.register_deferred_replay(hold, "owner_change", replay, tile_id, owner_id)
end

function landing_visual_hold.defer_bankruptcy_clear(state, game, player, owned_tile_ids, replay)
  local hold = _ensure_hold(state)
  return release_scheduler.register_deferred_replay(hold, "bankruptcy_clear", replay, game, player, owned_tile_ids)
end

function landing_visual_hold.with_flushing(state, fn)
  local hold = _ensure_hold(state)
  local previous = hold.flushing == true
  hold.flushing = true
  local ok, result_or_err = xpcall(fn, debug and debug.traceback or function(err)
    return err
  end)
  hold.flushing = previous
  if not ok then
    error(result_or_err)
  end
  return result_or_err
end

function landing_visual_hold.set_post_release_hook(fn)
  post_release_hook = fn
end

function landing_visual_hold.release(state, game)
  if game == nil and state and state.turn then
    return landing_visual_hold.clear_game(state)
  end
  if state and game then
    landing_visual_hold.sync_state_from_game(state, game)
  end
  local hold = _ensure_hold(state)
  if hold.release_pending ~= true then
    return false
  end

  hold.release_pending = false
  hold.active = false

  if game and game.dirty then
    deferred_dirty.merge_into(game.dirty, hold.deferred_dirty)
  end

  landing_visual_hold.with_flushing(state, function()
    release_scheduler.replay(hold)
  end)
  hold.frozen_ui_model = nil
  _reset_deferred_buffers(hold)

  if type(post_release_hook) == "function" then
    post_release_hook()
  end

  runtime_state.set_ui_dirty(state, true)
  landing_visual_hold.clear_game(game)
  return true
end

function landing_visual_hold.reset_state(state)
  local hold = _ensure_hold(state)
  event_log.pop_buffer(hold)
  hold.active = false
  hold.release_pending = false
  hold.flushing = false
  hold.frozen_ui_model = nil
  hold.source = nil
  _reset_deferred_buffers(hold)
  return hold
end

function landing_visual_hold.merge_dirty(target, dirty)
  return deferred_dirty.merge_into(target, dirty)
end

return landing_visual_hold
