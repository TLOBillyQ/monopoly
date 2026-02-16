---@class UIManager.Builder : Class
local Builder = Class("UIManager.Builder")
local nodes_list = UIManager.nodes_list
local name_node_mapping = UIManager.name_node_mapping

---@alias configName string
---@alias configType string

---@class BuilderConfig
---@field [1] configName 名称
---@field [2] configType 类型

---@async
---@param _config_list table<ENode, BuilderConfig>
function Builder:init(_config_list)
    if next(_config_list) == nil then
        error("Empty config!")
    end
    UIManager.config_list = _config_list
    -- 第一阶段：创建所有节点，但不建立父子关系
    for id, config in pairs(_config_list) do
        self:build_node(id, config)
    end

    -- 第二阶段：建立所有节点的父子关系
    for id, _ in pairs(_config_list) do
        local node = nodes_list[id]
        if node then
            node:__init_children()
        end
    end
end

---@param id ENode
---@param _config BuilderConfig
function Builder:build_node(id, _config)
    if nodes_list[id] then
        return
    end
    local buildName = _config[1]
    local buildType = _config[2]
    local buildFunc = UIManager[buildType] --[[@as UIManager.ENode?]]
    local uinode
    if buildFunc then
        uinode = buildFunc:new(id, buildName)
    else
        uinode = UIManager.ENode:new(id, buildName)
    end

    local name_node = name_node_mapping[buildName]
    if not name_node then
        name_node_mapping[buildName] = { uinode }
    else
        table.insert(name_node, uinode)
    end
    nodes_list[id] = uinode
end

return Builder
