local role_resolver = require("src.host.role_resolver")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local support = require("spec.support.shared_support")
local with_patches = support.with_patches

describe("role_resolver", function()
  describe("resolve_role_with", function()
    it("returns nil when no GameAPI and no port resolver", function()
      local result = role_resolver.resolve_role_with(nil, nil)
      assert(result == nil, "expected nil with no game engine")
    end)

    it("returns nil for valid player_id with no game engine", function()
      local result = role_resolver.resolve_role_with("player_1", nil)
      assert(result == nil, "expected nil without game engine resolution")
    end)

    it("returns nil when predicate rejects resolved nil role", function()
      local called = false
      local result = role_resolver.resolve_role_with(nil, function(r)
        called = true
        return r ~= nil
      end)
      assert(result == nil, "expected nil: nil role never passes predicate")
      assert(not called, "predicate should not be called when role is nil")
    end)
  end)

  describe("resolve_roles", function()
    it("returns empty table when no GameAPI and no port resolver", function()
      local result = role_resolver.resolve_roles()
      assert(type(result) == "table", "expected table")
    end)

    it("returns the runtime port roster verbatim when it is non-empty", function()
      local roster = { { id = 1 }, { id = 2 } }
      with_patches({
        { target = runtime_ports, key = "resolve_roles", value = function() return roster end },
      }, function()
        assert(role_resolver.resolve_roles() == roster, "a non-empty port roster should be returned as-is")
      end)
    end)

    it("falls back to GameAPI.get_all_valid_roles when the port roster is empty", function()
      local fallback = { { id = 9 } }
      with_patches({
        { target = runtime_ports, key = "resolve_roles", value = function() return {} end },
        { key = "GameAPI", value = { get_all_valid_roles = function() return fallback end } },
      }, function()
        assert(role_resolver.resolve_roles() == fallback,
          "an empty port roster should fall back to the host roles")
      end)
    end)

    it("returns the empty roster when the GameAPI fallback errors", function()
      with_patches({
        { target = runtime_ports, key = "resolve_roles", value = function() return {} end },
        { key = "GameAPI", value = { get_all_valid_roles = function() error("host roles boom") end } },
      }, function()
        local result = role_resolver.resolve_roles()
        assert(type(result) == "table" and #result == 0,
          "a throwing host fallback should yield the empty roster")
      end)
    end)
  end)
end)
