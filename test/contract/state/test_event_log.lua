local lu = require("luaunit")

local event_log = require("src.state.event_log")

TestEventLog = {}

function TestEventLog:test_enforces_capacity_and_keeps_latest_entries()
  local log = event_log.new(2)

  event_log.append(log, { kind = "k1", text = "one" })
  event_log.append(log, { kind = "k2", text = "two" })
  event_log.append(log, { kind = "k3", text = "three" })

  local entries = event_log.get_entries(log)
  lu.assertEquals(#entries, 2)
  lu.assertEquals(entries[1].text, "two")
  lu.assertEquals(entries[2].text, "three")
end

function TestEventLog:test_increments_seq_and_joins_text_with_time_prefix()
  local log = event_log.new()
  event_log.append(log, { kind = "k1", text = "alpha" })
  event_log.append(log, { kind = "k2", text = "beta" })

  lu.assertEquals(event_log.get_seq(log), 2)
  local text = event_log.get_text(log, 10)
  lu.assertEvalToTrue(text:match("^%d%d:%d%d:%d%d alpha\n%d%d:%d%d:%d%d beta$"))
end

function TestEventLog:test_entry_carries_time_text_in_hh_mm_ss_form()
  local log = event_log.new()
  event_log.append(log, { kind = "k", text = "x" })

  local entries = event_log.get_entries(log)
  lu.assertEquals(#entries, 1)
  lu.assertEvalToTrue(entries[1].time_text:match("^%d%d:%d%d:%d%d$"))
end

function TestEventLog:test_clear_resets_entries_and_seq()
  local log = event_log.new()
  event_log.append(log, { kind = "k1", text = "x" })
  event_log.clear(log)

  lu.assertEquals(#event_log.get_entries(log), 0)
  lu.assertEquals(event_log.get_seq(log), 0)
  lu.assertEquals(event_log.get_text(log, 10), "")
end


return TestEventLog
