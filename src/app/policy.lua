local startup_policy = {}

local function _is_non_empty_string(value)
  return type(value) == "string" and value ~= ""
end

local function _resolve_string_or(value, default)
  if _is_non_empty_string(value) then
    return tostring(value)
  end
  return default
end

function startup_policy.resolve(globals)
  local resolved_profile = _resolve_string_or(
    globals and globals.STARTUP_TEST_PROFILE, "default"
  )

  return {
    build_mode = _resolve_string_or(
      globals and globals.MONOPOLY_BUILD_MODE, "debug"
    ),
    profile_name = resolved_profile,
  }
end

function startup_policy.is_release(resolved)
  return resolved ~= nil and resolved.build_mode == "release"
end

return startup_policy

--[[ mutate4lua-manifest
version=2
projectHash=9b881d6df6207d6c
scope.0.id=chunk:src/app/policy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=32
scope.0.semanticHash=b8de0ac2de573214
scope.1.id=function:_is_non_empty_string:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=5f411e62f05a77f7
scope.2.id=function:_resolve_string_or:7
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=12
scope.2.semanticHash=b13cad0c58fa7d49
scope.3.id=function:startup_policy.resolve:14
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=25
scope.3.semanticHash=4141ade74efbabee
scope.4.id=function:startup_policy.is_release:27
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=29
scope.4.semanticHash=af3561fba136c06b
]]
