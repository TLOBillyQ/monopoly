---@class AC_Tips_UIBP_C:UserWidget
---@field TextBlock_Content UTextBlock
---@field WidgetSwitcher_Tips UWidgetSwitcher
--Edit Below--
local AC_Tips_UIBP = 
{
    LastTime = 0;
    bStart = false;
	
}
  
function AC_Tips_UIBP:Construct()
    self.bCanEverTick = true
    self:SetVisibility(ESlateVisibility.Collapsed);
end

function AC_Tips_UIBP:Show(bShow, TeamIndex, PlayerKey)
    if bShow == true then
        self.bStart = true
        self:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
        self.WidgetSwitcher_Tips:SetActiveWidgetIndex(TeamIndex - 1)
        print(string.format("AC_Tips_UIBP:Show: %s", BackgroundImagePath));
        if PlayerKey == AeroplaneChessMode.OwnerPlayerKey then

            self.TextBlock_Content:SetText("我方投掷");
        else 

            self.TextBlock_Content:SetText(ETeameColor[TeamIndex].."方投掷");
        end
        self.LastTime = GameplayStatics.GetRealTimeSeconds(self)
    else
        self.bStart = false
    end
end

function AC_Tips_UIBP:ShowAgain(bShow, TeamIndex, PlayerKey)
    if bShow == true then
        self.bStart = true
        self:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
        self.WidgetSwitcher_Tips:SetActiveWidgetIndex(TeamIndex - 1)
        print(string.format("AC_Tips_UIBP:ShowAgain: %s", BackgroundImagePath));
        if PlayerKey == AeroplaneChessMode.OwnerPlayerKey then

            self.TextBlock_Content:SetText("我方再次投掷");
        else 

            self.TextBlock_Content:SetText(ETeameColor[TeamIndex].."方再次投掷");
        end
        self.LastTime = GameplayStatics.GetRealTimeSeconds(self)
    else
        self.bStart = false
    end
end

function AC_Tips_UIBP:Tick(MyGeometry, InDeltaTime)
    if self.bStart == false then
        return
    end

    local Now = GameplayStatics.GetRealTimeSeconds(self)

    if Now >= self.LastTime + 5 then
        self:SetVisibility(ESlateVisibility.Collapsed);
        self.bStart = false;
    end 
    if not UGCGameSystem.GameState.ShowThrowTips and Now >= self.LastTime + 1 then
        self:SetVisibility(ESlateVisibility.Collapsed);
        self.bStart = false;
    end
end


return AC_Tips_UIBP;