---@class UIManager.EInputField : UIManager.ENode
---@field __name "UIManager.EInputField"
---@field text string 文本内容
---@field text_color Color 文本颜色，Hex值，例如0xFF0000是红色
---@field protected __protected_text string 受保护的文本内容
local EInputField = UIManager.Class("UIManager.EInputField", UIManager.ENode)
local allroles = UIManager.allroles

---@param _node ENode
---@param _name string
function EInputField:init(_node, _name)
    UIManager.ENode.init(self, _node, _name)
    self.__protected_text = ""
end

function EInputField:__get_text()
    return self.__protected_text
end

function EInputField:__set_text(value)
    self.__protected_text = value
    self:__update_text()
end

-- 更新文本数据
function EInputField:__update_text()
    if UIManager.client_role then
        UIManager.client_role.set_input_field_text(self.__protected_id, self.__protected_text)
    else
        for _, role in ipairs(allroles) do
            role.set_input_field_text(self.__protected_id, self.__protected_text)
        end
    end
end

return EInputField
