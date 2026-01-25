---@class UIManager.Builder : ClassUtil
---@field private progress Fixed 进度
---@field private total integer 总量
---@field private processd integer 已处理量
local Builder = UIManager.Class("UIManager.Builder")
local nodes_list = UIManager.nodes_list
local name_node_mapping = UIManager.name_node_mapping

---@alias configName string
---@alias configType string

---@class BuildConfig
---@field [1] configName 名称
---@field [2] configType 类型

---@private
---@param _config_list {[ENode]: BuildConfig, length: integer} 配置列表
---@param batch_size? integer 每批处理数量，必须大于1，否则视为不分批处理
---@param batch_cost? integer 每批处理间隔，单位帧，默认为1
function Builder:init(_config_list, batch_size, batch_cost)
    if next(_config_list) == nil then
        error("Empty config!")
    end
    UIManager.config_list = _config_list
    self.processd = 0
    self.total = _config_list.length
    self:pre_building(_config_list, batch_size, batch_cost, function()
        self:post_building(_config_list, batch_size, batch_cost)
    end)
end

---@private
---@param _config_list {[ENode]: BuildConfig, length: integer} 配置列表
---@param batch_size? integer
---@param batch_cost? integer
---@param _callback fun() 回调
function Builder:pre_building(_config_list, batch_size, batch_cost, _callback)
    if
        (not batch_size) or
        (batch_size <= 1)
    then
        for id, config in pairs(_config_list) do
            self:build_node(id, config)
        end
        return
    end
    batch_cost = batch_cost or 1
    local key = nil
    UIManager.set_frame_out(1, function(frameout)
        for _ = 1, batch_size do
            key = next(_config_list, key)
            if key == "length" then
                key = next(_config_list, key)
            end
            if key then
                local config = _config_list[key]
                self:build_node(key, config)
                self.processd = self.processd + 1
            else
                frameout:destroy()
                _callback()
                break
            end
        end
        LuaAPI.global_send_custom_event(UIManager.EVENTS.BUILDER_COMPLETE_ONE_BATCH, {
            processd = self.processd,
            total = self.total
        })
    end, -1, true)
end

---@private
---@param _config_list {[ENode]: BuildConfig, length: integer} 配置列表
---@param batch_size? integer
---@param batch_cost? integer
function Builder:post_building(_config_list, batch_size, batch_cost)
    if
        (not batch_size) or
        (batch_size <= 1)
    then
        for id, _ in pairs(_config_list) do
            local node = nodes_list[id]
            if node then
                node:__init_children()
            end
        end
        return
    end
    batch_cost = batch_cost or 1
    local key = nil
    UIManager.set_frame_out(1, function(frameout)
        for _ = 1, batch_size do
            key = next(_config_list, key)
            if key == "length" then
                key = next(_config_list, key)
            end
            if key then
                local node = nodes_list[key]
                if node then
                    node:__init_children()
                end
                self.processd = self.processd + 1
            else
                frameout:destroy()
                self:done_building()
                break
            end
        end
        LuaAPI.global_send_custom_event(UIManager.EVENTS.BUILDER_COMPLETE_ONE_BATCH, {
            processd = self.processd,
            total = self.total
        })
    end, -1, true)
end

function Builder:done_building()
    LuaAPI.global_send_custom_event(UIManager.EVENTS.BUILDER_INIT_DONE, {})
end

---@private
---@param id ENode
---@param _config BuildConfig
function Builder:build_node(id, _config)
    if nodes_list[id] then
        return
    end
    local buildName = _config[1]
    local buildType = _config[2]
    local buildFunc = UIManager[ buildType --[[@as string]] ] --[[@as UIManager.ENode?]]
    local uinode
    if buildFunc then
        uinode = buildFunc(id, buildName)
    else
        uinode = UIManager.ENode(id, buildName)
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
