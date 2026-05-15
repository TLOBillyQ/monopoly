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
end)
