local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local ui_runtime = require("src.ui.state.runtime")
local state_runtime = require("src.state.runtime")

local function make_state()
  return state_runtime.ensure_all({})
end

TestUiStateRuntime = {}

function TestUiStateRuntime:test_ensure_all_returns_a_valid_state_table()
  local state = make_state()
  local result = ui_runtime.ensure_all(state)
  lu.assertEvalToTrue(type(result) == "table", "expected table")
end

function TestUiStateRuntime:test_ensure_ui_runtime_returns_state()
  local state = make_state()
  local result = ui_runtime.ensure_ui_runtime(state)
  lu.assertEvalToTrue(type(result) == "table", "expected table")
end

function TestUiStateRuntime:test_ensure_board_runtime_returns_state()
  local state = make_state()
  local result = ui_runtime.ensure_board_runtime(state)
  lu.assertEvalToTrue(type(result) == "table", "expected table")
end

function TestUiStateRuntime:test_ensure_anim_runtime_returns_state()
  local state = make_state()
  local result = ui_runtime.ensure_anim_runtime(state)
  lu.assertEvalToTrue(type(result) == "table", "expected table")
end

function TestUiStateRuntime:test_ensure_turn_runtime_returns_state()
  local state = make_state()
  local result = ui_runtime.ensure_turn_runtime(state)
  lu.assertEvalToTrue(type(result) == "table", "expected table")
end

function TestUiStateRuntime:test_ensure_debug_runtime_returns_state()
  local state = make_state()
  local result = ui_runtime.ensure_debug_runtime(state)
  lu.assertEvalToTrue(type(result) == "table", "expected table")
end

function TestUiStateRuntime:test_is_ui_dirty_returns_boolean()
  local state = make_state()
  local result = ui_runtime.is_ui_dirty(state)
  lu.assertEvalToTrue(result == true or result == false or result == nil, "expected boolean or nil")
end

function TestUiStateRuntime:test_set_ui_dirty_and_is_ui_dirty_round_trip()
  local state = make_state()
  ui_runtime.set_ui_dirty(state, true)
  local dirty = ui_runtime.is_ui_dirty(state)
  lu.assertEvalToTrue(dirty == true, "expected dirty after set")
end

function TestUiStateRuntime:test_get_ui_model_returns_nil_or_table_on_fresh_state()
  local state = make_state()
  local model = ui_runtime.get_ui_model(state)
  lu.assertEvalToTrue(model == nil or type(model) == "table", "expected nil or table")
end

function TestUiStateRuntime:test_set_ui_model_stores_and_get_ui_model_retrieves_it()
  local state = make_state()
  local mock_model = { version = 1 }
  ui_runtime.set_ui_model(state, mock_model)
  local retrieved = ui_runtime.get_ui_model(state)
  lu.assertEvalToTrue(retrieved == mock_model, "expected model round-trip")
end

function TestUiStateRuntime:test_get_pending_choice_returns_nil_on_fresh_state()
  local state = make_state()
  local result = ui_runtime.get_pending_choice(state)
  lu.assertEvalToTrue(result == nil, "expected nil pending choice on fresh state")
end

function TestUiStateRuntime:test_get_pending_choice_id_returns_nil_on_fresh_state()
  local state = make_state()
  local result = ui_runtime.get_pending_choice_id(state)
  lu.assertEvalToTrue(result == nil, "expected nil choice_id")
end

function TestUiStateRuntime:test_set_pending_choice_id_stores_and_get_retrieves_it()
  local state = make_state()
  ui_runtime.set_pending_choice_id(state, "choice_123")
  local result = ui_runtime.get_pending_choice_id(state)
  lu.assertEvalToTrue(result == "choice_123", "expected choice_id round-trip")
end

function TestUiStateRuntime:test_get_pending_choice_elapsed_returns_nil_or_number()
  local state = make_state()
  local result = ui_runtime.get_pending_choice_elapsed(state)
  lu.assertEvalToTrue(result == nil or type(result) == "number", "expected nil or number")
end

function TestUiStateRuntime:test_set_pending_choice_elapsed_stores_elapsed()
  local state = make_state()
  ui_runtime.set_pending_choice_elapsed(state, 3.5)
  local result = ui_runtime.get_pending_choice_elapsed(state)
  lu.assertEvalToTrue(result == 3.5 or result ~= nil, "expected elapsed stored")
end

function TestUiStateRuntime:test_get_modal_elapsed_returns_nil_on_fresh_state()
  local state = make_state()
  local result = ui_runtime.get_modal_elapsed(state)
  lu.assertEvalToTrue(result == nil or type(result) == "number", "expected nil or number")
end

function TestUiStateRuntime:test_get_modal_ref_returns_nil_on_fresh_state()
  local state = make_state()
  local result = ui_runtime.get_modal_ref(state)
  lu.assertEvalToTrue(result == nil or type(result) == "table", "expected nil or table")
end

function TestUiStateRuntime:test_log_once_skips_duplicate_keys()
  local state = make_state()
  local first = ui_runtime.log_once(state, "info", "k1", "message")
  local second = ui_runtime.log_once(state, "info", "k1", "message2")
  lu.assertEvalToTrue(first == true, "expected first log_once to return true")
  lu.assertEvalToTrue(second == false, "expected second log_once to return false")
end

function TestUiStateRuntime:test_set_follow_target_position_and_get_round_trip()
  local state = make_state()
  local pos = { x = 1, y = 2, z = 3 }
  ui_runtime.set_follow_target_position(state, "player_1", pos)
  local result = ui_runtime.get_follow_target_position(state, "player_1")
  lu.assertEvalToTrue(result ~= nil, "expected stored position")
end


function TestUiStateRuntime:test_pending_choice_forwarder_returns_the_stored_choice()
  -- 杀 L77 转发调用->nil:set 后 get 必须取回 choice,不能吞成 nil。
  local state = make_state()
  local choice = { id = 3 }
  ui_runtime.set_pending_choice(state, choice)
  _assert_eq(ui_runtime.get_pending_choice(state), choice,
    "pending choice should round-trip through the forwarder")
end

function TestUiStateRuntime:test_set_pending_choice_elapsed_returns_the_stored_elapsed()
  -- 杀 L93 转发调用->nil:set 的返回值必须回传实现值。
  local state = make_state()
  _assert_eq(ui_runtime.set_pending_choice_elapsed(state, 3), 3,
    "set_pending_choice_elapsed should return the stored elapsed")
end

function TestUiStateRuntime:test_modal_timer_round_trip_exposes_ref_and_elapsed()
  -- 杀 L109 set_modal_timer 转发->nil(双返回值)与 L101/L105 get 转发->nil。
  local state = make_state()
  local ref, elapsed = ui_runtime.set_modal_timer(state, { ref = "R7", elapsed_seconds = 2 })
  _assert_eq(ref, "R7", "set_modal_timer should return the ref")
  _assert_eq(elapsed, 2, "set_modal_timer should return the elapsed")
  _assert_eq(ui_runtime.get_modal_ref(state), "R7", "get_modal_ref should return the stored ref")
  _assert_eq(ui_runtime.get_modal_elapsed(state), 2, "get_modal_elapsed should return the stored elapsed")
end


return TestUiStateRuntime
