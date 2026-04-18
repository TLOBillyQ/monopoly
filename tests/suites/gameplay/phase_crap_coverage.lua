-- Tests for src/rules/items/phase.lua build_wait_choice_args
-- CRAP coverage for meta.resume_next_state requirement and resume_next_args handling

local phase = require("src.rules.items.phase")

local build_wait_choice_args = phase.build_wait_choice_args

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _assert_not_nil(a, msg)
  assert(a ~= nil, tostring(msg) .. ": expected non-nil got nil")
end

local function _assert_table(a, msg)
  assert(type(a) == "table", tostring(msg) .. ": expected table got " .. type(a))
end

-- Test 1: build_wait_choice_args returns table with next_state and next_args
local function _test_build_wait_choice_args_returns_table_with_keys()
  local meta = {
    resume_next_state = "some_state",
    resume_next_args = { arg1 = "value1" },
  }
  local result = build_wait_choice_args(meta)

  _assert_table(result, "result should be table")
  _assert_not_nil(result.next_state, "result.next_state should exist")
  _assert_not_nil(result.next_args, "result.next_args should exist")
end

-- Test 2: build_wait_choice_args uses meta.resume_next_state as next_state
local function _test_build_wait_choice_args_next_state_from_meta()
  local meta = {
    resume_next_state = "target_state_123",
    resume_next_args = nil,
  }
  local result = build_wait_choice_args(meta)

  _assert_eq(result.next_state, "target_state_123", "next_state should equal resume_next_state")
end

-- Test 3: build_wait_choice_args missing resume_next_state triggers assertion error
local function _test_build_wait_choice_args_missing_resume_next_state_asserts()
  local meta = {
    resume_next_args = { some = "args" },
  }

  local ok, err = pcall(function()
    build_wait_choice_args(meta)
  end)

  assert(not ok, "should have raised an error")
  assert(err and string.find(err, "resume_next_state"), "error should mention resume_next_state")
end

-- Test 4: build_wait_choice_args with nil meta still fails (no resume_next_state)
local function _test_build_wait_choice_args_nil_meta_asserts()
  local ok, err = pcall(function()
    build_wait_choice_args(nil)
  end)

  assert(not ok, "nil meta should raise error")
  assert(err and string.find(err, "resume_next_state"), "error should mention resume_next_state")
end

-- Test 5: build_wait_choice_args next_args is nil when resume_next_args is nil
local function _test_build_wait_choice_args_next_args_nil_when_absent()
  local meta = {
    resume_next_state = "some_state",
  }
  local result = build_wait_choice_args(meta)

  _assert_eq(result.next_args, nil, "next_args should be nil when resume_next_args is nil")
end

-- Test 6: build_wait_choice_args next_args is nil when resume_next_args is explicitly nil
local function _test_build_wait_choice_args_next_args_nil_when_explicit()
  local meta = {
    resume_next_state = "some_state",
    resume_next_args = nil,
  }
  local result = build_wait_choice_args(meta)

  _assert_eq(result.next_args, nil, "next_args should be nil when resume_next_args is explicitly nil")
end

-- Test 7: build_wait_choice_args next_args is passed through when resume_next_args is present
local function _test_build_wait_choice_args_next_args_from_resume()
  local args_table = { player_id = 2, amount = 5000 }
  local meta = {
    resume_next_state = "payment_state",
    resume_next_args = args_table,
  }
  local result = build_wait_choice_args(meta)

  _assert_eq(result.next_args, args_table, "next_args should be resume_next_args")
  _assert_eq(result.next_args.player_id, 2, "next_args.player_id should be preserved")
  _assert_eq(result.next_args.amount, 5000, "next_args.amount should be preserved")
end

-- Test 8: build_wait_choice_args with resume_next_args=false still works (falsy but not nil)
local function _test_build_wait_choice_args_resume_next_args_false()
  local meta = {
    resume_next_state = "some_state",
    resume_next_args = false,
  }
  local result = build_wait_choice_args(meta)

  _assert_eq(result.next_args, nil, "next_args should be nil when resume_next_args is false")
end

return {
  _test_build_wait_choice_args_returns_table_with_keys,
  _test_build_wait_choice_args_next_state_from_meta,
  _test_build_wait_choice_args_missing_resume_next_state_asserts,
  _test_build_wait_choice_args_nil_meta_asserts,
  _test_build_wait_choice_args_next_args_nil_when_absent,
  _test_build_wait_choice_args_next_args_nil_when_explicit,
  _test_build_wait_choice_args_next_args_from_resume,
  _test_build_wait_choice_args_resume_next_args_false,
}
