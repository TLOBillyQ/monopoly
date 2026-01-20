--[[------------------------------------------玩家回合开始------------------------------------------------------]]--
local Action_PlayerStartNewRound = 
{
    MaxRoundWaitTime = 0;            -- 回合最长等待时长
}

function Action_PlayerStartNewRound:Execute()
    local NextTeamIndex = UGCGameSystem.GameState.CurRoundTeamIndex
    local IsPlayAnotherRound = false
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_ShowRemainTimeTips", true);
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_ShowThrowTips", true);
    if UGCGameSystem.GameState.CanPlayerStartAnotherRound then
        -- 掷到6，玩家再进行一回合
        print("Action_PlayerStartNewRound:Execute Start Another Round!")
        UGCGameSystem.GameState.CanPlayerStartAnotherRound = false
        IsPlayAnotherRound = true
    else 
        -- 找到下一个，还未结束游戏的玩家
        repeat
            NextTeamIndex = NextTeamIndex % 4 + 1
        until(UGCGameSystem.GameState:HasTeamFinishedGame(NextTeamIndex) == false or NextTeamIndex == UGCGameSystem.GameState.CurRoundTeamIndex)
        if NextTeamIndex == UGCGameSystem.GameState.CurRoundTeamIndex then
            print("Action_PlayerStartNewRound:Execute Error: Cannot Find Next Player, Game Should Already Be Finished!")
            return true
        end
    end

    UGCGameSystem.GameState.CurRoundTeamIndex = NextTeamIndex
    UGCGameSystem.GameState.CurRoundStatus = ERoundStatus.WaitForRollDice
    UGCGameSystem.GameState.CurRoundRemainTime = self.MaxRoundWaitTime
    UGCGameSystem.GameState.AeroplaneChessRoundNum = UGCGameSystem.GameState.AeroplaneChessRoundNum + 1
    print(string.format("Action_PlayerStartNewRound:Execute CurRoundTeamIndex[%d]", UGCGameSystem.GameState.CurRoundTeamIndex))
    local PlayerInfo = UGCGameSystem.GameState.PlayerInfos[UGCGameSystem.GameState.CurRoundTeamIndex]
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_NewRoundStart", NextTeamIndex, PlayerInfo.PlayerKey, IsPlayAnotherRound);

    if not UGCGameSystem.GameState:IsValidOnlinePlayer(PlayerInfo.PlayerKey) or PlayerInfo.IsInAutoPlay == true then
        -- 托管
        UGCGameSystem.GameState:DoRollDice()
    end
    self.bEnableActionTick = true
    -- 回合开始的时间
    self.RoundStartTime = GameplayStatics.GetRealTimeSeconds(self)

	return true
end

function Action_PlayerStartNewRound:Update(DeltaTime)
    -- 计算剩余时间
    local CurrentRealTime = GameplayStatics.GetRealTimeSeconds(self)
    if UGCGameSystem.GameState.IsStopDiceTimer then
        return;
    end
    local RemainTime = self.MaxRoundWaitTime - (CurrentRealTime - self.RoundStartTime)
    if RemainTime < 0 then
        RemainTime = 0
    end
    UGCGameSystem.GameState.CurRoundRemainTime = RemainTime
    
    if self.RemainTimeInSeconds ~= math.ceil(RemainTime) then
        self.RemainTimeInSeconds = math.ceil(RemainTime)
        ugcprint(string.format("Action_PlayerStartNewRound:RemainTimeInSeconds[%d]", self.RemainTimeInSeconds))
    end

    if RemainTime <= 0 then
        self:PlayerRoundTimeUp()
	end

end

-- 回合时间结束
function Action_PlayerStartNewRound:PlayerRoundTimeUp()
    ugcprint(string.format("Action_PlayerStartNewRound:PlayerRoundTimeUp"))
    self.bEnableActionTick = false
    -- 时间结束未操作，则进行托管
    if UGCGameSystem.GameState.CurRoundStatus == ERoundStatus.WaitForRollDice then
        print(string.format("Action_PlayerStartNewRound:PlayerRoundTimeUp Start AutoPlay"))
        UGCGameSystem.GameState:GetCurRoundPlayerInfo().IsInAutoPlay = true
        --UnrealNetwork.CallUnrealRPC(PlayerController, PlayerController, "ClientRPC_TrusteeshipTips")
    end
    -- 自动完成回合
    UGCGameSystem.GameState:AutoCompleteRound()
end

return Action_PlayerStartNewRound
