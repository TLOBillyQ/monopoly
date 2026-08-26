local lu = require("luaunit")
local luax = require("test.support.luax")
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

TestIntentDispatcherSurvivors = {}

function TestIntentDispatcherSurvivors:test_omits_the_body_separator_when_the_first_body_line_is_empty()
  local game, events = _choice_game()
  intent_dispatcher.open_choice(game, {
    kind = "probe",
    title = "标题",
    body_lines = { "" },
    options = {},
    meta = {},
  }, {})
  lu.assertEquals(#events, 1)
  lu.assertEquals(events[1].text, "等待选择：标题")
end

TestIntentDispatcherSurvivors["test_defaults the choice title to 请选择 when none is provided"] = function(self)
  local game = _choice_game()
  local entry = intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, {})
  lu.assertEquals(entry.title, "请选择")
end

function TestIntentDispatcherSurvivors:test_keeps_a_caller_provided_cancel_label()
  local game = _choice_game()
  local entry = intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    cancel_label = "退出",
    meta = {},
  }, {})
  lu.assertEquals(entry.cancel_label, "退出")
end

TestIntentDispatcherSurvivors["test_defaults the cancel label to 取消 when none is provided"] = function(self)
  local game = _choice_game()
  local entry = intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, {})
  lu.assertEquals(entry.cancel_label, "取消")
end

function TestIntentDispatcherSurvivors:test_increments_the_existing_choice_sequence_by_one()
  local game = _choice_game(5)
  local entry = intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, {})
  lu.assertEquals(entry.id, 6)
  lu.assertEquals(game.turn.choice_seq, 6)
end

function TestIntentDispatcherSurvivors:test_starts_the_choice_sequence_at_one_when_unset()
  local game = _choice_game()
  local entry = intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, {})
  lu.assertEquals(entry.id, 1)
end

function TestIntentDispatcherSurvivors:test_publishes_choice_picked_event_with_tip_false()
  local game, events = _choice_game()
  intent_dispatcher.open_choice(game, {
    kind = "probe",
    options = {},
    meta = {},
  }, {})
  lu.assertEquals(#events, 1)
  lu.assertFalse(events[1].tip)
end

function TestIntentDispatcherSurvivors:test_defaults_elapsed_seconds_to_0_when_opts_is_nil()
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
  lu.assertNotNil(captured_intent)
  lu.assertEquals(captured_intent.elapsed_seconds, 0)
end

function TestIntentDispatcherSurvivors:test_defaults_elapsed_seconds_to_0_when_opts_elapsed_seconds_is_nil()
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
  lu.assertNotNil(captured_intent)
  lu.assertEquals(captured_intent.elapsed_seconds, 0)
end

function TestIntentDispatcherSurvivors:test_passes_through_explicit_elapsed_seconds_when_provided()
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
  lu.assertNotNil(captured_intent)
  lu.assertEquals(captured_intent.elapsed_seconds, 7.5)
end

function TestIntentDispatcherSurvivors:test_uses_game_popup_port_directly()
  local port_a = _recording_port()
  local game = { popup_port = port_a }

  local ok = intent_dispatcher.push_popup(game, { message = "hi" }, { policy = "x" })

  lu.assertTrue(ok)
  lu.assertEquals(#port_a.calls, 1)
end

function TestIntentDispatcherSurvivors:test_rejects_a_missing_popup_port()
  local ok, err = pcall(intent_dispatcher.push_popup, {}, { message = "hi" }, {})

  lu.assertFalse(ok)
  lu.assertStrContains(tostring(err), "missing popup_port")
end

function TestIntentDispatcherSurvivors:test_forwards_the_opts_table_through_to_the_popup_port()
  local port_a = _recording_port()
  local game = { popup_port = port_a }

  intent_dispatcher.push_popup(game, { message = "hi" }, { policy = "replace" })

  lu.assertEquals(port_a.calls[1].opts.policy, "replace")
end

function TestIntentDispatcherSurvivors:test_treats_a_bare_intent_table_without_a_wrapper_as_the_intent()
  local game = _choice_game()
  local entry = intent_dispatcher.dispatch(game, {
    kind = "need_choice",
    choice_spec = { kind = "probe", options = {}, meta = {} },
  })
  lu.assertNotNil(entry)
  lu.assertEquals(entry.kind, "probe")
end

function TestIntentDispatcherSurvivors:test_routes_a_need_choice_intent_to_open_choice()
  local game = _choice_game()
  local entry = intent_dispatcher.dispatch(game, {
    intent = { kind = "need_choice", choice_spec = { kind = "probe", options = {}, meta = {} } },
  })
  lu.assertNotNil(entry)
  lu.assertEquals(entry.kind, "probe")
  lu.assertNotNil(game.turn.pending_choice)
end

function TestIntentDispatcherSurvivors:test_requires_both_need_choice_kind_and_a_choice_spec_to_open_a_choice()
  local game = _choice_game()
  local result = intent_dispatcher.dispatch(game, {
    intent = { kind = "unknown_kind", choice_spec = { kind = "probe", options = {}, meta = {} } },
  })
  lu.assertNil(result)
  lu.assertNil(game.turn.pending_choice)
end

function TestIntentDispatcherSurvivors:test_requires_a_payload_before_routing_a_push_popup_intent()
  local game = { popup_port = _recording_port() }
  local result = intent_dispatcher.dispatch(game, { intent = { kind = "push_popup" } })
  lu.assertNil(result)
end

function TestIntentDispatcherSurvivors:test_prefers_popup_opts_over_opts_when_forwarding_popup_opts()
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
  lu.assertEquals(port_a.calls[1].opts.tag, "primary")
end

function TestIntentDispatcherSurvivors:test_falls_back_to_opts_when_popup_opts_is_absent()
  local port_a = _recording_port()
  local game = { popup_port = port_a }
  intent_dispatcher.dispatch(game, {
    intent = {
      kind = "push_popup",
      payload = { message = "hi" },
      opts = { tag = "secondary" },
    },
  })
  lu.assertEquals(port_a.calls[1].opts.tag, "secondary")
end

function TestIntentDispatcherSurvivors:test_open_choice_without_game_turn_raises_choice_open_requires_game_turn()
  -- kills the assert's `and` -> `or` and message -> nil.
  luax.has_error(function()
    intent_dispatcher.open_choice({}, { kind = "probe", options = {} })
  end, "Choice.open requires game.turn")
end

function TestIntentDispatcherSurvivors:test_open_choice_without_choice_spec_raises_missing_choice_spec()
  local game = _choice_game()
  luax.has_error(function()
    intent_dispatcher.open_choice(game, nil)
  end, "missing choice_spec")
end

function TestIntentDispatcherSurvivors:test_push_popup_without_payload_raises_missing_popup_payload()
  luax.has_error(function()
    intent_dispatcher.push_popup({}, nil)
  end, "missing popup payload")
end

function TestIntentDispatcherSurvivors:test_push_popup_without_any_popup_port_raises_missing_popup_port()
  -- kills _resolve_popup_port's "missing popup_port" -> nil.
  luax.has_error(function()
    intent_dispatcher.push_popup({}, { text = "x" })
  end, "missing popup_port")
end

function TestIntentDispatcherSurvivors:test_push_popup_with_a_port_lacking_push_popup_raises_missing_popup_port_push_popup()
  luax.has_error(function()
    intent_dispatcher.push_popup({ popup_port = {} }, { text = "x" })
  end, "missing popup_port.push_popup")
end

function TestIntentDispatcherSurvivors:test_dispatch_without_payload_raises_missing_payload()
  luax.has_error(function()
    intent_dispatcher.dispatch({}, nil)
  end, "missing payload")
end

function TestIntentDispatcherSurvivors:test_dispatch_routes_a_bare_push_popup_intent_payload_intent_falls_back_to_payload()
  -- kills _resolve_intent's `payload.intent or payload` `or` -> `and`: a
  -- payload that IS the intent must still route to push_popup.
  local port = _recording_port()
  local game = { popup_port = port }
  local result = intent_dispatcher.dispatch(game, {
    kind = "push_popup",
    payload = { text = "hello" },
  })
  lu.assertEquals(result, true)
  lu.assertEquals(#port.calls, 1)
  lu.assertEquals(port.calls[1].payload.text, "hello")
end

function TestIntentDispatcherSurvivors:test_dispatch_returns_nil_for_a_truthy_non_table_wrapped_intent()
  -- kills _resolve_intent's `not intent or type(intent) ~= "table"` `or` -> `and`:
  -- a truthy non-table intent must be rejected; the `and` mutant returns it
  -- raw and the dispatcher goes on to index a number.
  local result = intent_dispatcher.dispatch({}, { intent = 5 })
  lu.assertNil(result)
end

function TestIntentDispatcherSurvivors:test_dispatch_returns_nil_for_a_bare_non_table_payload()
  local result = intent_dispatcher.dispatch({}, "not-an-intent")
  lu.assertNil(result)
end


return TestIntentDispatcherSurvivors
