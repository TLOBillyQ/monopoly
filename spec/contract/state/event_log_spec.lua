local event_log = require("src.state.event_log")

describe("state.event_log", function()
  it("enforces capacity and keeps latest entries", function()
    local log = event_log.new(2)

    event_log.append(log, { kind = "k1", text = "one" })
    event_log.append(log, { kind = "k2", text = "two" })
    event_log.append(log, { kind = "k3", text = "three" })

    local entries = event_log.get_entries(log)
    assert.equals(2, #entries)
    assert.equals("two", entries[1].text)
    assert.equals("three", entries[2].text)
  end)

  it("increments seq and joins text by newline", function()
    local log = event_log.new()
    event_log.append(log, { kind = "k1", text = "alpha" })
    event_log.append(log, { kind = "k2", text = "beta" })

    assert.equals(2, event_log.get_seq(log))
    assert.equals("alpha\nbeta", event_log.get_text(log, 10))
  end)

  it("clear resets entries and seq", function()
    local log = event_log.new()
    event_log.append(log, { kind = "k1", text = "x" })
    event_log.clear(log)

    assert.equals(0, #event_log.get_entries(log))
    assert.equals(0, event_log.get_seq(log))
    assert.equals("", event_log.get_text(log, 10))
  end)
end)
