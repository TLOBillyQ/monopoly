---@diagnostic disable: need-check-nil, different-requires, undefined-field

local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local default_ports = require("src.host.default_ports")

describe("default_ports", function()
  it("wall_diff_seconds_prefers_game_api_then_falls_back", function()
    local ctx = {
      env = {
        GameAPI = {
          get_timestamp_diff = function(current, previous)
            return (current - previous) * 2
          end,
        },
      },
    }
    local runtime_ctx = {
      current = function()
        return ctx
      end,
    }
    local ports = default_ports.build(runtime_ctx)

    _assert_eq(ports.wall_diff_seconds(9, 7), 4, "wall diff should prefer GameAPI semantics when available")
    ctx.env.GameAPI.get_timestamp_diff = nil
    _assert_eq(ports.wall_diff_seconds(9, 7), 2, "wall diff should fall back to arithmetic when GameAPI diff is unavailable")
    _assert_eq(ports.wall_diff_seconds("x", 7), 0, "wall diff should return 0 for non-numeric fallback inputs")
  end)

  describe("custom archive access", function()
    local original_enums

    before_each(function()
      original_enums = _G.Enums
      _G.Enums = { ArchiveType = { Int = 4 } }
    end)

    after_each(function()
      _G.Enums = original_enums
    end)

    local function _ports_with_role(role, game_api)
      local ctx = { env = { GameAPI = game_api }, roles = role and { role } or {} }
      return default_ports.build({ current = function() return ctx end })
    end

    it("archives_enabled_reflects_game_api_then_defaults_false", function()
      local ports = _ports_with_role(nil, { is_archives_enabled = function() return true end })
      _assert_eq(ports.archives_enabled(), true, "archives_enabled should follow GameAPI when present")

      local ports_off = _ports_with_role(nil, {})
      _assert_eq(ports_off.archives_enabled(), false, "archives_enabled should default to false without GameAPI support")

      local ports_no_api = _ports_with_role(nil, nil)
      _assert_eq(ports_no_api.archives_enabled(), false, "archives_enabled should be false (not error) when GameAPI is absent")
    end)

    it("get_archive_int_defaults_to_zero_for_non_numeric_archive", function()
      local role = {
        get_roleid = function() return 9 end,
        get_archive_by_type = function() return "not-a-number" end,
      }
      local ports = _ports_with_role(role, {})

      _assert_eq(ports.get_archive_int(9, 1001), 0, "non-numeric archive value should default to 0")
    end)

    it("get_archive_int_reads_int_archive_from_resolved_role", function()
      local seen = {}
      local role = {
        get_roleid = function() return 9 end,
        get_archive_by_type = function(_, archive_type, key)
          seen[#seen + 1] = { archive_type = archive_type, key = key }
          return 42
        end,
      }
      local ports = _ports_with_role(role, {})

      _assert_eq(ports.get_archive_int(9, 1001), 42, "get_archive_int should return the role's stored value")
      _assert_eq(seen[1].archive_type, 4, "get_archive_int should request the Int archive type")
      _assert_eq(seen[1].key, 1001, "get_archive_int should pass the archive key through")
      _assert_eq(ports.get_archive_int(404, 1001), 0, "get_archive_int should default to 0 for an unresolved role")
    end)

    it("set_archive_int_writes_int_archive_on_resolved_role", function()
      local written = nil
      local role = {
        get_roleid = function() return 9 end,
        set_archive_by_type = function(_, archive_type, key, value)
          written = { archive_type = archive_type, key = key, value = value }
          return true
        end,
      }
      local ports = _ports_with_role(role, {})

      _assert_eq(ports.set_archive_int(9, 1002, 80000), true, "set_archive_int should report success")
      _assert_eq(written.archive_type, 4, "set_archive_int should target the Int archive type")
      _assert_eq(written.key, 1002, "set_archive_int should pass the archive key")
      _assert_eq(written.value, 80000, "set_archive_int should pass the new value")
      _assert_eq(ports.set_archive_int(404, 1002, 1), false, "set_archive_int should fail safely for an unresolved role")
    end)
  end)
end)
