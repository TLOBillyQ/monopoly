---核心工具函数，参考 deepfuture 设计

local util = {}

---自动缓存装饰器
---第一次访问时计算值，后续直接返回缓存
---适用于配置加载、计算密集型操作
---
---用法:
---   local cached_rules = util.cache(function(name)
---     return load_config(name)  -- 只执行一次
---   end)
---   local cfg1 = cached_rules.advancement  -- 加载并缓存
---   local cfg2 = cached_rules.advancement  -- 直接返回缓存
---
---@param f function 计算函数，接收 key 返回 value
---@return table 缓存表
function util.cache(f)
  local meta = {}
  function meta:__index(k)
    local v = f(k)
    self[k] = v
    return v
  end
  return setmetatable({}, meta)
end

---带过期时间的缓存
---@param f function 计算函数
---@param ttl_seconds number 过期时间（秒）
---@return table 缓存表
function util.cache_with_ttl(f, ttl_seconds)
  local cache = {}
  local timestamps = {}
  local now = os.time

  return setmetatable({}, {
    __index = function(_, k)
      local ts = timestamps[k]
      if ts and (now() - ts) < ttl_seconds then
        return cache[k]
      end
      local v = f(k)
      cache[k] = v
      timestamps[k] = now()
      return v
    end,
    __newindex = function() end,  -- 禁止直接赋值
  })
end

---脏标记更新器
---当依赖数据变化时，强制重新计算
---
---用法:
---   local calc = util.dirty_update(function(x) return expensive(x) end)
---   local r1 = calc(5)  -- 计算
---   local r2 = calc(5)  -- 返回缓存
---   util.dirty_trigger(calc)  -- 标记为脏
---   local r3 = calc(5)  -- 重新计算
---
local dirty_flags = {}

function util.dirty_update(f)
  local wrapper = function(...)
    if dirty_flags[f] == nil then
      local r = f(...)
      dirty_flags[f] = r or false
      return r
    else
      return dirty_flags[f]
    end
  end
  return wrapper
end

function util.dirty_trigger(f)
  dirty_flags[f] = nil
end

---重置所有脏标记
function util.dirty_clear_all()
  for k, _ in pairs(dirty_flags) do
    dirty_flags[k] = nil
  end
end

---简单对象池
---用于频繁创建/销毁的小型对象
---
---用法:
---   local pool = util.pool(function() return {} end)
---   local obj = pool.acquire()  -- 获取或创建
---   -- 使用 obj
---   pool.release(obj)  -- 回收（会自动清空）
---
---@param factory function 创建新对象的工厂函数
---@param reset function|nil 可选的重置函数
---@return table 对象池
function util.pool(factory, reset)
  local pool = {}
  local objects = {}

  function pool.acquire()
    local obj = table.remove(objects)
    if obj then
      return obj
    end
    return factory()
  end

  function pool.release(obj)
    if reset then
      reset(obj)
    else
      -- 默认清空表
      for k, _ in pairs(obj) do
        obj[k] = nil
      end
    end
    table.insert(objects, obj)
  end

  function pool.size()
    return #objects
  end

  function pool.clear()
    for i = #objects, 1, -1 do
      objects[i] = nil
    end
  end

  return pool
end

---安全的 pcall 包装，返回默认值
---@param f function 要执行的函数
---@param default any 失败时的默认值
---@return any 成功返回值或默认值
function util.try(f, default, ...)
  local ok, result = pcall(f, ...)
  if ok then
    return result
  end
  return default
end

---字符串插值
---支持 ${key} 和 ${key|default} 格式
---
---用法:
---   util.interpolate("Hello ${name}", {name = "World"})  -- "Hello World"
---   util.interpolate("Value: ${x|0}", {})  -- "Value: 0"
---
---@param template string 模板字符串
---@param vars table 变量表
---@return string 插值后的字符串
function util.interpolate(template, vars)
  if not template then
    return ""
  end
  return template:gsub("${([^}]*)}", function(tag)
    local key, def = tag:match("^(.-)|(.*)$")
    key = key or tag
    local v = vars[key]
    if v == nil then
      return def or tag
    end
    return tostring(v)
  end)
end

---生成唯一ID
---简单的递增计数器，适用于运行时临时ID
local uid_counter = 0
function util.uid()
  uid_counter = uid_counter + 1
  return uid_counter
end

---重置UID计数器（测试用）
function util.reset_uid()
  uid_counter = 0
end

---深拷贝（简单版，不处理循环引用）
---@param t table 要拷贝的表
---@return table 深拷贝后的表
function util.deep_copy(t)
  if type(t) ~= "table" then
    return t
  end
  local result = {}
  for k, v in pairs(t) do
    result[k] = util.deep_copy(v)
  end
  return result
end

---浅拷贝
---@param t table 要拷贝的表
---@return table 浅拷贝后的表
function util.shallow_copy(t)
  if type(t) ~= "table" then
    return t
  end
  local result = {}
  for k, v in pairs(t) do
    result[k] = v
  end
  return result
end

---检查表是否为空（无键值对）
---@param t table
---@return boolean
function util.is_empty(t)
  if type(t) ~= "table" then
    return true
  end
  return next(t) == nil
end

---表长度（适用于数组部分和非数组部分）
---@param t table
---@return number
function util.table_size(t)
  if type(t) ~= "table" then
    return 0
  end
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

return util
