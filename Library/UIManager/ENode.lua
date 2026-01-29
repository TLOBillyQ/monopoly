---@class UIManager.ENode : Class
---@field __name "UIManager.ENode"
---@field id ENode ID值 - 只读
---@field name string UI名称 - 只读
---@field parent UIManager.ENode? 父亲节点 - 只读
---@field children ArrayReadOnly<UIManager.ENode> 子节点列表 - 只读
---@field visible boolean 是否可见
---@field disabled boolean 是否禁用
---@field custom_data table 自定义数据
---@field client_data table<RoleID, table> 客户端数据
---@field protected __protected_id ENode 受保护的id值
---@field protected __protected_name string 受保护的UI名称
---@field protected __protected_parent UIManager.ENode 受保护的父亲节点
---@field protected __protected_children Array<UIManager.ENode> 受保护的子节点列表
---@field protected __protected_visible boolean 受保护的是否可见
---@field protected __protected_disabled boolean 受保护的是否禁用
---@field protected __protected_custom_data table<RoleID, table> 受保护的自定义数据
---@field protected data table 被保护的数据
---@field new fun(self: UIManager.ENode, _node: ENode, _name: string)
local ENode = Class("UIManager.ENode")
local nodes_list = UIManager.nodes_list
local allroles = UIManager.allroles

local event_handlers = UIManager.event_handlers

function ENode.__custom_index(tbl, key)
    if string.sub(key, 1, 12) == "__protected_" then
        local role = UIManager.client_role
        if role then
            local client_data = rawget(tbl, "client_data")
            local data = client_data[role.get_roleid()]
            if not data then
                return client_data[-1][key]
            end
            if not data[key] then
                return client_data[-1][key]
            end
            return data[key]
        else
            return rawget(tbl, "client_data")[-1][key]
        end
    end
end

function ENode.__new_custom_index(tbl, key, value)
    if string.sub(key, 1, 12) == "__protected_" then
        local role = UIManager.client_role
        if role then
            local client_data = rawget(tbl, "client_data")
            if not client_data[role.get_roleid()] then
                client_data[role.get_roleid()] = {}
            end
            local data = client_data[role.get_roleid()]
            data[key] = value
        else
            local client_data = rawget(tbl, "client_data")
            client_data[-1][key] = value
        end
        return
    end
    rawset(tbl, key, value)
end

---@param _node ENode
---@param _name string
function ENode:init(_node, _name)
    if nodes_list[_node] then
        nodes_list[_node] = nil
    end
    nodes_list[_node] = self
    self.client_data = { [-1] = {} }
    self.data = {}
    self.__protected_custom_data = {}
    self.__protected_name = _name
    self.__protected_parent = nil
    self.__protected_id = _node

    local array = UIManager.Array:new() --[[@as Array<UIManager.ENode>]]
    self.__protected_children = array
    self.__protected_read_only_children = UIManager.ArrayReadOnly:new(array)
end

function ENode:__init_children()
    for idx, node in ipairs(GameAPI.get_eui_children(self.id)) do
        local uinode = nodes_list[node] --[[@as UIManager.ENode]]
        uinode.__protected_parent = self
        self.__protected_children:append(uinode)
    end
end

function ENode:__get_children()
    return self.__protected_read_only_children
end

function ENode:__set_children(value)
    warn(("attempt to set a read-only value field 'children' of '%s'"):format(self.__protected_name))
end

function ENode:__get_custom_data()
    return self.__protected_custom_data
end

function ENode:__set_custom_data(value)
    self.__protected_custom_data = value
end

function ENode:__get_parent()
    return self.__protected_parent
end

function ENode:__set_parent(value)
    warn(("attempt to set a read-only value field 'parent' of '%s'"):format(self.__name))
end

function ENode:__get_name()
    return self.__protected_name
end

function ENode:__set_name(value)
    warn(("attempt to set a read-only value field 'name' of '%s'"):format(self.__name))
end

function ENode:__get_id()
    return self.__protected_id
end

function ENode:__set_id(value)
    warn(("attempt to set a read-only value field 'id' of '%s'"):format(self.__name))
end

function ENode:__get_visible()
    return self.__protected_visible
end

function ENode:__set_visible(value)
    self.__protected_visible = value
    self:__update_visible()
end

function ENode:__update_visible()
    if UIManager.client_role then
        UIManager.client_role.set_node_visible(self.__protected_id, self.__protected_visible)
    else
        for _, role in ipairs(allroles) do
            role.set_node_visible(self.__protected_id, self.__protected_visible)
        end
    end
end

function ENode:__get_disabled()
    return self.__protected_disabled
end

function ENode:__set_disabled(value)
    self.__protected_disabled = value
    self:__update_disabled()
end

function ENode:__update_disabled()
    if UIManager.client_role then
        UIManager.client_role.set_node_touch_enabled(self.__protected_id, not self.__protected_disabled)
    else
        for _, role in ipairs(allroles) do
            role.set_node_touch_enabled(self.__protected_id, not self.__protected_disabled)
        end
    end
end

-- 根据名称查询第一个节点
---@param name string
---@return UIManager.ENodeUnion?
function ENode:get_first_node_by_name(name)
    local eui_id = GameAPI.get_eui_child_by_name(self.id, name)
    local status, node = pcall(UIManager.query_node_by_id, eui_id) --[[@cast node UIManager.ENodeUnion]]
    return status and node or nil
end

-- 根据名称查询节点
---@param name string
---@return UIManager.ENodeUnion[] | {[1]: nil}
function ENode:query_nodes_by_name(name)
    local list = {}
    self.children:forEach(function(child)
        if child.name == name then
            table.insert(list, child)
        end
    end)
    return list
end

-- 根据名称查询第一个节点（深度优先）
---@param name string
---@return UIManager.ENodeUnion?
function ENode:get_first_node_by_name_dfs(name)
    local node = self:get_first_node_by_name(name)
    if node then
        return node
    end
    for i = 1, self.children.length do
        local child = self.children[i]
        local dfs_node = child:get_first_node_by_name_dfs(name)
        if dfs_node then
            return dfs_node
        end
    end
    return nil
end

-- 根据名称查询节点（深度优先）
---@param name string
---@return UIManager.ENodeUnion[] | {[1]: nil}
function ENode:query_nodes_by_name_dfs(name)
    local list = {}
    ---@param node UIManager.ENode
    ---@return boolean
    local function dfs(node)
        local nodes = node:query_nodes_by_name(name)
        if nodes[1] then
            table.insert(list, nodes[1])
            return true
        end
        for i = 1, node.children.length do
            local child = node.children[i]
            local status = dfs(child)
            if status then
                return true
            end
        end
        return false
    end
    dfs(self)
    return list
end

-- 在事件回调中为每个玩家设置属性
---@param key string
---@param value any
function ENode:for_all_roles(key, value)
    local method = self["__set_" .. key]
    if not method then return end
    local client_role = UIManager.client_role
    UIManager.client_role = nil
    method(self, value)
    UIManager.client_role = client_role
end

-- 设置自定义属性
---@param key string
---@param value any
function ENode:set_attribute(key, value)
    self.data[key] = value
end

-- 获取自定义属性
---@param key string
---@return any
function ENode:get_attribtue(key)
    return self.data[key]
end

---@param _event string
---@param _callback fun(data: {role: Role, target: UIManager.ENode, listener: UIManager.Listener})
---@return UIManager.Listener
function ENode:listen(_event, _callback)
    local listener = UIManager.Listener:new()
    local handler = event_handlers[_event]
    local trigger
    if not handler then
        event_handlers[_event] = {}
        handler = event_handlers[_event]

        ---@param data {eui_node_id: ENode, role: Role}
        trigger = LuaAPI.global_register_custom_event(_event, function(_, _, data)
            local handler_data = event_handlers[_event][data.eui_node_id]
            if handler_data and handler_data.callbacks and not handler_data.node._disabled then
                UIManager.client_role = data.role
                for _, callback in ipairs(handler_data.callbacks) do
                    callback({
                        role = data.role,
                        target = handler_data.node,
                        listener = listener
                    })
                end
                UIManager.client_role = nil
            end
        end)
        handler.trigger = trigger
    end

    local handler_data = handler[self.__protected_id]
    if not handler_data then
        handler[self.__protected_id] = {
            callbacks = { _callback },
            node = self
        }
    else
        table.insert(handler_data.callbacks, _callback)
    end

    -- 设置 listener 的相关信息，用于后续删除
    listener._event = _event
    listener._callback = _callback
    listener._node_id = self.__protected_id

    return listener
end

return ENode
