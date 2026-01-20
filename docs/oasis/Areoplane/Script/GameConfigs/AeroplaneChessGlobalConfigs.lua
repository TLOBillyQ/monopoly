
-- 棋子状态
EPlaneState = {
    AtHome    = 1;   -- 尚未出发
    Ready     = 2;   -- 待出发状态
    InFlight  = 3;   -- 已经出发
    Finished  = 4;   -- 已经到达终点
};

-- 游戏状态
EGameStatus = {
    WaitReady               = 1;   -- 游戏开始前等待
    Gaming                  = 2;   -- 游戏中
    Result                  = 3;   -- 结算中
};

-- 回合状态
ERoundStatus = {
    WaitForRollDice         = 1;   -- 等待摇骰子
    DiceRolling             = 2;   -- 骰子动画中
    WaitForPlaneSelection   = 3;   -- 等待选择棋子
    PlaneFlying             = 4;   -- 棋子移动动画中
    RoundEnd                = 5;   -- 回合已经结束
};

-- 摄像机状态
ECameraState = {
    FreeCamera         = 1;   -- 自由视角
    AutoCamera         = 2;   -- 自动视角
    GlobalCamera       = 3;   -- 全局视角
};

-- 队伍对应颜色
ETeameColor = {
    "红";
    "黄";
    "绿";
    "蓝";
}


-- 队伍对应RGB
ETeameColorRGB = {};
ETeameColorRGB["红"] = {R = 1, G = 0, B = 0};
ETeameColorRGB["黄"] = {R = 1, G = 1, B = 0};
ETeameColorRGB["绿"] = {R = 0, G = 1, B = 0};
ETeameColorRGB["蓝"] = {R = 0, G = 0, B = 1};