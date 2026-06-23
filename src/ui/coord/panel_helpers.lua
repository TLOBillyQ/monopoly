local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_ui = require("src.ui.render.runtime_ui")
local with_client_role = require("src.ui.utils.with_client_role")

local M = {}

function M.resolve_runtime(state)
  local presentation_runtime = state and state.presentation_runtime or nil
  return (presentation_runtime and presentation_runtime.runtime) or runtime_ui
end

function M.with_owner_role(state, role_id, fn)
  local role = runtime_ports.resolve_role(role_id)
  if role == nil then
    return fn()
  end
  return with_client_role(M.resolve_runtime(state), role, fn)
end

function M.current_action_anim(state)
  local game = state and state.game or nil
  local turn = game and game.turn or nil
  return turn and turn.action_anim or nil
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=fb01e873b4275398
scope.0.id=chunk:src/ui/coord/panel_helpers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=7eac8d1a41d16882
scope.0.lastMutatedAt=2026-05-26T12:25:01Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:M.resolve_runtime:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=10
scope.1.semanticHash=21002a4523b6d3b1
scope.1.lastMutatedAt=2026-05-26T12:25:01Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:M.with_owner_role:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=18
scope.2.semanticHash=4002bb21b5fb9eaa
scope.2.lastMutatedAt=2026-05-26T12:25:01Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
]]
