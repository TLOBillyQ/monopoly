local event_log = require("src.state.event_log")

describe("state.event_log buffer semantics", function()
  it("appends directly without active buffer", function()
    local log = event_log.new()

    event_log.append(log, { kind = "direct", text = "line1" })

    local entries = event_log.get_entries(log)
    assert.equals(1, #entries)
    assert.equals("line1", entries[1].text)
    assert.equals(1, entries[1].seq)
  end)

  it("push then append then flush writes pending in order", function()
    local log = event_log.new()
    local hold = {}

    event_log.push_buffer(log, hold)
    event_log.append(log, { kind = "k", text = "a" })
    event_log.append(log, { kind = "k", text = "b" })
    event_log.append(log, { kind = "k", text = "c" })

    assert.equals(0, #event_log.get_entries(log))
    assert.equals(3, event_log.get_seq(log))

    event_log.flush_buffer(hold)

    local entries = event_log.get_entries(log)
    assert.equals(3, #entries)
    assert.equals("a", entries[1].text)
    assert.equals("b", entries[2].text)
    assert.equals("c", entries[3].text)
    assert.is_nil(hold._event_log_ref)
  end)

  it("push then append then pop discards pending", function()
    local log = event_log.new()
    local hold = {}

    event_log.push_buffer(log, hold)
    event_log.append(log, { kind = "k", text = "x" })
    event_log.append(log, { kind = "k", text = "y" })
    event_log.pop_buffer(hold)

    assert.equals(0, #event_log.get_entries(log))
    assert.equals(2, event_log.get_seq(log))
    assert.is_nil(hold._event_log_ref)
  end)

  it("nested push routes append to top buffer", function()
    local log = event_log.new()
    local hold_a = {}
    local hold_b = {}

    event_log.push_buffer(log, hold_a)
    event_log.push_buffer(log, hold_b)
    event_log.append(log, { kind = "k", text = "inner" })

    assert.equals(1, #hold_b.pending)
    assert.is_nil(hold_a.pending[1])

    event_log.flush_buffer(hold_b)
    event_log.append(log, { kind = "k", text = "outer" })

    assert.equals(1, #event_log.get_entries(log))
    assert.equals(1, #hold_a.pending)
    assert.equals("outer", hold_a.pending[1].text)
  end)
end)
