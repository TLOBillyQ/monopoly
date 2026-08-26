local runtime_ports = require("src.foundation.ports.runtime_ports")

local clock_ports = {}

function clock_ports.build()
  return {
    wall_now_seconds = function()
      return runtime_ports.wall_now_seconds()
    end,
    wall_diff_seconds = function(timestamp_1, timestamp_2)
      return runtime_ports.wall_diff_seconds(timestamp_1, timestamp_2)
    end,
    cpu_now_seconds = function()
      return runtime_ports.cpu_now_seconds()
    end,
    cpu_diff_seconds = function(timestamp_1, timestamp_2)
      return runtime_ports.cpu_diff_seconds(timestamp_1, timestamp_2)
    end,
  }
end

return clock_ports

--[[ mutate4lua-manifest
version=4
projectHash=b6a64253c9a90261
scope.0.id=chunk:src/ui/ports/clock.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=23
scope.0.semanticHash=667ca2bb109724ab
scope.1.id=function:clock_ports.build
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=20
scope.1.semanticHash=d70ca9d38fffae20
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=9
scope.2.semanticHash=04a3b0c01baa0aa1
scope.3.id=function:<anonymous>#2
scope.3.kind=function
scope.3.startLine=10
scope.3.endLine=12
scope.3.semanticHash=aba9250a8c6b104f
scope.4.id=function:<anonymous>#3
scope.4.kind=function
scope.4.startLine=13
scope.4.endLine=15
scope.4.semanticHash=04a3b0c01baa0aa1
scope.5.id=function:<anonymous>#4
scope.5.kind=function
scope.5.startLine=16
scope.5.endLine=18
scope.5.semanticHash=aba9250a8c6b104f
]]
