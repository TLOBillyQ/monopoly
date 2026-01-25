---@class UIManager.Listener : ClassUtil
---@field id integer
---@field _event string 事件名称
---@field _callback function 回调函数
---@field _node_id ENode 节点ID
---@field _trigger integer 触发器
local Listener = UIManager.Class("UIManager.Listener")
local id = 1
local ListenerMapping = {}
local event_handlers = UIManager.event_handlers

function Listener:init()
    self.id = id
    ListenerMapping[id] = self
    id = id + 1
end

function Listener:destroy()
    -- 获取对应事件的处理器
    local handler = event_handlers[self._event]

    if handler then
        local handler_data = handler[self._node_id]
        if handler_data and handler_data.callbacks then
            -- 找到并删除对应的 callback
            for i, callback in ipairs(handler_data.callbacks) do
                if callback == self._callback then
                    table.remove(handler_data.callbacks, i)
                    break
                end
            end

            -- 如果 callbacks 为空，删除 handler_data
            if #handler_data.callbacks == 0 then
                handler[self._node_id] = nil
            end

            -- 检查是否还有其他节点的处理器，如果没有则删除整个事件处理器
            local has_handlers = false
            for key in pairs(handler) do
                if key ~= "trigger" then
                    has_handlers = true
                    break
                end
            end

            if not has_handlers then
                LuaAPI.global_unregister_custom_event(handler.trigger)
                event_handlers[self._event] = nil
            end
        end
    end
    ListenerMapping[self.id] = nil
end

---@param _id integer
---@return UIManager.Listener
function Listener.query(_id)
    return ListenerMapping[_id]
end

return Listener
