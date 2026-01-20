--[[------------------------------------------准备阶段------------------------------------------------------]]--

local Action_PrepareStage = 
{
    TotalTime = 0;            -- 准备阶段时长
}


function Action_PrepareStage:Execute()
    print(string.format("Action_PrepareStage:Execute TotalTime[%d]", self.TotalTime))

    self.bEnableActionTick = true
    -- 播放BGM
    UGCBGMTools:SetState(EBGMState.Normal)
    -- 进入准备阶段的时间
    self.EnterStatgeTime = GameplayStatics.GetRealTimeSeconds(self)
    -- 更新信息面板间隔
    self.Timer = GameplayStatics.GetRealTimeSeconds(self)
	-- 设置游戏状态为准备中
	UGCGameSystem.GameState.CurrentGamestate = EGameStatus.WaitReady;
	return true
end

function Action_PrepareStage:Update(DeltaTime)
    -- 计算剩余时间
    local CurrentRealTime = GameplayStatics.GetRealTimeSeconds(self)
    local RemainTime = self.TotalTime - (CurrentRealTime - self.EnterStatgeTime)
    --UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_PlayerPanel", UGCGameSystem.GameState.PlayerInfos);
    -- 每格5秒更新一次信息面板
    local TempCount = CurrentRealTime - self.Timer;
    if TempCount > 5 then
        UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_PlayerPanel", UGCGameSystem.GameState.PlayerInfos);
        self.Timer = CurrentRealTime;
    end
    UGCGameSystem.GameState.PrepareStageRemainTime = RemainTime
    if RemainTime <= 0 then
        self:EndPrepareStage();
	end
end

function Action_PrepareStage:EndPrepareStage()
    print(string.format("Action_PrepareStage:EndPrepareStage"))
    
    self.bEnableActionTick = false;
    -- 记录游戏开始时间
    UGCGameSystem.GameState.AeroplaneChessGameStartTime = GameplayStatics.GetRealTimeSeconds(self)
    UGCGameSystem.GameState.AeroplaneChessRoundNum = 0
    -- 设置游戏状态为游戏中
    UGCGameSystem.GameState.CurrentGamestate = EGameStatus.Gaming;
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_PlayerPanel", UGCGameSystem.GameState.PlayerInfos);
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_ShowStartTips");
    LuaQuickFireEvent("PlayerStartNewRound", self)
end

return Action_PrepareStage
