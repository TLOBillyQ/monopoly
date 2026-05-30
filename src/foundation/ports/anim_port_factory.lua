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
version=2
projectHash=c26b632290359617
scope.0.id=chunk:src/foundation/ports/anim_port_factory.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=31
scope.0.semanticHash=907db1f0b7620adb
scope.1.id=function:port.is_enabled:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=14
scope.1.semanticHash=7dcf34ae5c57e65e
scope.2.id=function:port.queue:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=25
scope.2.semanticHash=abd7339aa5d47370
scope.3.id=function:M.build:3
scope.3.kind=function
scope.3.startLine=3
scope.3.endLine=28
scope.3.semanticHash=2b1d5dd0fd54cde1
]]
