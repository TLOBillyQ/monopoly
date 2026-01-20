---@class AC_GameVictory_Tips_UIBP_C:UserWidget
---@field CanvasPanel_0 UCanvasPanel
--Edit Below--
local AC_GameVictory_Tips_UIBP = {    
    LastTime = 0;
    bStart = false;
    TeamIndex = 0;
}; 

function AC_GameVictory_Tips_UIBP:Construct()
    self.bCanEverTick = true
    self:SetVisibility(ESlateVisibility.Collapsed);
end

function AC_GameVictory_Tips_UIBP:Show(bShow, TeamIndex)
    ugcprint("AC_GameVictory_Tips_UIBP:Show "..tostring(bShow));
    if bShow == true then
        self.bStart = true
        self:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
        self.LastTime = GameplayStatics.GetRealTimeSeconds(self);
        self.TeamIndex = TeamIndex;
    else
        self.bStart = false
    end
end

function AC_GameVictory_Tips_UIBP:Tick(MyGeometry, InDeltaTime)
    if self.bStart == false then
        return
    end

    local Now = GameplayStatics.GetRealTimeSeconds(self)
    if Now >= self.LastTime + 2 then
        ugcprint("AC_GameVictory_Tips_UIBP:End ");
        self:SetVisibility(ESlateVisibility.Collapsed);
        self.bStart = false
        -- UGCEventSystem:SendEvent(AeroplaneChessEventType.PlayerFinishedGame, self.TeamIndex);
        
        AeroplaneChessUIManager.MainUI:SetVisibility(ESlateVisibility.Collapsed);
        if AeroplaneChessUIManager.SettlementUI == nil then
            AeroplaneChessUIManager:CreateSettlementUI();
        else
            AeroplaneChessUIManager.SettlementUI:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
        end
    end 
end
return AC_GameVictory_Tips_UIBP;