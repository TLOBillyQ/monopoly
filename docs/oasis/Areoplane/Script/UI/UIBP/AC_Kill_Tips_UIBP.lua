---@class AC_Kill_Tips_UIBP_C:UserWidget
---@field TextBlock_Name01 UTextBlock
---@field TextBlock_Name02 UTextBlock
---@field WidgetSwitcher_State UWidgetSwitcher
--Edit Below--
local AC_Kill_Tips_UIBP = 
{
    LastTime = 0;
    bStart = false;
}

function AC_Kill_Tips_UIBP:Construct()
    self.bCanEverTick = true
    self:SetVisibility(ESlateVisibility.Collapsed);
end

function AC_Kill_Tips_UIBP:Show(bShow, TeamIndex1, TeamIndex2)
    if bShow == true then
        self.bStart = true
        self:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
        local PlayerName1 = UGCGameSystem.GameState.PlayerInfos[TeamIndex1].PlayerName;
        if PlayerName1 then
            self.TextBlock_Name01:SetText(tostring(PlayerName1))
        else
            self.TextBlock_Name01:SetText(tostring(TeamIndex1).."号")
        end
        local PlayerName2 = UGCGameSystem.GameState.PlayerInfos[TeamIndex2].PlayerName;
        if PlayerName2 then
            self.TextBlock_Name02:SetText("玩家"..tostring(PlayerName2))
        else
            self.TextBlock_Name02:SetText("玩家"..tostring(TeamIndex2).."号")
        end
        self.WidgetSwitcher_State:SetActiveWidgetIndex(0)
        self.WidgetSwitcher_State:SetRenderTranslation({X=4.0, Y=0.0})
        
        if UGCGameSystem.GameState.PlayerInfos[TeamIndex2].PlayerKey == AeroplaneChessMode.OwnerPlayerKey then
            self.TextBlock_Name02:SetText("你")
            self.WidgetSwitcher_State:SetActiveWidgetIndex(1)
            self.WidgetSwitcher_State:SetRenderTranslation({X=-7.0, Y=0.0})
        end
        self.LastTime = GameplayStatics.GetRealTimeSeconds(self)
    else
        self.bStart = false
    end
end

function AC_Kill_Tips_UIBP:Tick(MyGeometry, InDeltaTime)
    if self.bStart == false then
        return
    end

    local Now = GameplayStatics.GetRealTimeSeconds(self)
    if Now >= self.LastTime + 5 then
        self:SetVisibility(ESlateVisibility.Collapsed);
        self.bStart = false
    end 
end
return AC_Kill_Tips_UIBP;