require("test.bootstrap").install_package_paths()
local luassert = assert
local role_resolver = require("src.host.role_resolver")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local support = require("test.support.shared_support")
local with_patches = support.with_patches

describe("TestRoleResolver", function()

local function _test_returns_nil_when_no_gameapi_and_no_port_resolver()
  local result = role_resolver.resolve_role_with(nil, nil)
  luassert.truthy(result == nil, "expected nil with no game engine")
end

local function _test_returns_nil_for_valid_player_id_with_no_game_engine()
  local result = role_resolver.resolve_role_with("player_1", nil)
  luassert.truthy(result == nil, "expected nil without game engine resolution")
end

local function _test_returns_nil_when_predicate_rejects_resolved_nil_role()
  local called = false
  local result = role_resolver.resolve_role_with(nil, function(r)
    called = true
    return r ~= nil
  end)
  luassert.truthy(result == nil, "expected nil: nil role never passes predicate")
  luassert.truthy(not called, "predicate should not be called when role is nil")
end

local function _test_returns_the_port_role_and_skips_the_host_when_no_predicate_is_given()
  local role = { id = "port_role" }
  local host_consulted = false
  with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return role end },
    { key = "GameAPI", value = { get_role = function()
      host_consulted = true
      return { id = "host_role" }
    end } },
  }, function()
    local result = role_resolver.resolve_role_with("p1", nil)
    luassert.truthy(result == role, "a nil predicate should accept the resolved port role")
    luassert.truthy(not host_consulted, "host should not be consulted once the port role is accepted")
  end)
end

local function _test_falls_back_to_the_host_role_when_the_predicate_rejects_the_port_role()
  local port_role = { kind = "port" }
  local host_role = { kind = "host" }
  local seen_player_id = nil
  with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return port_role end },
    { key = "GameAPI", value = { get_role = function(player_id)
      seen_player_id = player_id
      return host_role
    end } },
  }, function()
    local result = role_resolver.resolve_role_with("p7", function(r) return r.kind == "host" end)
    luassert.truthy(result == host_role, "predicate accepting only the host role should return the host role")
    luassert.truthy(seen_player_id == "p7", "host get_role should receive the requested player_id")
  end)
end

local function _test_returns_nil_when_the_host_get_role_throws()
  with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return nil end },
    { key = "GameAPI", value = { get_role = function() error("host role boom") end } },
  }, function()
    local result = role_resolver.resolve_role_with("p1", nil)
    luassert.truthy(result == nil, "a throwing host get_role should resolve to nil")
  end)
end

local function _test_treats_a_truthy_but_not_true_predicate_result_as_a_rejection()
  local port_role = { id = "only_role" }
  with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return port_role end },
    { key = "GameAPI", value = { get_role = function() return nil end } },
  }, function()
    local result = role_resolver.resolve_role_with("p1", function() return "truthy" end)
    luassert.truthy(result == nil,
      "a predicate returning a non-true truthy value should reject the role, not accept it")
  end)
end

local function _test_accepts_the_role_only_when_the_predicate_returns_exactly_true()
  local port_role = { id = "role" }
  with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return port_role end },
  }, function()
    local result = role_resolver.resolve_role_with("p1", function() return true end)
    luassert.truthy(result == port_role, "predicate returning true should accept the port role")
  end)
end

local function _test_resolves_the_host_role_when_the_port_yields_nil_and_no_predicate_is_given()
  local host_role = { id = "host_only" }
  with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return nil end },
    { key = "GameAPI", value = { get_role = function() return host_role end } },
  }, function()
    local result = role_resolver.resolve_role_with("p1", nil)
    luassert.truthy(result == host_role,
      "a nil port role should not itself count as a match; it should fall through to the host role")
  end)
end

local function _test_treats_a_falsy_gameapi_as_absent_instead_of_indexing_it()
  with_patches({
    { target = runtime_ports, key = "resolve_role", value = function() return nil end },
    { key = "GameAPI", value = false },
  }, function()
    local result = role_resolver.resolve_role_with("p1", nil)
    luassert.truthy(result == nil, "a falsy GameAPI should be guarded, not indexed, yielding nil")
  end, { skip_runtime_context_refresh = true })
end

local function _test_returns_empty_table_when_no_gameapi_and_no_port_resolver()
  local result = role_resolver.resolve_roles()
  luassert.truthy(type(result) == "table", "expected table")
end

local function _test_returns_the_runtime_port_roster_verbatim_when_it_is_non_empty()
  local roster = { { id = 1 }, { id = 2 } }
  with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function() return roster end },
  }, function()
    luassert.truthy(role_resolver.resolve_roles() == roster, "a non-empty port roster should be returned as-is")
  end)
end

local function _test_returns_a_single_element_port_roster_directly_rather_than_the_host_fallback()
  local port_roster = { { id = "solo" } }
  local host_roster = { { id = "other" } }
  with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function() return port_roster end },
    { key = "GameAPI", value = { get_all_valid_roles = function() return host_roster end } },
  }, function()
    luassert.truthy(role_resolver.resolve_roles() == port_roster,
      "any non-empty port roster (even one element) should short-circuit before the host fallback")
  end)
end

local function _test_falls_back_to_gameapi_get_all_valid_roles_when_the_port_roster_is_empty()
  local fallback = { { id = 9 } }
  with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function() return {} end },
    { key = "GameAPI", value = { get_all_valid_roles = function() return fallback end } },
  }, function()
    luassert.truthy(role_resolver.resolve_roles() == fallback,
      "an empty port roster should fall back to the host roles")
  end)
end

local function _test_falls_back_to_the_host_roster_when_the_port_returns_a_non_table()
  local fallback = { { id = 5 } }
  with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function() return false end },
    { key = "GameAPI", value = { get_all_valid_roles = function() return fallback end } },
  }, function()
    luassert.truthy(role_resolver.resolve_roles() == fallback,
      "a non-table port result should fall back to the host roles")
  end)
end

local function _test_ignores_a_non_table_host_fallback_and_returns_the_empty_roster()
  with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function() return {} end },
    { key = "GameAPI", value = { get_all_valid_roles = function() return "not a table" end } },
  }, function()
    local result = role_resolver.resolve_roles()
    luassert.truthy(type(result) == "table" and #result == 0,
      "a non-table host fallback should be ignored, yielding the empty roster")
  end)
end

local function _test_returns_the_empty_roster_when_the_gameapi_fallback_errors()
  with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function() return {} end },
    { key = "GameAPI", value = { get_all_valid_roles = function() error("host roles boom") end } },
  }, function()
    local result = role_resolver.resolve_roles()
    luassert.truthy(type(result) == "table" and #result == 0,
      "a throwing host fallback should yield the empty roster")
  end)
end

local function _test_returns_a_fresh_empty_table_when_the_port_yields_nil_and_no_host_is_available()
  with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function() return nil end },
  }, function()
    local result = role_resolver.resolve_roles()
    luassert.truthy(type(result) == "table" and #result == 0,
      "a nil port roster with no host should coalesce to an empty table")
  end)
end

local function _test_treats_a_falsy_gameapi_as_absent_when_falling_back()
  with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function() return {} end },
    { key = "GameAPI", value = false },
  }, function()
    local result = role_resolver.resolve_roles()
    luassert.truthy(type(result) == "table" and #result == 0,
      "a falsy GameAPI should be guarded, not indexed, when the port roster is empty")
  end, { skip_runtime_context_refresh = true })
end


it("test_returns_nil_when_no_gameapi_and_no_port_resolver", _test_returns_nil_when_no_gameapi_and_no_port_resolver)
it("test_returns_nil_for_valid_player_id_with_no_game_engine", _test_returns_nil_for_valid_player_id_with_no_game_engine)
it("test_returns_nil_when_predicate_rejects_resolved_nil_role", _test_returns_nil_when_predicate_rejects_resolved_nil_role)
it("test_returns_the_port_role_and_skips_the_host_when_no_predicate_is_given", _test_returns_the_port_role_and_skips_the_host_when_no_predicate_is_given)
it("test_falls_back_to_the_host_role_when_the_predicate_rejects_the_port_role", _test_falls_back_to_the_host_role_when_the_predicate_rejects_the_port_role)
it("test_returns_nil_when_the_host_get_role_throws", _test_returns_nil_when_the_host_get_role_throws)
it("test_treats_a_truthy_but_not_true_predicate_result_as_a_rejection", _test_treats_a_truthy_but_not_true_predicate_result_as_a_rejection)
it("test_accepts_the_role_only_when_the_predicate_returns_exactly_true", _test_accepts_the_role_only_when_the_predicate_returns_exactly_true)
it("test_resolves_the_host_role_when_the_port_yields_nil_and_no_predicate_is_given", _test_resolves_the_host_role_when_the_port_yields_nil_and_no_predicate_is_given)
it("test_treats_a_falsy_gameapi_as_absent_instead_of_indexing_it", _test_treats_a_falsy_gameapi_as_absent_instead_of_indexing_it)
it("test_returns_empty_table_when_no_gameapi_and_no_port_resolver", _test_returns_empty_table_when_no_gameapi_and_no_port_resolver)
it("test_returns_the_runtime_port_roster_verbatim_when_it_is_non_empty", _test_returns_the_runtime_port_roster_verbatim_when_it_is_non_empty)
it("test_returns_a_single_element_port_roster_directly_rather_than_the_host_fallback", _test_returns_a_single_element_port_roster_directly_rather_than_the_host_fallback)
it("test_falls_back_to_gameapi_get_all_valid_roles_when_the_port_roster_is_empty", _test_falls_back_to_gameapi_get_all_valid_roles_when_the_port_roster_is_empty)
it("test_falls_back_to_the_host_roster_when_the_port_returns_a_non_table", _test_falls_back_to_the_host_roster_when_the_port_returns_a_non_table)
it("test_ignores_a_non_table_host_fallback_and_returns_the_empty_roster", _test_ignores_a_non_table_host_fallback_and_returns_the_empty_roster)
it("test_returns_the_empty_roster_when_the_gameapi_fallback_errors", _test_returns_the_empty_roster_when_the_gameapi_fallback_errors)
it("test_returns_a_fresh_empty_table_when_the_port_yields_nil_and_no_host_is_available", _test_returns_a_fresh_empty_table_when_the_port_yields_nil_and_no_host_is_available)
it("test_treats_a_falsy_gameapi_as_absent_when_falling_back", _test_treats_a_falsy_gameapi_as_absent_when_falling_back)
end)
