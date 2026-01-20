---@class AC_ResultTop_Item_UIBP_C:UserWidget
---@field Image_victory1 UImage
---@field TextBlock_Content UTextBlock
---@field TextBlock_Num UTextBlock
--Edit Below--
local AC_ResultTop_Item_UIBP = {}; 
--构造函数
function AC_ResultTop_Item_UIBP:Construct()
    ugcprint("AC_ResultTop_Item_UIBP:Construct");

    self:InitBindEvent();
end

--初始化-绑定事件
function AC_ResultTop_Item_UIBP:InitBindEvent()
    ugcprint("AC_ResultTop_Item_UIBP:InitBindEvent");

    --self.NewButton_Add.OnClicked:Add(self.AddFriend_Button_OnClicked, self);
    --self.Button_like.OnClicked:Add(self.Button_Like_OnClicked, self);
end

--根据传入的玩家结算数据，初始化UI
function AC_ResultTop_Item_UIBP:Init(Index, PlayerResultData)
    ugcprint(string.format("AC_ResultTop_Item_UIBP:Init Index[%d]",Index));

    if Index == 1 then
        self.Image_victory1:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
        self.TextBlock_Content:SetText("冠军")
    else
        self.Image_victory1:SetVisibility(ESlateVisibility.Collapsed)
        self.TextBlock_Content:SetText("再接再厉")
    end
    self.TextBlock_Num:SetText(tostring(Index))
end

return AC_ResultTop_Item_UIBP;