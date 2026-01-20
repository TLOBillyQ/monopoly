---@class AC_Throw_Item_UIBP_C:UserWidget
---@field NewButton_TakeOff UNewButton
--Edit Below--
local AC_Throw_Item_UIBP = {}; 
-- function AC_Throw_Item_UIBP:ReceiveBeginPlay()

-- end
-- function AC_Throw_Item_UIBP:ReceiveTick(DeltaTime)

-- end
-- function AC_Throw_Item_UIBP:ReceiveEndPlay()
 
-- end
--构造函数
function AC_Throw_Item_UIBP:Construct()
    ugcprint("AC_Throw_Item_UIBP:Construct");
    self:InitUI();
    self:InitBindEvent();
end
--初始化UI
function AC_Throw_Item_UIBP:InitUI()
    ugcprint("AC_Throw_Item_UIBP:InitUI");
end
--初始化-绑定事件
function AC_Throw_Item_UIBP:InitBindEvent()
    ugcprint("AC_Throw_Item_UIBP:NewButton_TakeOff_OnClicked ");
    self.NewButton_TakeOff.OnClicked:Add(self.NewButton_TakeOff_OnClicked, self);
end
--点击起飞按钮
function AC_Throw_Item_UIBP:NewButton_TakeOff_OnClicked()
    UGCGameSystem.GameState.FirstFly = false;
    ugcprint("AC_Throw_Item_UIBP:NewButton_TakeOff_OnClicked  false");
end

return AC_Throw_Item_UIBP;