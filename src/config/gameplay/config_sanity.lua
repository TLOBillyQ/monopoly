local runtime_assets = require("src.config.runtime_assets")

local config_sanity = {}

local validated = false

local function _validate_runtime_assets()
  local result = runtime_assets.validate_catalog()
  if result.ok == true then
    return
  end
  local first = result.errors and result.errors[1] or nil
  error((first and first.message) or "runtime asset catalog invalid", 0)
end

function config_sanity.validate()
  if validated then
    return true
  end
  _validate_runtime_assets()
  validated = true
  return true
end

function config_sanity.reset_for_tests()
  validated = false
end

return config_sanity

--[[ mutate4lua-manifest
version=2
projectHash=b672357e8804eb06
scope.0.id=chunk:src/config/gameplay/config_sanity.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=30
scope.0.semanticHash=b841d5f563b2c38e
scope.0.lastMutatedAt=2026-06-24T20:07:59Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=1
scope.1.id=function:_validate_runtime_assets:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=14
scope.1.semanticHash=ea4412fec2fa28f8
scope.1.lastMutatedAt=2026-06-24T20:07:59Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:config_sanity.validate:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=23
scope.2.semanticHash=9d41708459623a11
scope.2.lastMutatedAt=2026-06-24T20:07:59Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:config_sanity.reset_for_tests:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=27
scope.3.semanticHash=105c5f919a1e81e3
scope.3.lastMutatedAt=2026-06-24T20:07:59Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
]]
