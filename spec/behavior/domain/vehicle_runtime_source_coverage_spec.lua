local vehicle_runtime_source = require("src.state.vehicle_runtime_source")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_helper(get_roles, get_game_api)
  return vehicle_runtime_source.build_helper(get_roles, get_game_api, nil, {})
end

-- _resolve_module (via _M_test)





-- source.resolve




-- source.build_helper basic structure






-- resolve_role







-- resolve_any_role







-- emit functions

describe("domain vehicle runtime source coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("resolve_module nil globals returns nil", function()
    _assert_eq(vehicle_runtime_source._M_test._resolve_module(nil), nil, "nil globals → nil")
  end)

  it("resolve_module no key returns nil", function()
    _assert_eq(vehicle_runtime_source._M_test._resolve_module({}), nil, "no key → nil")
  end)

  it("resolve_module empty string returns nil", function()
    _assert_eq(vehicle_runtime_source._M_test._resolve_module({ VEHICLE_RUNTIME_MODULE = "" }), nil, "empty string → nil")
  end)

  it("resolve_module valid string returns string", function()
    _assert_eq(vehicle_runtime_source._M_test._resolve_module({ VEHICLE_RUNTIME_MODULE = "some.module" }), "some.module", "valid string → returned")
  end)

  it("resolve empty globals returns runtime table", function()
    local runtime = vehicle_runtime_source.resolve({})
    assert(type(runtime) == "table", "should return table")
    assert(type(runtime.build_helper) == "function", "should have build_helper")
  end)

  it("resolve mode none returns runtime table", function()
    local runtime = vehicle_runtime_source.resolve({ VEHICLE_RUNTIME_MODE = "none" })
    assert(type(runtime) == "table", "none mode → table")
    assert(type(runtime.build_helper) == "function", "none mode → build_helper")
  end)

  it("resolve custom mode no module falls back", function()
    local runtime = vehicle_runtime_source.resolve({ VEHICLE_RUNTIME_MODE = "custom" })
    assert(type(runtime) == "table", "custom mode with no module → fallback table")
    assert(type(runtime.build_helper) == "function", "fallback → build_helper")
  end)

  it("build_helper returns table", function()
    local helper = _make_helper(nil, nil)
    assert(type(helper) == "table", "should return helper table")
  end)

  it("build_helper player_id nil", function()
    local helper = _make_helper(nil, nil)
    _assert_eq(helper.player_id, nil, "player_id should be nil")
  end)

  it("build_helper vehicle_id nil", function()
    local helper = _make_helper(nil, nil)
    _assert_eq(helper.vehicle_id, nil, "vehicle_id should be nil")
  end)

  it("build_helper active_vehicle_by_player empty", function()
    local helper = _make_helper(nil, nil)
    assert(type(helper.active_vehicle_by_player) == "table", "should be table")
    _assert_eq(next(helper.active_vehicle_by_player), nil, "should be empty")
  end)

  it("build_helper needs_enter_wait_by_player empty", function()
    local helper = _make_helper(nil, nil)
    assert(type(helper.needs_enter_wait_by_player) == "table", "should be table")
    _assert_eq(next(helper.needs_enter_wait_by_player), nil, "should be empty")
  end)

  it("resolve_role nil returns nil", function()
    local helper = _make_helper(nil, nil)
    _assert_eq(helper.resolve_role(nil), nil, "nil role_id → nil")
  end)

  it("resolve_role no get_game_api returns nil", function()
    local helper = _make_helper(nil, nil)
    _assert_eq(helper.resolve_role(1), nil, "no get_game_api → nil")
  end)

  it("resolve_role game_api is nil returns nil", function()
    local helper = _make_helper(nil, function() return nil end)
    _assert_eq(helper.resolve_role(1), nil, "nil game_api → nil")
  end)

  it("resolve_role game_api no get_role returns nil", function()
    local helper = _make_helper(nil, function() return {} end)
    _assert_eq(helper.resolve_role(1), nil, "game_api without get_role → nil")
  end)

  it("resolve_role game_api returns role", function()
    local expected = { id = 1001 }
    local helper = _make_helper(nil, function()
      return { get_role = function(_) return expected end }
    end)
    _assert_eq(helper.resolve_role(1), expected, "should return role from get_role")
  end)

  it("resolve_role game_api throws returns nil", function()
    local helper = _make_helper(nil, function()
      return { get_role = function(_) error("boom") end }
    end)
    _assert_eq(helper.resolve_role(1), nil, "throwing get_role → nil via pcall")
  end)

  it("resolve_any_role no get_roles no game_api returns nil", function()
    local helper = _make_helper(nil, nil)
    _assert_eq(helper.resolve_any_role(), nil, "no get_roles, no game_api → nil")
  end)

  it("resolve_any_role get_roles returns first role", function()
    local role = { id = 1001 }
    local helper = _make_helper(function() return { role } end, nil)
    _assert_eq(helper.resolve_any_role(), role, "get_roles with role → first role")
  end)

  it("resolve_any_role get_roles not table falls through", function()
    local role = { id = 2001 }
    local helper = _make_helper(
      function() return "not_a_table" end,
      function()
        return { get_all_valid_roles = function() return { role } end }
      end
    )
    _assert_eq(helper.resolve_any_role(), role, "non-table get_roles → game_api fallback")
  end)

  it("resolve_any_role get_roles empty falls through to game_api", function()
    local role = { id = 2002 }
    local helper = _make_helper(
      function() return {} end,
      function()
        return { get_all_valid_roles = function() return { role } end }
      end
    )
    _assert_eq(helper.resolve_any_role(), role, "empty get_roles → game_api fallback")
  end)

  it("resolve_any_role game_api all_valid_roles returns first", function()
    local role = { id = 3001 }
    local helper = _make_helper(nil, function()
      return { get_all_valid_roles = function() return { role } end }
    end)
    _assert_eq(helper.resolve_any_role(), role, "get_all_valid_roles → first role")
  end)

  it("resolve_any_role all_valid_roles throws continues", function()
    local helper = _make_helper(nil, function()
      return { get_all_valid_roles = function() error("boom") end }
    end)
    _assert_eq(helper.resolve_any_role(), nil, "throwing get_all_valid_roles → nil")
  end)

  it("emit_vehicle_enter returns false", function()
    _assert_eq(_make_helper(nil, nil).emit_vehicle_enter(), false, "emit_vehicle_enter → false")
  end)

  it("emit_vehicle_exit returns false", function()
    _assert_eq(_make_helper(nil, nil).emit_vehicle_exit(), false, "emit_vehicle_exit → false")
  end)

  it("emit_vehicle_move returns false", function()
    _assert_eq(_make_helper(nil, nil).emit_vehicle_move(), false, "emit_vehicle_move → false")
  end)

  it("emit_vehicle_stop returns false", function()
    _assert_eq(_make_helper(nil, nil).emit_vehicle_stop(), false, "emit_vehicle_stop → false")
  end)

  it("emit_vehicle_set_position returns false", function()
    _assert_eq(_make_helper(nil, nil).emit_vehicle_set_position(), false, "emit_vehicle_set_position → false")
  end)

  it("consume_enter_delay returns zero", function()
    _assert_eq(_make_helper(nil, nil).consume_enter_delay(), 0, "consume_enter_delay → 0")
  end)
end)
