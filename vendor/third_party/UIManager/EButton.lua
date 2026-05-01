---@class UIManager.EButton : UIManager.ENode
---@field __name "UIManager.EButton"
---@field text string 按钮文本
---@field text_color Color 文本颜色，Hex值，例如0xFF0000是红色
---@field font_size Fixed 字体大小
---@field normal_image ImageKey 常态图片
---@field pressed_image ImageKey 按下图片
---@field protected __protected_text string 受保护的文本内容
---@field protected __protected_text_color Color 受保护的文本颜色
---@field protected __protected_font_size Fixed 受保护的字体大小
---@field protected __protected_normal_image ImageKey 常态图片
---@field protected __protected_pressed_image ImageKey 按下图片
local EButton = Class("UIManager.EButton", UIManager.ENode)
local allroles = UIManager.allroles

local function _host_market_debug(...)
    local text = "[MarketHostDebug] " .. table.concat({ ... }, " ")
    if type(GlobalAPI) == "table" and type(GlobalAPI.warning) == "function" then
        pcall(GlobalAPI.warning, text)
        return
    end
    if type(print) == "function" then
        pcall(print, text)
    end
end

local function _safe_role_id(role)
    if not role or type(role.get_roleid) ~= "function" then
        return nil
    end
    local ok, role_id = pcall(role.get_roleid, role)
    if not ok then
        return nil
    end
    return role_id
end

local function _is_market_button(button)
    local name = button and button.__protected_name or nil
    return type(name) == "string" and string.match(name, "^黑市") ~= nil
end

local function _log_market_button_call(button, method_name, extra)
    if not _is_market_button(button) then
        return
    end
    _host_market_debug(
        method_name,
        "node=" .. tostring(button.__protected_name),
        "id=" .. tostring(button.__protected_id),
        extra
    )
end

---@param _node ENode
---@param _name string
function EButton:init(_node, _name)
    UIManager.ENode.init(self, _node, _name)
    self.__protected_text = ""
end

function EButton:__set_disabled(value)
    self.__protected_disabled = value
    self:__update_disabled()
end

function EButton:__update_disabled()
    if UIManager.client_role then
        _log_market_button_call(self, "Role.set_node_touch_enabled", "touch_enabled=" .. tostring(not self.__protected_disabled) .. " role_id=" .. tostring(_safe_role_id(UIManager.client_role)))
        UIManager.client_role.set_node_touch_enabled(self.__protected_id, not self.__protected_disabled)
        _log_market_button_call(self, "Role.set_button_enabled", "enabled=" .. tostring(not self.__protected_disabled) .. " role_id=" .. tostring(_safe_role_id(UIManager.client_role)))
        UIManager.client_role.set_button_enabled(self.__protected_id, not self.__protected_disabled)
    else
        for _, role in ipairs(allroles) do
            _log_market_button_call(self, "Role.set_node_touch_enabled", "touch_enabled=" .. tostring(not self.__protected_disabled) .. " role_id=" .. tostring(_safe_role_id(role)))
            role.set_node_touch_enabled(self.__protected_id, not self.__protected_disabled)
            _log_market_button_call(self, "Role.set_button_enabled", "enabled=" .. tostring(not self.__protected_disabled) .. " role_id=" .. tostring(_safe_role_id(role)))
            role.set_button_enabled(self.__protected_id, not self.__protected_disabled)
        end
    end
end

function EButton:__get_text()
    return self.__protected_text
end

function EButton:__set_text(value)
    self.__protected_text = value
    self:__update_text()
end

-- 更新文本数据
function EButton:__update_text()
    if UIManager.client_role then
        _log_market_button_call(self, "Role.set_button_text", "text=" .. tostring(self.__protected_text) .. " role_id=" .. tostring(_safe_role_id(UIManager.client_role)))
        UIManager.client_role.set_button_text(self.__protected_id, self.__protected_text)
    else
        for _, role in ipairs(allroles) do
            _log_market_button_call(self, "Role.set_button_text", "text=" .. tostring(self.__protected_text) .. " role_id=" .. tostring(_safe_role_id(role)))
            role.set_button_text(self.__protected_id, self.__protected_text)
        end
    end
end

function EButton:__get_text_color()
    return self.__protected_text_color
end

function EButton:__set_text_color(value)
    self.__protected_text_color = value
    self:__update_text_color()
end

-- 更新文本颜色
function EButton:__update_text_color()
    if UIManager.client_role then
        UIManager.client_role.set_button_text_color(self.__protected_id, self.__protected_text_color)
    else
        for _, role in ipairs(allroles) do
            role.set_button_text_color(self.__protected_id, self.__protected_text_color)
        end
    end
end

function EButton:__get_font_size()
    return self.__protected_font_size
end

function EButton:__set_font_size(value)
    self.__protected_font_size = math.tofixed(value)
    self:__update_font_size()
end

-- 更新字体大小
function EButton:__update_font_size()
    if UIManager.client_role then
        UIManager.client_role.set_button_font_size(self.__protected_id, self.__protected_font_size)
    else
        for _, role in ipairs(allroles) do
            role.set_button_font_size(self.__protected_id, self.__protected_font_size)
        end
    end
end

return EButton
