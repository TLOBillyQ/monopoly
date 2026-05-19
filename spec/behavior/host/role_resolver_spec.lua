local role_resolver = require("src.host.role_resolver")

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
  end)
end)
