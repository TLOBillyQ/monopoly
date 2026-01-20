---@class AC_ResultMate_Item_UIBP_C:UserWidget
---@field AC_ResultTime_UIBP_01 UAC_ResultTime_UIBP_C
---@field AC_ResultTime_UIBP_02 UAC_ResultTime_UIBP_C
---@field AC_ResultTime_UIBP_03 UAC_ResultTime_UIBP_C
---@field AC_ResultTime_UIBP_04 UAC_ResultTime_UIBP_C
---@field Common_Avatar_BP UCommon_Avatar_BP_C
---@field CompleteNum UTextBlock
---@field EliminateNum UTextBlock
---@field General_AvatarFrame_UIBP UGeneral_AvatarFrame_UIBP_C
---@field Image_N01 UImage
---@field NewButton_Add UNewButton
---@field TextBlock_Name UTextBlock
---@field WidgetSwitcher_Rank UWidgetSwitcher
--Edit Below--
local AC_ResultMate_Item_UIBP = 
{
    --玩家结算数据
    PlayerResultData = {};

    --是否能发送添加好友请求
    IsCanSendAddFriendRequest = true;


    --自己的条目需要高亮显示的颜色
    SelfItemColor = 
    {
        SpecifiedColor = 
        {
            R = 1, 
            G = 0.298039, 
            B = 0.015686, 
            A = 1
        },
        ColorUseRule = 0,
    };
   
}

--构造函数
function AC_ResultMate_Item_UIBP:Construct()
    ugcprint("AC_ResultMate_Item_UIBP:Construct");

    self:InitBindEvent();
end

--初始化-绑定事件
function AC_ResultMate_Item_UIBP:InitBindEvent()
    ugcprint("AC_ResultMate_Item_UIBP:InitBindEvent");

    self.NewButton_Add.OnClicked:Add(self.AddFriend_Button_OnClicked, self);
    --self.Button_like.OnClicked:Add(self.Button_Like_OnClicked, self);
end

--根据传入的玩家结算数据，初始化UI
function AC_ResultMate_Item_UIBP:Init(Index, PlayerResultData)
    ugcprint(string.format("AC_ResultMate_Item_UIBP:Init Index[%d]",Index));
    log_tree_dev("PlayerResultData: ",PlayerResultData);

    -- if PlayerResultData.PlayerName == nil then 
    --     return 
    -- end

    -- 4个棋子到达时间UI
    self.PlayerResultTimeLists = {
        self.AC_ResultTime_UIBP_01;
        self.AC_ResultTime_UIBP_02;
        self.AC_ResultTime_UIBP_03;
        self.AC_ResultTime_UIBP_04;
    }

    self.PlayerResultData = TableHelper.DeepCopy(PlayerResultData);
    self.WidgetSwitcher_Rank:SetActiveWidgetIndex(Index - 1);
    if PlayerResultData.PlayerName ~= nil then 
        self.TextBlock_Name:SetText(PlayerResultData.PlayerName);
    end
    self.CompleteNum:SetText(PlayerResultData.EntryNum or 0);
    self.EliminateNum:SetText(PlayerResultData.EliminateNum or 0);

    -- 每枚棋子到达终点时间    
    --self.CompletionTime:SetText(self:GetCompletionTimeDisplayStr(PlayerResultData.CompletionTime));
    for i = 1, 4 do
        self.PlayerResultTimeLists[i]:Init(i, PlayerResultData)
    end
    --玩家头像
    if PlayerResultData.IconURL ~= nil then
        ugcprint("AC_ResultMate_Item_UIBP:ShowIcon");
        self.Common_Avatar_BP:InitView(1, PlayerResultData.UID, PlayerResultData.IconURL, PlayerResultData.Gender, PlayerResultData.FrameLevel, PlayerResultData.PlayerLevel, true, false);
        self.General_AvatarFrame_UIBP:SetVisibility(ESlateVisibility.Collapsed);
    end
    --self.General_AvatarFrame_UIBP:InitView(1, PlayerResultData.UID, PlayerResultData.IconURL, PlayerResultData.Gender, PlayerResultData.FrameLevel, PlayerResultData.PlayerLevel, true, false);
    --是否已是好友
    if FriendSystem.IsMyFriend(PlayerResultData.UID) and PlayerResultData.UID ~= nil or PlayerResultData.PlayerName == nil then
        self.IsCanSendAddFriendRequest = false;
        self.NewButton_Add:SetVisibility(ESlateVisibility.Collapsed);
    end

    --是自己
    if PlayerResultData.PlayerKey == AeroplaneChessMode.OwnerPlayerKey and PlayerResultData.PlayerKey ~= nil then
        self.NewButton_Add:SetVisibility(ESlateVisibility.Collapsed);
        self.TextBlock_Name:SetColorAndOpacity(self.SelfItemColor);
        self.CompleteNum:SetColorAndOpacity(self.SelfItemColor);
        self.EliminateNum:SetColorAndOpacity(self.SelfItemColor);

        --self.CompletionTime:SetColorAndOpacity(self.SelfItemColor);

        self.IsCanSendAddFriendRequest = false;
        self.NewButton_Add:SetIsEnabled(false);
        -- 设置结算界面最上方UI框
        if Index == 1 then
            AeroplaneChessUIManager.SettlementUI.AC_ResultTop_Item_UIBP.Image_victory1:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
            AeroplaneChessUIManager.SettlementUI.AC_ResultTop_Item_UIBP.TextBlock_Content:SetText("冠军")
        else
            AeroplaneChessUIManager.SettlementUI.AC_ResultTop_Item_UIBP.Image_victory1:SetVisibility(ESlateVisibility.Collapsed)
            AeroplaneChessUIManager.SettlementUI.AC_ResultTop_Item_UIBP.TextBlock_Content:SetText("再接再厉")
        end
        AeroplaneChessUIManager.SettlementUI.AC_ResultTop_Item_UIBP.TextBlock_Num:SetText(tostring(Index))
    end

    --自己的条目
    if AeroplaneChessMode.OwnerPlayerState and AeroplaneChessMode.OwnerPlayerState.PlayerKey == PlayerResultData.PlayerKey then
        
    end

end

-- 把秒数转换成显示用的x时x分x秒
function AC_ResultMate_Item_UIBP:GetCompletionTimeDisplayStr(TotalTimeInSeconds)
    TotalTimeInSeconds = TotalTimeInSeconds and math.floor(TotalTimeInSeconds) or 0
    local seconds = TotalTimeInSeconds % 60
    local totalMinutes = math.floor(TotalTimeInSeconds / 60)
    local minutes = totalMinutes % 60
    local hours = math.floor(totalMinutes / 60)
    local result = ""
    if hours > 0 then
        result = result..tostring(hours).."时"
    end
    if minutes > 0 then
        result = result..tostring(minutes).."分"
    end
    result = result..tostring(seconds).."秒"
    return result
end

--添加好友按钮按下
function AC_ResultMate_Item_UIBP:AddFriend_Button_OnClicked()
    if self.IsCanSendAddFriendRequest == false then return end
    ugcprint(string.format("AC_ResultMate_Item_UIBP:AddFriend_Button_OnClicked AddFriendPlayer[%s]", self.PlayerResultData.PlayerName));

    --发送好友申请
    if self.PlayerResultData.PlayerSex == 1 then
        FriendSystem.AddFriend(self.PlayerResultData.UID, BP_ENUM_ADD_FRIEND_FROM_BATTLE_RESULT, 7); -- 7是在好友申请配置表配置的男性默认语
    else
        FriendSystem.AddFriend(self.PlayerResultData.UID, BP_ENUM_ADD_FRIEND_FROM_BATTLE_RESULT, 8); -- 8是在好友申请配置表配置的女性默认语
    end
    
    PopUpNoticeUI.ShowFastNoticeQueue(string.format("已向%s发送好友申请消息", self.PlayerResultData.PlayerName));
    self.NewButton_Add:SetIsEnabled(false);
end
return AC_ResultMate_Item_UIBP;