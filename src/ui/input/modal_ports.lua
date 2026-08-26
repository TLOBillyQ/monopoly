local M = {}

function M.resolve(state)
  local ports = state and state.gameplay_loop_ports or nil
  return ports and ports.modal or {}
end

function M.close_choice_modal(state)
  local modal = M.resolve(state)
  if type(modal.close_choice_modal) == "function" then
    modal.close_choice_modal(state)
  end
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=0bdbd97defb5140f
scope.0.id=chunk:src/ui/input/modal_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=8b135216222d15e2
scope.1.id=function:M.resolve
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=6
scope.1.semanticHash=d1be5ea34e0a3d6c
scope.2.id=function:M.close_choice_modal
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=13
scope.2.semanticHash=bbd7eff7a8d0f20a
]]
