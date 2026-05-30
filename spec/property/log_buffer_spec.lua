---@diagnostic disable: need-check-nil, duplicate-set-field

local property = require("spec.support.property")
local logger = require("src.foundation.log")

-- Drive the real circular-buffer write path (`push` -> `_store_entry`) and read
-- it back through `get_entries`, across broad capacity x push-count ranges. The
-- example-based formatter spec only exercises the read side with hand-built
-- buffer states; these properties pin the wraparound arithmetic end-to-end:
-- the capacity bound, FIFO recency (newest entries survive, in insertion order),
-- and the max_lines tail truncation.
local push = logger.formatter.push
local get_entries = logger.formatter.get_entries

-- Each push prints the formatted entry through the global `print`; silence it so
-- generative runs do not flood the TAP stream. Restored after every case.
local _real_print
before_each(function()
  _real_print = _G.print
  _G.print = function() end
end)
after_each(function()
  _G.print = _real_print
end)

-- Fresh buffer state with an empty backing table; `seq` lets us assert which
-- entries survived without depending on entry text.
local function _new_state(capacity)
  return {
    entries = {},
    max_entries = capacity,
    seq = 0,
    timestamp_provider = function()
      return 0
    end,
    time_formatter = function(timestamp)
      return tostring(timestamp)
    end,
  }
end

-- Push `push_count` entries into a capacity-`capacity` buffer and return the
-- state. Levels stay "warn" so the info-per-turn throttle never drops a push.
local function _fill(capacity, push_count)
  local state = _new_state(capacity)
  for _ = 1, push_count do
    push(state, "warn", nil, "entry")
  end
  return state
end

local function _seqs(entries)
  local out = {}
  for index, entry in ipairs(entries) do
    out[index] = entry.seq
  end
  return out
end

local function _gen_case(rng)
  return { capacity = rng:int(1, 8), push_count = rng:int(0, 30) }
end

describe("log circular buffer properties", function()
  it("never retains more than the capacity, and keeps everything below it", function()
    property.for_all(_gen_case, function(case)
      local state = _fill(case.capacity, case.push_count)
      local kept = #get_entries(state)
      local expected = math.min(case.push_count, case.capacity)
      assert(kept == expected,
        "kept " .. kept .. " entries, expected min(push_count, capacity)=" .. expected)
    end)
  end)

  it("keeps the newest entries in insertion order (FIFO recency)", function()
    property.for_all(_gen_case, function(case)
      local entries = get_entries(_fill(case.capacity, case.push_count))
      local kept = math.min(case.push_count, case.capacity)
      -- seq increments 1..push_count across pushes, so the survivors must be the
      -- contiguous tail {push_count-kept+1, ..., push_count} in ascending order.
      local seqs = _seqs(entries)
      for offset = 1, kept do
        local expected_seq = case.push_count - kept + offset
        assert(seqs[offset] == expected_seq,
          "slot " .. offset .. " held seq " .. tostring(seqs[offset])
            .. ", expected " .. expected_seq)
      end
    end)
  end)

  it("max_lines returns the trailing window of the full listing", function()
    property.for_all(function(rng)
      local case = _gen_case(rng)
      case.max_lines = rng:int(0, case.capacity + 3)
      return case
    end, function(case)
      local state = _fill(case.capacity, case.push_count)
      local full = _seqs(get_entries(state))
      local limited = _seqs(get_entries(state, case.max_lines))
      local want = math.min(case.max_lines, #full)
      assert(#limited == want,
        "max_lines window held " .. #limited .. " entries, expected " .. want)
      for offset = 1, want do
        local expected_seq = full[#full - want + offset]
        assert(limited[offset] == expected_seq,
          "max_lines slot " .. offset .. " held seq " .. tostring(limited[offset])
            .. ", expected tail seq " .. tostring(expected_seq))
      end
    end)
  end)
end)
