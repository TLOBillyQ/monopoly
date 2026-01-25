---@class Array<T>
---@field [integer] T
---@field length integer 数组长度
---@field data T[]
---@field private __length integer
local Array = Class("Array")

-- 深拷贝（通过唯一标识符处理循环引用）
local function deep_copy(orig, seen, id_counter)
    if type(orig) ~= "table" then
        return orig
    end

    seen = seen or {}
    id_counter = id_counter or { value = 0 }

    -- 为当前表生成唯一ID（如果还没有）
    if not rawget(orig, "__copy_id") then
        id_counter.value = id_counter.value + 1
        rawset(orig, "__copy_id", id_counter.value)
    end

    local obj_id = rawget(orig, "__copy_id")

    -- 检查是否已经复制过
    if seen[obj_id] then
        return seen[obj_id]
    end

    local copy = {}
    seen[obj_id] = copy

    for k, v in pairs(orig) do
        if k ~= "__copy_id" then -- 跳过临时ID字段
            local keyType = type(k)
            if keyType == "string" or keyType == "number" then
                copy[k] = deep_copy(v, seen, id_counter)
            end
        end
    end

    local mt = getmetatable(orig)
    if mt then
        setmetatable(copy, mt)
    end

    return copy
end

-- 清理临时ID的辅助函数
local function clean_copy_ids(tbl, visited)
    if type(tbl) ~= "table" then
        return
    end

    visited = visited or {}
    local id = rawget(tbl, "__copy_id")

    if id and not visited[id] then
        visited[id] = true
        rawset(tbl, "__copy_id", nil)

        for k, v in pairs(tbl) do
            if type(v) == "table" then
                clean_copy_ids(v, visited)
            end
        end
    end
end

-- 构造函数
---@generic T
---@param from? T[] | Array<T>
---@return Array<T>
function Array:init(from)
    self.data = {}
    self.__length = 0
    if from and type(from) == "table" and from --[[@as table]].__name == "Array" then
        ---@cast from -T[], -?
        self.__length = from.__length
        for i = 1, self.__length do
            local copied = deep_copy(from.data[i])
            clean_copy_ids(from.data[i]) -- 清理源对象的临时ID
            clean_copy_ids(copied)       -- 清理复制对象的临时ID
            self.data[i] = copied
        end
    elseif from and (type(from) == "table") then
        ---@cast from -T[], -?
        self.__length = #from
        for i = 1, self.__length do
            local copied = deep_copy(from[i])
            clean_copy_ids(from[i]) -- 清理源对象的临时ID
            clean_copy_ids(copied)  -- 清理复制对象的临时ID
            self.data[i] = copied
        end
    end
    return self
end

---@param key integer
function Array:__custom_index(key)
    if type(key) == "number" then
        if key > 0 and key <= self.__length then
            return self.data[key]
        end
        return error(("%d out of range"):format(key))
    end
    return error(("'integer' needed but got '%s'"):format(type(key)))
end

function Array:__get_length()
    return self.__length
end

---@param value integer
function Array:__set_length(value)
    error("Array length is read-only")
end

---@param key integer
---@param value T
function Array:__new_custom_index(key, value)
    if type(key) == "number" then
        if key > 0 and key <= self.__length then
            self.data[key] = value
            return true
        end
    end
    return error(("'integer' needed but got '%s'"):format(type(key)))
end

---尾部追加元素
---@param value T
function Array:push(value)
    self.__length = self.__length + 1
    self.data[self.__length] = value
end

---头部追加元素
---@param value T
function Array:unshift(value)
    self.__length = self.__length + 1
    table.insert(self.data, 1, value)
end

---去除最后一个元素
---@return T
function Array:pop()
    if self.__length <= 0 then
        return nil
    end
    local result = self.data[self.__length]
    self.data[self.__length] = nil
    self.__length = self.__length - 1
    return result
end

---去除头部元素
---@return T
function Array:shift()
    if self.__length <= 0 then
        return nil
    end
    local result = table.remove(self.data, 1)
    self.__length = self.__length - 1
    return result
end

---是否全部满足条件
---@param predicate fun(item: T) : boolean
---@return boolean
function Array:every(predicate)
    local data = self.data
    local result = true
    for i = 1, self.__length do
        local item = data[i]
        if not predicate(item) then
            result = false
            break
        end
    end
    return result
end

---是否有满足条件的
---@param predicate fun(item: T) : boolean
---@return boolean
function Array:some(predicate)
    local data = self.data
    for i = 1, self.__length do
        local item = data[i]
        if predicate(item) then
            return true
        end
    end
    return false
end

---找到第一个满足条件的元素
---@param predicate fun(item: T) : boolean
---@return T? element 第一个满足条件的元素
function Array:find(predicate)
    local data = self.data
    for i = 1, self.__length do
        local item = data[i]
        if predicate(item) then
            return item
        end
    end
    return nil
end

---数组映射
---@generic G
---@param predicate fun(item: T) : G
---@return Array<G>
function Array:map(predicate)
    local newArr = Array() --[[@as Array<G>]]
    local data = self.data
    for i = 1, self.__length do
        local item = data[i]
        newArr:push(predicate(item))
    end
    return newArr
end

---数组切片
---@param start integer 开始索引
---@param over integer 结束索引
---@param step integer? 步数
---@return Array<T>
function Array:slice(start, over, step)
    local data = self.data
    local newArr = Array() --[[@as Array<T>]]
    local start_idx = math.tointeger(math.clamp(start, 1, self.__length))
    local over_idx = math.tointeger(math.clamp(over, 1, self.__length))
    step = step or 1
    for i = start_idx, over_idx, step do
        newArr:push(data[i])
    end
    return newArr
end

---@param index integer 开始索引
---@param count? integer 删除数量
---@param ... T... 要插入的元素
---@return Array<T>
function Array:splice(index, count, ...)
    local result = Array() --[[@as Array<T>]]

    -- 参数验证和默认值
    index = math.max(1, math.min(index, self.__length + 1))
    count = count or (self.__length - index + 1)
    count = math.max(0, math.min(count, self.__length - index + 1))

    -- 获取要插入的元素
    local insertElements = { ... }
    local insertCount = select("#", ...)

    -- 保存被删除的元素到结果数组
    for i = index, index + count - 1 do
        if i <= self.__length then
            result:push(self.data[i])
        end
    end

    -- 计算长度变化
    local lengthChange = insertCount - count

    if lengthChange > 0 then
        -- 插入的元素比删除的多，需要向后移动元素
        for i = self.__length, index + count, -1 do
            self.data[i + lengthChange] = self.data[i]
        end
    elseif lengthChange < 0 then
        -- 删除的元素比插入的多，需要向前移动元素
        for i = index + count, self.__length do
            self.data[i + lengthChange] = self.data[i]
        end
        -- 清理末尾的多余元素
        for i = self.__length + lengthChange + 1, self.__length do
            self.data[i] = nil
        end
    end

    -- 插入新元素
    for i = 1, insertCount do
        self.data[index + i - 1] = insertElements[i]
    end

    -- 更新长度
    self.__length = self.__length + lengthChange

    return result
end

---过滤数组元素
---@param predicate fun(item: T): boolean
---@return Array<T>
function Array:filter(predicate)
    local newArray = Array()
    local data = self.data
    for i = 1, self.__length do
        local item = data[i]
        if predicate(item) then
            newArray:push(item)
        end
    end
    return newArray
end

---@param item T
---@return integer
function Array:index_of(item)
    local data = self.data
    for i = 1, self.__length do
        if data[i] == item then
            return i
        end
    end
    return -1
end

function Array:clear()
    self.data = {}
    self.__length = 0
end

---@param func fun(index: integer, item: T)
function Array:for_each(func)
    for i = 1, self.__length do
        func(i, self.data[i])
    end
end

-- 排序函数
---@param comparator fun(a: T, b: T): boolean 比较函数，返回true表示a应排在b前面
function Array:sort(comparator)
    table.sort(self.data, comparator)
end

return Array
