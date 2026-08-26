-- 宿主 role.die 的规则层触达点(ADR 0046):盲试链与
-- get_component("LifeComp") 路径已删除,单次直调 role.die(role, nil) 的真实
-- 签名与成功判据(返回值 truthy)收在 src/host/role_die,本模块只经
-- runtime_ports 转发,规则层对宿主对象与组件系统零知识。
local runtime_ports = require("src.foundation.ports.runtime_ports")

local life_loss = {}

function life_loss.try_call_life_die(role)
  if not role then
    return false
  end
  return runtime_ports.call_role_die(role) == true
end

return life_loss

--[[ mutate4lua-manifest
version=4
projectHash=05bac08ea996168d
scope.0.id=chunk:src/rules/endgame/life_loss.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=4c138cc663f40d86
scope.1.id=function:life_loss.try_call_life_die
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=14
scope.1.semanticHash=07e6462e77a94349
]]
