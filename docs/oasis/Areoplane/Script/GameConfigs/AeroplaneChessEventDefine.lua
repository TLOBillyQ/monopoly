--飞行棋模式事件
AeroplaneChessEventType = AeroplaneChessEventType or {}; 

-----------------------------------------Server & Client----------------------------------------------------

-----------------------------------------Only Client----------------------------------------------------
AeroplaneChessEventType.PrepareStageRemainTimeChanged             = 201;  --准备阶段剩余时间改变
AeroplaneChessEventType.CurRoundRemainTimeChanged                 = 202;  --当前回合剩余时间改变
AeroplaneChessEventType.PlayerStartNewRound                       = 203;  --玩家开始回合
AeroplaneChessEventType.ReceivedDiceResult                        = 204;  --客户端收到骰子结果
AeroplaneChessEventType.PlayerFlyPlane                            = 205;  --玩家移动了棋子
AeroplaneChessEventType.PlayerInfosChanged                        = 206;  --位置（P1-P4）的状态信息改变
AeroplaneChessEventType.PlaneReachedEndPoint                      = 207;  --某个棋子到达终点
AeroplaneChessEventType.PlayerFinishedGame                        = 208;  --玩家结束游戏（棋子全部到达）
AeroplaneChessEventType.Kill                                      = 209;  --玩家A淘汰玩家B一枚X号棋子
AeroplaneChessEventType.AeroplaneChessGameFinished                = 210;  --整局游戏结束（3个玩家结束了游戏）
AeroplaneChessEventType.TeamIndexAssigned                         = 211;  --分配了位置
AeroplaneChessEventType.PlayerPanelChange                         = 212;  --玩家信息面板变化
AeroplaneChessEventType.CurRoundStatusChanged                     = 213;  --当前回合阶段改变
AeroplaneChessEventType.CurTeamIndexChanged                       = 214;  --当前回合玩家改变
AeroplaneChessEventType.GameStartChanged                          = 215;  --游戏开始

