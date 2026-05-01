local runtime_context = require("src.host.context")

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. " got " .. tostring(actual))
end

local function _build_noop_helper(opts)
  opts = opts or {}
  local ctx = runtime_context.new({
    GameAPI = opts.game_api,
  })
  ctx.roles = opts.roles
  ctx.camera_helper = {}
  ctx.synthetic_actor_registry = {}

  local previous_mode = _G.MONOPOLY_BUILD_MODE
  _G.MONOPOLY_BUILD_MODE = "release"
  local ok, result = pcall(runtime_context.install_runtime_helpers, ctx)
  _G.MONOPOLY_BUILD_MODE = previous_mode
  if not ok then
    error(result, 0)
  end
  return result.vehicle_helper
end

describe("host context crap coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("safe_get_role returns nil for nil role id", function()
    local helper = _build_noop_helper({
      game_api = {
        get_role = function()
          error("should not be called")
        end,
      },
    })

    _assert_eq(helper.resolve_role(nil), nil, "nil role_id should resolve nil")
  end)

  it("safe_get_role returns nil when get_role missing", function()
    local helper = _build_noop_helper({
      game_api = {},
    })

    _assert_eq(helper.resolve_role("role_1"), nil, "missing get_role should resolve nil")
  end)

  it("safe_get_role returns nil when game api throws", function()
    local helper = _build_noop_helper({
      game_api = {
        get_role = function()
          error("boom")
        end,
      },
    })

    _assert_eq(helper.resolve_role("role_1"), nil, "get_role error should resolve nil")
  end)

  it("safe_get_role returns role when game api succeeds", function()
    local role = { id = "role_1" }
    local helper = _build_noop_helper({
      game_api = {
        get_role = function(role_id)
          _assert_eq(role_id, "role_1", "get_role should receive requested role id")
          return role
        end,
      },
    })

    _assert_eq(helper.resolve_role("role_1"), role, "successful get_role should return role")
  end)

  it("resolve_any_role prefers provider role", function()
    local provider_role = { id = "provider_role" }
    local game_api_role = { id = "game_api_role" }
    local helper = _build_noop_helper({
      roles = { provider_role },
      game_api = {
        get_all_valid_roles = function()
          return { game_api_role }
        end,
      },
    })

    _assert_eq(helper.resolve_any_role(), provider_role, "provider role should win")
  end)

  it("resolve_any_role falls back to game api roles", function()
    local game_api_role = { id = "game_api_role" }
    local helper = _build_noop_helper({
      roles = {},
      game_api = {
        get_all_valid_roles = function()
          return { game_api_role }
        end,
      },
    })

    _assert_eq(helper.resolve_any_role(), game_api_role, "game api role should be fallback")
  end)

  it("resolve_any_role returns nil when game api throws", function()
    local helper = _build_noop_helper({
      roles = {},
      game_api = {
        get_all_valid_roles = function()
          error("boom")
        end,
      },
    })

    _assert_eq(helper.resolve_any_role(), nil, "game api error should resolve nil")
  end)

  it("resolve_any_role returns nil when provider and game api empty", function()
    local helper = _build_noop_helper({
      roles = {},
      game_api = {
        get_all_valid_roles = function()
          return {}
        end,
      },
    })

    _assert_eq(helper.resolve_any_role(), nil, "empty provider and game api should resolve nil")
  end)
end)
