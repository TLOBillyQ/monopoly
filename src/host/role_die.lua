-- role.die 宿主直调适配(ADR 0046):真实签名 die(self, nil) 经真机取证
-- (#263 PROBE),规则层经 runtime_ports.call_role_die 触达本适配,对宿主对象
-- 唯一的鸭子知识(方法存在性、签名、返回值判据)收在 host 层。
local host_types = require("src.foundation.host_types")
local logger = require("src.foundation.log")

local role_die = {}

-- 单次直调 role.die(role, nil)。pcall 只防宿主异常炸穿规则层;抛异常或返回
-- 非真值都留痕,禁止静默退到「假装没发生」(D2/D4)。
local function _attempt_die(role, die)
  local ok, result = pcall(die, role, nil)
  if not ok then
    logger.warn("role_die failed: role.die raised:", tostring(result))
    return false
  end
  if result == nil or result == false then
    logger.warn("role_die failed: role.die returned falsy:", tostring(result))
    return false
  end
  return true
end

-- 成功判据 = 返回值 truthy;前置守卫(role 缺位 / die 方法缺失)跳过必留痕。
function role_die.call_role_die(role)
  if role == nil then
    logger.warn("role_die skip: role is nil")
    return false
  end
  local die = host_types.method(role, "die")
  if die == nil then
    logger.warn("role_die skip: role has no die method")
    return false
  end
  return _attempt_die(role, die)
end

return role_die

--[[ mutate4lua-manifest
version=4
projectHash=c48acb1469372d95
scope.0.id=chunk:src/host/role_die.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=39
scope.0.semanticHash=390083c5bef877e0
scope.1.id=function:_attempt_die
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=22
scope.1.semanticHash=a0e048443f1d7080
scope.2.id=function:role_die.call_role_die
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=36
scope.2.semanticHash=9fdf1599a256d5b0
]]
