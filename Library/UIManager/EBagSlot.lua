---@class UIManager.EBagSlot : UIManager.ENode
---@field __name "UIManager.EBagSlot"
---@field related_lifeentity LifeEntity 绑定的LifeEntity
---@field protected __protected_related_lifeentity LifeEntity 受保护的绑定的LifeEntity
local EBagSlot = Class("UIManager.EBagSlot", UIManager.ENode)
local allroles = UIManager.allroles

---@param _node ENode
---@param _name string
function EBagSlot:init(_node, _name)
    UIManager.ENode.init(self, _node, _name)
    self.__protected_related_lifeentity = nil
end

function EBagSlot:__get_related_lifeentity()
    return self.__protected_related_lifeentity
end

function EBagSlot:__set_related_lifeentity(value)
    self.__protected_related_lifeentity = value
    self:__update_related_lifeentity()
end

-- 更新绑定的LifeEntity
function EBagSlot:__update_related_lifeentity()
    if UIManager.client_role then
        UIManager.client_role.set_bagslot_related_lifeentity(self.__protected_id, self.__protected_related_lifeentity)
    else
        for _, role in ipairs(allroles) do
            role.set_bagslot_related_lifeentity(self.__protected_id, self.__protected_related_lifeentity)
        end
    end
end

return EBagSlot
