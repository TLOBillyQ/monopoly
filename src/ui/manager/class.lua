-- ui.manager.class 富类系统:UIManager 子树(ENode/ELabel/… 深包 Eggy 宿主节点)专用。
-- 支持多父继承、__get_*/__set_* getter/setter、__custom_index、Init/init 双命名构造。
-- 写路径只认 __set_<key> 命名 setter,没有 __custom_new_index 机制(从未接线,整搬带入的
-- 死概念，勿再引入；读自定义 __custom_index 生效、写自定义走命名 setter（#268）。
-- 与 src.foundation.class(最小类,零继承)刻意分家:foundation.class 服务 rules/state 等
-- 零继承使用面，本模块承载 UIManager 整搬保行为所需的全部魔法（#60）。

---@class Class
---@field __name string 类名
---@field __index table 类的元表
---@field new fun(self: Class, ...): any 创建类的实例
---@field init fun(self: table, ...) 类的构造函数
local function Class(class_name, ...)
    local parents = { ... }
    local class_table = {
        __name = class_name,
    }

    -- 继承链解析只此一处:类表元表按父类声明顺序找成员,父类自己也是带同款元表的类表,
    -- 于是这一层查找天然递归到祖父及以上。别处要找继承成员一律写 class_table[key],
    -- 不再自建递归(那份递归与本元表逐句同义,且顺带满足 forbidden_globals 的 rawget 禁令,见 #60)。
    -- 零父类时元表照装:空 parents 循环返回 nil,与不装元表同义,省掉一条不可观测的分支。
    setmetatable(class_table, {
        __index = function(_, key)
            for _, parent in ipairs(parents) do
                local value = parent[key]
                if value ~= nil then
                    return value
                end
            end
        end
    })

    function class_table:new(...)
        local instance = {}

        local instance_meta = {
            __index = function(t, key)
                -- 1. 先检查是否有getter方法
                local getter = class_table["__get_" .. key]
                if getter then
                    return getter(t)
                end

                -- 2. 然后尝试自定义索引方法（递归查找继承链）
                local custom_index = class_table["__custom_index"]
                if custom_index then
                    local result = custom_index(t, key)
                    if result ~= nil then
                        return result
                    end
                end

                -- 3. 最后尝试在类继承链中查找
                local value = class_table[key]
                if value ~= nil then
                    return value
                end
            end,

            __newindex = function(t, key, value)
                local setter = class_table["__set_" .. key]
                if setter then
                    setter(t, value)
                else
                    rawset(t, key, value)
                end
            end
        }

        setmetatable(instance, instance_meta)

        -- 调用初始化方法（支持Init和init两种命名）
        if self.Init then
            self.Init(instance, ...)
        elseif self.init then
            self.init(instance, ...)
        end

        return instance
    end

    return class_table
end

return Class

--[[ mutate4lua-manifest
version=4
projectHash=f53e32e59f3a289c
scope.0.id=chunk:src/ui/manager/class.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=87
scope.0.semanticHash=cf2a56cf3d3f525d
scope.1.id=function:Class
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=84
scope.1.semanticHash=b21fb29b0680a111
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=31
scope.2.semanticHash=39bde97af76cb8bd
scope.3.id=function:class_table:new
scope.3.kind=function
scope.3.startLine=34
scope.3.endLine=81
scope.3.semanticHash=f8cd6bc6c6edfabf
scope.4.id=function:<anonymous>#2
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=59
scope.4.semanticHash=f7fd6f2cedff1a63
scope.5.id=function:<anonymous>#3
scope.5.kind=function
scope.5.startLine=61
scope.5.endLine=68
scope.5.semanticHash=54e51b3963d02370
]]
