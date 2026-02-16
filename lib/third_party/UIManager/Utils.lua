---@class UIManager
---@field client_role Role?
UIManager = {}

UIManager.allroles = ALLROLES
UIManager.nodes_list = {} --[[@as table<ENode, UIManager.ENode?>]]
UIManager.name_node_mapping = {} --[[@as table<string, UIManager.ENode[]?> ]]
---@type 
--- {
---     [string]: {
---         trigger: integer,
---         [ENode]: {
---             callbacks: fun(data: {
---                 role: Role,
---                 target: UIManager.ENodeUnion,
---                 listener: UIManager.Listener
---             })[],
---             node: UIManager.ENodeUnion
---         }?
---     }?
--- }
UIManager.event_handlers = {}

UIManager.ECanvas = require "lib.third_party.UIManager.ECanvas"
UIManager.ENode = require "lib.third_party.UIManager.ENode"
UIManager.ELabel = require "lib.third_party.UIManager.ELabel"
UIManager.EButton = require "lib.third_party.UIManager.EButton"
UIManager.EImage = require "lib.third_party.UIManager.EImage"
UIManager.EProgressbar = require "lib.third_party.UIManager.EProgressbar"
UIManager.EInputField = require "lib.third_party.UIManager.EInputField"
UIManager.Builder = require "lib.third_party.UIManager.Builder"
UIManager.Listener = require "lib.third_party.UIManager.Listener"
UIManager.Array = require "lib.third_party.UIManager.Array"
UIManager.ArrayReadOnly = require "lib.third_party.UIManager.ArrayReadOnly"

---@alias UIManager.ENodeUnion UIManager.ENode | UIManager.ELabel | UIManager.EImage | UIManager.EButton | UIManager.EProgressbar | UIManager.EInputField

---@enum UIManager.ENodeType
UIManager.ENodeType = {
    ELabel = "UIManager.ELabel",
    EButton = "UIManager.EButton",
    EImage = "UIManager.EImage",
    ENode = "UIManager.ENode",
}

-- 通过名称查询第一个节点
---@param _name string
---@return UIManager.ENodeUnion?
UIManager.get_first_node_by_name = function(_name)
    return UIManager.name_node_mapping[_name] and UIManager.name_node_mapping[_name][1] or nil
end

-- 通过名称查询节点数组
---@param _name string
---@return UIManager.ENodeUnion[]
UIManager.query_nodes_by_name = function(_name)
    return UIManager.name_node_mapping[_name] or {}
end

-- 通过ID查询节点
---@param _id ENode
---@return UIManager.ENodeUnion?
UIManager.query_node_by_id = function(_id)
    return UIManager.nodes_list[_id]
end

---@enum UIManager.EVENT
UIManager.EVENT = {
    CLICK = "CLICK"
}

---@generic T
---@param _node UIManager.ENodeUnion?
---@param _type `T`
---@return TypeGuard<T>
UIManager.typeof = function(_node, _type)
    return _node and _node.__name == _type or false
end

return UIManager
