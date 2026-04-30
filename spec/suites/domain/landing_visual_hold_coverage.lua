local landing_visual_hold = require("src.state.visual_hold")
local runtime_state = require("src.state.runtime_state")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game(opts)
  opts = opts or {}
  return {
    turn = opts.turn or {},
    dirty = opts.dirty or { any = false, turn = false },
  }
end

local function _make_state()
  return {}
end

-- is_active_game: game.turn path (no state)

local function test_is_active_game_false_when_no_hold()
  local game = _make_game()
  _assert_eq(landing_visual_hold.is_active_game(game), false, "no hold should return false")
end

local function test_is_active_game_true_via_game_turn()
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  _assert_eq(landing_visual_hold.is_active_game(game), true, "game.turn active=true should return true")
end

local function test_is_active_game_nil_game_returns_false()
  _assert_eq(landing_visual_hold.is_active_game(nil), false, "nil game should return false")
end

-- is_release_pending_game

local function test_is_release_pending_game_false_when_no_flag()
  local game = _make_game()
  _assert_eq(landing_visual_hold.is_release_pending_game(game), false, "no pending flag should return false")
end

local function test_is_release_pending_game_true_via_game_turn()
  local game = _make_game({ turn = { landing_visual_release_pending = true } })
  _assert_eq(landing_visual_hold.is_release_pending_game(game), true, "release_pending=true should return true")
end

-- mark_release_pending

local function test_mark_release_pending_returns_false_when_not_active()
  local game = _make_game()
  local result = landing_visual_hold.mark_release_pending(game)
  _assert_eq(result, false, "not active should return false")
end

local function test_mark_release_pending_returns_false_when_no_turn()
  local game = { dirty = {} }
  local result = landing_visual_hold.mark_release_pending(game)
  _assert_eq(result, false, "no turn should return false")
end

local function test_mark_release_pending_sets_flag_when_active()
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local result = landing_visual_hold.mark_release_pending(game)
  _assert_eq(result, true, "active game should return true")
  _assert_eq(game.turn.landing_visual_release_pending, true, "release_pending should be set")
  _assert_eq(game.dirty.any, true, "dirty.any should be set")
end

-- clear_game

local function test_clear_game_returns_false_when_no_turn()
  local game = { dirty = {} }
  local result = landing_visual_hold.clear_game(game)
  _assert_eq(result, false, "no turn should return false")
end

local function test_clear_game_returns_false_when_nothing_active()
  local game = _make_game()
  local result = landing_visual_hold.clear_game(game)
  _assert_eq(result, false, "nothing active should return false")
end

local function test_clear_game_clears_active_flag()
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local result = landing_visual_hold.clear_game(game)
  _assert_eq(result, true, "clearing active hold should return true")
  _assert_eq(game.turn.landing_visual_hold_active, false, "active flag should be cleared")
  _assert_eq(game.dirty.any, true, "dirty.any should be set")
end

local function test_clear_game_clears_release_pending()
  local game = _make_game({ turn = { landing_visual_release_pending = true } })
  local result = landing_visual_hold.clear_game(game)
  _assert_eq(result, true, "clearing release_pending should return true")
  _assert_eq(game.turn.landing_visual_release_pending, false, "release_pending should be cleared")
end

-- hold_state_for_game

local function test_hold_state_for_game_delegates_to_start()
  local game = _make_game()
  local result = landing_visual_hold.hold_state_for_game(game, nil)
  -- Without active state, start should activate and return true
  _assert_eq(result, true, "hold_state_for_game should delegate to start")
end

-- is_flushing_state

local function test_is_flushing_state_false_by_default()
  local state = _make_state()
  _assert_eq(landing_visual_hold.is_flushing_state(state), false, "not flushing by default")
end

-- with_flushing

local function test_with_flushing_calls_fn_and_returns_result()
  local state = _make_state()
  local called = false
  local result = landing_visual_hold.with_flushing(state, function()
    called = true
    return 42
  end)
  _assert_eq(called, true, "fn should be called")
  _assert_eq(result, 42, "result should be returned")
end

local function test_with_flushing_restores_flushing_flag_after_fn()
  local state = _make_state()
  landing_visual_hold.with_flushing(state, function() end)
  _assert_eq(landing_visual_hold.is_flushing_state(state), false, "flushing should be false after fn")
end

local function test_with_flushing_propagates_error()
  local state = _make_state()
  local ok = pcall(function()
    landing_visual_hold.with_flushing(state, function() error("test_error") end)
  end)
  _assert_eq(ok, false, "error in fn should propagate")
  _assert_eq(landing_visual_hold.is_flushing_state(state), false, "flushing should be restored after error")
end

-- is_active_state

local function test_is_active_state_false_by_default()
  local state = _make_state()
  _assert_eq(landing_visual_hold.is_active_state(state), false, "not active by default")
end

-- should_defer

local function test_should_defer_false_when_state_nil()
  local result = landing_visual_hold.should_defer(nil, nil)
  _assert_eq(result, false, "nil state should return false")
end

local function test_should_defer_false_when_not_active()
  local state = _make_state()
  _assert_eq(landing_visual_hold.should_defer(state, nil), false, "inactive state should not defer")
end

-- capture_frozen_ui_model

local function test_capture_frozen_ui_model_returns_nil_when_no_ui_model()
  local state = _make_state()
  local result = landing_visual_hold.capture_frozen_ui_model(state)
  _assert_eq(result, nil, "should return nil when no ui_model set")
end

local function test_capture_frozen_ui_model_returns_same_on_second_call()
  local state = _make_state()
  runtime_state.set_ui_model(state, { model = true })
  local m1 = landing_visual_hold.capture_frozen_ui_model(state)
  local m2 = landing_visual_hold.capture_frozen_ui_model(state)
  _assert_eq(m1, m2, "second call should return same frozen model")
end

-- freeze_active_ui

local function test_freeze_active_ui_returns_nil_when_not_active()
  local state = _make_state()
  local result = landing_visual_hold.freeze_active_ui(state)
  _assert_eq(result, nil, "not active should return nil")
end

-- set_post_release_hook

local function test_set_post_release_hook_stores_fn()
  landing_visual_hold.set_post_release_hook(function() end)
  landing_visual_hold.set_post_release_hook(nil)
end

-- merge_dirty

local function test_merge_dirty_delegates_to_deferred_dirty()
  local target = { any = false, players = false, board_tiles = false, turn = false, market = false, turn_countdown = false, inventory_ids = {} }
  local dirty = { any = true, players = true, board_tiles = false, turn = false, market = false, turn_countdown = false, inventory_ids = {} }
  landing_visual_hold.merge_dirty(target, dirty)
  _assert_eq(target.any, true, "any should be merged")
  _assert_eq(target.players, true, "players should be merged")
end

-- defer_dirty

local function test_defer_dirty_returns_hold_deferred_dirty()
  local state = _make_state()
  local dirty = { any = true, players = false, board_tiles = false, turn = false, market = false, turn_countdown = false, inventory_ids = {} }
  local result = landing_visual_hold.defer_dirty(state, dirty)
  assert(type(result) == "table", "defer_dirty should return the deferred_dirty bucket")
end

-- register_release_callback

local function test_register_release_callback_registers_fn()
  local state = _make_state()
  local fn = function() return true end
  local returned = landing_visual_hold.register_release_callback(state, "popup", fn, nil)
  _assert_eq(returned, fn, "should return registered fn")
end

-- run_or_defer: not deferred → fn called

local function test_run_or_defer_calls_fn_when_not_deferred()
  local state = _make_state()
  local called = false
  landing_visual_hold.run_or_defer(state, nil, "popup", function()
    called = true
    return true
  end, nil)
  _assert_eq(called, true, "fn should be called when not deferred")
end

-- defer_popup

local function test_defer_popup_registers_callback()
  local state = _make_state()
  local replay = function() return true end
  landing_visual_hold.defer_popup(state, { title = "hi" }, {}, replay)
end

-- defer_runtime_event

local function test_defer_runtime_event_registers_callback()
  local state = _make_state()
  local replay = function() return true end
  landing_visual_hold.defer_runtime_event(state, "some_event", { data = 1 }, replay)
end

-- defer_board_visual_sync

local function test_defer_board_visual_sync_registers_callback()
  local state = _make_state()
  local replay = function() return true end
  landing_visual_hold.defer_board_visual_sync(state, { tiles = {} }, replay)
end

-- defer_tile_update

local function test_defer_tile_update_registers_callback()
  local state = _make_state()
  local replay = function() return true end
  landing_visual_hold.defer_tile_update(state, 5, 2, replay)
end

-- defer_owner_change

local function test_defer_owner_change_registers_callback()
  local state = _make_state()
  local replay = function() return true end
  landing_visual_hold.defer_owner_change(state, 5, "player_1", replay)
end

-- defer_bankruptcy_clear

local function test_defer_bankruptcy_clear_registers_callback()
  local state = _make_state()
  local replay = function() return true end
  landing_visual_hold.defer_bankruptcy_clear(state, nil, nil, nil, replay)
end

-- reset_state

local function test_reset_state_clears_active_and_flushing()
  local state = _make_state()
  -- ensure hold is created first
  landing_visual_hold.is_flushing_state(state)
  local hold = landing_visual_hold.reset_state(state)
  _assert_eq(hold.active, false, "active should be false after reset")
  _assert_eq(hold.flushing, false, "flushing should be false after reset")
  _assert_eq(hold.release_pending, false, "release_pending should be false after reset")
  _assert_eq(hold.frozen_ui_model, nil, "frozen_ui_model should be nil after reset")
  _assert_eq(hold.source, nil, "source should be nil after reset")
end

-- release: game.turn path (state is a game-like table)

local function test_release_false_when_release_pending_not_set()
  local state = _make_state()
  local game = _make_game()
  local result = landing_visual_hold.release(state, game)
  _assert_eq(result, false, "release should return false when release_pending not set")
end

-- sync_state_from_game: non-state-source uses game turn

local function test_sync_state_from_game_uses_game_turn_active()
  local state = _make_state()
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local hold = landing_visual_hold.sync_state_from_game(state, game)
  _assert_eq(landing_visual_hold.is_active_state(state), true, "state should reflect game turn active")
  assert(hold ~= nil, "hold should be returned")
end

-- start: no turn → returns false

local function test_start_returns_false_when_no_turn()
  local game = { dirty = {} }
  local result = landing_visual_hold.start(game, nil)
  _assert_eq(result, false, "no turn should return false")
end

return {
  name = "domain landing visual hold coverage",
  tests = {
    { name = "is_active_game false when no hold", run = test_is_active_game_false_when_no_hold },
    { name = "is_active_game true via game.turn", run = test_is_active_game_true_via_game_turn },
    { name = "is_active_game nil game returns false", run = test_is_active_game_nil_game_returns_false },
    { name = "is_release_pending_game false when no flag", run = test_is_release_pending_game_false_when_no_flag },
    { name = "is_release_pending_game true via game.turn", run = test_is_release_pending_game_true_via_game_turn },
    { name = "mark_release_pending returns false when not active", run = test_mark_release_pending_returns_false_when_not_active },
    { name = "mark_release_pending returns false when no turn", run = test_mark_release_pending_returns_false_when_no_turn },
    { name = "mark_release_pending sets flag when active", run = test_mark_release_pending_sets_flag_when_active },
    { name = "clear_game returns false when no turn", run = test_clear_game_returns_false_when_no_turn },
    { name = "clear_game returns false when nothing active", run = test_clear_game_returns_false_when_nothing_active },
    { name = "clear_game clears active flag", run = test_clear_game_clears_active_flag },
    { name = "clear_game clears release_pending", run = test_clear_game_clears_release_pending },
    { name = "hold_state_for_game delegates to start", run = test_hold_state_for_game_delegates_to_start },
    { name = "is_flushing_state false by default", run = test_is_flushing_state_false_by_default },
    { name = "with_flushing calls fn and returns result", run = test_with_flushing_calls_fn_and_returns_result },
    { name = "with_flushing restores flushing flag after fn", run = test_with_flushing_restores_flushing_flag_after_fn },
    { name = "with_flushing propagates error", run = test_with_flushing_propagates_error },
    { name = "is_active_state false by default", run = test_is_active_state_false_by_default },
    { name = "should_defer false when state nil", run = test_should_defer_false_when_state_nil },
    { name = "should_defer false when not active", run = test_should_defer_false_when_not_active },
    { name = "capture_frozen_ui_model returns nil when no ui_model", run = test_capture_frozen_ui_model_returns_nil_when_no_ui_model },
    { name = "capture_frozen_ui_model returns same on second call", run = test_capture_frozen_ui_model_returns_same_on_second_call },
    { name = "freeze_active_ui returns nil when not active", run = test_freeze_active_ui_returns_nil_when_not_active },
    { name = "set_post_release_hook stores fn", run = test_set_post_release_hook_stores_fn },
    { name = "merge_dirty delegates to deferred_dirty", run = test_merge_dirty_delegates_to_deferred_dirty },
    { name = "defer_dirty returns hold deferred_dirty", run = test_defer_dirty_returns_hold_deferred_dirty },
    { name = "register_release_callback registers fn", run = test_register_release_callback_registers_fn },
    { name = "run_or_defer calls fn when not deferred", run = test_run_or_defer_calls_fn_when_not_deferred },
    { name = "defer_popup registers callback", run = test_defer_popup_registers_callback },
    { name = "defer_runtime_event registers callback", run = test_defer_runtime_event_registers_callback },
    { name = "defer_board_visual_sync registers callback", run = test_defer_board_visual_sync_registers_callback },
    { name = "defer_tile_update registers callback", run = test_defer_tile_update_registers_callback },
    { name = "defer_owner_change registers callback", run = test_defer_owner_change_registers_callback },
    { name = "defer_bankruptcy_clear registers callback", run = test_defer_bankruptcy_clear_registers_callback },
    { name = "reset_state clears active and flushing", run = test_reset_state_clears_active_and_flushing },
    { name = "release false when release_pending not set", run = test_release_false_when_release_pending_not_set },
    { name = "sync_state_from_game uses game turn active", run = test_sync_state_from_game_uses_game_turn_active },
    { name = "start returns false when no turn", run = test_start_returns_false_when_no_turn },
  },
}
