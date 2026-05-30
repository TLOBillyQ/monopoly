local actor_context = require("src.ui.coord.actor_context")

local actor_context_ports = {}

function actor_context_ports.build()
  return {
    resolve_local_actor_role_id = function(state)
      return actor_context.resolve_local_actor_role_id(state)
    end,
    resolve_role_by_id = function(role_id)
      return actor_context.resolve_role_by_id(role_id)
    end,
  }
end

return actor_context_ports

--[[ mutate4lua-manifest
version=2
projectHash=52c007200d6749a8
scope.0.id=chunk:src/ui/ports/actor_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=8e3ae1ef048d4080
scope.1.id=function:anonymous@7:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=73dce7bb96a2f16a
scope.2.id=function:anonymous@10:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=07cb36741c45c1e2
scope.3.id=function:actor_context_ports.build:5
scope.3.kind=function
scope.3.startLine=5
scope.3.endLine=14
scope.3.semanticHash=cae2c95726ea7529
]]
