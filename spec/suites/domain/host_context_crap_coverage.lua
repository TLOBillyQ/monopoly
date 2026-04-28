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

local function _test_safe_get_role_returns_nil_for_nil_role_id()
  local helper = _build_noop_helper({
    game_api = {
      get_role = function()
        error("should not be called")
      end,
    },
  })

  _assert_eq(helper.resolve_role(nil), nil, "nil role_id should resolve nil")
end

local function _test_safe_get_role_returns_nil_when_get_role_missing()
  local helper = _build_noop_helper({
    game_api = {},
  })

  _assert_eq(helper.resolve_role("role_1"), nil, "missing get_role should resolve nil")
end

local function _test_safe_get_role_returns_nil_when_game_api_throws()
  local helper = _build_noop_helper({
    game_api = {
      get_role = function()
        error("boom")
      end,
    },
  })

  _assert_eq(helper.resolve_role("role_1"), nil, "get_role error should resolve nil")
end

local function _test_safe_get_role_returns_role_when_game_api_succeeds()
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
end

local function _test_resolve_any_role_prefers_provider_role()
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
end

local function _test_resolve_any_role_falls_back_to_game_api_roles()
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
end

local function _test_resolve_any_role_returns_nil_when_game_api_throws()
  local helper = _build_noop_helper({
    roles = {},
    game_api = {
      get_all_valid_roles = function()
        error("boom")
      end,
    },
  })

  _assert_eq(helper.resolve_any_role(), nil, "game api error should resolve nil")
end

local function _test_resolve_any_role_returns_nil_when_provider_and_game_api_empty()
  local helper = _build_noop_helper({
    roles = {},
    game_api = {
      get_all_valid_roles = function()
        return {}
      end,
    },
  })

  _assert_eq(helper.resolve_any_role(), nil, "empty provider and game api should resolve nil")
end

return {
  name = "host context crap coverage",
  tests = {
    { name = "safe_get_role returns nil for nil role id", run = _test_safe_get_role_returns_nil_for_nil_role_id },
    { name = "safe_get_role returns nil when get_role missing", run = _test_safe_get_role_returns_nil_when_get_role_missing },
    { name = "safe_get_role returns nil when game api throws", run = _test_safe_get_role_returns_nil_when_game_api_throws },
    { name = "safe_get_role returns role when game api succeeds", run = _test_safe_get_role_returns_role_when_game_api_succeeds },
    { name = "resolve_any_role prefers provider role", run = _test_resolve_any_role_prefers_provider_role },
    { name = "resolve_any_role falls back to game api roles", run = _test_resolve_any_role_falls_back_to_game_api_roles },
    { name = "resolve_any_role returns nil when game api throws", run = _test_resolve_any_role_returns_nil_when_game_api_throws },
    { name = "resolve_any_role returns nil when provider and game api empty", run = _test_resolve_any_role_returns_nil_when_provider_and_game_api_empty },
  },
}
