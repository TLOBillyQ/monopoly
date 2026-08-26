local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local event_log = require("src.state.event_log")
local runtime_state = require("src.state.runtime")
local landing_visual_hold = require("src.state.visual_hold")

TestVisualHold = {}

function TestVisualHold:test_landing_visual_hold_defer_dirty_initializes_bucket_and_merges_inventory()
  local state = {}
  local dirty = {
    any = true,
    players = true,
    inventory = true,
  }

  local deferred = landing_visual_hold.defer_dirty(state, dirty)
  lu.assertEvalToTrue(deferred.any == true and deferred.players == true, "defer_dirty should merge boolean dirty flags")
  lu.assertEvalToTrue(deferred.inventory == true,
    "defer_dirty should merge inventory flag into initialized deferred bucket")
end

function TestVisualHold:test_landing_visual_hold_release_flushes_event_buffer_and_replays_deferred()
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
  lu.assertEvalToTrue(string.find(text, "deferred event during hold", 1, true) ~= nil, "release should flush event buffer")
end

function TestVisualHold:test_landing_visual_hold_release_orders_wrappers_by_priority()
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

function TestVisualHold:test_landing_visual_hold_release_skips_when_not_pending()
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

function TestVisualHold:test_landing_visual_hold_start_repairs_attached_state_when_game_is_already_active()
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

function TestVisualHold:test_landing_visual_hold_mark_release_pending_repairs_attached_state()
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

function TestVisualHold:test_landing_visual_hold_clear_game_repairs_attached_state()
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

function TestVisualHold:test_landing_visual_hold_state_wins_over_stale_game_turn_flags()
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

function TestVisualHold:test_sync_first_activation_pushes_buffer_even_in_defensive_hold_branch()
  -- #293: L16(防御分支 active 初值翻 true)与 L203(was_active 推导翻 false)都会
  -- 吃掉「首次激活补 buffer 事件」——mock ensure_turn_runtime 返回无 hold 的
  -- turn_runtime(与 test_ui_button_dispatch 的隔离 stub 同构),钉住首次 sync
  -- 激活时 buffer 必须被 push。
  local state = {}
  local game = {
    state = {
      event_log = event_log.new(),
    },
    turn = {
      landing_visual_hold_active = true,
      landing_visual_release_pending = false,
    },
  }
  local hold = nil
  support.with_patches({
    {
      target = runtime_state,
      key = "ensure_turn_runtime",
      value = function(st)
        st.turn_runtime = st.turn_runtime or {}
        return st.turn_runtime
      end,
    },
  }, function()
    hold = landing_visual_hold.sync_state_from_game(state, game)
  end)
  _assert_eq(#game.state.event_log.active_buffers, 1, "first activation must push a buffer event")
  _assert_eq(game.state.event_log.active_buffers[1], hold, "buffer should reference the activated hold")
end

function TestVisualHold:test_start_with_attached_state_activates_hold_via_state_branch()
  -- #293: L98(_begin_hold 的 state 参数翻 nil)只在「start + 已挂 state + turn 未
  -- 激活」路径可达——钉住该路径,变异体会在 ensure_turn_runtime(nil) 处崩。
  local state = {}
  local game = {
    dirty = {},
    turn = {
      landing_visual_hold_active = false,
      landing_visual_release_pending = false,
    },
    landing_visual_hold_state = state,
  }
  local started = landing_visual_hold.start(game)
  _assert_eq(started, true, "start should begin a fresh hold")
  _assert_eq(landing_visual_hold.is_active_state(state), true, "attached state should be activated")
  _assert_eq(game.turn.landing_visual_hold_active, true, "game turn flag should be projected")
end
function TestVisualHold:test_landing_visual_hold_release_destroys_hold_scope_exactly_once()
  local state = {}
  local game = {
    dirty = {},
    turn = {
      landing_visual_hold_active = false,
      landing_visual_release_pending = false,
    },
  }

  landing_visual_hold.start(game)
  landing_visual_hold.mark_release_pending(game)
  local hold = landing_visual_hold.sync_state_from_game(state, game)

  lu.assertEvalToTrue(hold.scope ~= nil, "activation should create a hold scope")
  landing_visual_hold.defer_board_visual_sync(state, { sync_data = true }, function() end)
  runtime_state.set_ui_model(state, { model = true })
  landing_visual_hold.capture_frozen_ui_model(state)
  _assert_eq(#hold.release_callbacks, 1, "precondition should register a deferred release callback")
  lu.assertEvalToTrue(hold.frozen_ui_model ~= nil, "precondition should capture a frozen ui model")

  local cleanups = 0
  hold.scope:defer(function()
    cleanups = cleanups + 1
  end)

  _assert_eq(landing_visual_hold.release(state, game), true, "release should flush the pending hold")
  _assert_eq(cleanups, 1, "release should run hold scope cleanups exactly once")
  _assert_eq(hold.scope, nil, "release should drop the destroyed hold scope")
  _assert_eq(hold.frozen_ui_model, nil, "release should clear the frozen ui model")
  _assert_eq(#hold.release_callbacks, 0, "release should clear deferred release callbacks")

  _assert_eq(landing_visual_hold.release(state, game), false, "repeated release should stay a no-op")
  landing_visual_hold.reset_state(state)
  _assert_eq(cleanups, 1, "repeated release and reset should not rerun hold scope cleanups")
  _assert_eq(hold.scope, nil, "repeated teardown should not recreate the hold scope")
end

function TestVisualHold:test_landing_visual_hold_reset_state_destroys_hold_scope_exactly_once()
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

  landing_visual_hold.start(game)
  local hold = landing_visual_hold.sync_state_from_game(state, game)
  lu.assertEvalToTrue(hold.scope ~= nil, "activation should create a hold scope")
  _assert_eq(#game.state.event_log.active_buffers, 1, "activation should push an event log buffer")

  local replayed = 0
  landing_visual_hold.defer_board_visual_sync(state, { sync_data = true }, function()
    replayed = replayed + 1
  end)

  local cleanups = 0
  hold.scope:defer(function()
    cleanups = cleanups + 1
  end)

  landing_visual_hold.reset_state(state)
  _assert_eq(cleanups, 1, "reset_state should run hold scope cleanups exactly once")
  _assert_eq(hold.scope, nil, "reset_state should drop the destroyed hold scope")
  _assert_eq(replayed, 0, "reset_state should discard deferred callbacks without replay")
  _assert_eq(#hold.release_callbacks, 0, "reset_state should clear deferred release callbacks")
  _assert_eq(#game.state.event_log.active_buffers, 0, "reset_state should pop the event log buffer")

  landing_visual_hold.reset_state(state)
  _assert_eq(cleanups, 1, "repeated reset_state should not rerun hold scope cleanups")
end

function TestVisualHold:test_landing_visual_hold_reactivation_creates_fresh_scope()
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

  landing_visual_hold.start(game)
  local hold = landing_visual_hold.sync_state_from_game(state, game)
  local first_scope = hold.scope
  lu.assertEvalToTrue(first_scope ~= nil, "activation should create a hold scope")

  landing_visual_hold.reset_state(state)
  _assert_eq(hold.scope, nil, "reset_state should drop the first hold scope")

  landing_visual_hold.sync_state_from_game(state, game)
  lu.assertEvalToTrue(hold.scope ~= nil, "reactivation should create a fresh hold scope")
  lu.assertEvalToTrue(hold.scope ~= first_scope, "reactivation should not reuse the destroyed hold scope")
end

function TestVisualHold:test_landing_visual_hold_clear_game_replays_pending_release_callbacks()
  -- #440: _phase_end 抢在 tick 的 release 之前 clear_game 时,release_pending 已置位
  -- 的 deferred 回调不得被静默丢弃——clear_game 必须先回放再清理。
  local state = {}
  local game = {
    dirty = {},
    turn = {
      landing_visual_hold_active = false,
      landing_visual_release_pending = false,
    },
    landing_visual_hold_state = state,
  }
  local replayed = {}

  landing_visual_hold.start(game)
  landing_visual_hold.mark_release_pending(game)
  landing_visual_hold.register_release_callback(state, "runtime_event", function()
    replayed[#replayed + 1] = "release"
  end)

  local cleared = landing_visual_hold.clear_game(game)

  _assert_eq(cleared, true, "clear_game should report a changed hold")
  _assert_eq(#replayed, 1, "clear_game should replay deferred callbacks instead of dropping them")
  _assert_eq(landing_visual_hold.is_active_game(game), false, "clear_game should still clear the active flag")
  _assert_eq(landing_visual_hold.is_release_pending_game(game), false, "clear_game should still clear the pending flag")
end

function TestVisualHold:test_landing_visual_hold_clear_game_destroys_scope_so_reactivation_is_fresh()
  -- #440 附带缺陷(#419 引入): clear_game 不走 _destroy_hold_scope,泄漏的 scope
  -- 让下回合 _ensure_active_scope 早退复用,陈旧 release_callbacks 跨回合存活。
  local state = {}
  local game = {
    dirty = {},
    turn = {
      landing_visual_hold_active = false,
      landing_visual_release_pending = false,
    },
    landing_visual_hold_state = state,
  }

  landing_visual_hold.start(game)
  local hold = runtime_state.ensure_turn_runtime(state).landing_visual_hold
  local stale_scope = hold.scope
  lu.assertEvalToTrue(stale_scope ~= nil, "activation should create a hold scope")
  landing_visual_hold.register_release_callback(state, "popup", function() end)
  _assert_eq(#hold.release_callbacks, 1, "precondition should register a deferred callback")

  landing_visual_hold.clear_game(game)

  _assert_eq(hold.scope, nil, "clear_game should destroy the hold scope")
  _assert_eq(#hold.release_callbacks, 0, "clear_game should not leave stale release callbacks behind")

  landing_visual_hold.start(game)
  lu.assertEvalToTrue(hold.scope ~= nil, "reactivation should create a scope")
  lu.assertEvalToTrue(hold.scope ~= stale_scope, "reactivation should not reuse the leaked scope")
  landing_visual_hold.clear_game(game)
end


return TestVisualHold
