--[[------------------------------------------玩家回合结束------------------------------------------------------]]--
local Action_PlayerRoundEnd = 
{
}

function Action_PlayerRoundEnd:Execute()
    ugcprint(string.format("Action_PlayerRoundEnd:Execute"))
    -- 判断整局游戏是否结束（3个玩家结束了游戏）
    if UGCGameSystem.GameState:IsAeroplaneChessGameFinished() then
        LuaQuickFireEvent("AeroplaneChessGameFinished", self)
        return
    end
    -- 判断玩家是否结束游戏（棋子全部到达）
    if UGCGameSystem.GameState:HasTeamFinishedGame(UGCGameSystem.GameState.CurRoundTeamIndex) then
        -- 已经结束的玩家，不需要再来一回合
        UGCGameSystem.GameState.CanPlayerStartAnotherRound = false
        LuaQuickFireEvent("PlayerFinishedGame", self)
    end
    
    -- 开始新回合
    if UGCGameSystem.GameState.CurRoundStatus == ERoundStatus.RoundEnd then
        LuaQuickFireEvent("PlayerStartNewRound", self)
    end
	return true
end

return Action_PlayerRoundEnd
