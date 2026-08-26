local M = {}

function M.build(kind)
  local wait_field = "wait_" .. kind .. "_anim"
  local queue_method = "queue_" .. kind .. "_anim"
  local port = {}

  function port.is_enabled(game)
    if not game then
      return false
    end
    local anim_gate_port = assert(game.anim_gate_port, "missing anim_gate_port")
    return anim_gate_port[wait_field] == true
  end

  function port.queue(game, payload)
    if not port.is_enabled(game) then
      return false
    end
    if not game[queue_method] then
      return false
    end
    game[queue_method](game, payload)
    return true
  end

  return port
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=6469a7809fbef5ba
scope.0.id=chunk:src/foundation/ports/anim_port_factory.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=31
scope.0.semanticHash=aed3d70ff75c8e03
scope.1.id=function:M.build
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=28
scope.1.semanticHash=ea71fb37a07f4fa1
scope.2.id=function:port.is_enabled
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=14
scope.2.semanticHash=52b9e02b70755592
scope.3.id=function:port.queue
scope.3.kind=function
scope.3.startLine=16
scope.3.endLine=25
scope.3.semanticHash=7f6c7807c13e6bce
]]
