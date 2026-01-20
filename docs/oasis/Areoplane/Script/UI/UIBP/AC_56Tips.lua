---@class AC_56Tips_C:UserWidget
---@field WidgetSwitcher_0 UWidgetSwitcher
--Edit Below--
local AC_56Tips = {
    LastTime = 0;
    bStart = false;
}

function AC_56Tips:Construct()
    self.bCanEverTick = true
    self:SetVisibility(ESlateVisibility.Collapsed);
end

function AC_56Tips:Show(AtHomeNum, IsSix)
    self.bStart = true
    if AtHomeNum > 0 then
        self:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
        if IsSix then
            self.WidgetSwitcher_0:SetActiveWidgetIndex(1);
        else
            self.WidgetSwitcher_0:SetActiveWidgetIndex(0);
        end
    else
        if IsSix then
            self:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
            self.WidgetSwitcher_0:SetActiveWidgetIndex(2);
        end
    end
    self.LastTime = GameplayStatics.GetRealTimeSeconds(self)
end

function AC_56Tips:Tick(MyGeometry, InDeltaTime)
    if self.bStart == false then
        return
    end
    local Now = GameplayStatics.GetRealTimeSeconds(self)
    if Now >= self.LastTime + 3 then
        self:SetVisibility(ESlateVisibility.Collapsed);
        self.bStart = false
    end 
end
return AC_56Tips;