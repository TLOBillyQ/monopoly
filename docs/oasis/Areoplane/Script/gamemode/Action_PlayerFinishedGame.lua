--[[------------------------------------------玩家结束游戏------------------------------------------------------]]--
local Action_PlayerFinishedGame = 
{

}

function Action_PlayerFinishedGame:Execute()

    local PlayerInfo = UGCGameSystem.GameState:GetCurRoundPlayerInfo()
    -- 记录游戏时长
    PlayerInfo.CompletionTime = GameplayStatics.GetRealTimeSeconds(self) - UGCGameSystem.GameState.AeroplaneChessGameStartTime
    local SettlementDatas = UGCGameSystem.GameState:GetSettlementData()
	log_tree("Action_PlayerFinishedGame:Execute SettlementData:", SettlementDatas)
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_PlayerFinishedGame", UGCGameSystem.GameState.CurRoundTeamIndex, SettlementDatas, true);

    return true
end


return Action_PlayerFinishedGame
