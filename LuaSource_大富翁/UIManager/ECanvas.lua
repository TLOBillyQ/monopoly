---@alias ECanvas string

---@class UIManager.ECanvas : ClassUtil, UIManager.ENode
---@field __name "UIManager.ECanvas"
---@field id ECanvas ID值 - 只读
---@field name string UI名称 - 只读
---@field parent UIManager.ECanvas? 父亲节点 - 只读
---@field children UIManager.ArrayReadOnly<UIManager.ECanvas> 子节点列表 - 只读
---@field protected __protected_id ECanvas 受保护的id值
---@field protected __protected_name string 受保护的UI名称
---@field protected __protected_parent UIManager.ECanvas 受保护的父亲节点
---@field protected __protected_children UIManager.Array<UIManager.ECanvas> 受保护的子节点列表
---@field new fun(self: UIManager.ECanvas, _node: ECanvas, _name: string)
---@field wait fun(self: UIManager.ECanvas, _interval: integer): UIManager.Promise<UIManager.ECanvas>
local ECanvas = UIManager.Class("UIManager.ECanvas")
local nodes_list = UIManager.nodes_list

---@param _node ECanvas
---@param _name string
function ECanvas:init(_node, _name)
    if nodes_list[_node] then
        nodes_list[_node] = nil
    end
    nodes_list[_node] = self
    self.__protected_name = _name
    self.__protected_parent = nil
    self.__protected_id = _node

    local array = UIManager.Array() --[[@as UIManager.Array<UIManager.ECanvas>]]
    self.__protected_children = array
    self.__protected_read_only_children = UIManager.ArrayReadOnly(array)
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
