---@diagnostic disable: need-check-nil, different-requires, undefined-field

local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local wait_callbacks = require("src.turn.waits.callback_registry")

describe("callback_registry_lifecycle", function()
  it("wait_lifecycle", function()
    local game = {}
    local wait_key = wait_callbacks.wait_keys.landing_visual
    local seq = wait_callbacks.begin_wait(game, wait_key)
    _assert_eq(wait_callbacks.pending_wait_seq(game, wait_key), seq, "begin_wait should store pending seq")
    _assert_eq(wait_callbacks.is_wait_ready(game, wait_key), false, "new wait should not be ready")
    _assert_eq(wait_callbacks.mark_wait_ready(game, wait_key, seq), true, "mark_wait_ready should accept matching seq")
    _assert_eq(wait_callbacks.is_wait_ready(game, wait_key), true, "ready wait should report ready")
    _assert_eq(wait_callbacks.finish_wait(game, wait_key, seq), true, "finish_wait should clear matching wait")
    _assert_eq(wait_callbacks.pending_wait_seq(game, wait_key), nil, "finish_wait should clear pending seq")
    _assert_eq(wait_callbacks.is_wait_ready(game, wait_key), false, "finished wait should no longer be ready")
  end)
end)
