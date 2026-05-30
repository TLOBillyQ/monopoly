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
version=2
projectHash=040ea39fed535cf9
scope.0.id=chunk:src/ui/ports/clock.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=23
scope.0.semanticHash=7bbaf178b7588195
scope.1.id=function:anonymous@7:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=a17494eb7b686304
scope.2.id=function:anonymous@10:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=21cb7df0fc0a9251
scope.3.id=function:anonymous@13:13
scope.3.kind=function
scope.3.startLine=13
scope.3.endLine=15
scope.3.semanticHash=f89bcdb61d3ebf3c
scope.4.id=function:anonymous@16:16
scope.4.kind=function
scope.4.startLine=16
scope.4.endLine=18
scope.4.semanticHash=561631a2530cb3bb
scope.5.id=function:clock_ports.build:5
scope.5.kind=function
scope.5.startLine=5
scope.5.endLine=20
scope.5.semanticHash=875c35615e022e26
]]
