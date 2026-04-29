local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local event_log = require("src.state.event_log")
local runtime_state = require("src.state.runtime_state")
local landing_visual_hold = require("src.state.landing_visual_hold")

local function _test_landing_visual_hold_defer_dirty_initializes_bucket_and_merges_inventory()
  local state = {}
  local dirty = {
    any = true,
    players = true,
    inventory_ids = {
      [1] = true,
      [2] = true,
    },
  }

  local deferred = landing_visual_hold.defer_dirty(state, dirty)
  assert(deferred.any == true and deferred.players == true, "defer_dirty should merge boolean dirty flags")
  assert(deferred.inventory_ids[1] == true and deferred.inventory_ids[2] == true,
    "defer_dirty should merge inventory_ids into initialized deferred bucket")
end

local function _test_landing_visual_hold_release_flushes_event_buffer_and_replays_deferred()
  local state = {}
  local game = {
    state = {
      event_log = event_log.new(),
    },
    dirty = {},
    turn = {
      landing_visual_hold_active = false,
      landing_visual_release_pending = false,
    },
  }

  local replayed_visual_syncs = {}
  local replayed_runtime_events = {}
  local replayed_popups = {}

  landing_visual_hold.start(game)
  landing_visual_hold.mark_release_pending(game)

  local hold = landing_visual_hold.sync_state_from_game(state, game)
  event_log.append(game.state.event_log, {
    kind = "test",
    text = "deferred event during hold",
  })

  landing_visual_hold.defer_board_visual_sync(state, { sync_data = true }, function(payload)
    replayed_visual_syncs[#replayed_visual_syncs + 1] = payload
  end)

  landing_visual_hold.defer_runtime_event(state, "test_event", { event_data = true }, function(payload)
    replayed_runtime_events[#replayed_runtime_events + 1] = payload
  end)

  landing_visual_hold.defer_popup(state, { popup_data = true }, { opt = 1 }, function(payload, opts)
    replayed_popups[#replayed_popups + 1] = { payload = payload, opts = opts }
  end)

  _assert_eq(#hold.release_callbacks, 3, "release should register all deferred callbacks")
  _assert_eq(hold.release_callbacks[1].key, "board_visual_sync", "visual sync should register first")
  _assert_eq(hold.release_callbacks[2].key, "runtime_event", "runtime event should register second")
  _assert_eq(hold.release_callbacks[3].key, "popup", "popup should register third")

  local released = landing_visual_hold.release(state, game)

  _assert_eq(released, true, "release should return true when release was pending")
  _assert_eq(#replayed_visual_syncs, 1, "release should replay deferred visual syncs")
  _assert_eq(replayed_visual_syncs[1].sync_data, true, "visual sync payload should be preserved")
  _assert_eq(#replayed_runtime_events, 1, "release should replay deferred runtime events")
  _assert_eq(replayed_runtime_events[1].event_data, true, "runtime event payload should be preserved")
  _assert_eq(#replayed_popups, 1, "release should replay deferred popups")
  _assert_eq(replayed_popups[1].payload.popup_data, true, "popup payload should be preserved")

  local text = event_log.get_text(game.state.event_log)
  assert(string.find(text, "deferred event during hold", 1, true) ~= nil, "release should flush event buffer")
end

local function _test_landing_visual_hold_release_orders_wrappers_by_priority()
  local state = {}
  local game = {
    dirty = {},
    turn = {
      landing_visual_hold_active = false,
      landing_visual_release_pending = false,
    },
  }
  local calls = {}

  landing_visual_hold.start(game)
  landing_visual_hold.mark_release_pending(game)
  local hold = landing_visual_hold.sync_state_from_game(state, game)

  landing_visual_hold.defer_popup(state, { name = "popup" }, nil, function(payload)
    calls[#calls + 1] = payload.name
  end)
  landing_visual_hold.defer_bankruptcy_clear(state, game, { id = 1 }, { 2 }, function(_, player)
    calls[#calls + 1] = "bankruptcy_" .. tostring(player.id)
  end)
  landing_visual_hold.defer_owner_change(state, 7, 8, function(tile_id, owner_id)
    calls[#calls + 1] = "owner_" .. tostring(tile_id) .. "_" .. tostring(owner_id)
  end)
  landing_visual_hold.defer_tile_update(state, 5, 6, function(tile_id, level)
    calls[#calls + 1] = "tile_" .. tostring(tile_id) .. "_" .. tostring(level)
  end)
  landing_visual_hold.defer_runtime_event(state, "evt", { name = "runtime" }, function(payload)
    calls[#calls + 1] = payload.name
  end)
  landing_visual_hold.defer_board_visual_sync(state, { name = "board" }, function(payload)
    calls[#calls + 1] = payload.name
  end)

  _assert_eq(#hold.release_callbacks, 6, "all wrapper helpers should register release callbacks")
  _assert_eq(landing_visual_hold.release(state, game), true, "release should flush deferred callbacks")
  _assert_eq(table.concat(calls, ","), "board,runtime,tile_5_6,owner_7_8,bankruptcy_1,popup",
    "release should replay wrapper callbacks in configured priority order")
end

local function _test_landing_visual_hold_release_skips_when_not_pending()
  local state = {}
  local game = {
    dirty = {},
    turn = {
      landing_visual_hold_active = false,
      landing_visual_release_pending = false,
    },
  }

  landing_visual_hold.start(game)

  local released = landing_visual_hold.release(state, game)
  _assert_eq(released, false, "release should return false when release_pending is false")
end

local function _test_landing_visual_hold_start_repairs_attached_state_when_game_is_already_active()
  local state = {}
  local game = {
    dirty = {},
    turn = {
      landing_visual_hold_active = true,
      landing_visual_release_pending = false,
    },
    landing_visual_hold_state = state,
  }
  local hold = runtime_state.ensure_turn_runtime(state).landing_visual_hold

  _assert_eq(hold.active, false, "precondition should start with inactive hold state")

  local started = landing_visual_hold.start(game)

  _assert_eq(started, false, "start should stay idempotent when game is already active")
  _assert_eq(hold.active, true, "start should repair the attached hold state when game is already active")
  _assert_eq(hold.release_pending, false, "start should keep release pending cleared on the attached hold state")
end

local function _test_landing_visual_hold_mark_release_pending_repairs_attached_state()
  local state = {}
  local game = {
    dirty = {},
    turn = {
      landing_visual_hold_active = true,
      landing_visual_release_pending = false,
    },
    landing_visual_hold_state = state,
  }
  local hold = landing_visual_hold.sync_state_from_game(state, game)

  _assert_eq(hold.active, true, "precondition should sync active hold state")
  _assert_eq(hold.release_pending, false, "precondition should start without release pending")

  local marked = landing_visual_hold.mark_release_pending(game)

  _assert_eq(marked, true, "mark_release_pending should accept an active hold")
  _assert_eq(hold.release_pending, true, "mark_release_pending should repair the attached hold state")
end

local function _test_landing_visual_hold_clear_game_repairs_attached_state()
  local state = {}
  local game = {
    dirty = {},
    turn = {
      landing_visual_hold_active = true,
      landing_visual_release_pending = true,
    },
    landing_visual_hold_state = state,
  }
  local hold = landing_visual_hold.sync_state_from_game(state, game)

  _assert_eq(hold.active, true, "precondition should sync active hold state")
  _assert_eq(hold.release_pending, true, "precondition should sync release pending hold state")

  local cleared = landing_visual_hold.clear_game(game)

  _assert_eq(cleared, true, "clear_game should report a changed hold")
  _assert_eq(hold.active, false, "clear_game should clear the attached hold state")
  _assert_eq(hold.release_pending, false, "clear_game should clear release pending on the attached hold state")
end

local function _test_landing_visual_hold_state_wins_over_stale_game_turn_flags()
  local state = {}
  local game = {
    dirty = {},
    turn = {
      landing_visual_hold_active = false,
      landing_visual_release_pending = false,
    },
    landing_visual_hold_state = state,
  }
  local hold = runtime_state.ensure_turn_runtime(state).landing_visual_hold

  landing_visual_hold.start(game)
  landing_visual_hold.mark_release_pending(game)

  _assert_eq(hold.active, true, "precondition should activate the attached hold state")
  _assert_eq(hold.release_pending, true, "precondition should mark the attached hold state for release")

  game.turn.landing_visual_hold_active = false
  game.turn.landing_visual_release_pending = false

  local synced = landing_visual_hold.sync_state_from_game(state, game)

  _assert_eq(synced.active, true, "sync_state_from_game should keep the attached hold state authoritative")
  _assert_eq(synced.release_pending, true, "sync_state_from_game should keep release pending on the attached hold state")
  _assert_eq(game.turn.landing_visual_hold_active, true, "sync_state_from_game should repair stale game hold flags")
  _assert_eq(game.turn.landing_visual_release_pending, true, "sync_state_from_game should repair stale release flags")
end

return {
  { name = "landing_visual_hold_defer_dirty_initializes_bucket_and_merges_inventory", run = _test_landing_visual_hold_defer_dirty_initializes_bucket_and_merges_inventory },
  { name = "landing_visual_hold_release_flushes_event_buffer_and_replays_deferred", run = _test_landing_visual_hold_release_flushes_event_buffer_and_replays_deferred },
  { name = "landing_visual_hold_release_orders_wrappers_by_priority", run = _test_landing_visual_hold_release_orders_wrappers_by_priority },
  { name = "landing_visual_hold_release_skips_when_not_pending", run = _test_landing_visual_hold_release_skips_when_not_pending },
  { name = "landing_visual_hold_start_repairs_attached_state_when_game_is_already_active", run = _test_landing_visual_hold_start_repairs_attached_state_when_game_is_already_active },
  { name = "landing_visual_hold_mark_release_pending_repairs_attached_state", run = _test_landing_visual_hold_mark_release_pending_repairs_attached_state },
  { name = "landing_visual_hold_clear_game_repairs_attached_state", run = _test_landing_visual_hold_clear_game_repairs_attached_state },
  { name = "landing_visual_hold_state_wins_over_stale_game_turn_flags", run = _test_landing_visual_hold_state_wins_over_stale_game_turn_flags },
}
