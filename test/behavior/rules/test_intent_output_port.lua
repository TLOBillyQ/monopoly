require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
local intent_output = require("src.rules.ports.intent_output")

local function _assert_eq(a, b, msg)
  luassert.is.same(b, a, msg)
end

-- 记录 port 调用的假 game:dispatch 只应经由 open_choice / push_popup 出口落地。
local function _make_game()
  local calls = {}
  return {
    calls = calls,
    intent_output_port = {
      open_choice = function(_, choice_spec)
        calls[#calls + 1] = { name = "open_choice", choice_spec = choice_spec }
        return "opened"
      end,
      push_popup = function(_, payload, opts)
        calls[#calls + 1] = { name = "push_popup", payload = payload, opts = opts }
        return "pushed"
      end,
    },
  }
end

do
  local _config_reset = require("test.support.config_reset")

  describe("TestIntentOutputPort", function()
  before_each(function()
    _config_reset.reset_all()
  end)

  it("test_routes_a_need_choice_intent_to_open_choice", function()
    local game = _make_game()
    local spec = { kind = "k" }
    local result = intent_output.dispatch(game, { kind = "need_choice", choice_spec = spec })
    _assert_eq(result, "opened", "should return open_choice result")
    _assert_eq(#game.calls, 1, "one port call")
    _assert_eq(game.calls[1].name, "open_choice", "should route to open_choice")
    _assert_eq(game.calls[1].choice_spec, spec, "should forward the choice_spec")
  end)

  it("test_unwraps_an_intent_envelope_before_routing", function()
    local game = _make_game()
    local spec = { kind = "k" }
    local result = intent_output.dispatch(game, { intent = { kind = "need_choice", choice_spec = spec } })
    _assert_eq(result, "opened", "envelope payload should dispatch its inner intent")
    _assert_eq(game.calls[1].choice_spec, spec, "should forward the inner choice_spec")
  end)

  it("test_routes_a_push_popup_intent_and_prefers_popup_opts_over_opts", function()
    local game = _make_game()
    local payload = { text = "hi" }
    local popup_opts = { a = 1 }
    local result = intent_output.dispatch(
      game,
      { kind = "push_popup", payload = payload, popup_opts = popup_opts },
      { b = 2 }
    )
    _assert_eq(result, "pushed", "should return push_popup result")
    _assert_eq(game.calls[1].name, "push_popup", "should route to push_popup")
    _assert_eq(game.calls[1].payload, payload, "should forward the payload")
    _assert_eq(game.calls[1].opts, popup_opts, "popup_opts should win over caller opts")
  end)

  it("test_falls_back_to_caller_opts_when_the_intent_carries_none", function()
    local game = _make_game()
    local opts = { b = 2 }
    intent_output.dispatch(game, { kind = "push_popup", payload = { text = "hi" } }, opts)
    _assert_eq(game.calls[1].opts, opts, "should fall back to caller opts")
  end)

  it("test_ignores_a_non_table_payload", function()
    local game = _make_game()
    _assert_eq(intent_output.dispatch(game, "not_a_table"), nil, "string payload should be ignored")
    _assert_eq(intent_output.dispatch(game, nil), nil, "nil payload should be ignored")
    _assert_eq(#game.calls, 0, "no port call for a non-table payload")
  end)

  it("test_ignores_a_payload_whose_intent_field_is_not_a_table", function()
    local game = _make_game()
    _assert_eq(intent_output.dispatch(game, { intent = "not_a_table" }), nil, "non-table intent ignored")
    _assert_eq(#game.calls, 0, "no port call for a non-table intent")
  end)

  it("test_ignores_a_table_intent_with_an_unknown_kind", function()
    local game = _make_game()
    _assert_eq(intent_output.dispatch(game, { kind = "mystery" }), nil, "unknown kind should be ignored")
    _assert_eq(#game.calls, 0, "no port call for an unknown kind")
  end)

  it("test_ignores_a_need_choice_intent_that_carries_no_choice_spec", function()
    local game = _make_game()
    _assert_eq(intent_output.dispatch(game, { kind = "need_choice" }), nil, "missing choice_spec ignored")
    _assert_eq(#game.calls, 0, "no port call without a choice_spec")
  end)
end)
end
