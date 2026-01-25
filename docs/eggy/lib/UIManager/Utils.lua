---@class UIManager
---@field client_role Role?
UIManager = {}

UIManager.allroles = GameAPI.get_all_valid_roles()
UIManager.nodes_list = {} --[[@as table<ENode, UIManager.ENode?>]]
UIManager.name_node_mapping = {} --[[@as table<string, UIManager.ENode[]?> ]]
---@type
--- {
---     [string]: {
---         ["trigger"]: integer,
---         [string]: {
---             callbacks: fun(data: {
---                 role: Role,
---                 target: UIManager.ENodeUnion,
---                 listener: UIManager.Listener
---             })[],
---             node: UIManager.ENodeUnion,
---             listener_id: integer,
---         }?
---     }?
--- }
UIManager.event_handlers = {}



---@enum UIManager.EVENTS
UIManager.EVENTS = {
    BUILDER_COMPLETE_ONE_BATCH = "UIMANAGER:BUILDER_COMPLETE_ONE_BATCH",
    BUILDER_INIT_DONE = "UIMANAGER:BUILDER_INIT_DONE",
}


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

---@class UIManager.Frameout
---@field frame integer 当前帧数
---@field left_count integer 剩余次数
---@field destroy fun() 销毁计时器
---@field pause fun() 暂停计时器
---@field resume fun() 恢复计时器

---@param interval integer 计时间隔（单位：帧）
---@param callback fun(frameout: UIManager.Frameout) 回调函数
---@param count integer? 重复次数，-1为无限次
---@param immediately boolean? 是否立即执行回调
UIManager.set_frame_out = function(interval, callback, count, immediately)
    count = count or 1 --[[@as integer]]
    local frameout = {
        frame = 0,
        left_count = count,
        status = true
    }
    local decorator = function()
        frameout.frame = frameout.frame + interval
        if count > 0 then
            frameout.left_count = frameout.left_count - 1
        end
        callback(frameout)
        if frameout and count > 0 and (frameout.left_count == 0) then
            frameout.destroy()
        end
    end
    local handler = LuaAPI.global_register_trigger_event(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(interval) / 30.0 }, decorator
    )
    ---销毁计时器
    frameout.destroy = function()
        LuaAPI.global_unregister_trigger_event(handler)
    end
    ---暂停计时器
    frameout.pause = function()
        LuaAPI.global_unregister_trigger_event(handler)
        frameout.status = false
    end
    ---恢复计时器
    frameout.resume = function()
        handler = LuaAPI.global_register_trigger_event(
            { EVENT.REPEAT_TIMEOUT, math.tofixed(interval) / 30.0 }, decorator
        )
        frameout.status = true
    end
    if immediately then
        decorator()
    end
    return frameout
end
require 'UIManager.ClassUtils'
UIManager.Class = Class
UIManager.ENode = require 'UIManager.ENode'
UIManager.ECanvas = require 'UIManager.ECanvas'
UIManager.ELabel = require 'UIManager.ELabel'
UIManager.EButton = require 'UIManager.EButton'
UIManager.EImage = require 'UIManager.EImage'
UIManager.EProgressbar = require 'UIManager.EProgressbar'
UIManager.EInputField = require 'UIManager.EInputField'
UIManager.Builder = require 'UIManager.Builder'
UIManager.Listener = require 'UIManager.Listener'
UIManager.Array = require 'UIManager.Array'
UIManager.Promise = require 'UIManager.Promise'
UIManager.ArrayReadOnly = require 'UIManager.ArrayReadOnly'

---@alias UIManager.ENodeUnion UIManager.ENode | UIManager.ELabel | UIManager.EImage

---@enum UIManager.ENodeType
UIManager.ENodeType = {
    ELabel = "UIManager.ELabel",
    EButton = "UIManager.EButton",
    EImage = "UIManager.EImage",
    ENode = "UIManager.ENode",
}