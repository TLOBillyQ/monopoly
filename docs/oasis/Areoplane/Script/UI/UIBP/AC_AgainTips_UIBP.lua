---@class AC_AgainTips_UIBP_C:UserWidget
---@field WidgetSwitcher_0 UWidgetSwitcher
--Edit Below--
local AC_AgainTips_UIBP = 
{
    LastTime = 0;
    bStart = false;
}

function AC_AgainTips_UIBP:Construct()
    self.bCanEverTick = true
    self:SetVisibility(ESlateVisibility.Collapsed);
end

function AC_AgainTips_UIBP:Show(bShow, IsSix)
    if bShow == true then
        self.bStart = true
        self:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
        if IsSix then
            self.WidgetSwitcher_0:SetActiveWidgetIndex(1);
        else
            self.WidgetSwitcher_0:SetActiveWidgetIndex(0);
        end
        print(string.format("AC_Tips_UIBP:Show: %s", BackgroundImagePath));
        self.LastTime = GameplayStatics.GetRealTimeSeconds(self)
    else
        self.bStart = false
    end
end

function AC_AgainTips_UIBP:Tick(MyGeometry, InDeltaTime)
    if self.bStart == false then
        return
    end
    local Now = GameplayStatics.GetRealTimeSeconds(self)
    if Now >= self.LastTime + 3 then
        self:SetVisibility(ESlateVisibility.Collapsed);
        self.bStart = false
    end 
end

return AC_AgainTips_UIBP;