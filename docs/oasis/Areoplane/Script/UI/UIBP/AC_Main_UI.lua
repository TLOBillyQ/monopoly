---@class AC_Main_UI_C:UAEUserWidget
---@field AC_56Tips UAC_56Tips_C
---@field AC_DiceShow_UIBP UAC_DiceShow_UIBP_C
---@field AC_GameOver_UIBP UAC_GameOver_UIBP_C
---@field AC_GameStart_Tips_UIBP UAC_GameStart_Tips_UIBP_C
---@field AC_GameVictory_Tips_UIBP UAC_GameVictory_Tips_UIBP_C
---@field AC_Kill_Tips_UIBP UAC_Kill_Tips_UIBP_C
---@field AC_RoundCountdown_UIBP UAC_RoundCountdown_UIBP_C
---@field AC_Throw_UIBP UAC_Throw_UIBP_C
---@field AC_Tips_UIBP UAC_Tips_UIBP_C
---@field AC_Trusteeship_Tips_UIBP UAC_Trusteeship_Tips_UIBP_C
---@field Border_Auto UBorder
---@field Border_List UBorder
---@field Border_throw UBorder
---@field Border_View UBorder
---@field CanvasPanel_0 UCanvasPanel
---@field CanvasPanel_View UCanvasPanel
---@field CommandInput UEditableText
---@field CustomizeAuto UCustomizeCanvasPanel_BP_C
---@field CustomizeCanvasList UCustomizeCanvasPanel_BP_C
---@field Customizethrow UCustomizeCanvasPanel_BP_C
---@field CustomizeView UCustomizeCanvasPanel_BP_C
---@field EndAutoPlay_Button UNewButton
---@field GMGoButton UButton
---@field GMPanel UCanvasPanel
---@field NewButton_Jiantou UNewButton
---@field NewButton_Quit UNewButton
---@field NewButton_view UNewButton
---@field NewButton_View01 UNewButton
---@field NewButton_View02 UNewButton
---@field NewButton_View03 UNewButton
---@field NewButton_zhihui UNewButton
---@field Player01 UAC_PlayerList_Item_UIBP_C
---@field Player02 UAC_PlayerList_Item_UIBP_C
---@field Player03 UAC_PlayerList_Item_UIBP_C
---@field Player04 UAC_PlayerList_Item_UIBP_C
---@field PrepareStageRemainTime UAC_PrepareStageRemainTime_UIBP_C
---@field StartAutoPlay_Button UNewButton
---@field TextBlock_1 UTextBlock
---@field TextBlock_2 UTextBlock
---@field TextBlock_3 UTextBlock
---@field TextBlock_trusteeship UTextBlock
---@field TextBlock_View UTextBlock
---@field TextBlock_View01 UTextBlock
---@field TextBlock_View02 UTextBlock
---@field TextBlock_View03 UTextBlock
---@field Throwing_Button UButton
---@field Throwing_Image UImage
---@field VerticalBox_View UVerticalBox
---@field WidgetSwitcher_AutoPlayButton UWidgetSwitcher
---@field WidgetSwitcher_jiantou UWidgetSwitcher
--Edit Below--
require("Script.GameConfigs.AeroplaneChessGlobalConfigs");
local AC_Main_UI = {
    -- 视角标记
    BJiantou = true;
    -- 游戏开始标记
    BGameStart = true;
}; 
-- UI构造函数
function AC_Main_UI:Construct()
    ugcprint("AC_Main_UI:Construct");
    self.bCanEverTick = true

    UICommonFunctionLibrary.SetAdaptation(self.CanvasPanel_0, self.CanvasPanel_0)
    
    self:InitUI();
    self:InitBindEvent();

    --关闭gm面板
    self.GMGoButton:SetVisibility(ESlateVisibility.Collapsed)
    self.CommandInput:SetVisibility(ESlateVisibility.Collapsed)
end

function AC_Main_UI:Tick(MyGeometry, InDeltaTime)
    -- 刚进入游戏时，如果已经过了准备阶段在回合中，则需要手动刷新UI
    if self.CurTeamIndex == nil and UGCGameSystem.GameState.CurRoundTeamIndex ~= 0 then
        local PlayerInfo = UGCGameSystem.GameState:GetCurRoundPlayerInfo()
        if PlayerInfo ~= nil then
            -- 手动调用开始回合通知，刷新UI
            print("AC_Main_UI:ReceiveTick Manually Call OnPlayerStartNewRound");
            self:OnPlayerStartNewRound(UGCGameSystem.GameState.CurRoundTeamIndex, PlayerInfo.PlayerKey, false)
        end
    end
end

-- function AC_Main_UI:ReceiveEndPlay()
 
-- end

function AC_Main_UI:InitUI()

    -- 4个选择棋子的按钮
    self.SelectPlaneButtons = {
        self.AC_Throw_UIBP.Select01.NewButton_qizi;
        self.AC_Throw_UIBP.Select02.NewButton_qizi;
        self.AC_Throw_UIBP.Select03.NewButton_qizi;
        self.AC_Throw_UIBP.Select04.NewButton_qizi;
    }
    -- 4个棋子起飞的按钮
    self.FlyPlaneButtons = {
        self.AC_Throw_UIBP.Select01.NewButton_TakeOff2;
        self.AC_Throw_UIBP.Select02.NewButton_TakeOff2;
        self.AC_Throw_UIBP.Select03.NewButton_TakeOff2;
        self.AC_Throw_UIBP.Select04.NewButton_TakeOff2;
    }
    -- 4个棋子确认的按钮
    self.ConfirmPlaneButtons = {
        self.AC_Throw_UIBP.Select01.NewButton_Sure;
        self.AC_Throw_UIBP.Select02.NewButton_Sure;
        self.AC_Throw_UIBP.Select03.NewButton_Sure;
        self.AC_Throw_UIBP.Select04.NewButton_Sure;
    }
    -- 4个棋子对应的BPUI
    self.AC_Throw_UIBP.ThrowID = {
        self.AC_Throw_UIBP.Select01;
        self.AC_Throw_UIBP.Select02;
        self.AC_Throw_UIBP.Select03;
        self.AC_Throw_UIBP.Select04;
    }

    -- 4个玩家面板对应的BPUI
    self.PlayerID = {
        self.Player01;
        self.Player02;
        self.Player03;
        self.Player04;
    }
    
    self.Customizethrow:SetVisibility(ESlateVisibility.Collapsed)
    self.AC_Tips_UIBP:SetVisibility(ESlateVisibility.Collapsed)
    self.AC_Trusteeship_Tips_UIBP:SetVisibility(ESlateVisibility.Collapsed)
    self.AC_GameStart_Tips_UIBP:SetVisibility(ESlateVisibility.Collapsed)
    self.AC_Throw_UIBP:SetVisibility(ESlateVisibility.Collapsed)
    self.AC_GameVictory_Tips_UIBP:SetVisibility(ESlateVisibility.Collapsed)
    self.AC_GameOver_UIBP:SetVisibility(ESlateVisibility.Collapsed)
    self.AC_Kill_Tips_UIBP:SetVisibility(ESlateVisibility.Collapsed)
    self.NewButton_Quit:SetVisibility(ESlateVisibility.Collapsed)
    self.WidgetSwitcher_AutoPlayButton:SetActiveWidgetIndex(1)
    -- self.ConfirmPlaneSelect_Button:SetVisibility(ESlateVisibility.Collapsed)
end

-- 初始化绑定事件
function AC_Main_UI:InitBindEvent()
    print("AC_Main_UI:InitBindEvent");
    -- 事件系统添加监听
    UGCEventSystem:AddListener(AeroplaneChessEventType.PrepareStageRemainTimeChanged, self.OnPrepareStageRemainTimeChanged, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.CurRoundRemainTimeChanged, self.OnCurRoundRemainTimeChanged, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.PlayerInfosChanged, self.OnPlayerInfosChanged, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.PlayerStartNewRound, self.OnPlayerStartNewRound, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.ReceivedDiceResult, self.OnReceivedDiceResult, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.PlayerFlyPlane, self.OnPlayerFlyPlane, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.PlayerFinishedGame, self.OnPlayerFinishedGame, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.AeroplaneChessGameFinished, self.OnAeroplaneChessGameFinished, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.Kill, self.OnKill, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.TeamIndexAssigned, self.OnTeamIndexAssigned, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.PlayerPanelChange, self.OnShowPlayerPanel, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.CurRoundStatusChanged, self.ForceUpdateUI, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.CurTeamIndexChanged, self.ForceUpdateUI, self);
    UGCEventSystem:AddListener(AeroplaneChessEventType.GameStartChanged, self.OnGameStartChanged, self);

    -- 掷骰子按钮
    self.Throwing_Button.OnClicked:Add(self.RollDice_Button_OnClicked, self);
    -- 选择棋子按钮
    for i, btn in pairs(self.SelectPlaneButtons) do
        btn.OnClicked:Add(function()self:SelectPlane_Button_OnClicked(i)end)
    end
    -- 棋子起飞按钮
    for i, btn in pairs(self.FlyPlaneButtons) do
        btn.OnClicked:Add(function()self:SelectPlane_Button_OnClicked(i)end)
    end

    -- 棋子确认按钮
    for i, btn in pairs(self.ConfirmPlaneButtons) do
        btn.OnClicked:Add(function()self:ConfirmPlaneSelect_Button_OnClicked(i)end)
    end

    --绑定按钮点击事件
    self.NewButton_View01.OnClicked:Add(self.Global_Button_OnClicked, self);
    self.NewButton_View03.OnClicked:Add(self.FreeView_Button_OnClicked, self);
    self.NewButton_View02.OnClicked:Add(self.AutomaticPerspective_Button_OnClicked, self);
    self.StartAutoPlay_Button.OnClicked:Add(self.Hosting_Button_OnClicked, self);
    self.EndAutoPlay_Button.OnClicked:Add(self.Hosting_Button_OnClicked, self);
    self.NewButton_view.OnClicked:Add(self.Jiantou_Button_OnClicked, self);
    self.NewButton_Jiantou.OnClicked:Add(self.Jiantou_Button_OnClicked, self);
    self.NewButton_Quit.OnClicked:Add(self.Quit_Button_OnClicked, self);
    self.GMGoButton.OnClicked:Add(self.GMGO_Button_OnClicked, self);
    self.AC_Throw_UIBP.AC_Throw_Item_UIBP.NewButton_TakeOff.OnClicked:Add(self.NewButton_TakeOff_OnClicked, self);
end

function AC_Main_UI:ReceivePreDestroy()
    ugcprint("AC_Main_UI:ReceivePreDestroy")
    self:UnBindEvents();
end

-- 解绑事件
function AC_Main_UI:UnBindEvents()
    self.NewButton_View01.OnClicked:RemoveAll(self.Global_Button_OnClicked, self);
    self.NewButton_View03.OnClicked:RemoveAll(self.FreeView_Button_OnClicked, self);
    self.NewButton_View02.OnClicked:RemoveAll(self.AutomaticPerspective_Button_OnClicked, self);
    self.StartAutoPlay_Button.OnClicked:RemoveAll(self.Hosting_Button_OnClicked, self);
    self.EndAutoPlay_Button.OnClicked:RemoveAll(self.Hosting_Button_OnClicked, self);
    self.NewButton_view.OnClicked:RemoveAll(self.Jiantou_Button_OnClicked, self);
    self.NewButton_Jiantou.OnClicked:RemoveAll(self.Jiantou_Button_OnClicked, self);
    self.NewButton_Quit.OnClicked:RemoveAll(self.Quit_Button_OnClicked, self);
    self.GMGoButton.OnClicked:RemoveAll(self.GMGO_Button_OnClicked, self);
    self.AC_Throw_UIBP.AC_Throw_Item_UIBP.NewButton_TakeOff.OnClicked:RemoveAll(self.NewButton_TakeOff_OnClicked, self);

    UGCEventSystem:RemoveListener(AeroplaneChessEventType.PrepareStageRemainTimeChanged, self.OnPrepareStageRemainTimeChanged, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.CurRoundRemainTimeChanged, self.OnCurRoundRemainTimeChanged, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.PlayerInfosChanged, self.OnPlayerInfosChanged, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.PlayerStartNewRound, self.OnPlayerStartNewRound, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.ReceivedDiceResult, self.OnReceivedDiceResult, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.PlayerFlyPlane, self.OnPlayerFlyPlane, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.PlayerFinishedGame, self.OnPlayerFinishedGame, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.AeroplaneChessGameFinished, self.OnAeroplaneChessGameFinished, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.Kill, self.OnKill, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.TeamIndexAssigned, self.OnTeamIndexAssigned, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.PlayerPanelChange, self.OnShowPlayerPanel, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.CurRoundStatusChanged, self.ForceUpdateUI, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.CurTeamIndexChanged, self.ForceUpdateUI, self);
    UGCEventSystem:RemoveListener(AeroplaneChessEventType.GameStartChanged, self.OnGameStartChanged, self);

end

-- 分配到了位置
function AC_Main_UI:OnTeamIndexAssigned(teamIndex, playerKey)
    print(string.format("AC_Main_UI:OnTeamIndexAssigned[%d] for Player[%d]", teamIndex, playerKey))
    if UGCGameSystem.GameState.CurrentGamestate ~= EGameStatus.WaitReady then
        print("UGCGameSystem.GameState.CurrentGamestate ~= EGameStatus.WaitReady, CurrentGamestate is:" .. tostring(UGCGameSystem.GameState.CurrentGamestate));
        return;
    end
    if AeroplaneChessMode.OwnerPlayerKey == playerKey then
        -- 高亮地板
        for index = 1, 4 do
            local plane = UGCGameSystem.GameState.PlayerInfos[teamIndex].PlaneInfos[index]
            plane:GetCurTile():SetTileHighlight(true)
        end
    end
end

-- 准备阶段倒计时更新
function AC_Main_UI:OnPrepareStageRemainTimeChanged(RemainTime)
    ugcprint(string.format("AC_Main_UI:OnPrepareStageRemainTimeChanged RemainTime[%f]", RemainTime))
   --剩余时间小于0时隐藏倒计时UI
    if RemainTime > 0 then
        self.PrepareStageRemainTime:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
        self.PrepareStageRemainTime.PrepareStageRemainTime_Text:SetText(tostring(math.ceil(RemainTime)))
    else
        self.PrepareStageRemainTime:SetVisibility(ESlateVisibility.Collapsed);
        -- 去除自身的高亮
        local myTeamIndex = self:GetMyTeamIndex()
        if myTeamIndex then
            for index = 1, 4 do
                local plane = UGCGameSystem.GameState.PlayerInfos[myTeamIndex].PlaneInfos[index]
                plane:GetCurTile():SetTileHighlight(false)
            end
        end
	end
end

-- 游戏开始提示
function AC_Main_UI:OnGameStartChanged()
    print("AC_Main_UI:OnGameStartChanged")
    self.AC_GameStart_Tips_UIBP:Show(true);
end

-- 当前回合倒计时更新
function AC_Main_UI:OnCurRoundRemainTimeChanged(RemainTime)
    if UGCGameSystem.GameState.ShowRemainTime then
        ugcprint(string.format("AC_Main_UI:OnCurRoundRemainTimeChanged RemainTime[%f]", RemainTime))
        self.AC_RoundCountdown_UIBP:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
        self.AC_RoundCountdown_UIBP.TextBlock_Time:SetText(""..math.ceil(RemainTime))
        if RemainTime <= 0 then
            self.AC_RoundCountdown_UIBP:SetVisibility(ESlateVisibility.Collapsed);
        end
    else
        if UE.IsValid(self) then
            self.AC_RoundCountdown_UIBP:SetVisibility(ESlateVisibility.Collapsed);
        end
    end
end

-- 玩家开始回合
function AC_Main_UI:OnPlayerStartNewRound(TeamIndex, PlayerKey, IsPlayAnotherRound)
    if not UE.IsValid(self) then return end
    if self.CurTeamIndex == TeamIndex and not IsPlayAnotherRound then return end
    ugcprint(string.format("AC_Main_UI:OnPlayerStartNewRound: P[%d] %s", TeamIndex, ETeameColor[TeamIndex]));
    -- 这里不刷新UI了，直接在同步变量时刷新
    -- self:ForceUpdateUI()
    self.IsMyRound = PlayerKey == AeroplaneChessMode.OwnerPlayerKey
    self.CurTeamIndex = TeamIndex
    self.AC_Tips_UIBP:Show(true, TeamIndex, PlayerKey);
    -- 同一个玩家，再掷一次骰子
    if IsPlayAnotherRound then
        self:OnPlayerStartAnotherRound(true, TeamIndex, PlayerKey)
    end
end

-- 刷新界面UI
function AC_Main_UI:ForceUpdateUI()
    if UGCGameSystem.GameState == nil or AeroplaneChessMode == nil or AeroplaneChessMode.OwnerPlayerState == nil then
        return;
    end
    if UGCGameSystem.GameState.CurrentGamestate == EGameStatus.Gaming then
        if AeroplaneChessMode.IsTeamIndexValid(UGCGameSystem.GameState.CurRoundTeamIndex) then
            self.CurTeamIndex = UGCGameSystem.GameState.CurRoundTeamIndex
            self.IsMyRound = self.CurTeamIndex == AeroplaneChessMode.OwnerPlayerState.TeamIndex
            print(string.format("AC_Main_UI:ForceUpdateUI: P[%d] IsMyRound:%s", self.CurTeamIndex, tostring(self.IsMyRound)));
            -- 骰子按钮
            local shouldShowDice = self.IsMyRound and UGCGameSystem.GameState.CurRoundStatus == ERoundStatus.WaitForRollDice
            self.Customizethrow:SetVisibility(shouldShowDice and ESlateVisibility.SelfHitTestInvisible or ESlateVisibility.Collapsed)
            -- 飞机选择面板
            local shouldShowPlaneSelection = self.IsMyRound and UGCGameSystem.GameState.CurRoundStatus == ERoundStatus.WaitForPlaneSelection
            self:ShowPlaneSelectionPanel(shouldShowPlaneSelection)
            -- 只有在游戏中阶段才需要更新托管UI
            self:UpdateAutoPlayUI()
        end
    else
        self.Customizethrow:SetVisibility(ESlateVisibility.Collapsed)
        self:ShowPlaneSelectionPanel(false)
    end
end

-- 收到骰子的结果
function AC_Main_UI:OnReceivedDiceResult(TeamIndex, DiceResult)
    print(string.format("AC_Main_UI:OnReceivedDiceResult: P[%d] Result[%d]", TeamIndex, DiceResult));
    ugcprint(UGCGameSystem.GameState.DiceActor:GetAnimPathWithResult(0));
    -- 显示骰子过程动画并设置结果图
    local PlayerController = GameplayStatics.GetPlayerController(UGCGameSystem.GameState, 0);
    UGCAsyncLoadTools:LoadObject(UGCGameSystem.GameState.DiceActor:GetAnimPathWithResult(0), 
        function (ProcessBrush)
            if UE.IsValid(self) then
                self.AC_DiceShow_UIBP.DiceShow_Image:SetBrushFromAsset(ProcessBrush);
            end
        end
    )
    UGCAsyncLoadTools:LoadObject(UGCGameSystem.GameState.DiceActor:GetAnimPathWithResult(DiceResult), 
        function (ResultBrush)
            if UE.IsValid(self) then
                self.AC_DiceShow_UIBP.ResultBrush = ResultBrush;
            end
        end
)
    --local ProcessBrush = UE.LoadObject(UGCGameSystem.GameState.DiceActor:GetAnimPathWithResult(0));

    --local ResultBrush = UE.LoadObject(UGCGameSystem.GameState.DiceActor:GetAnimPathWithResult(DiceResult));

    -- 播放音效
    UGCGameSystem.GameState.DiceActor:PlayRollDiceVoice();
    if not UE.IsValid(self) then return end
    -- self.AC_DiceShow_UIBP.DiceShow_Image:SetBrushFromAsset(ProcessBrush);
    -- self.AC_DiceShow_UIBP.ResultBrush = ResultBrush
    self.AC_DiceShow_UIBP.Result = DiceResult
    self.AC_DiceShow_UIBP:Show(true);
    

    if self.IsMyRound then
        self.Customizethrow:SetVisibility(ESlateVisibility.Collapsed)
    end
end

-- 玩家移动了棋子
function AC_Main_UI:OnPlayerFlyPlane(TeamIndex, PlaneIndex, NumSteps)
    print(string.format("AC_Main_UI:OnPlayerFlyPlane: P[%d] Plane[%d] Step[%d]", TeamIndex, PlaneIndex, NumSteps));
    if not UE.IsValid(self) then return end
    if self.IsMyRound then
        self.CurSelectedPlaneIndex = nil
        -- 隐藏棋子选择面板
        self:ShowPlaneSelectionPanel(false)
        -- 去除地板高亮
        for index = 1, 4 do
            local plane = UGCGameSystem.GameState:GetCurRoundPlayerInfo().PlaneInfos[index]
            plane:GetCurTile():SetTileHighlight(false)
        end
    end
end

function AC_Main_UI:GetMyTeamIndex()
    if AeroplaneChessMode.OwnerPlayerState ~= nil and AeroplaneChessMode.IsTeamIndexValid(AeroplaneChessMode.OwnerPlayerState.TeamIndex) then
        return AeroplaneChessMode.OwnerPlayerState.TeamIndex
    end
    return nil
end

-- 位置的状态信息改变
function AC_Main_UI:OnPlayerInfosChanged(playerInfo)
    ugcprint("AC_Main_UI:OnPlayerInfosChanged");
    log_tree_dev(playerInfo)
    self:UpdateAutoPlayUI()
    self:UpdateWatchingUI(playerInfo);
end

-- 更新托管相关UI
function AC_Main_UI:UpdateAutoPlayUI()
    -- 加点日志排查托管按钮一直是灰色的问题
    print("AC_Main_UI:UpdateAutoPlayUI");
    if self.IsObserving then
        -- 观战时隐藏托管UI
        print("AC_Main_UI:UpdateAutoPlayUI IsObserving Hide UI");
        self.WidgetSwitcher_AutoPlayButton:SetVisibility(ESlateVisibility.Collapsed)
        self.AC_Trusteeship_Tips_UIBP:SetVisibility(ESlateVisibility.Collapsed)
    else
        local myTeamIndex = self:GetMyTeamIndex()
        if myTeamIndex and UGCGameSystem.GameState.CurrentGamestate == EGameStatus.Gaming then
            local IsInAutoPlay = UGCGameSystem.GameState.PlayerInfos[myTeamIndex].IsInAutoPlay
            print("AC_Main_UI:UpdateAutoPlayUI "..tostring(IsInAutoPlay))
            self.WidgetSwitcher_AutoPlayButton:SetActiveWidgetIndex(IsInAutoPlay and 2 or 0)
            self.AC_Trusteeship_Tips_UIBP:SetVisibility(IsInAutoPlay and ESlateVisibility.SelfHitTestInvisible or ESlateVisibility.Collapsed)
        else
            if myTeamIndex == nil then
                print("AC_Main_UI:UpdateAutoPlayUI Error: myTeamIndex is nil");
            elseif UGCGameSystem.GameState.CurrentGamestate ~= EGameStatus.Gaming then
                print("AC_Main_UI:UpdateAutoPlayUI Error: CurrentGamestate is "..tostring(UGCGameSystem.GameState.CurrentGamestate));
            end
        end
    end
end

-- 更新观战相关UI
function AC_Main_UI:UpdateWatchingUI(playerInfo)
    ugcprint("AC_Main_UI:UpdateWatchingUI");
    for TeamIndex = 1, 4 do
		if UGCGameSystem.GameState.PlayerInfos[TeamIndex].InWatching and UGCGameSystem.GameState.PlayerInfos[TeamIndex].PlayerKey == AeroplaneChessMode.OwnerPlayerKey then
            ugcprint("AC_Main_UI:UpdateWatchingUI 1");
            -- 观战
            self:OnPlayerContinueObserving();
        end
    end

    self:OnShowPlayerPanel(playerInfo);
end

-- 玩家结束了游戏
function AC_Main_UI:OnPlayerFinishedGame(TeamIndex, IsShowVictory)
    print("AC_Main_UI:OnPlayerFinishedGame");
    
    if UGCGameSystem.GameState.PlayerInfos[TeamIndex].PlayerKey == AeroplaneChessMode.OwnerPlayerKey then
        print("AC_Main_UI:OnPlayerFinishedGame IsShowVictory"..tostring(IsShowVictory));

        NetUtil.StopCheckDSActive();
        BattleResult.IgnoreDSError = true;

        if IsShowVictory then
            -- 胜利的玩家展示胜利界面
            print("AC_Main_UI:OnPlayerFinishedGame AC_GameVictory_Tips");
            self.AC_GameVictory_Tips_UIBP:Show(IsShowVictory, TeamIndex);
        else
            self:SetVisibility(ESlateVisibility.Collapsed);
            if AeroplaneChessUIManager.SettlementUI == nil then
                AeroplaneChessUIManager:CreateSettlementUI();
            else
                AeroplaneChessUIManager.SettlementUI:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
            end
        end
    else
        -- 其余玩家
    end
end

-- 整局游戏结束
function AC_Main_UI:OnAeroplaneChessGameFinished()
    print("AC_Main_UI:OnAeroplaneChessGameFinished");

    NetUtil.StopCheckDSActive();
    BattleResult.IgnoreDSError = true;

    self:SetVisibility(ESlateVisibility.Collapsed);
    -- 更新最新结算面板
    if AeroplaneChessUIManager.SettlementUI then
        AeroplaneChessUIManager.SettlementUI:SetVisibility(ESlateVisibility.Collapsed);
        AeroplaneChessUIManager.SettlementUI = nil;
    end
    AeroplaneChessUIManager:CreateSettlementUI();
end

-- 显示棋子选择面板
function AC_Main_UI:ShowPlaneSelectionPanel(Show)
    ugcprint(string.format("AC_Main_UI:ShowPlaneSelectionPanel:%d", Show and 1 or 0));
    self.AC_Throw_UIBP:SetVisibility(Show and ESlateVisibility.SelfHitTestInvisible or ESlateVisibility.Collapsed)
    --设置当前棋子状态对应的Switcher
    if UGCGameSystem.GameState.FirstFly then
        self.AC_Throw_UIBP.WidgetSwitcher_State:SetActiveWidgetIndex(0)
    else
        self.AC_Throw_UIBP.WidgetSwitcher_State:SetActiveWidgetIndex(1)
        self:ShowFlyPanel(Show)
    end
end

-- 判断当前可操作的棋子
function AC_Main_UI:ShowFlyPanel(Show)
    for i=1, 4 do
        self.AC_Throw_UIBP.ThrowID[i]:SetIsEnabled(false)
        local plane = UGCGameSystem.GameState:GetCurRoundPlayerInfo().PlaneInfos[i] 
        ugcprint("AC_Main_UI:ShowFlyPanel")     
        if plane.CurrentState == EPlaneState.AtHome then
            ugcprint("AC_Main_UI:ShowFlyPanel EPlaneState.AtHome")
            ugcprint(string.format("AC_Main_UI:ShowFlyPanel: %d", self.AC_DiceShow_UIBP.Result))
            self.AC_Throw_UIBP.ThrowID[i].WidgetSwitcher_State:SetActiveWidgetIndex(2)
            if self.AC_DiceShow_UIBP.Result >= 5 then
                self.AC_Throw_UIBP.ThrowID[i]:SetIsEnabled(true)
            end
        end
        if plane.CurrentState == EPlaneState.InFlight or plane.CurrentState == EPlaneState.Ready then
            ugcprint("AC_Main_UI:ShowFlyPanel EPlaneState.InFlight")
            self.AC_Throw_UIBP.ThrowID[i].WidgetSwitcher_State:SetActiveWidgetIndex(0)
            self.AC_Throw_UIBP.ThrowID[i].TextBlock_Num:SetText(i)
            self.AC_Throw_UIBP.ThrowID[i]:SetIsEnabled(true)
        end
    end
    
end
--玩家再投一次
function AC_Main_UI:OnPlayerStartAnotherRound(bFind, TeamIndex, PlayerKey)
    print(string.format("AC_Main_UI:OnPlayerStartAnotherRound : %s", ETeameColor[TeamIndex]))
    self.AC_Tips_UIBP:ShowAgain(bFind, TeamIndex, PlayerKey);
end

--玩家A淘汰玩家B一枚X号棋子
function AC_Main_UI:OnKill(TeamIndex1,TeamIndex2)
    ugcprint("AC_Main_UI:OnKill");
    self.AC_Kill_Tips_UIBP:Show(true,TeamIndex1,TeamIndex2);
    local score = self.PlayerID[TeamIndex1].TextBlock_Score:GetText();
    score = score + 1;
    self.PlayerID[TeamIndex1].TextBlock_Score:SetText(tostring(math.ceil(score)))
end

--显示玩家信息面板
function AC_Main_UI:OnShowPlayerPanel(PlayerInfos)
    ugcprint("AC_Main_UI:OnShowPlayerPanel");
    for i, PlayerState in ipairs(PlayerInfos) do

        if PlayerInfos[i].PlayerName ~= nil then
            self.PlayerID[i].TextBlock_Name:SetText(PlayerInfos[i].PlayerName)
            --self.PlayerID[i].TextBlock_Rank:SetText(i)
        end
        self.PlayerID[i].WidgetSwitcher_Tips:SetActiveWidgetIndex(i - 1)
        self.PlayerID[i].TextBlock_Rank:SetText(i)
        self.PlayerID[i].TextBlock_Score:SetText(tostring(math.ceil(PlayerInfos[i].EliminateNum)))
    end
end

-- -- 某个棋子到达了终点
-- function AC_Main_UI:OnPlaneReachedEndPoint(TeamIndex, PlaneIndex)
--     self.BPUI_Success:Show(true, TeamIndex, PlaneIndex)
-- end


-- 玩家结束游戏后继续观战
function AC_Main_UI:OnPlayerContinueObserving()
    print("AC_Main_UI:OnPlayerContinueObserving");
    self:SetVisibility(ESlateVisibility.SelfHitTestInvisible);
    --self.CanvasPanel_View:SetVisibility(ESlateVisibility.Collapsed);
    self.NewButton_Quit:SetVisibility(ESlateVisibility.Visible);
    self.AC_Throw_UIBP:SetVisibility(ESlateVisibility.Collapsed);
    self.AC_GameStart_Tips_UIBP:SetVisibility(ESlateVisibility.Collapsed);
    self.PrepareStageRemainTime:SetVisibility(ESlateVisibility.Collapsed);
    self.WidgetSwitcher_AutoPlayButton:SetVisibility(ESlateVisibility.Collapsed);
    self.IsObserving = true
    self:UpdateAutoPlayUI()
end

--[[------------------------------------------UI点击事件------------------------------------------------------]]--
-- 摇骰子按钮
function AC_Main_UI:RollDice_Button_OnClicked()
    print("AC_Main_UI:RollDice_Button_OnClicked");
    if self.BGameStart then
        self.AC_GameStart_Tips_UIBP:SetVisibility(ESlateVisibility.Collapsed);
        self.BGameStart = false;
    end
    UnrealNetwork.CallUnrealRPC(AeroplaneChessMode.OwnerController, AeroplaneChessMode.OwnerController, "ServerRPC_RollDice");
    UnrealNetwork.CallUnrealRPC(AeroplaneChessMode.OwnerController, AeroplaneChessMode.OwnerController, "ServerRPC_ShowThrowTips", false);
end

-- 摇骰子后，点击了选择某个棋子的按钮
function AC_Main_UI:SelectPlane_Button_OnClicked(planeIndex)
    print("AC_Main_UI:SelectPlane_Button_OnClicked"..planeIndex);
    self.CurSelectedPlaneIndex = planeIndex
    self.AC_Throw_UIBP.ThrowID[planeIndex].TextBlock_0:SetText(planeIndex)
    for i=1, 4 do
        if planeIndex == i then
            self.AC_Throw_UIBP.ThrowID[planeIndex].WidgetSwitcher_State:SetActiveWidgetIndex(1)
            self.ConfirmPlaneButtons[planeIndex]:SetVisibility(ESlateVisibility.Visible)
        else
            self.AC_Throw_UIBP.ThrowID[i].WidgetSwitcher_State:SetActiveWidgetIndex(0)
            self.AC_Throw_UIBP.ThrowID[i].TextBlock_Num:SetText(i)
        end
    end
    -- 高亮对应的棋盘格子
    self:SetPlaneTileHighlight(planeIndex)
end

-- 开启某个棋子地板的高亮
function AC_Main_UI:SetPlaneTileHighlight(planeIndex)
    ugcprint("AC_Main_UI:SetPlaneTileHighlight"..planeIndex);
    if planeIndex >= 1 and planeIndex <= 4 then
        -- 直接遍历一次的做法在两个棋子站同一格时会有问题
        for index = 1, 4 do
            local plane = UGCGameSystem.GameState:GetCurRoundPlayerInfo().PlaneInfos[index]
            plane:GetCurTile():SetTileHighlight(false)
        end
        local plane = UGCGameSystem.GameState:GetCurRoundPlayerInfo().PlaneInfos[planeIndex]
        plane:GetCurTile():SetTileHighlight(true)
    end
end

-- 确认选择棋子的按钮
function AC_Main_UI:ConfirmPlaneSelect_Button_OnClicked(planeIndex)
    print("AC_Main_UI:ConfirmPlaneSelect_Button_OnClicked"..planeIndex);
    if self.CurSelectedPlaneIndex ~= nil then
        UnrealNetwork.CallUnrealRPC(AeroplaneChessMode.OwnerController, AeroplaneChessMode.OwnerController, "ServerRPC_ShowRemainTimeTips", false);
        UnrealNetwork.CallUnrealRPC(AeroplaneChessMode.OwnerController, AeroplaneChessMode.OwnerController, "ServerRPC_SelectPlaneToFly", self.CurSelectedPlaneIndex);
    end
end

-- 托管按钮
function AC_Main_UI:Hosting_Button_OnClicked()
    local myTeamIndex = self:GetMyTeamIndex()
    print("AC_Main_UI:Hosting_Button_OnClicked"..tostring(myTeamIndex))
    log_tree_dev(UGCGameSystem.GameState.PlayerInfos[myTeamIndex])
    if myTeamIndex then
        local IsInAutoPlay = UGCGameSystem.GameState.PlayerInfos[myTeamIndex].IsInAutoPlay
        UnrealNetwork.CallUnrealRPC(AeroplaneChessMode.OwnerController, AeroplaneChessMode.OwnerController, "ServerRPC_SetAutoPlayMode", not IsInAutoPlay);
    end
end

-- 视角箭头
function AC_Main_UI:Jiantou_Button_OnClicked()
    if self.BJiantou then
        print("AC_Main_UI:Jiantou_Button_OnClicked true");
        self.VerticalBox_View:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
        self.BJiantou = false
    else
        print("AC_Main_UI:Jiantou_Button_OnClicked false");
        self.VerticalBox_View:SetVisibility(ESlateVisibility.Collapsed)
        self.BJiantou = true
    end
end
-- 全局按钮
function AC_Main_UI:Global_Button_OnClicked()
    print("AC_Main_UI:Global_Button_OnClicked");
    local PlayerController = GameplayStatics.GetPlayerController(self, 0);
    if PlayerController ~= nil then
        PlayerController:SetCameraState(ECameraState.GlobalCamera);
        PlayerController:SetCameraToTop(0.5);
        PlayerController:ResetCameraLocation();
        self.TextBlock_View:SetText("全局视角");
        if not self.BJiantou then
            print("AC_Main_UI:Global_Button_OnClicked false");
            self.VerticalBox_View:SetVisibility(ESlateVisibility.Collapsed)
            self.BJiantou = true
        end
    end
end

-- 自由视角按钮
function AC_Main_UI:FreeView_Button_OnClicked()
    print("AC_Main_UI:FreeView_Button_OnClicked");
    local PlayerController = GameplayStatics.GetPlayerController(self, 0);
    if PlayerController ~= nil then
        PlayerController:SetCameraState(ECameraState.FreeCamera);
        PlayerController:SetCameraToTop(0.5);
        self.TextBlock_View:SetText("自由视角");
        if not self.BJiantou then
            print("AC_Main_UI:FreeView_Button_OnClicked false");
            self.VerticalBox_View:SetVisibility(ESlateVisibility.Collapsed)
            self.BJiantou = true
        end
    end
end

-- 自动视角按钮
function AC_Main_UI:AutomaticPerspective_Button_OnClicked()
    print("AC_Main_UI:AutomaticPerspective_Button_OnClicked");
    local PlayerController = GameplayStatics.GetPlayerController(self, 0);
    if PlayerController ~= nil then
        PlayerController:SetCameraState(ECameraState.AutoCamera);
        PlayerController:ResetCameraLocation();
        PlayerController:SetCameraToTop(0.5);
        self.TextBlock_View:SetText("自动视角");
        if not self.BJiantou then
            print("AC_Main_UI:AutomaticPerspective_Button_OnClicked false");
            self.VerticalBox_View:SetVisibility(ESlateVisibility.Collapsed)
            self.BJiantou = true
        end
    end
end

-- 退出游戏按钮
function AC_Main_UI:Quit_Button_OnClicked()
    print("AC_Main_UI:Quit_Button_OnClicked");
    NetUtil.SendPkg("giveup_enter_game")
    LobbySystem.ReturnToLobby()
end

-- 点击GM按钮
function AC_Main_UI:GMGO_Button_OnClicked()
    ugcprint("AC_Main_UI:GMGO_Button_OnClicked");
    local commandStr = self.CommandInput:GetText()
    UnrealNetwork.CallUnrealRPC(AeroplaneChessMode.OwnerController, AeroplaneChessMode.OwnerController, "ServerRPC_ExecuteGMCommand", commandStr);
end

--点击起飞按钮
function AC_Main_UI:NewButton_TakeOff_OnClicked()
    UGCGameSystem.GameState.FirstFly = false;
    print("AC_Main_UI:NewButton_TakeOff_OnClicked  false");
    self.AC_Throw_UIBP:SetVisibility(ESlateVisibility.SelfHitTestInvisible)
    self.AC_Throw_UIBP.WidgetSwitcher_State:SetActiveWidgetIndex(1)
    self:ShowPlaneSelectionPanel(true)
end
return AC_Main_UI;