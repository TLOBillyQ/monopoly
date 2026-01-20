local Action_PlayerExit = 
{
	PlayerKey = 0;
	AllPlayersLeaveNotifyEvent = "";
}


function Action_PlayerExit:Execute()
	print(string.format("Action_PlayerExit:Execute PlayerKey[%d]",self.PlayerKey));

    -- 玩家退出，进入托管
    local PlayerInfo = UGCGameSystem.GameState:GetPlayerInfoWithPlayerKey(self.PlayerKey)
    if PlayerInfo ~= nil then
        PlayerInfo.IsInAutoPlay = true
    end

	local PlayerList = UGCGameSystem.GetAllPlayerController()
	local Count = #PlayerList
	if Count == 0 then
		if self.AllPlayersLeaveNotifyEvent ~= "" then 
			print("Action_PlayerExit:Execute Send AllPlayersLeaveNotifyEvent"..self.AllPlayersLeaveNotifyEvent);
			LuaQuickFireEvent(self.AllPlayersLeaveNotifyEvent, self); 
		end
	end

	return true;
end


return Action_PlayerExit
