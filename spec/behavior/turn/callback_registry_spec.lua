local callback_registry = require("src.turn.waits.callback_registry")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game()
  return {}
end

-- register and peek


-- register: invalid key errors


-- register: non-function callback errors


-- take: removes and returns callback


-- take: returns nil when no callback registered


-- clear: specific key


-- clear: nil key clears all callbacks


-- clear specific key also removes seq state


-- reset_runtime delegates to clear


-- begin_wait increments seq


-- begin_wait: invalid key errors


-- pending_wait_seq returns pending seq


-- mark_wait_ready: matching seq returns true


-- mark_wait_ready: mismatched seq returns false


-- is_wait_ready: true after mark_wait_ready


-- is_wait_ready: false when no pending wait


-- is_wait_ready: false when pending but not marked ready


-- finish_wait: matching seq clears pending and ready, returns true


-- finish_wait: mismatched seq returns false


-- _ensure_runtime: reuses existing runtime

describe("domain callback registry coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("register stores callback", function()
    local game = _make_game()
    local fn = function() return "ok" end
    local returned = callback_registry.register(game, "after_action_anim", fn)
    _assert_eq(returned, fn, "register should return the callback")
    _assert_eq(callback_registry.peek(game, "after_action_anim"), fn, "peek should return registered callback")
  end)

  it("register errors on empty key", function()
    local game = _make_game()
    local ok = pcall(function()
      callback_registry.register(game, "", function() end)
    end)
    _assert_eq(ok, false, "empty key should error")
  end)

  it("register errors on non function", function()
    local game = _make_game()
    local ok = pcall(function()
      callback_registry.register(game, "key", "not_a_fn")
    end)
    _assert_eq(ok, false, "non-function callback should error")
  end)

  it("take removes callback", function()
    local game = _make_game()
    local fn = function() end
    callback_registry.register(game, "after_landing_visual", fn)
    local taken = callback_registry.take(game, "after_landing_visual")
    _assert_eq(taken, fn, "take should return callback")
    _assert_eq(callback_registry.peek(game, "after_landing_visual"), nil, "after take callback should be nil")
  end)

  it("take returns nil when missing", function()
    local game = _make_game()
    local result = callback_registry.take(game, "missing_key")
    _assert_eq(result, nil, "take on missing key should return nil")
  end)

  it("clear specific key removes callback", function()
    local game = _make_game()
    callback_registry.register(game, "k1", function() end)
    callback_registry.register(game, "k2", function() end)
    callback_registry.clear(game, "k1")
    _assert_eq(callback_registry.peek(game, "k1"), nil, "cleared key should be nil")
    assert(callback_registry.peek(game, "k2") ~= nil, "other key should remain")
  end)

  it("clear nil key clears all", function()
    local game = _make_game()
    callback_registry.register(game, "k1", function() end)
    callback_registry.register(game, "k2", function() end)
    callback_registry.clear(game, nil)
    _assert_eq(callback_registry.peek(game, "k1"), nil, "all callbacks should be cleared")
    _assert_eq(callback_registry.peek(game, "k2"), nil, "all callbacks should be cleared")
  end)

  it("clear specific key removes seq state", function()
    local game = _make_game()
    local seq = callback_registry.begin_wait(game, "landing_visual")
    callback_registry.mark_wait_ready(game, "landing_visual", seq)
    callback_registry.clear(game, "landing_visual")
    _assert_eq(callback_registry.pending_wait_seq(game, "landing_visual"), nil, "clear should remove pending seq")
    _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "clear should remove ready seq")
  end)

  it("reset_runtime clears all", function()
    local game = _make_game()
    callback_registry.register(game, "k1", function() end)
    callback_registry.reset_runtime(game)
    _assert_eq(callback_registry.peek(game, "k1"), nil, "reset_runtime should clear all callbacks")
  end)

  it("begin_wait returns incrementing seq", function()
    local game = _make_game()
    local s1 = callback_registry.begin_wait(game, "landing_visual")
    local s2 = callback_registry.begin_wait(game, "landing_visual")
    _assert_eq(s1, 1, "first seq should be 1")
    _assert_eq(s2, 2, "second seq should be 2")
  end)

  it("begin_wait errors on empty key", function()
    local game = _make_game()
    local ok = pcall(function() callback_registry.begin_wait(game, "") end)
    _assert_eq(ok, false, "empty key should error in begin_wait")
  end)

  it("pending_wait_seq returns current", function()
    local game = _make_game()
    local seq = callback_registry.begin_wait(game, "landing_visual")
    _assert_eq(callback_registry.pending_wait_seq(game, "landing_visual"), seq, "should return pending seq")
  end)

  it("mark_wait_ready matching seq returns true", function()
    local game = _make_game()
    local seq = callback_registry.begin_wait(game, "landing_visual")
    local ok = callback_registry.mark_wait_ready(game, "landing_visual", seq)
    _assert_eq(ok, true, "matching seq should return true")
  end)

  it("mark_wait_ready mismatch returns false", function()
    local game = _make_game()
    callback_registry.begin_wait(game, "landing_visual")
    local ok = callback_registry.mark_wait_ready(game, "landing_visual", 999)
    _assert_eq(ok, false, "mismatched seq should return false")
  end)

  it("is_wait_ready true after mark", function()
    local game = _make_game()
    local seq = callback_registry.begin_wait(game, "landing_visual")
    callback_registry.mark_wait_ready(game, "landing_visual", seq)
    _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), true, "should be ready after mark")
  end)

  it("is_wait_ready false when no wait", function()
    local game = _make_game()
    _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "no wait → not ready")
  end)

  it("is_wait_ready false when pending not marked", function()
    local game = _make_game()
    callback_registry.begin_wait(game, "landing_visual")
    _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "pending without mark → not ready")
  end)

  it("finish_wait matching seq returns true", function()
    local game = _make_game()
    local seq = callback_registry.begin_wait(game, "landing_visual")
    callback_registry.mark_wait_ready(game, "landing_visual", seq)
    local ok = callback_registry.finish_wait(game, "landing_visual", seq)
    _assert_eq(ok, true, "finish_wait with matching seq should return true")
    _assert_eq(callback_registry.pending_wait_seq(game, "landing_visual"), nil, "pending seq should be cleared")
    _assert_eq(callback_registry.is_wait_ready(game, "landing_visual"), false, "should not be ready after finish")
  end)

  it("finish_wait mismatch returns false", function()
    local game = _make_game()
    callback_registry.begin_wait(game, "landing_visual")
    local ok = callback_registry.finish_wait(game, "landing_visual", 999)
    _assert_eq(ok, false, "finish_wait with wrong seq should return false")
  end)

  it("ensure_runtime idempotent", function()
    local game = _make_game()
    callback_registry.register(game, "k1", function() end)
    local rt1 = game.wait_callback_runtime
    callback_registry.register(game, "k2", function() end)
    _assert_eq(game.wait_callback_runtime, rt1, "runtime should be reused across calls")
  end)
end)
