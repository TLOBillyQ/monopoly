local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_ui = require("src.ui.render.support.runtime_ui")
local with_client_role = require("src.ui.render.support.with_client_role")

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

return M

--[[ mutate4lua-manifest
version=4
projectHash=cc34329d839561a9
scope.0.id=chunk:src/ui/render/support/panel_helpers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=aeccdb2157325ad1
scope.1.id=function:M.resolve_runtime
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=10
scope.1.semanticHash=59f25f618bd56beb
scope.2.id=function:M.with_owner_role
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=18
scope.2.semanticHash=9a222366a9291117
]]
