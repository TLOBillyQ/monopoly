local lu = require("luaunit")
local luax = require("test.support.luax")
local callback_registry = require("src.turn.waits.callback_registry")
local _config_reset = require("test.support.config_reset")

-- 原生 LuaUnit 迁移:describe("domain callback registry coverage") 拍平为文件级
-- TestCallbackRegistry 类,before_each → setUp,用例数与改写前一一对应(22 例)。

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game()
  return {}
end

TestCallbackRegistry = {}

function TestCallbackRegistry:setUp()
  _config_reset.reset_all()
end

function TestCallbackRegistry:test_register_stores_callback()
  local game = _make_game()
  local fn = function() return "ok" end
  local returned = callback_registry.register(game, "after_action_anim", fn)
  _assert_eq(returned, fn, "register should return the callback")
  _assert_eq(callback_registry.peek(game, "after_action_anim"), fn, "peek should return registered callback")
end

function TestCallbackRegistry:test_register_errors_on_empty_key()
  local game = _make_game()
  luax.has_error(function()
    callback_registry.register(game, "", function() end)
  end, "missing callback key")
end

function TestCallbackRegistry:test_register_errors_on_non_function()
  local game = _make_game()
  luax.has_error(function()
    callback_registry.register(game, "key", "not_a_fn")
  end, "missing callback")
end

function TestCallbackRegistry:test_peek_errors_on_nil_game_with_guard_message()
  -- kills _ensure_runtime's "missing game" -> nil.
  luax.has_error(function()
    callback_registry.peek(nil, "k")
  end, "missing game")
end

function TestCallbackRegistry:test_begin_wait_errors_on_nil_key_with_guard_message()
  -- kills begin_wait's "missing wait key" -> nil.
  luax.has_error(function()
    callback_registry.begin_wait(_make_game(), nil)
  end, "missing wait key")
end

function TestCallbackRegistry:test_take_removes_callback()
  local game = _make_game()
  local fn = function() end
  callback_registry.register(game, "after_landing_visual", fn)
  local taken = callback_registry.take(game, "after_landing_visual")
  _assert_eq(taken, fn, "take should return callback")
  _assert_eq(callback_registry.peek(game, "after_landing_visual"), nil, "after take callback should be nil")
end

function TestCallbackRegistry:test_take_returns_nil_when_missing()
  local game = _make_game()
  local result = callback_registry.take(game, "missing_key")
  _assert_eq(result, nil, "take on missing key should return nil")
end

function TestCallbackRegistry:test_clear_specific_key_removes_callback()
  local game = _make_game()
  callback_registry.register(game, "k1", function() end)
  callback_registry.register(game, "k2", function() end)
  callback_registry.clear(game, "k1")
  _assert_eq(callback_registry.peek(game, "k1"), nil, "cleared key should be nil")
  lu.assertEvalToTrue(callback_registry.peek(game, "k2") ~= nil, "other key should remain")
end

function TestCallbackRegistry:test_clear_nil_key_clears_all()
  local game = _make_game()
  callback_registry.register(game, "k1", function() end)
  callback_registry.register(game, "k2", function() end)
  callback_registry.clear(game, nil)
  _assert_eq(callback_registry.peek(game, "k1"), nil, "all callbacks should be cleared")
  _assert_eq(callback_registry.peek(game, "k2"), nil, "all callbacks should be cleared")
end

function TestCallbackRegistry:test_clear_specific_key_removes_seq_state()
  local game = _make_game()
  local seq = callback_registry.begin_wait(game, "landing_visual")
  callback_registry.mark_wait_ready(game, "landing_visual", seq)
  callback_registry.clear(game, "landing_visual")
  _assert_eq(callback_registry.pending_wait_seq(game, "landing_visual"), nil, "clear should remove pending seq")
  _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "clear should remove ready seq")
end

function TestCallbackRegistry:test_reset_runtime_clears_all()
  local game = _make_game()
  callback_registry.register(game, "k1", function() end)
  callback_registry.reset_runtime(game)
  _assert_eq(callback_registry.peek(game, "k1"), nil, "reset_runtime should clear all callbacks")
end

function TestCallbackRegistry:test_begin_wait_returns_incrementing_seq()
  local game = _make_game()
  local s1 = callback_registry.begin_wait(game, "landing_visual")
  local s2 = callback_registry.begin_wait(game, "landing_visual")
  _assert_eq(s1, 1, "first seq should be 1")
  _assert_eq(s2, 2, "second seq should be 2")
end

function TestCallbackRegistry:test_begin_wait_errors_on_empty_key()
  local game = _make_game()
  local ok = pcall(function() callback_registry.begin_wait(game, "") end)
  _assert_eq(ok, false, "empty key should error in begin_wait")
end

function TestCallbackRegistry:test_pending_wait_seq_returns_current()
  local game = _make_game()
  local seq = callback_registry.begin_wait(game, "landing_visual")
  _assert_eq(callback_registry.pending_wait_seq(game, "landing_visual"), seq, "should return pending seq")
end

function TestCallbackRegistry:test_mark_wait_ready_matching_seq_returns_true()
  local game = _make_game()
  local seq = callback_registry.begin_wait(game, "landing_visual")
  local ok = callback_registry.mark_wait_ready(game, "landing_visual", seq)
  _assert_eq(ok, true, "matching seq should return true")
end

function TestCallbackRegistry:test_mark_wait_ready_mismatch_returns_false()
  local game = _make_game()
  callback_registry.begin_wait(game, "landing_visual")
  local ok = callback_registry.mark_wait_ready(game, "landing_visual", 999)
  _assert_eq(ok, false, "mismatched seq should return false")
end

function TestCallbackRegistry:test_is_wait_ready_true_after_mark()
  local game = _make_game()
  local seq = callback_registry.begin_wait(game, "landing_visual")
  callback_registry.mark_wait_ready(game, "landing_visual", seq)
  _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), true, "should be ready after mark")
end

function TestCallbackRegistry:test_is_wait_ready_false_when_no_wait()
  local game = _make_game()
  _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "no wait → not ready")
end

function TestCallbackRegistry:test_is_wait_ready_false_when_pending_not_marked()
  local game = _make_game()
  callback_registry.begin_wait(game, "landing_visual")
  _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "pending without mark → not ready")
end

function TestCallbackRegistry:test_finish_wait_matching_seq_returns_true()
  local game = _make_game()
  local seq = callback_registry.begin_wait(game, "landing_visual")
  callback_registry.mark_wait_ready(game, "landing_visual", seq)
  local ok = callback_registry.finish_wait(game, "landing_visual", seq)
  _assert_eq(ok, true, "finish_wait with matching seq should return true")
  _assert_eq(callback_registry.pending_wait_seq(game, "landing_visual"), nil, "pending seq should be cleared")
  _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "should not be ready after finish")
end

function TestCallbackRegistry:test_finish_wait_mismatch_returns_false()
  local game = _make_game()
  callback_registry.begin_wait(game, "landing_visual")
  local ok = callback_registry.finish_wait(game, "landing_visual", 999)
  _assert_eq(ok, false, "finish_wait with wrong seq should return false")
end

function TestCallbackRegistry:test_ensure_runtime_idempotent()
  local game = _make_game()
  callback_registry.register(game, "k1", function() end)
  local rt1 = game.wait_callback_runtime
  callback_registry.register(game, "k2", function() end)
  _assert_eq(game.wait_callback_runtime, rt1, "runtime should be reused across calls")
end


return TestCallbackRegistry
