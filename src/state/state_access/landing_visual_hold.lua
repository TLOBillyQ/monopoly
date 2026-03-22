local runtime_state = require("src.state.state_access.runtime_state")
local dirty_tracker = require("src.core.utils.dirty_tracker")

local landing_visual_hold = {}

local release_priority = {
  board_visual_sync = 1,
  runtime_event = 2,
  tile_update = 3,
  owner_change = 4,
  bankruptcy_clear = 5,
  popup = 6,
}

local function _new_dirty_bucket()
  return dirty_tracker.new()
end

local function _ensure_dirty_inventory_ids(hold)
  if type(hold.deferred_dirty) ~= "table" then
    hold.deferred_dirty = _new_dirty_bucket()
  end
  dirty_tracker.ensure_inventory_ids(hold.deferred_dirty)
end

local function _ensure_hold_buffers(hold)
  hold.release_callbacks = hold.release_callbacks or {}
end

local function _ensure_hold(state)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local hold = turn_runtime.landing_visual_hold
  if type(hold) ~= "table" then
    hold = {
      active = false,
      release_pending = false,
      flushing = false,
      frozen_ui_model = nil,
      deferred_dirty = _new_dirty_bucket(),
      release_callbacks = {},
    }
    turn_runtime.landing_visual_hold = hold
  end
  _ensure_dirty_inventory_ids(hold)
  _ensure_hold_buffers(hold)
  return hold
end

local function _merge_dirty_into(target, dirty)
  return dirty_tracker.merge_into(target, dirty)
end

local function _mark_turn_dirty(game)
  if not (game and game.dirty) then
    return
  end
  game.dirty.turn = true
  game.dirty.any = true
end

local function _reset_deferred_buffers(hold)
  hold.deferred_dirty = _new_dirty_bucket()
  hold.release_callbacks = {}
end

function landing_visual_hold.start(game, opts)
  local _ = opts
  if not (game and game.turn) then
    return false
  end
  if game.turn.landing_visual_hold_active == true then
    return false
  end
  game.turn.landing_visual_hold_active = true
  game.turn.landing_visual_release_pending = false
  local state = game.landing_visual_hold_state
  if type(state) == "table" then
    local hold = _ensure_hold(state)
    hold.active = true
    hold.release_pending = false
    local logger = require("src.core.utils.logger")
    logger.push_event_buffer(hold)
  end
  _mark_turn_dirty(game)
  return true
end

function landing_visual_hold.hold_state_for_game(game, opts)
  return landing_visual_hold.start(game, opts)
end

function landing_visual_hold.is_active_game(game)
  return game and game.turn and game.turn.landing_visual_hold_active == true or false
end

function landing_visual_hold.is_release_pending_game(game)
  return game and game.turn and game.turn.landing_visual_release_pending == true or false
end

function landing_visual_hold.mark_release_pending(game)
  if not (game and game.turn) then
    return false
  end
  if game.turn.landing_visual_hold_active ~= true then
    return false
  end
  game.turn.landing_visual_release_pending = true
  _mark_turn_dirty(game)
  return true
end

function landing_visual_hold.clear_game(game)
  if not (game and game.turn) then
    return false
  end
  local changed = game.turn.landing_visual_hold_active == true
    or game.turn.landing_visual_release_pending == true
  game.turn.landing_visual_hold_active = false
  game.turn.landing_visual_release_pending = false
  if changed then
    _mark_turn_dirty(game)
  end
  return changed
end

function landing_visual_hold.is_active_state(state)
  local hold = _ensure_hold(state)
  return hold.active == true
end

function landing_visual_hold.is_flushing_state(state)
  local hold = _ensure_hold(state)
  return hold.flushing == true
end

function landing_visual_hold.sync_state_from_game(state, game)
  local hold = _ensure_hold(state)
  local was_active = hold.active == true
  hold.active = landing_visual_hold.is_active_game(game)
  hold.release_pending = landing_visual_hold.is_release_pending_game(game)
  if hold.active == true and was_active ~= true then
    local logger = require("src.core.utils.logger")
    logger.push_event_buffer(hold)
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
  _merge_dirty_into(hold.deferred_dirty, dirty)
  return hold.deferred_dirty
end

function landing_visual_hold.register_release_callback(state, key, fn, opts)
  assert(type(fn) == "function", "missing release callback")
  local hold = _ensure_hold(state)
  opts = opts or {}
  hold.release_callbacks[#hold.release_callbacks + 1] = {
    key = key,
    fn = fn,
    order = #hold.release_callbacks + 1,
    priority = release_priority[key] or opts.priority or 100,
  }
  return fn
end

function landing_visual_hold.run_or_defer(state, game, key, fn, opts)
  if landing_visual_hold.should_defer(state, game) then
    landing_visual_hold.register_release_callback(state, key, fn, opts)
    return true
  end
  return fn()
end

local function _register_deferred_replay(state, key, replay, ...)
  local replay_args = { ... }
  return landing_visual_hold.register_release_callback(state, key, function()
    if type(replay) == "function" then
      return replay(table.unpack(replay_args))
    end
    return nil
  end)
end

function landing_visual_hold.defer_popup(state, payload, opts, replay)
  return _register_deferred_replay(state, "popup", replay, payload, opts)
end

function landing_visual_hold.defer_runtime_event(state, event_name, payload, replay)
  local _ = event_name
  return _register_deferred_replay(state, "runtime_event", replay, payload)
end

function landing_visual_hold.defer_board_visual_sync(state, payload, replay)
  return _register_deferred_replay(state, "board_visual_sync", replay, payload)
end

function landing_visual_hold.defer_tile_update(state, tile_id, level, replay)
  return _register_deferred_replay(state, "tile_update", replay, tile_id, level)
end

function landing_visual_hold.defer_owner_change(state, tile_id, owner_id, replay)
  return _register_deferred_replay(state, "owner_change", replay, tile_id, owner_id)
end

function landing_visual_hold.defer_bankruptcy_clear(state, game, player, owned_tile_ids, replay)
  return _register_deferred_replay(state, "bankruptcy_clear", replay, game, player, owned_tile_ids)
end

local function _sort_release_callbacks(release_callbacks)
  table.sort(release_callbacks, function(left, right)
    if left.priority ~= right.priority then
      return left.priority < right.priority
    end
    return left.order < right.order
  end)
end

local function _replay_release_callbacks(hold)
  local logger = require("src.core.utils.logger")
  logger.flush_event_buffer(hold)
  _sort_release_callbacks(hold.release_callbacks)
  for _, entry in ipairs(hold.release_callbacks) do
    if type(entry.fn) == "function" then
      entry.fn()
    end
  end
end

local function _reset_release_state(hold)
  hold.frozen_ui_model = nil
  _reset_deferred_buffers(hold)
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
    _merge_dirty_into(game.dirty, hold.deferred_dirty)
  end

  landing_visual_hold.with_flushing(state, function()
    _replay_release_callbacks(hold)
  end)
  _reset_release_state(hold)

  runtime_state.set_ui_dirty(state, true)
  landing_visual_hold.clear_game(game)
  return true
end

function landing_visual_hold.reset_state(state)
  local hold = _ensure_hold(state)
  local logger = require("src.core.utils.logger")
  logger.pop_event_buffer(hold)
  hold.active = false
  hold.release_pending = false
  hold.flushing = false
  hold.frozen_ui_model = nil
  _reset_deferred_buffers(hold)
  return hold
end

function landing_visual_hold.merge_dirty(target, dirty)
  return _merge_dirty_into(target, dirty)
end

return landing_visual_hold
