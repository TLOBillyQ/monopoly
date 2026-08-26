---@class UIManager.ECanvas : Class
---@field __name "UIManager.ECanvas"
---@field id ECanvas ID值 - 只读
---@field name string UI名称 - 只读
---@field parent UIManager.ECanvas? 父亲节点 - 只读
---@field children ArrayReadOnly<UIManager.ECanvas> 子节点列表 - 只读
---@field protected __protected_id ECanvas 受保护的id值
---@field protected __protected_name string 受保护的UI名称
---@field protected __protected_parent UIManager.ECanvas 受保护的父亲节点
---@field protected __protected_children Array<UIManager.ECanvas> 受保护的子节点列表
---@field new fun(self: UIManager.ECanvas, node: ECanvas, name: string)
local Class = require("src.ui.manager.class")
local context = require("src.ui.manager.context")
local Array = require("src.ui.manager.array")
local ArrayReadOnly = require("src.ui.manager.array_read_only")
local ECanvas = Class("UIManager.ECanvas")
local nodes_list = context.nodes_list

---@param node ECanvas
---@param name string
function ECanvas:init(node, name)
    if nodes_list[node] then
        nodes_list[node] = nil
    end
    nodes_list[node] = self
    self.__protected_name = name
    self.__protected_parent = nil
    self.__protected_id = node

    local array = Array:new() --[[@as Array<UIManager.ECanvas>]]
    self.__protected_children = array
    self.__protected_read_only_children = ArrayReadOnly:new(array)
end

function ECanvas:__init_children()
    for idx, node in ipairs(GameAPI.get_eui_children(self.id)) do
        local uinode = nodes_list[node] --[[@as UIManager.ECanvas]]
        uinode.__protected_parent = self
        self.__protected_children:append(uinode)
    end
end

function ECanvas:__get_children()
    return self.__protected_read_only_children
end

function ECanvas:__set_children(value)
    warn(("attempt to set a read-only value field 'children' of '%s'"):format(self.__name))
end

function ECanvas:__get_parent()
    return self.__protected_parent
end

function ECanvas:__set_parent(value)
    warn(("attempt to set a read-only value field 'parent' of '%s'"):format(self.__name))
end

function ECanvas:__get_name()
    return self.__protected_name
end

function ECanvas:__set_name(value)
    warn(("attempt to set a read-only value field 'name' of '%s'"):format(self.__name))
end

function ECanvas:__get_id()
    return self.__protected_id
end

function ECanvas:__set_id(value)
    warn(("attempt to set a read-only value field 'id' of '%s'"):format(self.__name))
end

return ECanvas

--[[ mutate4lua-manifest
version=4
projectHash=f1fd54a3de83c4c5
scope.0.id=chunk:src/ui/manager/ecanvas.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=76
scope.0.semanticHash=f768e18c8ce73d01
scope.1.id=function:ECanvas:init
scope.1.kind=function
scope.1.startLine=21
scope.1.endLine=33
scope.1.semanticHash=7e803d0c0bed6900
scope.2.id=function:ECanvas:__init_children
scope.2.kind=function
scope.2.startLine=35
scope.2.endLine=41
scope.2.semanticHash=6c699043b1949529
scope.3.id=function:ECanvas:__get_children
scope.3.kind=function
scope.3.startLine=43
scope.3.endLine=45
scope.3.semanticHash=c0484ae42c9068b0
scope.4.id=function:ECanvas:__set_children
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=49
scope.4.semanticHash=95e19093d3c9cec2
scope.5.id=function:ECanvas:__get_parent
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=53
scope.5.semanticHash=c0484ae42c9068b0
scope.6.id=function:ECanvas:__set_parent
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=57
scope.6.semanticHash=95e19093d3c9cec2
scope.7.id=function:ECanvas:__get_name
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=61
scope.7.semanticHash=c0484ae42c9068b0
scope.8.id=function:ECanvas:__set_name
scope.8.kind=function
scope.8.startLine=63
scope.8.endLine=65
scope.8.semanticHash=95e19093d3c9cec2
scope.9.id=function:ECanvas:__get_id
scope.9.kind=function
scope.9.startLine=67
scope.9.endLine=69
scope.9.semanticHash=c0484ae42c9068b0
scope.10.id=function:ECanvas:__set_id
scope.10.kind=function
scope.10.startLine=71
scope.10.endLine=73
scope.10.semanticHash=95e19093d3c9cec2
]]
