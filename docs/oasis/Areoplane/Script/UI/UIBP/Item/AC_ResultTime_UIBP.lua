---@class AC_ResultTime_UIBP_C:UserWidget
---@field HorizontalBox_0 UHorizontalBox
---@field TextBlock_Num UTextBlock
---@field TextBlock_Time UTextBlock
--Edit Below--
local AC_ResultTime_UIBP = {
    SelfItemColor = 
    {
        SpecifiedColor = 
        {
            R = 1, 
            G = 0.298039, 
            B = 0.015686, 
            A = 1
        },
        ColorUseRule = 0,
    };
}; 

function AC_ResultTime_UIBP:Init(Index, PlayerResultData)
    ugcprint("AC_ResultTime_UIBP:Init")
    self.TextBlock_Num:SetText(Index);
    if PlayerResultData.PlaneCompletionTime[Index]  ~= nil then
        ugcprint(string.format("AC_ResultTime_UIBP:Init:%s", self:GetCompletionTimeDisplayStr(PlayerResultData.PlaneCompletionTime[Index])))
        self.TextBlock_Time:SetText(self:GetCompletionTimeDisplayStr(PlayerResultData.PlaneCompletionTime[Index]))
    else
        self.HorizontalBox_0:SetVisibility(ESlateVisibility.Collapsed);
    end
    

    if PlayerResultData.PlayerKey == AeroplaneChessMode.OwnerPlayerKey then
        self.TextBlock_Num:SetColorAndOpacity(self.SelfItemColor);
        self.TextBlock_Time:SetColorAndOpacity(self.SelfItemColor);
    end
end

function AC_ResultTime_UIBP:GetCompletionTimeDisplayStr(TotalTimeInSeconds)
    ugcprint("AC_ResultTime_UIBP:GetCompletionTimeDisplayStr")
    TotalTimeInSeconds = TotalTimeInSeconds and math.floor(TotalTimeInSeconds) or 0
    local seconds = TotalTimeInSeconds % 60
    local totalMinutes = math.floor(TotalTimeInSeconds / 60)
    local minutes = totalMinutes % 60
    local hours = math.floor(totalMinutes / 60)
    local result = ""
    if hours > 0 then
        result = result..tostring(hours).."时"
    end
    if minutes > 0 then
        result = result..tostring(minutes).." : "
    else
        result = "00 : "..result
    end
    result = result..tostring(seconds)
    return result
end
return AC_ResultTime_UIBP;