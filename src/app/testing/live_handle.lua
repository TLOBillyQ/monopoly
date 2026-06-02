--- Single seam the e2e profile lane uses to reach the running game model from
--- inside the editor play runtime.
---
--- The app keeps the current game in a closure-captured ref that is not
--- reachable from an editor-cli `exec` snippet. This module stashes the current
--- game on a module-level reference that the lane can pull via
--- `require("src.app.testing.live_handle").get()`. It holds no logic and no
--- Eggy dependency -- it exists only to keep the unsuitable editor boundary thin.
local live_handle = {}

local _current_game = nil
local _current_state = nil

function live_handle.set(game, state)
  _current_game = game
  _current_state = state
end

function live_handle.get()
  return _current_game
end

function live_handle.get_state()
  return _current_state
end

function live_handle.clear()
  _current_game = nil
  _current_state = nil
end

return live_handle

--[[ mutate4lua-manifest
version=2
projectHash=ec9cf71af2c1a18a
scope.0.id=chunk:src/app/testing/live_handle.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=33
scope.0.semanticHash=897da4108372f5e0
scope.0.lastMutatedAt=2026-06-02T08:17:21Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=no_sites
scope.0.lastMutationSites=0
scope.0.lastMutationKilled=0
scope.1.id=function:live_handle.set:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=17
scope.1.semanticHash=15f8d60374c313a5
scope.1.lastMutatedAt=2026-06-02T08:17:21Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=no_sites
scope.1.lastMutationSites=0
scope.1.lastMutationKilled=0
scope.2.id=function:live_handle.get:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=21
scope.2.semanticHash=665103969be7e865
scope.2.lastMutatedAt=2026-06-02T08:17:21Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=no_sites
scope.2.lastMutationSites=0
scope.2.lastMutationKilled=0
scope.3.id=function:live_handle.get_state:23
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=25
scope.3.semanticHash=00074c47529e0944
scope.3.lastMutatedAt=2026-06-02T08:17:21Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=no_sites
scope.3.lastMutationSites=0
scope.3.lastMutationKilled=0
scope.4.id=function:live_handle.clear:27
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=30
scope.4.semanticHash=b656ae98f4c4942a
scope.4.lastMutatedAt=2026-06-02T08:17:21Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=no_sites
scope.4.lastMutationSites=0
scope.4.lastMutationKilled=0
]]
