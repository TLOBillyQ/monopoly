---@class Dice_C:Actor
---@field DefaultSceneRoot USceneComponent
--Edit Below--
local Dice = 
{
    -- 骰子可能的结果
    PossibleResults = { 1, 2, 3, 4, 5, 6 };
    -- 骰子的结果
    Result  = nil;
};

-- (DS) 随机返回 Numbers 中的结果
function Dice:GetRandomResult()
    local ResultIndex = math.random(1, #self.PossibleResults);
    self.Result = self.PossibleResults[ResultIndex]
    return self.Result
end

-- (DS) 获取指定结果
function Dice:GetSpecificResult(InResultIndex)
    self.Result = self.PossibleResults[InResultIndex];
    return self.Result
end

-- (Client) 根据结果播放指定动画
function Dice:GetAnimPathWithResult(InResult)
    -- 播放指定动画
    ugcprint(string.format("Dice:GetAnimPathWithResult InResult[%d]", InResult));
    return UGCMapInfoLib.GetRootLongPackagePath() .. AeroplaneChessUIManager.DiceAnimConfigList[InResult].IconPath;
end

-- (Client) 播放音效
function Dice:PlayRollDiceVoice()
    ugcprint(string.format("Dice:PlayRollDiceVoice:%d", AeroplaneChessAudioConfig.ID.ROLLDICE));
    UGCSoundTools:ClientPlaySound2D(AeroplaneChessAudioConfig.ID.ROLLDICE);
end

-- 需要复制的属性
function Dice:GetReplicatedProperties()
    return
    "Result";
end

--  注册 Server RPC
function Dice:GetAvailableServerRPCs()
    return;
end

-- function Dice:ReceiveBeginPlay()

-- end

-- function Dice:ReceiveTick(DeltaTime)

-- end

-- function Dice:ReceiveEndPlay()
 
-- end

return Dice;