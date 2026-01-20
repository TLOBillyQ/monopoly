--[[------------------------------------------音效配置------------------------------------------------------]]--
AeroplaneChessAudioConfig = AeroplaneChessAudioConfig or {}

local Path = function(Str)
    return UGCMapInfoLib.GetRootLongPackagePath()..Str
end

--[[------------------------------------------配置数据------------------------------------------------------]]--

AeroplaneChessAudioConfig.ID = 
{
    BGM_NORMAL             = 64;
    ROLLDICE               = 65;
}

AeroplaneChessAudioConfig.ID2Path = 
{
    [AeroplaneChessAudioConfig.ID.BGM_NORMAL]             = Path("Asset/WwiseEvent/BGM.BGM");
    [AeroplaneChessAudioConfig.ID.ROLLDICE]               = Path('Asset/WwiseEvent/RollDiceVoice.RollDiceVoice')
}

return AeroplaneChessAudioConfig
