---@generic T
---@class UIManager.ArrayReadOnly<T>: UIManager.Array<T>, ClassUtil
---@field length integer 数组长度
---@field protected __protected_sequence UIManager.Array<T> 数组数据
---@field protected __protected_length integer 数组长度
local ArrayReadOnly = UIManager.Class("UIManager.ArrayReadOnly", UIManager.Array)

function ArrayReadOnly:__custom_index(key)
    return self.__protected_sequence[key]
end

function ArrayReadOnly:__custom_new_index(key, value)
    error("This Array is read-only")
end

---@param _sequence UIManager.Array<T>
function ArrayReadOnly:init(_sequence)
    self.__protected_sequence = _sequence
end

function ArrayReadOnly:__get_length()
    return self.__protected_sequence.__protected_length
end

function ArrayReadOnly:append(value)
    error("This Array is read-only")
end

function ArrayReadOnly:pop()
    error("This Array is read-only")
end

return ArrayReadOnly