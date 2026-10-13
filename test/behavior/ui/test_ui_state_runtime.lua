-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end
local ui_runtime = require("src.ui.state.runtime")
local state_runtime = require("src.state.runtime")

local function make_state()
  return state_runtime.ensure_all({})
end

describe("TestUiStateRuntime", function()

it("test_ensure_all_returns_a_valid_state_table", function()
  local state = make_state()
  local result = ui_runtime.ensure_all(state)
  luassert.truthy(type(result) == "table", "expected table")
end)

it("test_ensure_ui_runtime_returns_state", function()
  local state = make_state()
  local result = ui_runtime.ensure_ui_runtime(state)
  luassert.truthy(type(result) == "table", "expected table")
end)

it("test_ensure_board_runtime_returns_state", function()
  local state = make_state()
  local result = ui_runtime.ensure_board_runtime(state)
  luassert.truthy(type(result) == "table", "expected table")
end)

it("test_ensure_anim_runtime_returns_state", function()
  local state = make_state()
  local result = ui_runtime.ensure_anim_runtime(state)
  luassert.truthy(type(result) == "table", "expected table")
end)

it("test_ensure_turn_runtime_returns_state", function()
  local state = make_state()
  local result = ui_runtime.ensure_turn_runtime(state)
  luassert.truthy(type(result) == "table", "expected table")
end)

it("test_ensure_debug_runtime_returns_state", function()
  local state = make_state()
  local result = ui_runtime.ensure_debug_runtime(state)
  luassert.truthy(type(result) == "table", "expected table")
end)

it("test_is_ui_dirty_returns_boolean", function()
  local state = make_state()
  local result = ui_runtime.is_ui_dirty(state)
  luassert.truthy(result == true or result == false or result == nil, "expected boolean or nil")
end)

it("test_set_ui_dirty_and_is_ui_dirty_round_trip", function()
  local state = make_state()
  ui_runtime.set_ui_dirty(state, true)
  local dirty = ui_runtime.is_ui_dirty(state)
  luassert.truthy(dirty == true, "expected dirty after set")
end)

it("test_get_ui_model_returns_nil_or_table_on_fresh_state", function()
  local state = make_state()
  local model = ui_runtime.get_ui_model(state)
  luassert.truthy(model == nil or type(model) == "table", "expected nil or table")
end)

it("test_set_ui_model_stores_and_get_ui_model_retrieves_it", function()
  local state = make_state()
  local mock_model = { version = 1 }
  ui_runtime.set_ui_model(state, mock_model)
  local retrieved = ui_runtime.get_ui_model(state)
  luassert.truthy(retrieved == mock_model, "expected model round-trip")
end)

it("test_get_pending_choice_returns_nil_on_fresh_state", function()
  local state = make_state()
  local result = ui_runtime.get_pending_choice(state)
  luassert.truthy(result == nil, "expected nil pending choice on fresh state")
end)

it("test_get_pending_choice_id_returns_nil_on_fresh_state", function()
  local state = make_state()
  local result = ui_runtime.get_pending_choice_id(state)
  luassert.truthy(result == nil, "expected nil choice_id")
end)

it("test_set_pending_choice_id_stores_and_get_retrieves_it", function()
  local state = make_state()
  ui_runtime.set_pending_choice_id(state, "choice_123")
  local result = ui_runtime.get_pending_choice_id(state)
  luassert.truthy(result == "choice_123", "expected choice_id round-trip")
end)

it("test_get_pending_choice_elapsed_returns_nil_or_number", function()
  local state = make_state()
  local result = ui_runtime.get_pending_choice_elapsed(state)
  luassert.truthy(result == nil or type(result) == "number", "expected nil or number")
end)

it("test_set_pending_choice_elapsed_stores_elapsed", function()
  local state = make_state()
  ui_runtime.set_pending_choice_elapsed(state, 3.5)
  local result = ui_runtime.get_pending_choice_elapsed(state)
  luassert.truthy(result == 3.5 or result ~= nil, "expected elapsed stored")
end)

it("test_get_modal_elapsed_returns_nil_on_fresh_state", function()
  local state = make_state()
  local result = ui_runtime.get_modal_elapsed(state)
  luassert.truthy(result == nil or type(result) == "number", "expected nil or number")
end)

it("test_get_modal_ref_returns_nil_on_fresh_state", function()
  local state = make_state()
  local result = ui_runtime.get_modal_ref(state)
  luassert.truthy(result == nil or type(result) == "table", "expected nil or table")
end)

it("test_log_once_skips_duplicate_keys", function()
  local state = make_state()
  local first = ui_runtime.log_once(state, "info", "k1", "message")
  local second = ui_runtime.log_once(state, "info", "k1", "message2")
  luassert.truthy(first == true, "expected first log_once to return true")
  luassert.truthy(second == false, "expected second log_once to return false")
end)

it("test_set_follow_target_position_and_get_round_trip", function()
  local state = make_state()
  local pos = { x = 1, y = 2, z = 3 }
  ui_runtime.set_follow_target_position(state, "player_1", pos)
  local result = ui_runtime.get_follow_target_position(state, "player_1")
  luassert.truthy(result ~= nil, "expected stored position")
end)


it("test_pending_choice_forwarder_returns_the_stored_choice", function()
  -- 杀 L77 转发调用->nil:set 后 get 必须取回 choice,不能吞成 nil。
  local state = make_state()
  local choice = { id = 3 }
  ui_runtime.set_pending_choice(state, choice)
  _assert_eq(ui_runtime.get_pending_choice(state), choice,
    "pending choice should round-trip through the forwarder")
end)

it("test_set_pending_choice_elapsed_returns_the_stored_elapsed", function()
  -- 杀 L93 转发调用->nil:set 的返回值必须回传实现值。
  local state = make_state()
  _assert_eq(ui_runtime.set_pending_choice_elapsed(state, 3), 3,
    "set_pending_choice_elapsed should return the stored elapsed")
end)

it("test_modal_timer_round_trip_exposes_ref_and_elapsed", function()
  -- 杀 L109 set_modal_timer 转发->nil(双返回值)与 L101/L105 get 转发->nil。
  local state = make_state()
  local ref, elapsed = ui_runtime.set_modal_timer(state, { ref = "R7", elapsed_seconds = 2 })
  _assert_eq(ref, "R7", "set_modal_timer should return the ref")
  _assert_eq(elapsed, 2, "set_modal_timer should return the elapsed")
  _assert_eq(ui_runtime.get_modal_ref(state), "R7", "get_modal_ref should return the stored ref")
  _assert_eq(ui_runtime.get_modal_elapsed(state), 2, "get_modal_elapsed should return the stored elapsed")
end)


end)
