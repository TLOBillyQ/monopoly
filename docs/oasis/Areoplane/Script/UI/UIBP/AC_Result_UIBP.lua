---@class AC_Result_UIBP_C:UserWidget
---@field AC_ResultTitle_Item_UIBP UAC_ResultTitle_Item_UIBP_C
---@field AC_ResultTop_Item_UIBP UAC_ResultTop_Item_UIBP_C
---@field BattleDetailBG UCanvasPanel
---@field CanvasPanel_0 UCanvasPanel
---@field HorizontalBox_1 UHorizontalBox
---@field Image_3 UImage
---@field NewButton_Back UNewButton
---@field NewButton_GoOn UNewButton
---@field NewButton_Reort UNewButton
---@field NewButton_Share UNewButton
---@field SizeBox_01 USizeBox
---@field SizeBox_02 USizeBox
---@field SizeBox_03 USizeBox
---@field SizeBox_04 USizeBox
---@field TextBlock_1 UTextBlock
---@field TextBlock_Time UTextBlock
---@field VerticalBox_RankList UVerticalBox
--Edit Below--
local AC_Result_UIBP = 
{
    --结算数据
    GameResultData = {};
    TotalTime = 120;
    NowTime = 0;
    LastTime = 0;
    bStart = false;
}
   
--构造函数
function AC_Result_UIBP:Construct()
    ugcprint("AC_Result_UIBP:Construct");
   
   
    --UGCBGMTools:SetState(EBGMState.Stop)
    self.bCanEverTick = true
    self:InitUI()
    self:InitBindEvent();
    self:ShowResult();
end
   
function AC_Result_UIBP:InitUI()
    -- 4个结算玩家框
    self.PlayerItemLists = {
        self.SizeBox_01;
        self.SizeBox_02;
        self.SizeBox_03;
        self.SizeBox_04;
    }
    self.NewButton_Reort:SetVisibility(ESlateVisibility.Collapsed);
end

--初始化-绑定事件
function AC_Result_UIBP:InitBindEvent()
       ugcprint("AC_Result_UIBP:InitBindEvent");
   
    self.NewButton_Back.OnClicked:Add(self.Back_Button_OnClicked, self);
    self.NewButton_Share.OnClicked:Add(self.Share_Button_OnClicked, self);
    self.NewButton_GoOn.OnClicked:Add(self.GoOn_Button_OnClicked, self);
    self.NewButton_Reort.OnClicked:Add(self.Reort_Button_OnClicked, self);
end
   
--显示结算
function AC_Result_UIBP:ShowResult()
    log_tree_dev("AC_Result_UIBP:ShowResult GameResultData:", AeroplaneChessMode.GameResultData);
    self.Now = GameplayStatics.GetRealTimeSeconds(self)
    self:InitSettlementPlayerList();
    self.bStart = true;
end
   
--初始化结算玩家列表
function AC_Result_UIBP:InitSettlementPlayerList()
    log_tree_dev("AC_Result_UIBP:InitSettlementPlayerList PlayerResultDatas :", AeroplaneChessMode.GameResultData.PlayerResultDatas);
    --if #AeroplaneChessMode.GameResultData.PlayerResultDatas == 0 then return false; end
       
    --local SettlementPlayerListItemClass = UE.LoadClass(AeroplaneChessUIManager.SettlementPlayerListItemClassPath);
    local PlayerController = GameplayStatics.GetPlayerController(UGCGameSystem.GameState, 0);
    CommonUtils:AsyncLoadClass
    (PlayerController, AeroplaneChessUIManager.SettlementPlayerListItemClassPath, 
        function (SettlementPlayerListItemClass)
            if SettlementPlayerListItemClass == nil then
                ugcprint(string.format("Error: LittleRedUIManager:InitSettlementPlayerList SettlementPlayerListItemClass[%s] == nil!", AeroplaneChessUIManager.SettlementPlayerListItemClassPath));
                return false;
            end
           
            if AeroplaneChessMode.OwnerController == nil then
                ugcprint("Error: AC_Result_UIBP:InitSettlementPlayerList OwnerController == nil!");
                return false;
            end
           
            --根据玩家结算数据，创建对应数量的玩家数据UI条目控件
            if AeroplaneChessMode.GameResultData ~= nil and AeroplaneChessMode.GameResultData.PlayerResultDatas ~= nil then
                --结算数据排序
                local CompGameResultData = function(a, b)
                    if a.EntryNum == b.EntryNum then
                        return a.CompletionTime < b.CompletionTime
                    else
                        return a.EntryNum > b.EntryNum
                    end
                end
                table.sort( AeroplaneChessMode.GameResultData.PlayerResultDatas, CompGameResultData )
                log_tree_dev("AC_Result_UIBP:InitSettlementPlayerList PlayerResultDatas order:", AeroplaneChessMode.GameResultData.PlayerResultDatas);
                local Index = 1
                local CompleteNum = 0
                for k, PlayerResultData in pairs(AeroplaneChessMode.GameResultData.PlayerResultDatas) do
                    if PlayerResultData ~= nil then
                        local SettlementPlayerListItem = UserWidget.NewWidgetObjectBP(AeroplaneChessMode.OwnerController, SettlementPlayerListItemClass);
                        
                        if SettlementPlayerListItem then    
                            self.PlayerItemLists[Index]:AddChild(SettlementPlayerListItem);
                            SettlementPlayerListItem:Init(Index, PlayerResultData);
                            Index = Index + 1
                        else
                            print("Error: AC_Result_UIBP:InitSettlementPlayerList SettlementPlayerListItem is nil!")
                        end
        
                        if PlayerResultData.EntryNum == 4 then
                            CompleteNum = CompleteNum + 1
                        end
                    end
                end
                -- 设置继续观战按钮
                if CompleteNum > 2 or UGCGameSystem.GameState.CurrentGamestate == EGameStatus.Result then
                    ugcprint("AC_Result_UIBP:IsAeroplaneChessGameFinished")
                    self.NewButton_GoOn:SetVisibility(ESlateVisibility.Collapsed);
                end
            end
        end
     )
    -- if SettlementPlayerListItemClass == nil then
    --     ugcprint(string.format("Error: LittleRedUIManager:InitSettlementPlayerList SettlementPlayerListItemClass[%s] == nil!", AeroplaneChessUIManager.SettlementPlayerListItemClassPath));
    --     return false;
    -- end
   
    -- if AeroplaneChessMode.OwnerController == nil then
    --     ugcprint("Error: AC_Result_UIBP:InitSettlementPlayerList OwnerController == nil!");
    --     return false;
    -- end
   
    -- --根据玩家结算数据，创建对应数量的玩家数据UI条目控件
    -- if AeroplaneChessMode.GameResultData ~= nil and AeroplaneChessMode.GameResultData.PlayerResultDatas ~= nil then
    --     --结算数据排序
    --     local CompGameResultData = function(a, b)
    --         if a.EntryNum == b.EntryNum then
    --             return a.CompletionTime < b.CompletionTime
    --         else
    --             return a.EntryNum > b.EntryNum
    --         end
    --     end
    --     table.sort( AeroplaneChessMode.GameResultData.PlayerResultDatas, CompGameResultData )
    --     log_tree_dev("AC_Result_UIBP:InitSettlementPlayerList PlayerResultDatas order:", AeroplaneChessMode.GameResultData.PlayerResultDatas);
    --     local Index = 1
    --     local CompleteNum = 0
    --     for k, PlayerResultData in pairs(AeroplaneChessMode.GameResultData.PlayerResultDatas) do
    --         if PlayerResultData ~= nil then
    --             local SettlementPlayerListItem = UserWidget.NewWidgetObjectBP(AeroplaneChessMode.OwnerController, SettlementPlayerListItemClass);
                
    --             if SettlementPlayerListItem then    
    --                 self.PlayerItemLists[Index]:AddChild(SettlementPlayerListItem);
    --                 SettlementPlayerListItem:Init(Index, PlayerResultData);
    --                 Index = Index + 1
    --             else
    --                 print("Error: AC_Result_UIBP:InitSettlementPlayerList SettlementPlayerListItem is nil!")
    --             end

    --             if PlayerResultData.EntryNum == 4 then
    --                 CompleteNum = CompleteNum + 1
    --             end
    --         end
    --     end
    --     -- 设置继续观战按钮
    --     if CompleteNum > 2 then
    --         ugcprint("AC_Result_UIBP:IsAeroplaneChessGameFinished")
    --         self.NewButton_GoOn:SetVisibility(ESlateVisibility.Collapsed);
    --     end
    -- end
end
   

--分享按钮按下
function AC_Result_UIBP:Share_Button_OnClicked()
    ugcprint("AC_Result_UIBP:Share_Button_OnClicked");
    UGCWidgetManagerSystem.Share()
end
   
--返回大厅按钮按下
function AC_Result_UIBP:Back_Button_OnClicked()
    ugcprint("AC_Result_UIBP:Back_Button_OnClicked");
   
    --UGCSoundTools:ClientStopAllSound()
    NetUtil.SendPkg("giveup_enter_game")
    LobbySystem.ReturnToLobby()
end

--进行观赛按钮按下
function AC_Result_UIBP:GoOn_Button_OnClicked()
    ugcprint("AC_Result_UIBP:GoOn_Button_OnClicked");
    self:SetVisibility(ESlateVisibility.Collapsed);
    self.bStart = false;
    AeroplaneChessUIManager.MainUI:OnPlayerContinueObserving()
    UnrealNetwork.CallUnrealRPC(AeroplaneChessMode.OwnerController, AeroplaneChessMode.OwnerController, "ServerRPC_SetWatching", true);
end

--举报按钮按下
function AC_Result_UIBP:Reort_Button_OnClicked()
    ugcprint("AC_Result_UIBP:Reort_Button_OnClicked");

end

function AC_Result_UIBP:Tick(MyGeometry, InDeltaTime)
    if self.bStart == false then
        return
    end
    -- 计算剩余时间
    local CurrentRealTime = GameplayStatics.GetRealTimeSeconds(self)
    local RemainTime = self.TotalTime - (CurrentRealTime - self.Now)

    ugcprint(string.format("AC_Result_UIBP:Tick RemainTime[%s]", RemainTime))
    if RemainTime >0 then
        self.TextBlock_Time:SetText(tostring(math.floor(RemainTime)))
    end
    
    if RemainTime <= 0 then
        self:Back_Button_OnClicked();
        self.bStart = false
	end   

end
return AC_Result_UIBP;