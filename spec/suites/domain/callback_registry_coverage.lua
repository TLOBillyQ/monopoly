local callback_registry = require("src.turn.waits.callback_registry")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game()
  return {}
end

-- register and peek

local function test_register_stores_callback()
  local game = _make_game()
  local fn = function() return "ok" end
  local returned = callback_registry.register(game, "after_action_anim", fn)
  _assert_eq(returned, fn, "register should return the callback")
  _assert_eq(callback_registry.peek(game, "after_action_anim"), fn, "peek should return registered callback")
end

-- register: invalid key errors

local function test_register_errors_on_empty_key()
  local game = _make_game()
  local ok = pcall(function()
    callback_registry.register(game, "", function() end)
  end)
  _assert_eq(ok, false, "empty key should error")
end

-- register: non-function callback errors

local function test_register_errors_on_non_function()
  local game = _make_game()
  local ok = pcall(function()
    callback_registry.register(game, "key", "not_a_fn")
  end)
  _assert_eq(ok, false, "non-function callback should error")
end

-- take: removes and returns callback

local function test_take_removes_callback()
  local game = _make_game()
  local fn = function() end
  callback_registry.register(game, "after_landing_visual", fn)
  local taken = callback_registry.take(game, "after_landing_visual")
  _assert_eq(taken, fn, "take should return callback")
  _assert_eq(callback_registry.peek(game, "after_landing_visual"), nil, "after take callback should be nil")
end

-- take: returns nil when no callback registered

local function test_take_returns_nil_when_missing()
  local game = _make_game()
  local result = callback_registry.take(game, "missing_key")
  _assert_eq(result, nil, "take on missing key should return nil")
end

-- clear: specific key

local function test_clear_specific_key_removes_callback()
  local game = _make_game()
  callback_registry.register(game, "k1", function() end)
  callback_registry.register(game, "k2", function() end)
  callback_registry.clear(game, "k1")
  _assert_eq(callback_registry.peek(game, "k1"), nil, "cleared key should be nil")
  assert(callback_registry.peek(game, "k2") ~= nil, "other key should remain")
end

-- clear: nil key clears all callbacks

local function test_clear_nil_key_clears_all()
  local game = _make_game()
  callback_registry.register(game, "k1", function() end)
  callback_registry.register(game, "k2", function() end)
  callback_registry.clear(game, nil)
  _assert_eq(callback_registry.peek(game, "k1"), nil, "all callbacks should be cleared")
  _assert_eq(callback_registry.peek(game, "k2"), nil, "all callbacks should be cleared")
end

-- clear specific key also removes seq state

local function test_clear_specific_key_removes_seq_state()
  local game = _make_game()
  local seq = callback_registry.begin_wait(game, "landing_visual")
  callback_registry.mark_wait_ready(game, "landing_visual", seq)
  callback_registry.clear(game, "landing_visual")
  _assert_eq(callback_registry.pending_wait_seq(game, "landing_visual"), nil, "clear should remove pending seq")
  _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "clear should remove ready seq")
end

-- reset_runtime delegates to clear

local function test_reset_runtime_clears_all()
  local game = _make_game()
  callback_registry.register(game, "k1", function() end)
  callback_registry.reset_runtime(game)
  _assert_eq(callback_registry.peek(game, "k1"), nil, "reset_runtime should clear all callbacks")
end

-- begin_wait increments seq

local function test_begin_wait_returns_incrementing_seq()
  local game = _make_game()
  local s1 = callback_registry.begin_wait(game, "landing_visual")
  local s2 = callback_registry.begin_wait(game, "landing_visual")
  _assert_eq(s1, 1, "first seq should be 1")
  _assert_eq(s2, 2, "second seq should be 2")
end

-- begin_wait: invalid key errors

local function test_begin_wait_errors_on_empty_key()
  local game = _make_game()
  local ok = pcall(function() callback_registry.begin_wait(game, "") end)
  _assert_eq(ok, false, "empty key should error in begin_wait")
end

-- pending_wait_seq returns pending seq

local function test_pending_wait_seq_returns_current()
  local game = _make_game()
  local seq = callback_registry.begin_wait(game, "landing_visual")
  _assert_eq(callback_registry.pending_wait_seq(game, "landing_visual"), seq, "should return pending seq")
end

-- mark_wait_ready: matching seq returns true

local function test_mark_wait_ready_matching_seq_returns_true()
  local game = _make_game()
  local seq = callback_registry.begin_wait(game, "landing_visual")
  local ok = callback_registry.mark_wait_ready(game, "landing_visual", seq)
  _assert_eq(ok, true, "matching seq should return true")
end

-- mark_wait_ready: mismatched seq returns false

local function test_mark_wait_ready_mismatch_returns_false()
  local game = _make_game()
  callback_registry.begin_wait(game, "landing_visual")
  local ok = callback_registry.mark_wait_ready(game, "landing_visual", 999)
  _assert_eq(ok, false, "mismatched seq should return false")
end

-- is_wait_ready: true after mark_wait_ready

local function test_is_wait_ready_true_after_mark()
  local game = _make_game()
  local seq = callback_registry.begin_wait(game, "landing_visual")
  callback_registry.mark_wait_ready(game, "landing_visual", seq)
  _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), true, "should be ready after mark")
end

-- is_wait_ready: false when no pending wait

local function test_is_wait_ready_false_when_no_wait()
  local game = _make_game()
  _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "no wait → not ready")
end

-- is_wait_ready: false when pending but not marked ready

local function test_is_wait_ready_false_when_pending_not_marked()
  local game = _make_game()
  callback_registry.begin_wait(game, "landing_visual")
  _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "pending without mark → not ready")
end

-- finish_wait: matching seq clears pending and ready, returns true

local function test_finish_wait_matching_seq_returns_true()
  local game = _make_game()
  local seq = callback_registry.begin_wait(game, "landing_visual")
  callback_registry.mark_wait_ready(game, "landing_visual", seq)
  local ok = callback_registry.finish_wait(game, "landing_visual", seq)
  _assert_eq(ok, true, "finish_wait with matching seq should return true")
  _assert_eq(callback_registry.pending_wait_seq(game, "landing_visual"), nil, "pending seq should be cleared")
  _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "should not be ready after finish")
end

-- finish_wait: mismatched seq returns false

local function test_finish_wait_mismatch_returns_false()
  local game = _make_game()
  callback_registry.begin_wait(game, "landing_visual")
  local ok = callback_registry.finish_wait(game, "landing_visual", 999)
  _assert_eq(ok, false, "finish_wait with wrong seq should return false")
end

-- _ensure_runtime: reuses existing runtime

local function test_ensure_runtime_idempotent()
  local game = _make_game()
  callback_registry.register(game, "k1", function() end)
  local rt1 = game.wait_callback_runtime
  callback_registry.register(game, "k2", function() end)
  _assert_eq(game.wait_callback_runtime, rt1, "runtime should be reused across calls")
end

return {
  name = "domain callback registry coverage",
  tests = {
    { name = "register stores callback", run = test_register_stores_callback },
    { name = "register errors on empty key", run = test_register_errors_on_empty_key },
    { name = "register errors on non function", run = test_register_errors_on_non_function },
    { name = "take removes callback", run = test_take_removes_callback },
    { name = "take returns nil when missing", run = test_take_returns_nil_when_missing },
    { name = "clear specific key removes callback", run = test_clear_specific_key_removes_callback },
    { name = "clear nil key clears all", run = test_clear_nil_key_clears_all },
    { name = "clear specific key removes seq state", run = test_clear_specific_key_removes_seq_state },
    { name = "reset_runtime clears all", run = test_reset_runtime_clears_all },
    { name = "begin_wait returns incrementing seq", run = test_begin_wait_returns_incrementing_seq },
    { name = "begin_wait errors on empty key", run = test_begin_wait_errors_on_empty_key },
    { name = "pending_wait_seq returns current", run = test_pending_wait_seq_returns_current },
    { name = "mark_wait_ready matching seq returns true", run = test_mark_wait_ready_matching_seq_returns_true },
    { name = "mark_wait_ready mismatch returns false", run = test_mark_wait_ready_mismatch_returns_false },
    { name = "is_wait_ready true after mark", run = test_is_wait_ready_true_after_mark },
    { name = "is_wait_ready false when no wait", run = test_is_wait_ready_false_when_no_wait },
    { name = "is_wait_ready false when pending not marked", run = test_is_wait_ready_false_when_pending_not_marked },
    { name = "finish_wait matching seq returns true", run = test_finish_wait_matching_seq_returns_true },
    { name = "finish_wait mismatch returns false", run = test_finish_wait_mismatch_returns_false },
    { name = "ensure_runtime idempotent", run = test_ensure_runtime_idempotent },
  },
}
