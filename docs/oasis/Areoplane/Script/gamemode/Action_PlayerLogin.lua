local Action_PlayerLogin = 
{
	PlayerKey = 0;
}

function Action_PlayerLogin:Execute()
	print(string.format("Action_PlayerLogin:Execute PlayerKey[%d]", self.PlayerKey));

	local PlayerState = UGCGameSystem.GetPlayerStateByPlayerKey(self.PlayerKey)

	-- 登录时，为其分配位置
	if PlayerState ~= nil and PlayerState.TeamIndex == 0 then
        UGCGameSystem.GameState:DisTributeTeamForPlayer(PlayerState)
    end

    -- 不需要取消托管
    -- local PlayerInfo = UGCGameSystem.GameState:GetPlayerInfoWithPlayerKey(self.PlayerKey)
    -- if PlayerInfo ~= nil then
    --     PlayerInfo.IsInAutoPlay = false
    -- end
    
	return true;
end

return Action_PlayerLogin
