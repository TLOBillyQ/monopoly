---@class AC_DiceShow_UIBP_C:UserWidget
---@field DiceShow_Image UImage
---@field Image_DiceShow UImage
---@field TextBlock_0 UTextBlock
--Edit Below--
local AC_DiceShow_UIBP = 
{
    LastTime = 0;
    bStart = false;
    ResultBrush = nil;        -- 结果图
    bSetResultBrush = false;  -- 是否设置结果图
    Result = 0
}

function AC_DiceShow_UIBP:Construct()
    self.bCanEverTick = true
    self:SetVisibility(ESlateVisibility.Collapsed);
end

function AC_DiceShow_UIBP:Show(bShow)
    if bShow == true then
        self.bStart = true
        self.bSetResultBrush = false
        self:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
        self.TextBlock_0:SetVisibility(ESlateVisibility.Collapsed);
        self.LastTime = GameplayStatics.GetRealTimeSeconds(self)
    else
        self.bStart = false
    end
end

function AC_DiceShow_UIBP:Tick(MyGeometry, InDeltaTime)
    if self.bStart == false then
        return
    end

    local Now = GameplayStatics.GetRealTimeSeconds(self)

    if Now >= self.LastTime + 1 and self.bSetResultBrush == false then
        self.DiceShow_Image:SetBrushFromAsset(self.ResultBrush);
        --self.TextBlock_0:SetText(self.Result .. "")
        self.bSetResultBrush = true
    end

    if Now >= self.LastTime + 2 then
        self:SetVisibility(ESlateVisibility.Collapsed);
        self.bStart = false
    end
end


return AC_DiceShow_UIBP;