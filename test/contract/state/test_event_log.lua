local luassert = assert

local event_log = require("src.state.event_log")

describe("TestEventLog", function()

it("test_enforces_capacity_and_keeps_latest_entries", function()
  local log = event_log.new(2)

  event_log.append(log, { kind = "k1", text = "one" })
  event_log.append(log, { kind = "k2", text = "two" })
  event_log.append(log, { kind = "k3", text = "three" })

  local entries = event_log.get_entries(log)
  luassert.is.equal(2, #entries)
  luassert.is.equal("two", entries[1].text)
  luassert.is.equal("three", entries[2].text)
end)

it("test_increments_seq_and_joins_text_with_time_prefix", function()
  local log = event_log.new()
  event_log.append(log, { kind = "k1", text = "alpha" })
  event_log.append(log, { kind = "k2", text = "beta" })

  luassert.is.equal(2, event_log.get_seq(log))
  local text = event_log.get_text(log, 10)
  luassert.truthy(text:match("^%d%d:%d%d:%d%d alpha\n%d%d:%d%d:%d%d beta$"))
end)

it("test_entry_carries_time_text_in_hh_mm_ss_form", function()
  local log = event_log.new()
  event_log.append(log, { kind = "k", text = "x" })

  local entries = event_log.get_entries(log)
  luassert.is.equal(1, #entries)
  luassert.truthy(entries[1].time_text:match("^%d%d:%d%d:%d%d$"))
end)

it("test_clear_resets_entries_and_seq", function()
  local log = event_log.new()
  event_log.append(log, { kind = "k1", text = "x" })
  event_log.clear(log)

  luassert.is.equal(0, #event_log.get_entries(log))
  luassert.is.equal(0, event_log.get_seq(log))
  luassert.is.equal("", event_log.get_text(log, 10))
end)

end)
