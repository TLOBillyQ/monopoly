local host_types = {}

local function _make_constructor(host_key)
  return function(x, y, z)
    if math and math[host_key] then
      return math[host_key](x, y, z)
    end
    return { x = x, y = y, z = z }
  end
end

host_types.vec3 = _make_constructor("Vector3")
host_types.quat = _make_constructor("Quaternion")

-- 宿主对象（Role / Unit / Vector3 …）在 Eggy 沙盒里 type() 返回的是宿主类名，
-- 不是 "table"——真机取证 #266：Role 返回 "CampRole"。所以凡是可能拿到宿主对象
-- 的地方都不能用 type(x) == "table" 把门：那是一道恒假的门，会让整条链静默退化
-- 回旧行为（功能不崩、外观不变），是最难被发现的失败模式。
--
-- 宿主对象一律鸭子判定：取得到要用的那个字段/方法就用。索引宿主对象本身也可能
-- 抛（元表行为不受我们控制），所以连取字段一起 pcall。
function host_types.field(obj, name)
  if obj == nil then
    return nil
  end
  local ok, value = pcall(function()
    return obj[name]
  end)
  if not ok then
    return nil
  end
  return value
end

function host_types.method(obj, name)
  local fn = host_types.field(obj, name)
  if type(fn) ~= "function" then
    return nil
  end
  return fn
end

-- 调用宿主对象上的方法：取不到方法、或调用本身抛了，都返回 nil。self 不自动
-- 传——宿主的调用约定并不统一（有的要 self，有的不要），交给调用方显式给。
--
-- 注意 nil 的聚合语义：call 不区分「取不到方法」「调用抛错」与「调用成功但返回
-- nil」。宿主方法成功时若返回 nil（或干脆无返回值），call 同样给出 nil。要拿
-- 返回值判定「成功」的调用方（如锁存副作用、把返回值当投递结果）请先
-- host_types.method 取方法，再自行 pcall，保住「不抛错即成功」的语义。
function host_types.call(obj, name, ...)
  local fn = host_types.method(obj, name)
  if fn == nil then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok then
    return nil
  end
  return value
end

return host_types

--[[ mutate4lua-manifest
version=4
projectHash=5f606d81b47ae43a
scope.0.id=chunk:src/foundation/host_types.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=63
scope.0.semanticHash=e62fa2ec8c627756
scope.1.id=function:_make_constructor
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=10
scope.1.semanticHash=1ec7ccd485e5ae61
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=4
scope.2.endLine=9
scope.2.semanticHash=e8f30547bdedfe64
scope.3.id=function:host_types.field
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=33
scope.3.semanticHash=467c018787f93d50
scope.4.id=function:<anonymous>#2
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=28
scope.4.semanticHash=479ee593b7c390c0
scope.5.id=function:host_types.method
scope.5.kind=function
scope.5.startLine=35
scope.5.endLine=41
scope.5.semanticHash=036c163aeb192d00
scope.6.id=function:host_types.call
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=60
scope.6.semanticHash=575c44d3bd63cbdd
]]
