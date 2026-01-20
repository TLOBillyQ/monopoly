---@class AC_GameShows_UIBP_C:UserWidget
---@field General_MessageBox_UIBP UGeneral_MessageBox_UIBP_C
---@field Image_Icon UImage
---@field NewButton_JoinIN UNewButton
---@field NewCheckBox_Tips UNewCheckBox
--Edit Below--
local AC_GameShows_UIBP = {}; 

function AC_GameShows_UIBP:Construct()
    ugcprint("AC_GameShows_UIBP:Construct")
    self.NewButton_JoinIN.OnClicked:Add(self.NewButton_JoinIN_OnClicked, self);
end

function AC_GameShows_UIBP:NewButton_JoinIN_OnClicked()
    ugcprint("AC_GameShows_UIBP:NewButton_JoinIN_OnClicked")
    self:SetVisibility(ESlateVisibility.Collapsed)
    self:RemoveFromParent()
    AeroplaneChessUIManager.StartGuideUI = nil
end

return AC_GameShows_UIBP;