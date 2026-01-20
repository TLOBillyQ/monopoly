---@class AC_GameStart_Tips_UIBP_C:UserWidget
---@field CanvasPanel_0 UCanvasPanel
--Edit Below--
local AC_GameStart_Tips_UIBP = {
    LastTime = 0;
    bStart = false;
}; 
-- function AC_GameStart_Tips_UIBP:ReceiveBeginPlay()

-- end
-- function AC_GameStart_Tips_UIBP:ReceiveTick(DeltaTime)

-- end
-- function AC_GameStart_Tips_UIBP:ReceiveEndPlay()
 
-- end
function AC_GameStart_Tips_UIBP:Construct()
    self.bCanEverTick = true
    self:SetVisibility(ESlateVisibility.Collapsed);
end

function AC_GameStart_Tips_UIBP:Show(bShow)
    if bShow == true then
        self.bStart = true
        self:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
        self.LastTime = GameplayStatics.GetRealTimeSeconds(self)
    else
        self.bStart = false
    end
end

function AC_GameStart_Tips_UIBP:Tick(MyGeometry, InDeltaTime)
    if self.bStart == false then
        return
    end

    local Now = GameplayStatics.GetRealTimeSeconds(self)
    if Now >= self.LastTime + 2 then
        self:SetVisibility(ESlateVisibility.Collapsed);
        self.bStart = false
    end 
end
return AC_GameStart_Tips_UIBP;