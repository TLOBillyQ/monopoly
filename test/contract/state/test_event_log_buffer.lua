local luassert = assert

local event_log = require("src.state.event_log")

describe("TestEventLogBuffer", function()

it("test_appends_directly_without_active_buffer", function()
  local log = event_log.new()

  event_log.append(log, { kind = "direct", text = "line1" })

  local entries = event_log.get_entries(log)
  luassert.is.equal(1, #entries)
  luassert.is.equal("line1", entries[1].text)
  luassert.is.equal(1, entries[1].seq)
end)

it("test_push_then_append_writes_entries_directly_and_tracks_pending", function()
  local log = event_log.new()
  local hold = {}

  event_log.push_buffer(log, hold)
  event_log.append(log, { kind = "k", text = "a" })
  event_log.append(log, { kind = "k", text = "b" })
  event_log.append(log, { kind = "k", text = "c" })

  local entries = event_log.get_entries(log)
  luassert.is.equal(3, #entries)
  luassert.is.equal("a", entries[1].text)
  luassert.is.equal("b", entries[2].text)
  luassert.is.equal("c", entries[3].text)
  luassert.is.equal(3, event_log.get_seq(log))
  luassert.is.equal(3, #hold.pending)

  event_log.flush_buffer(hold)

  luassert.is.equal(3, #event_log.get_entries(log))
  luassert.is_nil(hold.pending)
  luassert.is_nil(hold._event_log_ref)
end)

it("test_pop_after_append_leaves_entries_written_and_clears_pending_ref", function()
  local log = event_log.new()
  local hold = {}

  event_log.push_buffer(log, hold)
  event_log.append(log, { kind = "k", text = "x" })
  event_log.append(log, { kind = "k", text = "y" })
  event_log.pop_buffer(hold)

  luassert.is.equal(2, #event_log.get_entries(log))
  luassert.is.equal(2, event_log.get_seq(log))
  luassert.is_nil(hold._event_log_ref)
end)

it("test_nested_push_routes_pending_tracking_to_top_buffer", function()
  local log = event_log.new()
  local hold_a = {}
  local hold_b = {}

  event_log.push_buffer(log, hold_a)
  event_log.push_buffer(log, hold_b)
  event_log.append(log, { kind = "k", text = "inner" })

  luassert.is.equal(1, #event_log.get_entries(log))
  luassert.is.equal(1, #hold_b.pending)
  luassert.is_nil(hold_a.pending[1])

  event_log.flush_buffer(hold_b)
  event_log.append(log, { kind = "k", text = "outer" })

  luassert.is.equal(2, #event_log.get_entries(log))
  luassert.is.equal(1, #hold_a.pending)
  luassert.is.equal("outer", hold_a.pending[1].text)
end)

end)
