---@class UIManager.ELabel : UIManager.ENode
---@field __name "UIManager.ELabel"
---@field text string 文本内容
---@field label_background_color Color 背景颜色
---@field label_background_opacity Fixed 背景不透明度
---@field text_color Color 文本颜色，Hex值，例如0xFF0000是红色
---@field transition_time Fixed 样式变化时间
---@field font_family FontKey 字体
---@field font_size integer 字体大小
---@field outline_color Color 描边颜色
---@field outline boolean 是否描边
---@field outline_opacity Fixed 描边不透明度
---@field outline_width Fixed 描边宽度
---@field shadow_color Color 阴影颜色
---@field shadow boolean 是否阴影
---@field shadow_x_offset Fixed 阴影x偏移
---@field shadow_y_offset Fixed 阴影y偏移
---@field protected __protected_text string 受保护的文本内容
---@field protected __protected_label_background_color Color 背景颜色
---@field protected __protected_label_background_opacity Fixed 背景不透明度
---@field protected __protected_text_color Color 受保护的文本颜色
---@field protected __protected_transition_time Fixed 受保护的样式变化时间
---@field protected __protected_font_family FontKey 字体
---@field protected __protected_font_size integer 字体大小
---@field protected __protected_outline_color Color 描边颜色
---@field protected __protected_outline boolean 是否描边
---@field protected __protected_outline_opacity Fixed 描边不透明度
---@field protected __protected_outline_width Fixed 描边宽度
---@field protected __protected_shadow_color Color 阴影颜色
---@field protected __protected_shadow boolean 是否阴影
---@field protected __protected_shadow_x_offset Fixed 阴影x偏移
---@field protected __protected_shadow_y_offset Fixed 阴影y偏移
local ELabel = UIManager.Class("UIManager.ELabel", UIManager.ENode)
local allroles = UIManager.allroles

---@param _node ENode
---@param _name string
function ELabel:init(_node, _name)
    UIManager.ENode.init(self, _node, _name)
    self.__protected_text = ""
    self.__protected_transition_time = 0.0
end

function ELabel:__get_text()
    return self.__protected_text
end

function ELabel:__set_text(value)
    self.__protected_text = value
    self:__update_text()
end

-- 更新文本数据
function ELabel:__update_text()
    if UIManager.client_role then
        UIManager.client_role.set_label_text(self.__protected_id, self.__protected_text)
    else
        for _, role in ipairs(allroles) do
            role.set_label_text(self.__protected_id, self.__protected_text)
        end
    end
end

function ELabel:__get_label_background_color()
    return self.__protected_label_background_color
end

function ELabel:__set_label_background_color(value)
    self.__protected_label_background_color = value
    self:__update_label_background_color()
end

-- 更新背景颜色
function ELabel:__update_label_background_color()
    if UIManager.client_role then
        UIManager.client_role.set_label_background_color(self.__protected_id, self.__protected_label_background_color,
            self.__protected_transition_time)
    else
        for _, role in ipairs(allroles) do
            role.set_label_background_color(self.__protected_id, self.__protected_label_background_color,
                self.__protected_transition_time)
        end
    end
end

function ELabel:__get_label_background_opactiy()
    return self.__protected_label_background_opactiy
end

function ELabel:__set_label_background_opactiy(value)
    self.__protected_label_background_opactiy = value
    self:__update_label_background_opactiy()
end

-- 更新背景不透明度
function ELabel:__update_label_background_opactiy()
    if UIManager.client_role then
        UIManager.client_role.set_label_background_opacity(self.__protected_id, self
            .__protected_label_background_opacity, self.__protected_transition_time)
    else
        for _, role in ipairs(allroles) do
            role.set_label_background_opacity(self.__protected_id, self.__protected_label_background_opacity,
                self.__protected_transition_time)
        end
    end
end

function ELabel:__get_text_color()
    return self.__protected_text_color
end

function ELabel:__set_text_color(value)
    self.__protected_text_color = value
    self:__update_text_color()
end

-- 更新文本颜色
function ELabel:__update_text_color()
    if UIManager.client_role then
        UIManager.client_role.set_label_color(self.__protected_id, self.__protected_text_color,
            self.__protected_transition_time)
    else
        for _, role in ipairs(allroles) do
            role.set_label_color(self.__protected_id, self.__protected_text_color, self.__protected_transition_time)
        end
    end
end

function ELabel:__get_transition_time()
    return self.__protected_transition_time
end

function ELabel:__set_transition_time(value)
    self.__protected_transition_time = math.tofixed(value)
end

function ELabel:__get_font_family()
    return self.__protected_font_family
end

function ELabel:__set_font_family(value)
    self.__protected_font_family = value
    self:__update_font_family()
end

-- 更新字体
function ELabel:__update_font_family()
    if UIManager.client_role then
        UIManager.client_role.set_label_font(self.__protected_id, self.__protected_font_family)
    else
        for _, role in ipairs(allroles) do
            role.set_label_font(self.__protected_id, self.__protected_font_family)
        end
    end
end

function ELabel:__get_font_size()
    return self.__protected_font_size
end

function ELabel:__set_font_size(value)
    self.__protected_font_size = math.tointeger(value)
    self:__update_font_size()
end

-- 更新字体大小
function ELabel:__update_font_size()
    if UIManager.client_role then
        UIManager.client_role.set_label_font_size(self.__protected_id, self.__protected_font_size,
            self.__protected_transition_time)
    else
        for _, role in ipairs(allroles) do
            role.set_label_font_size(self.__protected_id, self.__protected_font_size, self.__protected_transition_time)
        end
    end
end

function ELabel:__get_outline_color()
    return self.__protected_outline_color
end

function ELabel:__set_outline_color(value)
    self.__protected_outline_color = value
    self:__update_outline_color()
end

-- 更新描边颜色
function ELabel:__update_outline_color()
    if UIManager.client_role then
        UIManager.client_role.set_label_outline_color(self.__protected_id, self.__protected_outline_color)
    else
        for _, role in ipairs(allroles) do
            role.set_label_outline_color(self.__protected_id, self.__protected_outline_color)
        end
    end
end

function ELabel:__get_outline()
    return self.__protected_outline
end

function ELabel:__set_outline(value)
    self.__protected_outline = value
    self:__update_outline()
end

-- 更新是否描边
function ELabel:__update_outline()
    if UIManager.client_role then
        UIManager.client_role.set_label_outline_enabled(self.__protected_id, self.__protected_outline)
    else
        for _, role in ipairs(allroles) do
            role.set_label_outline_enabled(self.__protected_id, self.__protected_outline)
        end
    end
end

function ELabel:__get_outline_opacity()
    return self.__protected_outline_opacity
end

function ELabel:__set_outline_opacity(value)
    self.__protected_outline_opacity = math.tofixed(value)
    self:__update_outline_opacity()
end

-- 更新描边不透明度
function ELabel:__update_outline_opacity()
    if UIManager.client_role then
        UIManager.client_role.set_label_outline_opacity(self.__protected_id, self.__protected_outline_opacity)
    else
        for _, role in ipairs(allroles) do
            role.set_label_outline_opacity(self.__protected_id, self.__protected_outline_opacity)
        end
    end
end

function ELabel:__get_outline_width()
    return self.__protected_outline_width
end

function ELabel:__set_outline_width(value)
    self.__protected_outline_width = math.tofixed(value)
    self:__update_outline_width()
end

-- 更新描边宽度
function ELabel:__update_outline_width()
    if UIManager.client_role then
        UIManager.client_role.set_label_outline_width(self.__protected_id, self.__protected_outline_width)
    else
        for _, role in ipairs(allroles) do
            role.set_label_outline_width(self.__protected_id, self.__protected_outline_width)
        end
    end
end

function ELabel:__get_shadow_color()
    return self.__protected_shadow_color
end

function ELabel:__set_shadow_color(value)
    self.__protected_shadow_color = value
    self:__update_shadow_color()
end

-- 更新阴影颜色
function ELabel:__update_shadow_color()
    if UIManager.client_role then
        UIManager.client_role.set_label_shadow_color(self.__protected_id, self.__protected_shadow_color)
    else
        for _, role in ipairs(allroles) do
            role.set_label_shadow_color(self.__protected_id, self.__protected_shadow_color)
        end
    end
end

function ELabel:__get_shadow()
    return self.__protected_shadow
end

function ELabel:__set_shadow(value)
    self.__protected_shadow = value
    self:__update_shadow()
end

-- 更新是否阴影
function ELabel:__update_shadow()
    if UIManager.client_role then
        UIManager.client_role.set_label_shadow_enabled(self.__protected_id, self.__protected_shadow)
    else
        for _, role in ipairs(allroles) do
            role.set_label_shadow_enabled(self.__protected_id, self.__protected_shadow)
        end
    end
end

function ELabel:__get_shadow_x_offset()
    return self.__protected_shadow_x_offset
end

function ELabel:__set_shadow_x_offset(value)
    self.__protected_shadow_x_offset = math.tofixed(value)
    self:__update_shadow_x_offset()
end

-- 更新阴影x偏移
function ELabel:__update_shadow_x_offset()
    if UIManager.client_role then
        UIManager.client_role.set_label_shadow_x_offset(self.__protected_id, self.__protected_shadow_x_offset)
    else
        for _, role in ipairs(allroles) do
            role.set_label_shadow_x_offset(self.__protected_id, self.__protected_shadow_x_offset)
        end
    end
end

function ELabel:__get_shadow_y_offset()
    return self.__protected_shadow_y_offset
end

function ELabel:__set_shadow_y_offset(value)
    self.__protected_shadow_y_offset = math.tofixed(value)
    self:__update_shadow_y_offset()
end

-- 更新阴影y偏移
function ELabel:__update_shadow_y_offset()
    if UIManager.client_role then
        UIManager.client_role.set_label_shadow_y_offset(self.__protected_id, self.__protected_shadow_y_offset)
    else
        for _, role in ipairs(allroles) do
            role.set_label_shadow_y_offset(self.__protected_id, self.__protected_shadow_y_offset)
        end
    end
end

return ELabel
