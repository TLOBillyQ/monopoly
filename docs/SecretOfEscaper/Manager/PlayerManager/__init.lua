local Player = require 'Manager.PlayerManager.Player'

---@class PlayerManager
PlayerManager = {}

PlayerManager.role_mapping = {}
for _, role in ipairs(ALLROLES) do
    PlayerManager.role_mapping[role.get_roleid()] = Player:new(role)
end

-- 通过role找到player
---@param role Role
---@return Player
PlayerManager.find_player_by_role = function(role)
    return PlayerManager.role_mapping[role.get_roleid()]
end