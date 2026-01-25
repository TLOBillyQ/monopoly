---@class UIManager.EProgressbar : UIManager.ENode
---@field __name "UIManager.EProgressbar"
---@field value integer 进度值
---@field max_value integer 最大进度值
---@field min_value integer 最小进度值
---@field transition_time Fixed 样式变化时间
---@field protected __protected_value integer 进度值
---@field protected __protected_max_value integer 最大进度值
---@field protected __protected_min_value integer 最小进度值
---@field protected __protected_transition_time Fixed 受保护的样式变化时间
local EProgressbar = UIManager.Class("UIManager.EProgressbar", UIManager.ENode)
local allroles = UIManager.allroles

---@param _node ENode
---@param _name string
function EProgressbar:init(_node, _name)
    UIManager.ENode.init(self, _node, _name)
    self.__protected_text = ""
end

function EProgressbar:__get_value()
    return self.__protected_value
end

function EProgressbar:__set_value(value)
    self.__protected_value = value
    self:__update_value()
end

-- 更新进度值
function EProgressbar:__update_value()
    if UIManager.client_role then
        UIManager.client_role.set_progressbar_transition(self.__protected_id, self.__protected_value, self.__protected_transition_time)
    else
        for _, role in ipairs(allroles) do
            role.set_progressbar_transition(self.__protected_id, self.__protected_value, self.__protected_transition_time)
        end
    end
end

function EProgressbar:__get_max_value()
    return self.__protected_max_value
end

function EProgressbar:__set_max_value(value)
    self.__protected_max_value = value
    self:__update_max_value()
end

-- 更新最大进度值
function EProgressbar:__update_max_value()
    if UIManager.client_role then
        UIManager.client_role.set_progressbar_max(self.__protected_id, self.__protected_max_value)
    else
        for _, role in ipairs(allroles) do
            role.set_progressbar_max(self.__protected_id, self.__protected_max_value)
        end
    end
end

function EProgressbar:__get_min_value()
    return self.__protected_min_value
end

function EProgressbar:__set_min_value(value)
    self.__protected_min_value = value
    self:__update_min_value()
end

-- 更新最小进度值
function EProgressbar:__update_min_value()
    if UIManager.client_role then
        UIManager.client_role.set_progressbar_min(self.__protected_id, self.__protected_min_value)
    else
        for _, role in ipairs(allroles) do
            role.set_progressbar_min(self.__protected_id, self.__protected_min_value)
        end
    end
end

function EProgressbar:__get_transition_time()
    return self.__protected_transition_time
end

function EProgressbar:__set_transition_time(value)
    self.__protected_transition_time = value
end

return EProgressbar
