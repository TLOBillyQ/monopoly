--[[------------------------------------------UI管理器------------------------------------------------------]]--
AeroplaneChessUIManager = AeroplaneChessUIManager or {};

--[[------------------------------------------配置数据------------------------------------------------------]]--
AeroplaneChessUIManager.MainUIClassPath = UGCMapInfoLib.GetRootLongPackagePath().. "Asset/UI/UIBP/AC_Main_UI.AC_Main_UI_C";
AeroplaneChessUIManager.SettlementUIClassPath = UGCMapInfoLib.GetRootLongPackagePath().. "Asset/UI/UIBP/AC_Result_UIBP.AC_Result_UIBP_C";
AeroplaneChessUIManager.SettlementPlayerListItemClassPath = UGCMapInfoLib.GetRootLongPackagePath().. "Asset/UI/UIBP/Item/AC_ResultMate_Item_UIBP.AC_ResultMate_Item_UIBP_C";
AeroplaneChessUIManager.GuideUIClassPath = UGCMapInfoLib.GetRootLongPackagePath().. "Asset/UI/UIBP/AC_GameShows_UIBP.AC_GameShows_UIBP_C";

AeroplaneChessUIManager.DiceAnimConfigList = 
{
    [0] = 
    {
        IconPath = "Asset/UI/ItemIcon/DiceBrushAsset.DiceBrushAsset";
    };
    [1] = 
    {
        IconPath = "Asset/UI/ItemIcon/DiceBrushAsset_01.DiceBrushAsset_01";
    };
    [2] = 
    {
        IconPath = "Asset/UI/ItemIcon/DiceBrushAsset_02.DiceBrushAsset_02";
    };
    [3] = 
    {
        IconPath = "Asset/UI/ItemIcon/DiceBrushAsset_03.DiceBrushAsset_03";
    };
    [4] = 
    {
        IconPath = "Asset/UI/ItemIcon/DiceBrushAsset_04.DiceBrushAsset_04";
    };
    [5] = 
    {
        IconPath = "Asset/UI/ItemIcon/DiceBrushAsset_05.DiceBrushAsset_05";
    };
    [6] = 
    {
        IconPath = "Asset/UI/ItemIcon/DiceBrushAsset_06.DiceBrushAsset_06";
    };
}


--[[------------------------------------------动态数据------------------------------------------------------]]--
AeroplaneChessUIManager.MainUI = nil;
AeroplaneChessUIManager.SettlementUI = nil;

--[[------------------------------------------逻辑------------------------------------------------------]]--
function AeroplaneChessUIManager:Init()
	ugcprint("AeroplaneChessUIManager:Init");

    self:InitBaseUI();

    self:CreateMainUI();

    self:CreateStartGuideUI();
end

function AeroplaneChessUIManager:InitBaseUI()
	ugcprint("AeroplaneChessUIManager:InitBaseUI");

    -- 接口有问题，IOS上无法正常获取到
    -- local MainControlPanel = UGCWidgetManagerSystem.GetMainUI();
    local MainControlPanel = GameBusinessManager.GetWidgetFromName(ingame, "MainControlPanelTochButton_C");
    
    if MainControlPanel ~= nil then
        -- 隐藏和平的主界面UI、射击UI，保留设置和聊天按钮
        -- UGCWidgetManagerSystem.AddWidgetHiddenLayer(MainControlPanel.MainControlBaseUI)
        -- TODO: 应增加一些调整和平UI的接口
        local MainControlBaseUI = MainControlPanel.MainControlBaseUI;
        MainControlBaseUI.NavigatorPanel:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.Image_0:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.CanvasPanel_5:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.CanvasPanel_FreeCamera:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.InvalidationBox_TipsContainer:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.InvalidationBox_3:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.CanvasPanel_MiniMapAndSetting:AddAdvancedCollapsedCount(1);
        -- MainControlBaseUI.Canvas_Speaker:AddAdvancedCollapsedCount(1);
        -- MainControlBaseUI.Canvas_Microphone:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.Emote_SwimingControl:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.SignalReceivingAreaTIPS_UIBP:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.Border_TopPlatformTipsColor:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.BackPackPickUpPanel_BP_0:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.InvalidationBox_GM:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.PlayerInfoSocket:AddAdvancedCollapsedCount(1);
        MainControlBaseUI.IsNeedTeamPanel = false;

        -- UGCWidgetManagerSystem.AddWidgetHiddenLayer(MainControlPanel.ShootingUIPanel)
        -- 聊天面板在战斗UI中，需要显示
        local ShootingUIPanel = MainControlPanel.ShootingUIPanel;
        ShootingUIPanel.InvalidationBox_2:AddAdvancedCollapsedCount(1);
        ShootingUIPanel.CanvasPanel_16:AddAdvancedCollapsedCount(1);
        ShootingUIPanel.NewbieGuideCanvas:AddAdvancedCollapsedCount(1);
        ShootingUIPanel.Fade:AddAdvancedCollapsedCount(1);
    else
        print("Error: AeroplaneChessUIManager:InitBaseUI MainControlPanel == nil!");
    end
end

function AeroplaneChessUIManager:CreateMainUI()
	ugcprint("AeroplaneChessUIManager:CreateMainUI");
    local MainUIClass = UE.LoadClass(AeroplaneChessUIManager.MainUIClassPath);
    if MainUIClass == nil then
        print(string.format("Error: AeroplaneChessUIManager:CreateMainUI MainUIClass[%s] == nil!", AeroplaneChessUIManager.MainUIClassPath));
        return false;
    end

    local PlayerController = GameplayStatics.GetPlayerController(UGCGameSystem.GameState, 0);
    if PlayerController == nil then
        print("Error: AeroplaneChessUIManager:CreateMainUI PlayerController == nil!");
        return false;
    end

    self.MainUI = UserWidget.NewWidgetObjectBP(PlayerController, MainUIClass);
    if self.MainUI == nil then
        print("Error: AeroplaneChessUIManager:CreateMainUI MainUI == nil!");
        return false;
    end

    -- 这里不知为何会报错，暂时用下面这个
    -- UGCWidgetManagerSystem.AddChildToTochButton(self.MainUI)
    local TochButton = GameBusinessManager.GetWidgetFromName(ingame, "MainControlPanelTochButton_C");
    if TochButton ~= nil then
        -- 添加自定义按钮功能
        UIUtil.AttachTo(TochButton:GetWidgetFromName("CanvasPanel_IPX"), self.MainUI, 0, { Minimum = { X = 0, Y = 0 }, Maximum = { X = 1, Y = 1 } }, { Left = 0, Right = -1.5, Bottom = 0, Top = 0 })
        CustomizeUtils.ApplyAllUGCButtonsSetting(self.MainUI)
    else
        print("Error: TochButton is nil")
    end

    return AeroplaneChessUIManager.MainUI;
end

-- 创建并显示新手指引UI
function AeroplaneChessUIManager:CreateStartGuideUI()
	ugcprint("AeroplaneChessUIManager:CreateStartGuideUI");
    local GuideUIClass = UE.LoadClass(AeroplaneChessUIManager.GuideUIClassPath);
    if GuideUIClass == nil then
        print(string.format("Error: AeroplaneChessUIManager:CreateStartGuideUI GuideUIClass[%s] == nil!", AeroplaneChessUIManager.GuideUIClassPath));
        return false;
    end

    local PlayerController = GameplayStatics.GetPlayerController(UGCGameSystem.GameState, 0);
    if PlayerController == nil then
        print("Error: AeroplaneChessUIManager:CreateStartGuideUI PlayerController == nil!");
        return false;
    end

    self.StartGuideUI = UserWidget.NewWidgetObjectBP(PlayerController, GuideUIClass);
    if self.StartGuideUI == nil then
        print("Error: AeroplaneChessUIManager:CreateStartGuideUI StartGuideUI == nil!");
        return false;
    end

    self.StartGuideUI:AddToViewport(10051);
end


-- 创建结算界面UI
function AeroplaneChessUIManager:CreateSettlementUI()
	ugcprint("AeroplaneChessUIManager:CreateSettlementUI begin");
    local PlayerController = GameplayStatics.GetPlayerController(UGCGameSystem.GameState, 0);
    CommonUtils:AsyncLoadClass
    (PlayerController, AeroplaneChessUIManager.SettlementUIClassPath, 
        function (SettlementUIClass)
            if SettlementUIClass == nil then
                print(string.format("Error: AeroplaneChessUIManager:CreateSettlementUI SettlementUIClass[%s] == nil!", AeroplaneChessUIManager.SettlementUIClassPath));
                return false;
            end
            local PlayerController = GameplayStatics.GetPlayerController(UGCGameSystem.GameState, 0);

            if PlayerController == nil then
                print("Error: AeroplaneChessUIManager:CreateSettlementUI PlayerController == nil!");
                return false;
            end

            AeroplaneChessUIManager.SettlementUI = UserWidget.NewWidgetObjectBP(PlayerController, SettlementUIClass);
            if AeroplaneChessUIManager.SettlementUI ~= nil then
                ugcprint("AeroplaneChessUIManager:CreateSettlementUI SettlementUI")
                AeroplaneChessUIManager.SettlementUI:AddToViewport(10050);
            else
                print("Error: AeroplaneChessUIManager:CreateSettlementUI SettlementUI == nil!"); 
            end
            -- if IsWatching then
            --     ugcprint("AeroplaneChessUIManager:CreateSettlementUI IsWatching");
            --     AeroplaneChessUIManager.SettlementUI:SetVisibility(ESlateVisibility.Collapsed);
            --     AeroplaneChessUIManager.MainUI:OnPlayerContinueObserving();
            -- end
        end
     )
    --local SettlementUIClass = UE.LoadClass(AeroplaneChessUIManager.SettlementUIClassPath);

    -- if SettlementUIClass == nil then
    --     print(string.format("Error: AeroplaneChessUIManager:CreateSettlementUI SettlementUIClass[%s] == nil!", AeroplaneChessUIManager.SettlementUIClassPath));
    --     return false;
    -- end

    -- local PlayerController = GameplayStatics.GetPlayerController(UGCGameSystem.GameState, 0);

    -- if PlayerController == nil then
    --     print("Error: AeroplaneChessUIManager:CreateSettlementUI PlayerController == nil!");
    --     return false;
    -- end

    -- AeroplaneChessUIManager.SettlementUI = UserWidget.NewWidgetObjectBP(PlayerController, SettlementUIClass);
    -- if AeroplaneChessUIManager.SettlementUI ~= nil then
    --     ugcprint("AeroplaneChessUIManager:CreateSettlementUI SettlementUI")
    --     AeroplaneChessUIManager.SettlementUI:AddToViewport(10050);
    -- else
    --     print("Error: AeroplaneChessUIManager:CreateSettlementUI SettlementUI == nil!"); 
    -- end
end

-- 创建胜利界面UI
-- function AeroplaneChessUIManager:CreateWinUI()
-- 	ugcprint("AeroplaneChessUIManager:CreateWinUI");

--     local WinUIClass = UE.LoadClass(AeroplaneChessUIManager.WinUIClassPath);

--     if WinUIClass == nil then
--         print(string.format("Error: AeroplaneChessUIManager:CreateWinUI WinUIClass[%s] == nil!", AeroplaneChessUIManager.WinUIClassPath));
--         return false;
--     end

--     local PlayerController = GameplayStatics.GetPlayerController(UGCGameSystem.GameState, 0);

--     if PlayerController == nil then
--         print("Error: AeroplaneChessUIManager:CreateWinUI PlayerController == nil!");
--         return false;
--     end

--     AeroplaneChessUIManager.WinUI = UserWidget.NewWidgetObjectBP(PlayerController, WinUIClass);
--     if AeroplaneChessUIManager.WinUI ~= nil then
--         AeroplaneChessUIManager.WinUI:AddToViewport(10050);
--     else
--         print("Error: AeroplaneChessUIManager:CreateWinUI WinUI == nil!"); 
--     end
-- end
