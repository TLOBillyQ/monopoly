local source = {}
local default_map_module = "src.config.content.maps.default_map"

local function _require_default_map()
  local ok, map_or_err = pcall(require, default_map_module)
  assert(ok, "failed to require default map module: " .. tostring(map_or_err))
  return map_or_err
end

local function _load_generated_payload(profile_module)
  if type(profile_module) ~= "string" or profile_module == "" then
    return nil
  end
  local ok, payload_or_err = pcall(require, profile_module)
  assert(ok, "failed to require generated startup profile module: " .. tostring(payload_or_err))
  assert(type(payload_or_err) == "table", "invalid generated startup profile payload")
  return payload_or_err
end

local function _resolve_testing_bootstrap(profile_name)
  if type(profile_name) ~= "string" or profile_name == "" or profile_name == "default" then
    return {}
  end
  local resolver = require("src.app.bootstrap.testing.test_profile_resolver")
  return resolver.resolve_bootstrap(profile_name)
end

function source.resolve_map(startup)
  local generated = _load_generated_payload(startup and startup.profile_module or nil)
  if generated and generated.map_module then
    local ok, map_or_err = pcall(require, generated.map_module)
    assert(ok, "failed to require generated startup map module: " .. tostring(map_or_err))
    return map_or_err
  end
  return _require_default_map()
end

function source.resolve_bootstrap(startup)
  if startup and startup.profile_source == "generated" then
    local generated = _load_generated_payload(startup.profile_module)
    return generated and generated.bootstrap or {}
  end
  return _resolve_testing_bootstrap(startup and startup.profile_name or nil)
end

return source
