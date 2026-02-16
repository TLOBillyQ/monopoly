---@class UIManager.EImage : UIManager.ENode
---@field __name "UIManager.EImage"
---@field image_color Color 图片颜色
---@field image_texture ImageKey 图片预设
---@field transition_time Fixed 样式变化时间
---@field protected __protected_image_color Color 图片颜色
---@field protected __protected_image_texture ImageKey 图片预设
---@field protected __protected_transition_time Fixed 受保护的样式变化时间
local EImage = Class("UIManager.EImage", UIManager.ENode)
local allroles = UIManager.allroles

---@param _node ENode
---@param _name string
function EImage:init(_node, _name)
    UIManager.ENode.init(self, _node, _name)
    self.__protected_image_color = 0xffffff
    self.__protected_image_texture = -1
    self.__protected_transition_time = 0.0
end

function EImage:__get_image_color()
    return self.__protected_image_color
end

function EImage:__set_image_color(value)
    self.__protected_image_color = value
    self:__update_image_color()
end

-- 更新图片颜色
function EImage:__update_image_color()
    if UIManager.client_role then
        UIManager.client_role.set_image_color(self.__protected_id, self.__protected_image_color,
            self.__protected_transition_time)
    else
        for _, role in ipairs(allroles) do
            role.set_image_color(self.__protected_id, self.__protected_image_color, self.__protected_transition_time)
        end
    end
end

function EImage:__get_image_texture()
    return self.__protected_image_texture
end

function EImage:__set_image_texture(value)
    self.__protected_image_texture = value
    self:__update_image_texture()
end

-- 更新图片预设
function EImage:__update_image_texture()
    self:__apply_image_texture(false)
end

function EImage:__apply_image_texture(reset_size)
    local should_reset_size = reset_size == true
    if UIManager.client_role then
        UIManager.client_role.set_image_texture_by_key_with_auto_resize(self.__protected_id,
            self.__protected_image_texture, should_reset_size)
    else
        for _, role in ipairs(allroles) do
            role.set_image_texture_by_key_with_auto_resize(self.__protected_id, self.__protected_image_texture,
                should_reset_size)
        end
    end
end

function EImage:__get_transition_time()
    return self.__protected_transition_time
end

function EImage:__set_transition_time(value)
    self.__protected_transition_time = math.tofixed(value)
end

function EImage:set_texture_keep_size(image_key)
    self.__protected_image_texture = image_key
    self:__apply_image_texture(false)
end

function EImage:set_texture_native_size(image_key)
    self.__protected_image_texture = image_key
    self:__apply_image_texture(true)
end

function EImage:reset_size()
    self:__apply_image_texture(true)
end

return EImage
