local lu = require("luaunit")

local event_log = require("src.state.event_log")

TestEventLogBuffer = {}

function TestEventLogBuffer:test_appends_directly_without_active_buffer()
  local log = event_log.new()

  event_log.append(log, { kind = "direct", text = "line1" })

  local entries = event_log.get_entries(log)
  lu.assertEquals(#entries, 1)
  lu.assertEquals(entries[1].text, "line1")
  lu.assertEquals(entries[1].seq, 1)
end

function TestEventLogBuffer:test_push_then_append_writes_entries_directly_and_tracks_pending()
  local log = event_log.new()
  local hold = {}

  event_log.push_buffer(log, hold)
  event_log.append(log, { kind = "k", text = "a" })
  event_log.append(log, { kind = "k", text = "b" })
  event_log.append(log, { kind = "k", text = "c" })

  local entries = event_log.get_entries(log)
  lu.assertEquals(#entries, 3)
  lu.assertEquals(entries[1].text, "a")
  lu.assertEquals(entries[2].text, "b")
  lu.assertEquals(entries[3].text, "c")
  lu.assertEquals(event_log.get_seq(log), 3)
  lu.assertEquals(#hold.pending, 3)

  event_log.flush_buffer(hold)

  lu.assertEquals(#event_log.get_entries(log), 3)
  lu.assertNil(hold.pending)
  lu.assertNil(hold._event_log_ref)
end

function TestEventLogBuffer:test_pop_after_append_leaves_entries_written_and_clears_pending_ref()
  local log = event_log.new()
  local hold = {}

  event_log.push_buffer(log, hold)
  event_log.append(log, { kind = "k", text = "x" })
  event_log.append(log, { kind = "k", text = "y" })
  event_log.pop_buffer(hold)

  lu.assertEquals(#event_log.get_entries(log), 2)
  lu.assertEquals(event_log.get_seq(log), 2)
  lu.assertNil(hold._event_log_ref)
end

function TestEventLogBuffer:test_nested_push_routes_pending_tracking_to_top_buffer()
  local log = event_log.new()
  local hold_a = {}
  local hold_b = {}

  event_log.push_buffer(log, hold_a)
  event_log.push_buffer(log, hold_b)
  event_log.append(log, { kind = "k", text = "inner" })

  lu.assertEquals(#event_log.get_entries(log), 1)
  lu.assertEquals(#hold_b.pending, 1)
  lu.assertNil(hold_a.pending[1])

  event_log.flush_buffer(hold_b)
  event_log.append(log, { kind = "k", text = "outer" })

  lu.assertEquals(#event_log.get_entries(log), 2)
  lu.assertEquals(#hold_a.pending, 1)
  lu.assertEquals(hold_a.pending[1].text, "outer")
end


return TestEventLogBuffer
