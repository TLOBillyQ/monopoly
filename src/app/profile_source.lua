local source = {}
local default_map_module = "src.config.content.default_map"

local function _require_default_map()
  local ok, map_or_err = pcall(require, default_map_module)
  assert(ok, "failed to require default map module: " .. tostring(map_or_err))
  return map_or_err
end

local function _resolve_testing_bootstrap(profile_name)
  if type(profile_name) ~= "string" or profile_name == "" or profile_name == "default" then
    return {}
  end
  local resolver = require("src.app.testing.test_profile_resolver")
  return resolver.resolve_bootstrap(profile_name)
end

function source.resolve_map()
  return _require_default_map()
end

function source.resolve_bootstrap(startup)
  return _resolve_testing_bootstrap(startup and startup.profile_name or nil)
end

return source
