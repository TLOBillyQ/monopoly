-- 破产出局的宿主侧执行(ADR 0046,取证结论以 #610 为准):宿主 CampRole 没有
-- die,die 在 role.get_ctrl_unit() 返回的单位上,签名单参可省、不带 self、无返回
-- 值,成功信号是 unit.is_die_status() 翻 true;合成 AI 适配器是 Lua table,自带
-- die 返回布尔并自行退役销毁单位,仍按 truthy 判定。两类对象的鸭子知识(方法在
-- 谁身上、签名、成功判据)全部收在本模块,规则层只经 runtime_ports.call_role_die
-- 触达。
local host_types = require("src.foundation.host_types")
local unit_lifecycle = require("src.host.units")
local logger = require("src.foundation.log")

local role_die = {}

-- 合成 AI 适配器路径:die 有明确布尔返回值,成功判据仍是 truthy(#263 探到的
-- 就是这个适配器)。pcall 只防异常炸穿规则层,抛错与假值都留痕。
local function _call_adapter_die(die)
  local ok, result = pcall(die)
  if not ok then
    logger.warn("role_die failed: adapter die raised:", tostring(result))
    return false
  end
  if result == nil or result == false then
    logger.warn("role_die failed: adapter die returned falsy:", tostring(result))
    return false
  end
  return true
end

-- 宿主 Role 无 die 时经控制单位出局;取不到单位即对象缺失,留痕后放弃。
local function _resolve_ctrl_unit(role)
  local get_ctrl_unit = host_types.method(role, "get_ctrl_unit")
  if get_ctrl_unit == nil then
    logger.warn("role_die skip: role has neither die nor get_ctrl_unit")
    return nil
  end
  local ok, unit = pcall(get_ctrl_unit)
  if not ok then
    logger.warn("role_die skip: get_ctrl_unit raised:", tostring(unit))
    return nil
  end
  if unit == nil then
    logger.warn("role_die skip: role has no ctrl unit")
    return nil
  end
  return unit
end

-- unit.die(dmg_unit) 单参、不带 self(冒号调用被宿主拒收),且无返回值——参数
-- 出错时宿主只记 ERROR 返回 nil、不抛异常,所以「pcall 没抛」不是成功信号,一律
-- 回读 is_die_status。已死单位再调 die 幂等,回读同样为 true。
local function _kill_ctrl_unit(unit)
  local die = host_types.method(unit, "die")
  if die == nil then
    logger.warn("role_die skip: ctrl unit has no die method")
    return false
  end
  local is_die_status = host_types.method(unit, "is_die_status")
  if is_die_status == nil then
    logger.warn("role_die skip: ctrl unit has no is_die_status method")
    return false
  end
  local ok, err = pcall(die, nil)
  if not ok then
    logger.warn("role_die failed: ctrl unit die raised:", tostring(err))
    return false
  end
  local ok_status, status = pcall(is_die_status)
  if not (ok_status and status == true) then
    logger.warn("role_die failed: ctrl unit is_die_status not true after die:", tostring(status))
    return false
  end
  return true
end

-- 单位移除复用合成 AI 退役的同一条 GameAPI.destroy_unit 路径,两类玩家一致。
-- 真机验证待主会话完成:若销毁真人控制单位触发宿主重生或镜头异常,退到隐藏路径
-- (LCharacter 上有 destroy、无 set_visible,隐藏手段需另行取证)。出局语义已由
-- is_die_status 达成,移除失败只留痕、不推翻端口成功(ADR 0046)。
local function _remove_ctrl_unit(unit)
  local ok, destroyed = pcall(unit_lifecycle.destroy_unit, unit)
  if not ok then
    logger.warn("role_die: ctrl unit destroy raised:", tostring(destroyed))
    return
  end
  if destroyed ~= true then
    logger.warn("role_die: ctrl unit destroy skipped: missing GameAPI.destroy_unit")
  end
end

-- 返回 true 表示宿主侧出局处理成功。对象缺失、方法缺失、调用后状态未翻转与移除
-- 失败四类各自留一条 warn,禁止静默。
function role_die.call_role_die(role)
  if role == nil then
    logger.warn("role_die skip: role is nil")
    return false
  end
  local adapter_die = host_types.method(role, "die")
  if adapter_die ~= nil then
    return _call_adapter_die(adapter_die)
  end
  local unit = _resolve_ctrl_unit(role)
  if unit == nil then
    return false
  end
  if not _kill_ctrl_unit(unit) then
    return false
  end
  _remove_ctrl_unit(unit)
  return true
end

return role_die

--[[ mutate4lua-manifest
version=4
projectHash=7d0ec03f36a9823f
scope.0.id=chunk:src/host/role_die.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=112
scope.0.semanticHash=1e41fa045b85d5dd
scope.1.id=function:_call_adapter_die
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=26
scope.1.semanticHash=a71844651eac75bc
scope.2.id=function:_resolve_ctrl_unit
scope.2.kind=function
scope.2.startLine=29
scope.2.endLine=45
scope.2.semanticHash=91e8573235d64740
scope.3.id=function:_kill_ctrl_unit
scope.3.kind=function
scope.3.startLine=50
scope.3.endLine=72
scope.3.semanticHash=dcb03ab7eee63de7
scope.4.id=function:_remove_ctrl_unit
scope.4.kind=function
scope.4.startLine=78
scope.4.endLine=87
scope.4.semanticHash=ac44287f5e9abf49
scope.5.id=function:role_die.call_role_die
scope.5.kind=function
scope.5.startLine=91
scope.5.endLine=109
scope.5.semanticHash=bef0eeb7377262ec
]]
