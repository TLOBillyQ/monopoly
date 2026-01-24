local refs = require "refs"

local items = {}


items.init = function()

end

items.set_slot = function(role_id, slot_id, item_id)
    local slot_key = refs["道具槽位" .. tostring(slot_id)]
    local item_key = refs[tostring(item_id)]
    local role = GameAPI.get_role(role_id)
    role.set_image_texture_by_key_with_auto_resize(slot_key, item_key, false)
    
end


return items
