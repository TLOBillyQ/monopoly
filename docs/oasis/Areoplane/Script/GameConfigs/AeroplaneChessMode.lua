--[[------------------------------------------飞行棋模式数据管理中心------------------------------------------------------]]--
AeroplaneChessMode = AeroplaneChessMode or {}

--[[------------------------------------------配置数据------------------------------------------------------]]--



--[[------------------------------------------动态数据------------------------------------------------------]]--

--结算数据（仅用于Client）
AeroplaneChessMode.GameResultData = {};


--[[------------------------------------------常用指针------------------------------------------------------]]--


--当前Controller（仅用于Client）
AeroplaneChessMode.OwnerController = nil;

--当前PlayerState（仅用于Client）
AeroplaneChessMode.OwnerPlayerState = nil;

--当前PlayerKey（仅用于Client）
AeroplaneChessMode.OwnerPlayerKey = 0;

function AeroplaneChessMode.IsTeamIndexValid(teamIndex)
    return teamIndex >= 1 and teamIndex <= 4
end
