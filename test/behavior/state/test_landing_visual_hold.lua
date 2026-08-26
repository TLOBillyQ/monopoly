local lu = require("luaunit")
local landing_visual_hold = require("src.state.visual_hold")
local runtime_state = require("src.state.runtime")

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

local _config_reset = require("test.support.config_reset")

TestLandingVisualHold = {}

function TestLandingVisualHold:setUp()
  _config_reset.reset_all()
end

function TestLandingVisualHold:test_is_active_game_false_when_no_hold()
  local game = _make_game()
  _assert_eq(landing_visual_hold.is_active_game(game), false, "no hold should return false")
end

function TestLandingVisualHold:test_is_active_game_true_via_game_turn()
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  _assert_eq(landing_visual_hold.is_active_game(game), true, "game.turn active=true should return true")
end

function TestLandingVisualHold:test_is_active_game_nil_game_returns_false()
  _assert_eq(landing_visual_hold.is_active_game(nil), false, "nil game should return false")
end

function TestLandingVisualHold:test_is_release_pending_game_false_when_no_flag()
  local game = _make_game()
  _assert_eq(landing_visual_hold.is_release_pending_game(game), false, "no pending flag should return false")
end

function TestLandingVisualHold:test_is_release_pending_game_true_via_game_turn()
  local game = _make_game({ turn = { landing_visual_release_pending = true } })
  _assert_eq(landing_visual_hold.is_release_pending_game(game), true, "release_pending=true should return true")
end

function TestLandingVisualHold:test_mark_release_pending_returns_false_when_not_active()
  local game = _make_game()
  local result = landing_visual_hold.mark_release_pending(game)
  _assert_eq(result, false, "not active should return false")
end

function TestLandingVisualHold:test_mark_release_pending_returns_false_when_no_turn()
  local game = { dirty = {} }
  local result = landing_visual_hold.mark_release_pending(game)
  _assert_eq(result, false, "no turn should return false")
end

function TestLandingVisualHold:test_mark_release_pending_sets_flag_when_active()
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local result = landing_visual_hold.mark_release_pending(game)
  _assert_eq(result, true, "active game should return true")
  _assert_eq(game.turn.landing_visual_release_pending, true, "release_pending should be set")
  _assert_eq(game.dirty.any, true, "dirty.any should be set")
end

function TestLandingVisualHold:test_clear_game_returns_false_when_no_turn()
  local game = { dirty = {} }
  local result = landing_visual_hold.clear_game(game)
  _assert_eq(result, false, "no turn should return false")
end

function TestLandingVisualHold:test_clear_game_returns_false_when_nothing_active()
  local game = _make_game()
  local result = landing_visual_hold.clear_game(game)
  _assert_eq(result, false, "nothing active should return false")
end

function TestLandingVisualHold:test_clear_game_clears_active_flag()
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local result = landing_visual_hold.clear_game(game)
  _assert_eq(result, true, "clearing active hold should return true")
  _assert_eq(game.turn.landing_visual_hold_active, false, "active flag should be cleared")
  _assert_eq(game.dirty.any, true, "dirty.any should be set")
end

function TestLandingVisualHold:test_clear_game_clears_release_pending()
  local game = _make_game({ turn = { landing_visual_release_pending = true } })
  local result = landing_visual_hold.clear_game(game)
  _assert_eq(result, true, "clearing release_pending should return true")
  _assert_eq(game.turn.landing_visual_release_pending, false, "release_pending should be cleared")
end

function TestLandingVisualHold:test_hold_state_for_game_delegates_to_start()
  local game = _make_game()
  local result = landing_visual_hold.hold_state_for_game(game, nil)
  -- Without active state, start should activate and return true
  _assert_eq(result, true, "hold_state_for_game should delegate to start")
end

function TestLandingVisualHold:test_is_flushing_state_false_by_default()
  local state = _make_state()
  _assert_eq(landing_visual_hold.is_flushing_state(state), false, "not flushing by default")
end

function TestLandingVisualHold:test_with_flushing_calls_fn_and_returns_result()
  local state = _make_state()
  local called = false
  local result = landing_visual_hold.with_flushing(state, function()
    called = true
    return 42
  end)
  _assert_eq(called, true, "fn should be called")
  _assert_eq(result, 42, "result should be returned")
end

function TestLandingVisualHold:test_with_flushing_restores_flushing_flag_after_fn()
  local state = _make_state()
  landing_visual_hold.with_flushing(state, function() end)
  _assert_eq(landing_visual_hold.is_flushing_state(state), false, "flushing should be false after fn")
end

function TestLandingVisualHold:test_with_flushing_propagates_error()
  local state = _make_state()
  local ok = pcall(function()
    landing_visual_hold.with_flushing(state, function() error("test_error") end)
  end)
  _assert_eq(ok, false, "error in fn should propagate")
  _assert_eq(landing_visual_hold.is_flushing_state(state), false, "flushing should be restored after error")
end

function TestLandingVisualHold:test_is_active_state_false_by_default()
  local state = _make_state()
  _assert_eq(landing_visual_hold.is_active_state(state), false, "not active by default")
end

function TestLandingVisualHold:test_should_defer_false_when_state_nil()
  local result = landing_visual_hold.should_defer(nil, nil)
  _assert_eq(result, false, "nil state should return false")
end

function TestLandingVisualHold:test_should_defer_false_when_not_active()
  local state = _make_state()
  _assert_eq(landing_visual_hold.should_defer(state, nil), false, "inactive state should not defer")
end

function TestLandingVisualHold:test_capture_frozen_ui_model_returns_nil_when_no_ui_model()
  local state = _make_state()
  local result = landing_visual_hold.capture_frozen_ui_model(state)
  _assert_eq(result, nil, "should return nil when no ui_model set")
end

function TestLandingVisualHold:test_capture_frozen_ui_model_returns_same_on_second_call()
  local state = _make_state()
  runtime_state.set_ui_model(state, { model = true })
  local m1 = landing_visual_hold.capture_frozen_ui_model(state)
  local m2 = landing_visual_hold.capture_frozen_ui_model(state)
  _assert_eq(m1, m2, "second call should return same frozen model")
end

function TestLandingVisualHold:test_freeze_active_ui_returns_nil_when_not_active()
  local state = _make_state()
  local result = landing_visual_hold.freeze_active_ui(state)
  _assert_eq(result, nil, "not active should return nil")
end

function TestLandingVisualHold:test_merge_dirty_delegates_to_deferred_dirty()
  local target = { any = false, players = false, board_tiles = false, turn = false, market = false, turn_countdown = false, inventory = false }
  local dirty = { any = true, players = true, board_tiles = false, turn = false, market = false, turn_countdown = false, inventory = false }
  landing_visual_hold.merge_dirty(target, dirty)
  _assert_eq(target.any, true, "any should be merged")
  _assert_eq(target.players, true, "players should be merged")
end

function TestLandingVisualHold:test_register_release_callback_registers_fn()
  local state = _make_state()
  local fn = function() return true end
  local returned = landing_visual_hold.register_release_callback(state, "popup", fn, nil)
  _assert_eq(returned, fn, "should return registered fn")
end

function TestLandingVisualHold:test_run_or_defer_calls_fn_when_not_deferred()
  local state = _make_state()
  local called = false
  landing_visual_hold.run_or_defer(state, nil, "popup", function()
    called = true
    return true
  end, nil)
  _assert_eq(called, true, "fn should be called when not deferred")
end

function TestLandingVisualHold:test_reset_state_clears_active_and_flushing()
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

function TestLandingVisualHold:test_sync_state_from_game_uses_game_turn_active()
  local state = _make_state()
  local game = _make_game({ turn = { landing_visual_hold_active = true } })
  local hold = landing_visual_hold.sync_state_from_game(state, game)
  _assert_eq(landing_visual_hold.is_active_state(state), true, "state should reflect game turn active")
  lu.assertEvalToTrue(hold ~= nil, "hold should be returned")
end

function TestLandingVisualHold:test_start_returns_false_when_no_turn()
  local game = { dirty = {} }
  local result = landing_visual_hold.start(game, nil)
  _assert_eq(result, false, "no turn should return false")
end


return TestLandingVisualHold
