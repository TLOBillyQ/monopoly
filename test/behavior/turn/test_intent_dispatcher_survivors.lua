-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
local function _assert_same(actual, expected, message)
  luassert.is.same(expected, actual, message)
end
local function _assert_contains(actual, expected, message)
  luassert.matches(expected, actual, 1, true, message)
end
local intent_dispatcher = require("src.turn.output.intent_dispatcher")

-- Minimal game that satisfies open_choice: a turn table for the choice sequence,
-- a plain dirty table for dirty_tracker.mark, and an event_feed_port that records
-- published events so the choice-log text can be asserted directly.
local function _choice_game(choice_seq)
  local events = {}
  local game = {
    turn = { choice_seq = choice_seq, pending_choice = nil },
    dirty = {},
    event_feed_port = {
      publish = function(_, _, event)
        events[#events + 1] = event
        return true
      end,
    },
  }
  return game, events
end

local function _recording_port()
  local port = { calls = {} }
  port.push_popup = function(_, payload, opts)
    port.calls[#port.calls + 1] = { payload = payload, opts = opts }
  end
  return port
end

describe("TestIntentDispatcherSurvivors", function()

it("test_omits_the_body_separator_when_the_first_body_line_is_empty", function()
  local game, events = _choice_game()
  intent_dispatcher.open_choice(game, {
    kind = "probe",
    title = "标题",
    body_lines = { "" },
    options = {},
    meta = {},
  }, {})
  _assert_same(#events, 1)
  _assert_same(events[1].text, "等待选择：标题")
end)

it("test_defaults the choice title to 请选择 when none is provided", function()
  local game = _choice_game()
  local entry = intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, {})
  _assert_same(entry.title, "请选择")
end)

it("test_keeps_a_caller_provided_cancel_label", function()
  local game = _choice_game()
  local entry = intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    cancel_label = "退出",
    meta = {},
  }, {})
  _assert_same(entry.cancel_label, "退出")
end)

it("test_defaults the cancel label to 取消 when none is provided", function()
  local game = _choice_game()
  local entry = intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, {})
  _assert_same(entry.cancel_label, "取消")
end)

it("test_increments_the_existing_choice_sequence_by_one", function()
  local game = _choice_game(5)
  local entry = intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, {})
  _assert_same(entry.id, 6)
  _assert_same(game.turn.choice_seq, 6)
end)

it("test_starts_the_choice_sequence_at_one_when_unset", function()
  local game = _choice_game()
  local entry = intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, {})
  _assert_same(entry.id, 1)
end)

it("test_publishes_choice_picked_event_with_tip_false", function()
  local game, events = _choice_game()
  intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, {})
  _assert_same(#events, 1)
  luassert.is_false(events[1].tip)
end)

it("test_defaults_elapsed_seconds_to_0_when_opts_is_nil", function()
  local events_mod = package.loaded["src.foundation.events"]
  local saved = events_mod.emit_intent
  local captured_intent
  events_mod.emit_intent = function(kind, payload)
    captured_intent = payload
  end
  local game = _choice_game()
  intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, nil)
  events_mod.emit_intent = saved
  luassert.is_not_nil(captured_intent)
  _assert_same(captured_intent.elapsed_seconds, 0)
end)

it("test_defaults_elapsed_seconds_to_0_when_opts_elapsed_seconds_is_nil", function()
  local events_mod = package.loaded["src.foundation.events"]
  local saved = events_mod.emit_intent
  local captured_intent
  events_mod.emit_intent = function(kind, payload)
    captured_intent = payload
  end
  local game = _choice_game()
  intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, {})
  events_mod.emit_intent = saved
  luassert.is_not_nil(captured_intent)
  _assert_same(captured_intent.elapsed_seconds, 0)
end)

it("test_passes_through_explicit_elapsed_seconds_when_provided", function()
  local events_mod = package.loaded["src.foundation.events"]
  local saved = events_mod.emit_intent
  local captured_intent
  events_mod.emit_intent = function(kind, payload)
    captured_intent = payload
  end
  local game = _choice_game()
  intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, { elapsed_seconds = 7.5 })
  events_mod.emit_intent = saved
  luassert.is_not_nil(captured_intent)
  _assert_same(captured_intent.elapsed_seconds, 7.5)
end)

it("test_uses_game_popup_port_directly", function()
  local port_a = _recording_port()
  local game = { popup_port = port_a }

  local ok = intent_dispatcher.push_popup(game, { message = "hi" }, { policy = "x" })

  luassert.is_true(ok)
  _assert_same(#port_a.calls, 1)
end)

it("test_rejects_a_missing_popup_port", function()
  local ok, err = pcall(intent_dispatcher.push_popup, {}, { message = "hi" }, {})

  luassert.is_false(ok)
  _assert_contains(tostring(err), "missing popup_port")
end)

it("test_forwards_the_opts_table_through_to_the_popup_port", function()
  local port_a = _recording_port()
  local game = { popup_port = port_a }

  intent_dispatcher.push_popup(game, { message = "hi" }, { policy = "replace" })

  _assert_same(port_a.calls[1].opts.policy, "replace")
end)

it("test_treats_a_bare_intent_table_without_a_wrapper_as_the_intent", function()
  local game = _choice_game()
  local entry = intent_dispatcher.dispatch(game, {
    kind = "need_choice",
    choice_spec = { kind = "probe", options = {}, meta = {} },
  })
  luassert.is_not_nil(entry)
  _assert_same(entry.kind, "probe")
end)

it("test_routes_a_need_choice_intent_to_open_choice", function()
  local game = _choice_game()
  local entry = intent_dispatcher.dispatch(game, {
    intent = { kind = "need_choice", choice_spec = { kind = "probe", options = {}, meta = {} } },
  })
  luassert.is_not_nil(entry)
  _assert_same(entry.kind, "probe")
  luassert.is_not_nil(game.turn.pending_choice)
end)

it("test_requires_both_need_choice_kind_and_a_choice_spec_to_open_a_choice", function()
  local game = _choice_game()
  local result = intent_dispatcher.dispatch(game, {
    intent = { kind = "unknown_kind", choice_spec = { kind = "probe", options = {}, meta = {} } },
  })
  luassert.is_nil(result)
  luassert.is_nil(game.turn.pending_choice)
end)

it("test_requires_a_payload_before_routing_a_push_popup_intent", function()
  local game = { popup_port = _recording_port() }
  local result = intent_dispatcher.dispatch(game, { intent = { kind = "push_popup" } })
  luassert.is_nil(result)
end)

it("test_prefers_popup_opts_over_opts_when_forwarding_popup_opts", function()
  local port_a = _recording_port()
  local game = { popup_port = port_a }
  intent_dispatcher.dispatch(game, {
    intent = {
      kind = "push_popup",
      payload = { message = "hi" },
      popup_opts = { tag = "primary" },
      opts = { tag = "secondary" },
    },
  })
  _assert_same(port_a.calls[1].opts.tag, "primary")
end)

it("test_falls_back_to_opts_when_popup_opts_is_absent", function()
  local port_a = _recording_port()
  local game = { popup_port = port_a }
  intent_dispatcher.dispatch(game, {
    intent = {
      kind = "push_popup",
      payload = { message = "hi" },
      opts = { tag = "secondary" },
    },
  })
  _assert_same(port_a.calls[1].opts.tag, "secondary")
end)

it("test_open_choice_without_game_turn_raises_choice_open_requires_game_turn", function()
  -- kills the assert's `and` -> `or` and message -> nil.
  luassert.has_error(function()
    intent_dispatcher.open_choice({}, { kind = "probe", options = {} })
  end, "Choice.open requires game.turn")
end)

it("test_open_choice_without_choice_spec_raises_missing_choice_spec", function()
  local game = _choice_game()
  luassert.has_error(function()
    intent_dispatcher.open_choice(game, nil)
  end, "missing choice_spec")
end)

it("test_push_popup_without_payload_raises_missing_popup_payload", function()
  luassert.has_error(function()
    intent_dispatcher.push_popup({}, nil)
  end, "missing popup payload")
end)

it("test_push_popup_without_any_popup_port_raises_missing_popup_port", function()
  -- kills _resolve_popup_port's "missing popup_port" -> nil.
  luassert.has_error(function()
    intent_dispatcher.push_popup({}, { text = "x" })
  end, "missing popup_port")
end)

it("test_push_popup_with_a_port_lacking_push_popup_raises_missing_popup_port_push_popup", function()
  luassert.has_error(function()
    intent_dispatcher.push_popup({ popup_port = {} }, { text = "x" })
  end, "missing popup_port.push_popup")
end)

it("test_dispatch_without_payload_raises_missing_payload", function()
  luassert.has_error(function()
    intent_dispatcher.dispatch({}, nil)
  end, "missing payload")
end)

it("test_dispatch_routes_a_bare_push_popup_intent_payload_intent_falls_back_to_payload", function()
  -- kills _resolve_intent's `payload.intent or payload` `or` -> `and`: a
  -- payload that IS the intent must still route to push_popup.
  local port = _recording_port()
  local game = { popup_port = port }
  local result = intent_dispatcher.dispatch(game, {
    kind = "push_popup",
    payload = { text = "hello" },
  })
  _assert_same(result, true)
  _assert_same(#port.calls, 1)
  _assert_same(port.calls[1].payload.text, "hello")
end)

it("test_dispatch_returns_nil_for_a_truthy_non_table_wrapped_intent", function()
  -- kills _resolve_intent's `not intent or type(intent) ~= "table"` `or` -> `and`:
  -- a truthy non-table intent must be rejected; the `and` mutant returns it
  -- raw and the dispatcher goes on to index a number.
  local result = intent_dispatcher.dispatch({}, { intent = 5 })
  luassert.is_nil(result)
end)

it("test_dispatch_returns_nil_for_a_bare_non_table_payload", function()
  local result = intent_dispatcher.dispatch({}, "not-an-intent")
  luassert.is_nil(result)
end)
end)
