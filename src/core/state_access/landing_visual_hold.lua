local runtime_state = require("src.core.state_access.runtime_state")

local landing_visual_hold = {}

local function _new_dirty_bucket()
  return {
    any = false,
    players = false,
    board_tiles = false,
    turn = false,
    market = false,
    turn_countdown = false,
    inventory_ids = {},
  }
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
      deferred_popups = {},
      deferred_runtime_events = {},
      deferred_board_visual_syncs = {},
      deferred_tile_updates = {},
      deferred_owner_changes = {},
      deferred_bankruptcy_clears = {},
    }
    turn_runtime.landing_visual_hold = hold
  end
  if type(hold.deferred_dirty) ~= "table" then
    hold.deferred_dirty = _new_dirty_bucket()
  end
  if type(hold.deferred_dirty.inventory_ids) ~= "table" then
    hold.deferred_dirty.inventory_ids = {}
  end
  hold.deferred_popups = hold.deferred_popups or {}
  hold.deferred_runtime_events = hold.deferred_runtime_events or {}
  hold.deferred_board_visual_syncs = hold.deferred_board_visual_syncs or {}
  hold.deferred_tile_updates = hold.deferred_tile_updates or {}
  hold.deferred_owner_changes = hold.deferred_owner_changes or {}
  hold.deferred_bankruptcy_clears = hold.deferred_bankruptcy_clears or {}
  return hold
end

local function _merge_dirty_into(target, dirty)
  if type(target) ~= "table" or type(dirty) ~= "table" then
    return target
  end
  if dirty.any then
    target.any = true
  end
  if dirty.players then
    target.players = true
  end
  if dirty.board_tiles then
    target.board_tiles = true
  end
  if dirty.turn then
    target.turn = true
  end
  if dirty.market then
    target.market = true
  end
  if dirty.turn_countdown then
    target.turn_countdown = true
  end
  if type(dirty.inventory_ids) == "table" then
    local inventory_ids = target.inventory_ids or {}
    target.inventory_ids = inventory_ids
    for player_id in pairs(dirty.inventory_ids) do
      inventory_ids[player_id] = true
    end
  end
  return target
end

local function _mark_turn_dirty(game)
  if not (game and game.dirty) then
    return
  end
  game.dirty.turn = true
  game.dirty.any = true
end

function landing_visual_hold.start(game)
  if not (game and game.turn) then
    return false
  end
  if game.turn.landing_visual_hold_active == true then
    return false
  end
  game.turn.landing_visual_hold_active = true
  game.turn.landing_visual_release_pending = false
  game.turn.landing_visual_wait_started = false
  game.turn.landing_visual_wait_seq = nil
  game.turn.landing_visual_wait_ready = false
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
  game.turn.landing_visual_wait_started = false
  game.turn.landing_visual_wait_seq = nil
  _mark_turn_dirty(game)
  return true
end

function landing_visual_hold.clear_game(game)
  if not (game and game.turn) then
    return false
  end
  local changed = game.turn.landing_visual_hold_active == true
    or game.turn.landing_visual_release_pending == true
    or game.turn.landing_visual_wait_started == true
    or game.turn.landing_visual_wait_seq ~= nil
    or game.turn.landing_visual_wait_ready == true
  game.turn.landing_visual_hold_active = false
  game.turn.landing_visual_release_pending = false
  game.turn.landing_visual_wait_started = false
  game.turn.landing_visual_wait_seq = nil
  game.turn.landing_visual_wait_ready = false
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

function landing_visual_hold.defer_popup(state, payload, opts, replay)
  local hold = _ensure_hold(state)
  hold.deferred_popups[#hold.deferred_popups + 1] = {
    payload = payload,
    opts = opts,
    replay = replay,
  }
end

function landing_visual_hold.defer_runtime_event(state, event_name, payload, replay)
  local hold = _ensure_hold(state)
  hold.deferred_runtime_events[#hold.deferred_runtime_events + 1] = {
    event_name = event_name,
    payload = payload,
    replay = replay,
  }
end

function landing_visual_hold.defer_board_visual_sync(state, payload, replay)
  local hold = _ensure_hold(state)
  hold.deferred_board_visual_syncs[#hold.deferred_board_visual_syncs + 1] = {
    payload = payload,
    replay = replay,
  }
end

function landing_visual_hold.defer_tile_update(state, tile_id, level, replay)
  local hold = _ensure_hold(state)
  hold.deferred_tile_updates[#hold.deferred_tile_updates + 1] = {
    tile_id = tile_id,
    level = level,
    replay = replay,
  }
end

function landing_visual_hold.defer_owner_change(state, tile_id, owner_id, replay)
  local hold = _ensure_hold(state)
  hold.deferred_owner_changes[#hold.deferred_owner_changes + 1] = {
    tile_id = tile_id,
    owner_id = owner_id,
    replay = replay,
  }
end

function landing_visual_hold.defer_bankruptcy_clear(state, game, player, owned_tile_ids, replay)
  local hold = _ensure_hold(state)
  hold.deferred_bankruptcy_clears[#hold.deferred_bankruptcy_clears + 1] = {
    game = game,
    player = player,
    owned_tile_ids = owned_tile_ids,
    replay = replay,
  }
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
    local logger = require("src.core.utils.logger")
    logger.flush_event_buffer(hold)

    for _, entry in ipairs(hold.deferred_board_visual_syncs) do
      if type(entry.replay) == "function" then
        entry.replay(entry.payload)
      end
    end

    for _, entry in ipairs(hold.deferred_runtime_events) do
      if type(entry.replay) == "function" then
        entry.replay(entry.payload)
      end
    end
    for _, entry in ipairs(hold.deferred_tile_updates) do
      if type(entry.replay) == "function" then
        entry.replay(entry.tile_id, entry.level)
      end
    end
    for _, entry in ipairs(hold.deferred_owner_changes) do
      if type(entry.replay) == "function" then
        entry.replay(entry.tile_id, entry.owner_id)
      end
    end
    for _, entry in ipairs(hold.deferred_bankruptcy_clears) do
      if type(entry.replay) == "function" then
        entry.replay(entry.game, entry.player, entry.owned_tile_ids)
      end
    end
    for _, entry in ipairs(hold.deferred_popups) do
      if type(entry.replay) == "function" then
        entry.replay(entry.payload, entry.opts)
      end
    end
  end)

  hold.frozen_ui_model = nil
  hold.deferred_dirty = _new_dirty_bucket()
  hold.deferred_popups = {}
  hold.deferred_runtime_events = {}
  hold.deferred_board_visual_syncs = {}
  hold.deferred_tile_updates = {}
  hold.deferred_owner_changes = {}
  hold.deferred_bankruptcy_clears = {}

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
  hold.deferred_dirty = _new_dirty_bucket()
  hold.deferred_popups = {}
  hold.deferred_runtime_events = {}
  hold.deferred_board_visual_syncs = {}
  hold.deferred_tile_updates = {}
  hold.deferred_owner_changes = {}
  hold.deferred_bankruptcy_clears = {}
  return hold
end

function landing_visual_hold.merge_dirty(target, dirty)
  return _merge_dirty_into(target, dirty)
end

return landing_visual_hold
