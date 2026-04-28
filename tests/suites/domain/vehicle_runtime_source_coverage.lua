local vehicle_runtime_source = require("src.state.vehicle_runtime_source")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_helper(get_roles, get_game_api)
  return vehicle_runtime_source.build_helper(get_roles, get_game_api, nil, {})
end

-- _resolve_module (via _M_test)

local function test_resolve_module_nil_globals_returns_nil()
  _assert_eq(vehicle_runtime_source._M_test._resolve_module(nil), nil, "nil globals → nil")
end

local function test_resolve_module_no_key_returns_nil()
  _assert_eq(vehicle_runtime_source._M_test._resolve_module({}), nil, "no key → nil")
end

local function test_resolve_module_empty_string_returns_nil()
  _assert_eq(vehicle_runtime_source._M_test._resolve_module({ VEHICLE_RUNTIME_MODULE = "" }), nil, "empty string → nil")
end

local function test_resolve_module_valid_string_returns_string()
  _assert_eq(vehicle_runtime_source._M_test._resolve_module({ VEHICLE_RUNTIME_MODULE = "some.module" }), "some.module", "valid string → returned")
end

-- source.resolve

local function test_resolve_empty_globals_returns_runtime_table()
  local runtime = vehicle_runtime_source.resolve({})
  assert(type(runtime) == "table", "should return table")
  assert(type(runtime.build_helper) == "function", "should have build_helper")
end

local function test_resolve_mode_none_returns_runtime_table()
  local runtime = vehicle_runtime_source.resolve({ VEHICLE_RUNTIME_MODE = "none" })
  assert(type(runtime) == "table", "none mode → table")
  assert(type(runtime.build_helper) == "function", "none mode → build_helper")
end

local function test_resolve_custom_mode_no_module_falls_back()
  local runtime = vehicle_runtime_source.resolve({ VEHICLE_RUNTIME_MODE = "custom" })
  assert(type(runtime) == "table", "custom mode with no module → fallback table")
  assert(type(runtime.build_helper) == "function", "fallback → build_helper")
end

-- source.build_helper basic structure

local function test_build_helper_returns_table()
  local helper = _make_helper(nil, nil)
  assert(type(helper) == "table", "should return helper table")
end

local function test_build_helper_player_id_nil()
  local helper = _make_helper(nil, nil)
  _assert_eq(helper.player_id, nil, "player_id should be nil")
end

local function test_build_helper_vehicle_id_nil()
  local helper = _make_helper(nil, nil)
  _assert_eq(helper.vehicle_id, nil, "vehicle_id should be nil")
end

local function test_build_helper_active_vehicle_by_player_empty()
  local helper = _make_helper(nil, nil)
  assert(type(helper.active_vehicle_by_player) == "table", "should be table")
  _assert_eq(next(helper.active_vehicle_by_player), nil, "should be empty")
end

local function test_build_helper_needs_enter_wait_by_player_empty()
  local helper = _make_helper(nil, nil)
  assert(type(helper.needs_enter_wait_by_player) == "table", "should be table")
  _assert_eq(next(helper.needs_enter_wait_by_player), nil, "should be empty")
end

-- resolve_role

local function test_resolve_role_nil_returns_nil()
  local helper = _make_helper(nil, nil)
  _assert_eq(helper.resolve_role(nil), nil, "nil role_id → nil")
end

local function test_resolve_role_no_get_game_api_returns_nil()
  local helper = _make_helper(nil, nil)
  _assert_eq(helper.resolve_role(1), nil, "no get_game_api → nil")
end

local function test_resolve_role_game_api_is_nil_returns_nil()
  local helper = _make_helper(nil, function() return nil end)
  _assert_eq(helper.resolve_role(1), nil, "nil game_api → nil")
end

local function test_resolve_role_game_api_no_get_role_returns_nil()
  local helper = _make_helper(nil, function() return {} end)
  _assert_eq(helper.resolve_role(1), nil, "game_api without get_role → nil")
end

local function test_resolve_role_game_api_returns_role()
  local expected = { id = 1001 }
  local helper = _make_helper(nil, function()
    return { get_role = function(_) return expected end }
  end)
  _assert_eq(helper.resolve_role(1), expected, "should return role from get_role")
end

local function test_resolve_role_game_api_throws_returns_nil()
  local helper = _make_helper(nil, function()
    return { get_role = function(_) error("boom") end }
  end)
  _assert_eq(helper.resolve_role(1), nil, "throwing get_role → nil via pcall")
end

-- resolve_any_role

local function test_resolve_any_role_no_get_roles_no_game_api_returns_nil()
  local helper = _make_helper(nil, nil)
  _assert_eq(helper.resolve_any_role(), nil, "no get_roles, no game_api → nil")
end

local function test_resolve_any_role_get_roles_returns_first_role()
  local role = { id = 1001 }
  local helper = _make_helper(function() return { role } end, nil)
  _assert_eq(helper.resolve_any_role(), role, "get_roles with role → first role")
end

local function test_resolve_any_role_get_roles_not_table_falls_through()
  local role = { id = 2001 }
  local helper = _make_helper(
    function() return "not_a_table" end,
    function()
      return { get_all_valid_roles = function() return { role } end }
    end
  )
  _assert_eq(helper.resolve_any_role(), role, "non-table get_roles → game_api fallback")
end

local function test_resolve_any_role_get_roles_empty_falls_through_to_game_api()
  local role = { id = 2002 }
  local helper = _make_helper(
    function() return {} end,
    function()
      return { get_all_valid_roles = function() return { role } end }
    end
  )
  _assert_eq(helper.resolve_any_role(), role, "empty get_roles → game_api fallback")
end

local function test_resolve_any_role_game_api_all_valid_roles_returns_first()
  local role = { id = 3001 }
  local helper = _make_helper(nil, function()
    return { get_all_valid_roles = function() return { role } end }
  end)
  _assert_eq(helper.resolve_any_role(), role, "get_all_valid_roles → first role")
end

local function test_resolve_any_role_all_valid_roles_throws_continues()
  local helper = _make_helper(nil, function()
    return { get_all_valid_roles = function() error("boom") end }
  end)
  _assert_eq(helper.resolve_any_role(), nil, "throwing get_all_valid_roles → nil")
end

-- emit functions

local function test_emit_vehicle_enter_returns_false()
  _assert_eq(_make_helper(nil, nil).emit_vehicle_enter(), false, "emit_vehicle_enter → false")
end

local function test_emit_vehicle_exit_returns_false()
  _assert_eq(_make_helper(nil, nil).emit_vehicle_exit(), false, "emit_vehicle_exit → false")
end

local function test_emit_vehicle_move_returns_false()
  _assert_eq(_make_helper(nil, nil).emit_vehicle_move(), false, "emit_vehicle_move → false")
end

local function test_emit_vehicle_stop_returns_false()
  _assert_eq(_make_helper(nil, nil).emit_vehicle_stop(), false, "emit_vehicle_stop → false")
end

local function test_emit_vehicle_set_position_returns_false()
  _assert_eq(_make_helper(nil, nil).emit_vehicle_set_position(), false, "emit_vehicle_set_position → false")
end

local function test_consume_enter_delay_returns_zero()
  _assert_eq(_make_helper(nil, nil).consume_enter_delay(), 0, "consume_enter_delay → 0")
end

return {
  name = "domain vehicle runtime source coverage",
  tests = {
    { name = "resolve_module nil globals returns nil", run = test_resolve_module_nil_globals_returns_nil },
    { name = "resolve_module no key returns nil", run = test_resolve_module_no_key_returns_nil },
    { name = "resolve_module empty string returns nil", run = test_resolve_module_empty_string_returns_nil },
    { name = "resolve_module valid string returns string", run = test_resolve_module_valid_string_returns_string },
    { name = "resolve empty globals returns runtime table", run = test_resolve_empty_globals_returns_runtime_table },
    { name = "resolve mode none returns runtime table", run = test_resolve_mode_none_returns_runtime_table },
    { name = "resolve custom mode no module falls back", run = test_resolve_custom_mode_no_module_falls_back },
    { name = "build_helper returns table", run = test_build_helper_returns_table },
    { name = "build_helper player_id nil", run = test_build_helper_player_id_nil },
    { name = "build_helper vehicle_id nil", run = test_build_helper_vehicle_id_nil },
    { name = "build_helper active_vehicle_by_player empty", run = test_build_helper_active_vehicle_by_player_empty },
    { name = "build_helper needs_enter_wait_by_player empty", run = test_build_helper_needs_enter_wait_by_player_empty },
    { name = "resolve_role nil returns nil", run = test_resolve_role_nil_returns_nil },
    { name = "resolve_role no get_game_api returns nil", run = test_resolve_role_no_get_game_api_returns_nil },
    { name = "resolve_role game_api is nil returns nil", run = test_resolve_role_game_api_is_nil_returns_nil },
    { name = "resolve_role game_api no get_role returns nil", run = test_resolve_role_game_api_no_get_role_returns_nil },
    { name = "resolve_role game_api returns role", run = test_resolve_role_game_api_returns_role },
    { name = "resolve_role game_api throws returns nil", run = test_resolve_role_game_api_throws_returns_nil },
    { name = "resolve_any_role no get_roles no game_api returns nil", run = test_resolve_any_role_no_get_roles_no_game_api_returns_nil },
    { name = "resolve_any_role get_roles returns first role", run = test_resolve_any_role_get_roles_returns_first_role },
    { name = "resolve_any_role get_roles not table falls through", run = test_resolve_any_role_get_roles_not_table_falls_through },
    { name = "resolve_any_role get_roles empty falls through to game_api", run = test_resolve_any_role_get_roles_empty_falls_through_to_game_api },
    { name = "resolve_any_role game_api all_valid_roles returns first", run = test_resolve_any_role_game_api_all_valid_roles_returns_first },
    { name = "resolve_any_role all_valid_roles throws continues", run = test_resolve_any_role_all_valid_roles_throws_continues },
    { name = "emit_vehicle_enter returns false", run = test_emit_vehicle_enter_returns_false },
    { name = "emit_vehicle_exit returns false", run = test_emit_vehicle_exit_returns_false },
    { name = "emit_vehicle_move returns false", run = test_emit_vehicle_move_returns_false },
    { name = "emit_vehicle_stop returns false", run = test_emit_vehicle_stop_returns_false },
    { name = "emit_vehicle_set_position returns false", run = test_emit_vehicle_set_position_returns_false },
    { name = "consume_enter_delay returns zero", run = test_consume_enter_delay_returns_zero },
  },
}
