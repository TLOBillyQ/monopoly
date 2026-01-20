--[[------------------------------------------游戏结束------------------------------------------------------]]--
local Action_AeroplaneChessGameFinished = 
{

}

function Action_AeroplaneChessGameFinished:Execute()
    print("Action_AeroplaneChessGameFinished:Execute")
	-- 设置游戏状态为结算中
	UGCGameSystem.GameState.CurrentGamestate = EGameStatus.Result;

    local SettlementDatas = UGCGameSystem.GameState:GetSettlementData()
	log_tree("Action_AeroplaneChessGameFinished:Execute SettlementData:", SettlementDatas)
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_AeroplaneChessGameFinished", SettlementDatas);

	for TeamIndex = 1, 4 do
		UGCGameSystem.GameState.PlayerInfos[TeamIndex].InWatching = false;
	end
    self:SendUGCModeBattleResult()
    self:TLogDataReport(SettlementDatas)
	return true
end

-- UGC模式结算，发送至后台记录
function Action_AeroplaneChessGameFinished:SendUGCModeBattleResult()
	local PlayerControllerList = UGCGameSystem.GetAllPlayerController()
	for _, PlayerController in ipairs(PlayerControllerList) do
		if PlayerController then
			print("Action_AeroplaneChessGameFinished:SendUGCModeBattleResult PlayerKey:"..tostring(PlayerController.PlayerKey))
			UGCGameSystem.SendPlayerSettlement(PlayerController.PlayerKey)
		else
			print("Error: Action_AeroplaneChessGameFinished:SendUGCModeBattleResult PlayerController is nil!")
		end
	end
end

--TLog数据上报
function Action_AeroplaneChessGameFinished:TLogDataReport(SettlementDatas)
    print("Action_AeroplaneChessGameFinished:TLogDataReport")

    local tempData = TableHelper.DeepCopy(SettlementDatas)
    for i, v in ipairs(tempData) do
        v.TeamIndex = i
    end

    local CompGameResultData = function(a, b)
        if a.EntryNum == b.EntryNum then
            return a.CompletionTime < b.CompletionTime
        else
            return a.EntryNum > b.EntryNum
        end
    end

    table.sort(tempData, CompGameResultData )

    for rank,teamData in pairs(tempData) do
        --story=871737603 【UGC】【CG018】【飞行棋】飞行棋新增Tlog 每个玩家所在队伍托管使用时间
		NetUtil.SendPacketCustom(string.format("AeroplaneChess_AutoPlayTotalTime_Team%d:", tostring(teamData.TeamIndex)), tostring(math.floor(UGCGameSystem.GameState.AutoPlayTotalTime[teamData.TeamIndex])))
		--story=871736985 【UGC】【CG018】【飞行棋】飞行棋新增Tlog 每个玩家所在队伍棋子被淘汰的次数
		NetUtil.SendPacketCustom(string.format("AeroplaneChess_GetKickedTimes_Team%d:", tostring(teamData.TeamIndex)), tostring(UGCGameSystem.GameState.PlayerInfos[teamData.TeamIndex].GetKickedTimes))
        
        NetUtil.SendPacketCustom("TeamKilledCount_" .. teamData.TeamIndex, tostring(teamData.EliminateNum))
        NetUtil.SendPacketCustom("TeamAllPlanesDoneTime_" .. teamData.TeamIndex, tostring(teamData.CompletionTime))
        NetUtil.SendPacketCustom("TeamRank_" .. teamData.TeamIndex, tostring(rank))

        for i,planeCompletionTime in pairs(teamData.PlaneCompletionTime) do
            NetUtil.SendPacketCustom(string.format("TeamPlaneFlyTime_%s_PlaneIndex_%s", tostring(teamData.TeamIndex), tostring(i)) ,tostring(planeCompletionTime) )
        end
    end

    -- 上报每个角色摄像机状态时间
    local AllPlayerController = UGCGameSystem.GetAllPlayerController();
    print("Action_AeroplaneChessGameFinished:TLogDataReport Start Report CameraStateTime,PlayerNum is:" .. #AllPlayerController);
    for _,v in pairs(AllPlayerController) do
        v:TlogCameraStateUseTime();
    end
end



return Action_AeroplaneChessGameFinished
