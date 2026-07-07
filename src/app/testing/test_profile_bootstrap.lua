local test_profile_resolver = require("src.app.testing.test_profile_resolver")
local startup_bootstrap = require("src.app.profile_bootstrap")

local bootstrap = {}

bootstrap.apply_bootstrap = startup_bootstrap.apply_bootstrap

function bootstrap.apply(game, profile_name)
  local cfg = test_profile_resolver.resolve_bootstrap(profile_name)
  return startup_bootstrap.apply_bootstrap(game, cfg)
end

return bootstrap

--[[ mutate4lua-manifest
version=2
projectHash=803453f78eacbc9c
scope.0.id=chunk:src/app/testing/test_profile_bootstrap.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=14
scope.0.semanticHash=2b84b9c37afe9843
scope.0.lastMutatedAt=2026-07-07T03:17:40Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:bootstrap.apply:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=11
scope.1.semanticHash=2ee0461719c20578
scope.1.lastMutatedAt=2026-07-07T03:17:40Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
]]
