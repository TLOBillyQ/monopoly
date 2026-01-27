---@class Frameout
---@field frame integer 当前帧数
---@field left_count integer 剩余次数
---@field execute_count integer 已执行次数
---@field status boolean 状态
---@field destroy fun() 销毁计时器
---@field pause fun() 暂停计时器
---@field resume fun() 恢复计时器

---@param interval integer 计时间隔（单位：帧）
---@param callback fun(frameout: Frameout) 回调函数
---@param count integer? 重复次数，-1为无限次，默认1次
---@param immediately boolean? 是否立即执行回调
SetFrameOut = function(interval, callback, count, immediately)
    count = count or 1 --[[@as integer]]
    local frameout = {} --[[@cast frameout Frameout]]
    setmetatable(frameout, {
        __index = function(t, k)
            if k == "execute_count" then
                return count - frameout.left_count
            end
        end
    })
    frameout.frame = 0
    frameout.left_count = count
    frameout.status = true --[[@as boolean]]
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
        { EVENT.REPEAT_TIMEOUT, math.tofixed(interval + 1) / 30.0 }, decorator
    )
    ---销毁计时器
    frameout.destroy = function()
        LuaAPI.global_unregister_trigger_event(handler)
        frameout.pause = nil
        frameout.resume = nil
        frameout.left_count = nil
        frameout.frame = nil
        frameout.execute_count = nil
        frameout.status = nil
        frameout.destroy = nil
    end
    ---暂停计时器
    frameout.pause = function()
        if frameout.status then
            LuaAPI.global_unregister_trigger_event(handler)
            frameout.status = false
        end
    end
    ---恢复计时器
    frameout.resume = function()
        if not frameout.status then
            handler = LuaAPI.global_register_trigger_event(
                { EVENT.REPEAT_TIMEOUT, math.tofixed(interval) / 30.0 }, decorator
            )
            frameout.status = true
        end
    end
    if immediately then
        decorator()
    end
    return frameout
end
