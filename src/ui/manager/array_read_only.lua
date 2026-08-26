---@generic T
---@class ArrayReadOnly<T>: Array<T>
---@field length integer 数组长度
---@field protected __protected_sequence Array<T> 数组数据
---@field protected __protected_length integer 数组长度
---@field new fun(self: ArrayReadOnly, _array: Array<T>): ArrayReadOnly<T>
local Class = require("src.ui.manager.class")
local Array = require("src.ui.manager.array")
local number_utils = require("src.foundation.number")
local ArrayReadOnly = Class("UIManager.ArrayReadOnly", Array)

-- 只代理元素读（数值下标）；方法名落回类链，不再穿透 backing 实例（#267）：
-- 穿透曾让 ro:append/pop 借到 Array 的实现直接写坏共享 backing(data 与 length 脱节)。
function ArrayReadOnly:__custom_index(key)
    if number_utils.is_numeric(key) then
        return self.__protected_sequence[key]
    end
end

---@param sequence Array<T>
function ArrayReadOnly:init(sequence)
    self.__protected_sequence = sequence
end

-- 方法面由视图类自带(不再从 backing 实例借):只读遍历委托 backing 以自身为 self 执行。
---@param callback fun(e: T)
function ArrayReadOnly:forEach(callback)
    self.__protected_sequence:forEach(callback)
end

-- 只读契约:变更方法 fail-fast 报错(与 Array:__set_length 同款),不做静默 no-op(#267)。
function ArrayReadOnly:append(_value)
    error("ArrayReadOnly is read-only")
end

function ArrayReadOnly:pop()
    error("ArrayReadOnly is read-only")
end

function ArrayReadOnly:__get_length()
    return self.__protected_sequence.__protected_length
end

return ArrayReadOnly

--[[ mutate4lua-manifest
version=4
projectHash=c1f320be90b2a926
scope.0.id=chunk:src/ui/manager/array_read_only.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=45
scope.0.semanticHash=1c799b112f725b42
scope.1.id=function:ArrayReadOnly:__custom_index
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=18
scope.1.semanticHash=f283192661d1e653
scope.2.id=function:ArrayReadOnly:init
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=23
scope.2.semanticHash=e66f374cdcfa7616
scope.3.id=function:ArrayReadOnly:forEach
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=29
scope.3.semanticHash=954b73eae822f9b0
scope.4.id=function:ArrayReadOnly:append
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=34
scope.4.semanticHash=57f430cdc8cb12a4
scope.5.id=function:ArrayReadOnly:pop
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=38
scope.5.semanticHash=cbb19448adf66af7
scope.6.id=function:ArrayReadOnly:__get_length
scope.6.kind=function
scope.6.startLine=40
scope.6.endLine=42
scope.6.semanticHash=525c612c62352c4f
]]
