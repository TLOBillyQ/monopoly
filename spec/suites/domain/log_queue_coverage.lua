local log_queue = require("src.core.utils.log_queue")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_state(opts)
  opts = opts or {}
  return {
    seq = 0,
    event_seq = 0,
    max_entries = opts.max_entries or 10,
    entries = opts.entries or {},
    entries_head = opts.entries_head,
    entries_count = opts.entries_count,
    timestamp_provider = opts.timestamp_provider or function() return 0 end,
    time_formatter = opts.time_formatter or function() return "" end,
    event_collection_enabled_provider = opts.event_collection_enabled_provider,
    event_buffer_stack = opts.event_buffer_stack,
    info_per_turn_limit = opts.info_per_turn_limit,
    info_turn_provider = opts.info_turn_provider,
    info_turn = opts.info_turn,
    info_turn_count = opts.info_turn_count or 0,
    ui_sink = opts.ui_sink,
  }
end

-- push: basic info entry stored

local function test_push_info_stores_entry()
  local state = _make_state()
  log_queue.push(state, "info", nil, "hello")
  _assert_eq(state.entries_count, 1, "should store one entry")
  _assert_eq(state.entries[1].text, "hello", "entry text should match")
  _assert_eq(state.entries[1].level, "info", "entry level should be info")
end

-- push: event increments event_seq

local function test_push_event_increments_event_seq()
  local state = _make_state()
  log_queue.push(state, "event", nil, "ev")
  _assert_eq(state.event_seq, 1, "event_seq should increment for event level")
end

-- push: info does not increment event_seq

local function test_push_info_does_not_increment_event_seq()
  local state = _make_state()
  log_queue.push(state, "info", nil, "msg")
  _assert_eq(state.event_seq, 0, "info push should not touch event_seq")
end

-- push: event collection disabled → skips store

local function test_push_event_skipped_when_collection_disabled()
  local state = _make_state({
    event_collection_enabled_provider = function() return false end,
  })
  log_queue.push(state, "event", nil, "ev")
  _assert_eq(state.entries_count or 0, 0, "event should be skipped when collection disabled")
end

-- push: event collection provider errors → treated as enabled

local function test_push_event_stored_when_provider_errors()
  local state = _make_state({
    event_collection_enabled_provider = function() error("boom") end,
  })
  log_queue.push(state, "event", nil, "ev")
  _assert_eq(state.entries_count, 1, "pcall failure in provider should default to enabled")
end

-- push: ui_sink called

local function test_push_calls_ui_sink()
  local received = nil
  local state = _make_state({ ui_sink = function(e) received = e end })
  log_queue.push(state, "info", nil, "sink_test")
  assert(received ~= nil, "ui_sink should be called")
  _assert_eq(received.text, "sink_test", "sink should receive correct entry")
end

-- push: info turn limit skips when exceeded

local function test_push_info_skipped_when_turn_limit_exceeded()
  local state = _make_state({
    info_per_turn_limit = 1,
    info_turn_provider = function() return 1 end,
    info_turn = 1,
    info_turn_count = 1,
  })
  log_queue.push(state, "info", nil, "over_limit")
  _assert_eq(state.entries_count or 0, 0, "info should be skipped when turn limit exceeded")
end

-- push: info turn limit resets on turn change

local function test_push_info_resets_count_on_turn_change()
  local state = _make_state({
    info_per_turn_limit = 1,
    info_turn_provider = function() return 2 end,
    info_turn = 1,
    info_turn_count = 99,
  })
  log_queue.push(state, "info", nil, "new_turn")
  _assert_eq(state.entries_count, 1, "should store entry after turn change resets count")
  _assert_eq(state.info_turn, 2, "info_turn should update")
  _assert_eq(state.info_turn_count, 1, "info_turn_count should be 1 after reset+increment")
end

-- push: unlimited flag bypasses turn limit

local function test_push_info_unlimited_bypasses_turn_limit()
  local state = _make_state({
    info_per_turn_limit = 1,
    info_turn_provider = function() return 1 end,
    info_turn = 1,
    info_turn_count = 99,
  })
  log_queue.push(state, "info", { unlimited = true }, "bypass")
  _assert_eq(state.entries_count, 1, "unlimited=true should bypass turn limit")
end

-- push: event buffered when active event buffer present

local function test_push_event_buffered_when_active_buffer()
  local buf = { entries = {} }
  local state = _make_state({ event_buffer_stack = { buf } })
  log_queue.push(state, "event", nil, "buffered_ev")
  _assert_eq(#buf.entries, 1, "event should be buffered in active buffer")
  _assert_eq(state.entries_count or 0, 0, "event should not be stored in main queue")
end

-- push: no_tip flag forwarded to buffered entry

local function test_push_event_no_tip_forwarded_to_buffer()
  local buf = { entries = {} }
  local state = _make_state({ event_buffer_stack = { buf } })
  log_queue.push(state, "event", { no_tip = true }, "no_tip_ev")
  _assert_eq(buf.entries[1].no_tip, true, "no_tip should be forwarded to buffer entry")
end

-- _store_entry: max_entries <= 0 does not store

local function test_push_does_not_store_when_max_entries_zero()
  local state = _make_state({ max_entries = 0 })
  log_queue.push(state, "info", nil, "msg")
  _assert_eq(#state.entries, 0, "max_entries=0 should skip store")
end

-- _store_entry: circular overwrite when full

local function test_push_overwrites_oldest_when_full()
  local state = _make_state({ max_entries = 2 })
  log_queue.push(state, "info", nil, "a")
  log_queue.push(state, "info", nil, "b")
  log_queue.push(state, "info", nil, "c")
  _assert_eq(state.entries_count, 2, "count should stay at max_entries")
  -- Entries rotate: both entries should exist
  local found_b, found_c = false, false
  for _, e in ipairs(state.entries) do
    if e.text == "b" then found_b = true end
    if e.text == "c" then found_c = true end
  end
  assert(found_b and found_c, "latest two entries should be b and c after overwrite")
end

-- push_event_buffer: basic push

local function test_push_event_buffer_adds_to_stack()
  local state = _make_state()
  local buf = {}
  log_queue.push_event_buffer(state, buf)
  assert(type(state.event_buffer_stack) == "table", "stack should be created")
  _assert_eq(#state.event_buffer_stack, 1, "buffer should be in stack")
end

-- push_event_buffer: dedup (same buffer not added twice)

local function test_push_event_buffer_dedup()
  local state = _make_state()
  local buf = {}
  log_queue.push_event_buffer(state, buf)
  log_queue.push_event_buffer(state, buf)
  _assert_eq(#state.event_buffer_stack, 1, "same buffer should not be added twice")
end

-- push_event_buffer: initializes entries when not a table

local function test_push_event_buffer_initializes_entries()
  local state = _make_state()
  local buf = {}
  log_queue.push_event_buffer(state, buf)
  assert(type(buf.entries) == "table", "entries should be initialized")
end

-- pop_event_buffer: nil buffer removes top

local function test_pop_event_buffer_nil_removes_top()
  local state = _make_state()
  local buf1 = {}
  local buf2 = {}
  log_queue.push_event_buffer(state, buf1)
  log_queue.push_event_buffer(state, buf2)
  local popped = log_queue.pop_event_buffer(state, nil)
  _assert_eq(popped, buf2, "nil buffer should pop top")
  _assert_eq(#state.event_buffer_stack, 1, "stack should have one remaining")
end

-- pop_event_buffer: named buffer removes matching entry

local function test_pop_event_buffer_named_removes_matching()
  local state = _make_state()
  local buf1 = {}
  local buf2 = {}
  log_queue.push_event_buffer(state, buf1)
  log_queue.push_event_buffer(state, buf2)
  local popped = log_queue.pop_event_buffer(state, buf1)
  _assert_eq(popped, buf1, "should remove named buffer")
  _assert_eq(#state.event_buffer_stack, 1, "one buffer should remain")
  _assert_eq(state.event_buffer_stack[1], buf2, "remaining buffer should be buf2")
end

-- pop_event_buffer: buffer not found returns nil

local function test_pop_event_buffer_not_found_returns_nil()
  local state = _make_state()
  local buf = {}
  local other = {}
  log_queue.push_event_buffer(state, buf)
  local result = log_queue.pop_event_buffer(state, other)
  _assert_eq(result, nil, "unknown buffer should return nil")
end

-- pop_event_buffer: empty stack returns nil

local function test_pop_event_buffer_empty_stack_returns_nil()
  local state = _make_state()
  local result = log_queue.pop_event_buffer(state, nil)
  _assert_eq(result, nil, "empty stack should return nil")
end

-- flush_event_buffer: empty buffer returns false

local function test_flush_event_buffer_empty_returns_false()
  local state = _make_state()
  local buf = { entries = {} }
  local result = log_queue.flush_event_buffer(state, buf)
  _assert_eq(result, false, "empty buffer should return false")
end

-- flush_event_buffer: non-table buffer returns false

local function test_flush_event_buffer_non_table_returns_false()
  local state = _make_state()
  local result = log_queue.flush_event_buffer(state, nil)
  _assert_eq(result, false, "nil buffer should return false")
end

-- flush_event_buffer: flushes entries to main queue

local function test_flush_event_buffer_flushes_entries()
  local state = _make_state()
  local buf = { entries = { { level = "event", text = "ev1" }, { level = "event", text = "ev2" } } }
  log_queue.push_event_buffer(state, buf)
  local result = log_queue.flush_event_buffer(state, buf)
  _assert_eq(result, true, "flush should return true for non-empty buffer")
  _assert_eq(state.entries_count, 2, "both entries should be stored after flush")
end

-- flush_event_buffer: no_tip entries flushed correctly

local function test_flush_event_buffer_no_tip_entries()
  local state = _make_state()
  local buf = { entries = { { level = "event", text = "no_tip_ev", no_tip = true } } }
  log_queue.push_event_buffer(state, buf)
  log_queue.flush_event_buffer(state, buf)
  _assert_eq(state.entries_count, 1, "no_tip entry should still be stored on flush")
end

-- flush_event_buffer: pops buffer from stack if active

local function test_flush_event_buffer_pops_from_stack_if_active()
  local state = _make_state()
  local buf = { entries = { { level = "event", text = "x" } } }
  log_queue.push_event_buffer(state, buf)
  log_queue.flush_event_buffer(state, buf)
  _assert_eq(#(state.event_buffer_stack or {}), 0, "buffer should be popped from stack on flush")
end

return {
  name = "domain log queue coverage",
  tests = {
    { name = "push info stores entry", run = test_push_info_stores_entry },
    { name = "push event increments event_seq", run = test_push_event_increments_event_seq },
    { name = "push info does not increment event_seq", run = test_push_info_does_not_increment_event_seq },
    { name = "push event skipped when collection disabled", run = test_push_event_skipped_when_collection_disabled },
    { name = "push event stored when provider errors", run = test_push_event_stored_when_provider_errors },
    { name = "push calls ui_sink", run = test_push_calls_ui_sink },
    { name = "push info skipped when turn limit exceeded", run = test_push_info_skipped_when_turn_limit_exceeded },
    { name = "push info resets count on turn change", run = test_push_info_resets_count_on_turn_change },
    { name = "push info unlimited bypasses turn limit", run = test_push_info_unlimited_bypasses_turn_limit },
    { name = "push event buffered when active buffer", run = test_push_event_buffered_when_active_buffer },
    { name = "push event no_tip forwarded to buffer", run = test_push_event_no_tip_forwarded_to_buffer },
    { name = "push does not store when max_entries zero", run = test_push_does_not_store_when_max_entries_zero },
    { name = "push overwrites oldest when full", run = test_push_overwrites_oldest_when_full },
    { name = "push_event_buffer adds to stack", run = test_push_event_buffer_adds_to_stack },
    { name = "push_event_buffer dedup", run = test_push_event_buffer_dedup },
    { name = "push_event_buffer initializes entries", run = test_push_event_buffer_initializes_entries },
    { name = "pop_event_buffer nil removes top", run = test_pop_event_buffer_nil_removes_top },
    { name = "pop_event_buffer named removes matching", run = test_pop_event_buffer_named_removes_matching },
    { name = "pop_event_buffer not found returns nil", run = test_pop_event_buffer_not_found_returns_nil },
    { name = "pop_event_buffer empty stack returns nil", run = test_pop_event_buffer_empty_stack_returns_nil },
    { name = "flush_event_buffer empty returns false", run = test_flush_event_buffer_empty_returns_false },
    { name = "flush_event_buffer non table returns false", run = test_flush_event_buffer_non_table_returns_false },
    { name = "flush_event_buffer flushes entries", run = test_flush_event_buffer_flushes_entries },
    { name = "flush_event_buffer no_tip entries", run = test_flush_event_buffer_no_tip_entries },
    { name = "flush_event_buffer pops from stack if active", run = test_flush_event_buffer_pops_from_stack_if_active },
  },
}
