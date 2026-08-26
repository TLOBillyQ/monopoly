local actor_context = require("src.ui.coord.actor_context")

local actor_context_ports = {}

-- 只暴露 resolve_role_by_id:「用例层经端口自行解析行动者」的通路已拆(#442)——
-- 行动者归属在事件边界裁定一次,用例层只消费 intent.actor_role_id(ADR 0054,
-- CONTEXT.md「行动者」)。边界代码解析点击者仍走接缝 resolve_from_event。
function actor_context_ports.build()
  return {
    resolve_role_by_id = function(role_id)
      return actor_context.resolve_role_by_id(role_id)
    end,
  }
end

return actor_context_ports

--[[ mutate4lua-manifest
version=4
projectHash=f9130564d94120f5
scope.0.id=chunk:src/ui/ports/actor_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=0b273bec8e187db6
scope.1.id=function:actor_context_ports.build
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=14
scope.1.semanticHash=ba26ec36cfdb45c9
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=f1ce1850b7232305
]]
