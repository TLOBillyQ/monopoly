---@class UGCPlayerController_C:BP_STExtraPlayerController_C
--Edit Below--
local UGCPlayerController = {
    -- 顶部摄像机引用
    TopCamera = nil;
    -- 上次触摸时候的屏幕坐标
    LastTouchLocation = {
        x = 0,
        y = 0,
    };
    -- 第一根手指是否是第一次触摸
    FirstTouchOne = true;
    -- 第二根手指是否是第一次触摸
    FirstTouchTwo = true;
    -- 上次两指距离
    LastTwoFingerDistance = 0;
    -- 顶部摄像机缩放灵敏度
    TopCameraScaleSensitive = 3;
    -- 顶部摄像机移动灵敏度
    TopCameraMoveSensitive = 3;
    -- 是否开启手指控制顶部摄像机移动 全局控制
    EnableCameraMove = false;

    -- 摄像机是否可以移动
    CameraCanMove = false;
    -- 摄像机是否可以缩放
    CameraCanScale = false;
    -- 是否可以前后左右拖动 边界控制
    CanMoveForward = true;
    CanMoveBack = true;
    CanMoveLeft = true;
    CanMoveRight = true;
    -- [CS]当前摄像机状态 默认位全局相机
    CurrentCameraState = 3;

    -- [S]每种摄像机状态时间
    CameraStateTimeMap = {
        FreeCameraTime = 0,
        AutoCameraTime = 0,
        GlobalCameraTime = 0
    };

}; 

--注册Server RPC
function UGCPlayerController:GetAvailableServerRPCs()
    ugcprint("Regist Server_RPC")
    return 
    "ServerRPC_RollDice",
    "ServerRPC_SelectPlaneToFly",
    "ServerRPC_SetChessAvatar",
    "ServerRPC_SetAutoPlayMode",
    "ServerRPC_ExecuteGMCommand",
    "ServerRPC_ShowRemainTimeTips",
    "ServerRPC_ShowThrowTips",
    "ServerRPC_SetWatching",
    "ServerRPC_SetServerCameraState"
end

function UGCPlayerController:ReceiveBeginPlay()
    ugcprint("UGCPlayerController:ReceiveBeginPlay")
    self.bNeedResetCameraOnPossess = false;
    if self:HasAuthority() == true then 
        self.PrimaryActorTick.bCanEverTick = true;
        self.bAllowBPReceiveTickEvent = true;
        self.bAllowReceiveTickEventOnDedicatedServer = true
        -- 断线重连事件(包括静默重连和杀进程重连)（切后台、断网重连、杀进程重连都会有回调）
        self.PlayerControllerReconnectedDelegate:Add(self.PlayerControllerReconnected, self);
        self.PlayerControllerRecoveredDelegate:Add(self.PlayerControllerRecovered, self);
    else
        AeroplaneChessMode.OwnerController = self
        AeroplaneChessMode.OwnerPlayerKey = AeroplaneChessMode.OwnerController.PlayerKey;

        -- 加入队伍语音房间
        UGCVoiceManagerSystem.JoinVoiceRoom("AeroplaneVoiceRoomID")
        self:ActivateTouchInterface(nil)
        self.bAutoManageActiveCameraTarget = false;
        local CameraActors = GameplayStatics.GetAllActorsWithTag(self, "TopCamera")
        ugcprint("UGCPlayerController CameraActors num is:" .. #CameraActors)
        self.TopCamera = CameraActors[1];
        self.OnFingerMove:Add(self.OnTouchMove,self);
        self.OnReleaseScreen:Add(self.OnReleaseScreenCallBack,self);
        -- 将摄像机移到顶部
        self:SetCameraToTop(0);
        -- 监听棋子移动事件
        UGCEventSystem:AddListener(AeroplaneChessEventType.PlayerFlyPlane, self.OnPlayerFlyPlane, self);
        -- 断线重连事件(包括静默重连和杀进程重连)（仅在断线重连会有回调）
        -- self.OnReconnected:Add(self.OnClientReconnected, self);
    end
end

function UGCPlayerController:ReceiveTick(DeltaTime)
    if self:HasAuthority() == true then 
        if self.CurrentCameraState == ECameraState.FreeCamera then
            self.CameraStateTimeMap.FreeCameraTime = self.CameraStateTimeMap.FreeCameraTime + DeltaTime;
        elseif self.CurrentCameraState == ECameraState.AutoCamera then
            self.CameraStateTimeMap.AutoCameraTime = self.CameraStateTimeMap.AutoCameraTime + DeltaTime;
        elseif self.CurrentCameraState == ECameraState.GlobalCamera then
            self.CameraStateTimeMap.GlobalCameraTime = self.CameraStateTimeMap.GlobalCameraTime + DeltaTime;
        end
    end
end


-- [C]设置摄像机状态
function UGCPlayerController:SetCameraState(NewState)
    self.CurrentCameraState = NewState;
    UnrealNetwork.CallUnrealRPC(self, self, "ServerRPC_SetServerCameraState", NewState);
end

function UGCPlayerController:PlayerControllerReconnected()
    ugcprint("UGCPlayerController:PlayerControllerReconnected");
    UnrealNetwork.CallUnrealRPC(self, self, "OnPlayerHandleReconnected");
    self:OnPlayerReconnected();
end

function UGCPlayerController:PlayerControllerRecovered()
    ugcprint("UGCPlayerController:PlayerControllerRecovered");
    UnrealNetwork.CallUnrealRPC(self, self, "OnPlayerHandleReconnected");
    self:OnPlayerReconnected();
end

function UGCPlayerController:OnPlayerHandleReconnected()
    ugcprint("UGCPlayerController:OnPlayerHandleReconnected")
    if AeroplaneChessUIManager == nil then return end
    -- 重连后刷新UI
    if AeroplaneChessUIManager ~= nil and AeroplaneChessUIManager.MainUI ~= nil and UE.IsValid(AeroplaneChessUIManager.MainUI) then
        
    AeroplaneChessUIManager.MainUI:ForceUpdateUI()
    end
end

function UGCPlayerController:OnClientReconnected()
    ugcprint("UGCPlayerController:OnClientReconnected")
end


--[DS] 上报摄像机使用时间Tlog
function UGCPlayerController:TlogCameraStateUseTime()
    for i, v in pairs(self.CameraStateTimeMap) do
        print("UGCPlayerController:TlogCameraStateUseTime Key:" .. tostring(self.PlayerState.TeamIndex) .. "_" .. tostring(i) .. ",Value is:" .. tostring(math.floor(v)));
        NetUtil.SendPacketCustom(tostring(self.PlayerState.TeamIndex) .. "_" .. tostring(i), tostring(math.floor(v)));
    end
end

--(DS) 断线重连
function UGCPlayerController:OnPlayerReconnected()
    ugcprint("UGCPlayerController:OnPlayerReconnected");
    log_tree_dev("UGCPlayerController:OnPlayerReconnected PlayerInfos", UGCGameSystem.GameState.PlayerInfos);
    local TeamIndex = UGCGameSystem.GameState:GetTeamIndexWithPlayerKey(self.PlayerKey);
    if TeamIndex == nil then
        print("UGCPlayerController:OnPlayerReconnected Error: TeamIndex Is Nil");
        return
    end
    -- 是否处于观战模式
    if UGCGameSystem.GameState.PlayerInfos[TeamIndex].InWatching then
        ugcprint("UGCPlayerController:OnPlayerReconnected InWatching");
        UnrealNetwork.CallUnrealRPC(self, self, "ClientRPC_SetWatching");
    -- 全局结算时断线
    elseif UGCGameSystem.GameState.CurrentGamestate == EGameStatus.Result then
        ugcprint("UGCPlayerController:OnPlayerReconnected EGameStatus.Result");
        local SettlementDatas = UGCGameSystem.GameState:GetSettlementData();
        UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_PlayerFinishedGame", TeamIndex, SettlementDatas, false);        
    -- 个人结算时断线
    elseif UGCGameSystem.GameState.PlayerInfos[TeamIndex].EntryNum == 4 then
        ugcprint("UGCPlayerController:OnPlayerReconnected IsFinished");
        local SettlementDatas = UGCGameSystem.GameState:GetSettlementData();
        UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_PlayerFinishedGame", TeamIndex, SettlementDatas, false);
    end
    -- 更新玩家信息面板
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_PlayerPanel", UGCGameSystem.GameState.PlayerInfos);
    -- 更新剩余时间显示
    UnrealNetwork.CallUnrealRPC(self, self, "ClientRPC_ShowRemainTime");
end

function UGCPlayerController:ReceiveEndPlay()
    ugcprint("UGCPlayerController : ReceiveEndPlay")

    UGCEventSystem:RemoveListener(AeroplaneChessEventType.PlayerFlyPlane, self.OnPlayerFlyPlane, self);
end


function UGCPlayerController:OnRep_Pawn_BP()
    ugcprint("UGCPlayerController:OnRep_Pawn")
end

-- [C]设置摄像机到顶部
function UGCPlayerController:SetCameraToTop(blendTime) 
    if self.TopCamera == nil then
        print("UGCPlayerController:SetCameraToTop SetCameraToTop but topCamera is nil")
    end
    self:SetViewTargetWithBlend(self.TopCamera,blendTime,EViewTargetBlendFunction.VTBlend_Linear,0, false); 
    ugcprint("UGCPlayerController:SetCameraToTop SetViewTargetWithBlend end");
    self.EnableCameraMove = true;
end

-- 重置摄像机位置
function UGCPlayerController:ResetCameraLocation()
    if self.TopCamera ~= nil then
        if self.TopCamera.CameraOriLocation ~= nil then
            self.TopCamera:K2_SetActorLocation(self.TopCamera.CameraOriLocation);
        end
    end
end
 
function UGCPlayerController:OnTouchMove(FingerIndex, Location)
    if self.EnableCameraMove ~= true then
        print("UGCPlayerController:OnTouchMove EnableCameraMove is false");
        return;
    end
    ugcprint("UGCPlayerController:OnTouchMove:" .. FingerIndex)
    -- 只有一指 进行移动逻辑
    if FingerIndex == 0 and self.FirstTouchOne then
        self.CameraCanMove = true;
        self.CameraCanScale = false;
    end
    -- 两指同时，进入缩放逻辑
    if FingerIndex == 1 and self.FirstTouchTwo then
        self.CameraCanMove = false;
        self.CameraCanScale = true;
    end
    
    if self.CameraCanMove and self.CurrentCameraState ~= ECameraState.AutoCamera then
        if FingerIndex == 0 and self.FirstTouchOne then
        self.LastTouchLocation.x = Location.x;
        self.LastTouchLocation.y = Location.y;
            self.FirstTouchOne = false;
            ugcprint("UGCPlayerController:OnTouchMove FingerOne first touch")
        return;
        elseif FingerIndex == 0 and not self.FirstTouchOne then
        local ScreenOffset = {}
        -- 注意ScrrenOffset的Y变化对应的摄像机前后移动 X变化对应的左右移动
        ScreenOffset.x = -(Location.x - self.LastTouchLocation.x);
        ScreenOffset.y = (Location.y - self.LastTouchLocation.y);
        self:LimitScreenOffset(ScreenOffset)
        if self.TopCamera ~= nil then
            -- 因为是俯视角 所以前后方向拿到摄像机的UpVector,对应UE4 Z轴
            local ForwardVector = VectorHelper.ToLuaTable(self.TopCamera.SceneComponent:GetUpVector());
            -- forwardVector表示摄像机前后移动的方向，值为UpVector的去除掉Z轴分量的值然后标准化
            ForwardVector.z = 0;
            ForwardVector = KismetMathLibrary.Normal(ForwardVector);
            ForwardVector.x = ForwardVector.x * ScreenOffset.y * self.TopCameraMoveSensitive;
            ForwardVector.y = ForwardVector.y * ScreenOffset.y * self.TopCameraMoveSensitive;
            -- 左右方向拿到摄像机的RightVector,对应UE4 Y轴
            local RightVector = self.TopCamera.SceneComponent:GetRightVector()
            -- RightVector表示摄像机左右移动的方向，值为RightVector的去除掉Z轴分量的值然后标准化
            RightVector.z = 0;
            RightVector = KismetMathLibrary.Normal(RightVector);
            RightVector.x = RightVector.x * ScreenOffset.x * self.TopCameraMoveSensitive;
            RightVector.y = RightVector.y * ScreenOffset.x * self.TopCameraMoveSensitive;
            -- 最终的移动向量
            local moveOffset = {}
            moveOffset.x = ForwardVector.x + RightVector.x
            moveOffset.y = ForwardVector.y + RightVector.y
            local Sweep = self.TopCamera.SceneComponent:K2_AddWorldOffset(moveOffset, false,nil, false);
        end
        self.LastTouchLocation.x = Location.x;
        self.LastTouchLocation.y = Location.y;
    end
    elseif self.CameraCanScale and self.CurrentCameraState == ECameraState.FreeCamera then
        if FingerIndex == 1 and self.FirstTouchTwo then
            local IsTwoFinger,Distance = self:GetTwoFingerDistance();
            if IsTwoFinger then
                self.LastTwoFingerDistance = Distance;
            else
                print("UGCPlayerController:OnTouchMove CameraCanScale is True,But dont find two Finger Pressed");
            end
            self.FirstTouchTwo = false;
            return;
        elseif FingerIndex == 1 and not self.FirstTouchTwo then
            local IsTwoFinger,Distance = self:GetTwoFingerDistance();
            if IsTwoFinger then
                local ScaleValue = Distance - self.LastTwoFingerDistance;
                -- 摄像机缩放
                self.TopCamera:ScaleCamera(ScaleValue * self.TopCameraScaleSensitive);
                self.LastTwoFingerDistance = Distance;
            else
                print("UGCPlayerController:OnTouchMove self.FirstTouchTwo is false and CameraCanScale is True,But dont find two Finger Pressed");
            end
        end
    end
end

-- 获得两指距离
function UGCPlayerController:GetTwoFingerDistance()
    local LocationX_Finger1,LocationY_Finger1,IsPressed_Finger1 = self:GetInputTouchState(ETouchIndex.Touch1);
    local LocationX_Finger2,LocationY_Finger2,IsPressed_Finger2 = self:GetInputTouchState(ETouchIndex.Touch2);
    local Location_Finger1 = {X = LocationX_Finger1,Y = LocationY_Finger1};
    local Location_Finger2 = {X = LocationX_Finger2,Y = LocationY_Finger2};
    local Distance = VectorHelper.GetDistance2D(Location_Finger1,Location_Finger2);
    return IsPressed_Finger1 and IsPressed_Finger2,Distance
end

-- 根据是否到达地图边界限制MoveOffset的拖动
function UGCPlayerController:LimitScreenOffset(moveOffset)
    if self.CanMoveForward == false then
        if moveOffset.y > 0 then
            moveOffset.y = 0
        end
    end
    if self.CanMoveBack == false then
        if moveOffset.y < 0 then
            moveOffset.y = 0
        end
    end
    if self.CanMoveRight == false then
        if moveOffset.x > 0 then
            moveOffset.x = 0
        end
    end
    if self.CanMoveLeft == false then
        if moveOffset.x < 0 then
            moveOffset.x = 0
        end
    end
end

-- 当手指离开屏幕
function UGCPlayerController:OnReleaseScreenCallBack(FingerIndex)
    if self.EnableCameraMove ~= true then
        print("UGCPlayerController:OnReleaseScreenCallBack is false");
        return;
    end
    ugcprint("UGCPlayerController:OnReleaseScreenCallBack");
    if FingerIndex == 0 then
        self.FirstTouchOne = true
    elseif FingerIndex == 1 then
        self.FirstTouchTwo = true
    end
end

-- 切换视角到棋子上
function UGCPlayerController:SetCameraToPawn(Pawn)
    self:SetViewTargetWithBlend(Pawn,0.5,EViewTargetBlendFunction.VTBlend_Linear,0, false); 
end

-- 客户端玩家视角聚焦Pawn
function UGCPlayerController:FocusCameraToPawn(TeamIndex, PlaneIndex)
    ugcprint("UGCPlayerController:FocusCameraToPawn TeamIndex is" .. TeamIndex .. ",PlaneIndex is :" .. PlaneIndex);
    if self.CurrentCameraState ~= ECameraState.AutoCamera then
        return;
    end
    local Pawn = UGCGameSystem.GameState.PlayerInfos[TeamIndex].PlaneInfos[PlaneIndex];
    if Pawn ~= nil then
        self:SetCameraToPawn(Pawn)
    else
        print("UGCPlayerController:FocusCameraToPawn Pawn is nil");
    end
end

function UGCPlayerController:OnPlayerFlyPlane(TeamIndex, PlaneIndex, NumSteps)
    self:FocusCameraToPawn(TeamIndex, PlaneIndex)
end

--[[------------------------------------------ServerRPC------------------------------------------------------]]--

-- 设置服务器记录当前摄像机状态
function UGCPlayerController:ServerRPC_SetServerCameraState(NewCameraState)
    self.CurrentCameraState = NewCameraState;
end


-- 请求摇骰子
function UGCPlayerController:ServerRPC_RollDice()
    if self:HasAuthority() == false then return end
    ugcprint("UGCPlayerController:ServerRPC_RollDice");
    if UGCGameSystem.GameState:GetCurRoundPlayerInfo().PlayerKey ~= self.PlayerKey then
        ugcprint("UGCPlayerController:ServerRPC_RollDice Not Current Player!");
        return
    end
    UGCGameSystem.GameState:DoRollDice()
end

-- 请求移动某个棋子
function UGCPlayerController:ServerRPC_SelectPlaneToFly(PlaneIndex)
    if self:HasAuthority() == false then return end
    ugcprint("UGCPlayerController:ServerRPC_SelectPlaneToFly");
    if UGCGameSystem.GameState:GetCurRoundPlayerInfo().PlayerKey ~= self.PlayerKey then
        ugcprint("UGCPlayerController:ServerRPC_SelectPlaneToFly Not Current Player!");
        return
    end
    UGCGameSystem.GameState:DoFlyPlane(PlaneIndex)
end

-- 请求托管/取消托管
function UGCPlayerController:ServerRPC_SetAutoPlayMode(open)
    if self:HasAuthority() == false then return end
    ugcprint("UGCPlayerController:ServerRPC_SetAutoPlayMode "..tostring(open));
    -- 获取对应位置的玩家数据
    local PlayerInfo = UGCGameSystem.GameState:GetPlayerInfoWithPlayerKey(self.PlayerKey)
    
    if PlayerInfo ~= nil then
        PlayerInfo.IsInAutoPlay = open
        -- 打开托管时，立刻自动操作
        if open and AeroplaneChessMode.IsTeamIndexValid(UGCGameSystem.GameState.CurRoundTeamIndex) then
            UGCGameSystem.GameState:AutoCompleteRound()
        end
    end
end

-- 设置棋子的Avatar
function UGCPlayerController:ServerRPC_SetChessAvatar()
    if self:HasAuthority() == false then return end
    ugcprint("UGCPlayerController:ServerRPC_SetChessAvatar");

    local PlayerAvatarData = 
    {
        Gender = self.DefaultCharacterGender;
        PlayerName = self.PlayerName;
        AvatarItemIDList = {};
    }

    log_tree_dev("UGCPlayerController:ServerRPC_SetChessAvatar InitialItemList:", totable(self.InitialItemList))
    for _, ItemData in pairs(self.InitialItemList) do
        local ItemType = UGCItemSystem.GetItemType(ItemData.ItemTableID)
        local ItemSubType = UGCItemSystem.GetItemSubType(ItemData.ItemTableID)

        -- 4 类型为 Avatar
        -- 701 SubType为降落伞，需要过滤
        if ItemType == 4 and ItemSubType ~= 701 and ItemSubType ~= 411 then
            table.insert(PlayerAvatarData.AvatarItemIDList, ItemData.ItemTableID)
        end
    end

    for PlaneIndex, Plane in pairs(UGCGameSystem.GameState.PlayerInfos[self.PlayerState.TeamIndex].PlaneInfos) do
        Plane:SetAvatar(PlayerAvatarData)
    end
end

-- 执行来自客户端的GM命令
function UGCPlayerController:ServerRPC_ExecuteGMCommand(commandStr)
    ugcprint("UGCPlayerController:ServerRPC_ExecuteGMCommand:"..commandStr)
    local args = string.split(commandStr, " ")
    local command = args[1]
    if command == "setdice" and args[2] ~= nil then
        UGCGameSystem.GameState.GMSetDiceResult = tonumber(args[2])
    elseif command == "gotoend" and args[2] ~= nil and args[3] ~= nil then
        local teamIndex, planeIndex = tonumber(args[2]), tonumber(args[3])
        local playerInfo = UGCGameSystem.GameState.PlayerInfos[teamIndex]
        local plane = playerInfo.PlaneInfos[planeIndex]
        if plane ~= nil then
            plane.CurrentState = EPlaneState.Finished
            playerInfo.EntryNum = playerInfo.EntryNum + 1
            plane.CompletionTime = GameplayStatics.GetRealTimeSeconds(self) - UGCGameSystem.GameState.AeroplaneChessGameStartTime
            plane:GetController():SendPlaneHome()
            UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_PlaneReachedEndPoint", teamIndex, planeIndex);
        end
    elseif command == "StopDiceTimer" then
        if args[2] == "0" then
            UGCGameSystem.GameState.IsStopDiceTimer = false;
        else
            UGCGameSystem.GameState.IsStopDiceTimer = true;
        end

    end
end

-- 请求关闭剩余时间提示
function UGCPlayerController:ServerRPC_ShowRemainTimeTips(open)
    if self:HasAuthority() == false then return end
    ugcprint("UGCPlayerController:ServerRPC_ShowRemainTimeTips "..tostring(open));
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_ShowRemainTimeTips", open);
end

-- 请求关闭投掷提示
function UGCPlayerController:ServerRPC_ShowThrowTips(open)
    if self:HasAuthority() == false then return end
    ugcprint("UGCPlayerController:ServerRPC_ShowThrowTips "..tostring(open));
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_ShowThrowTips", open);
end

-- 请求观战
function UGCPlayerController:ServerRPC_SetWatching(open)
    if self:HasAuthority() == false then return end
    ugcprint("UGCPlayerController:ServerRPC_SetWatching "..tostring(open));
    local TeamIndex = UGCGameSystem.GameState:GetTeamIndexWithPlayerKey(self.PlayerKey);
    UGCGameSystem.GameState.PlayerInfos[TeamIndex].InWatching = open;
end
--[[------------------------------------------ClientRPC------------------------------------------------------]]--
-- 通知客户端展示选择棋子按钮，给定可选的棋子index
function UGCPlayerController:ClientRPC_StartPlaneSelection(CanChoosePlaneIndex)
    log_tree_dev("UGCPlayerController:ClientRPC_StartPlaneSelection", CanChoosePlaneIndex)
    if AeroplaneChessUIManager then
        AeroplaneChessUIManager.MainUI:ShowPlaneSelectionPanel(true);
    end
end

-- 通知客户端展示可以起飞或再投一次
function UGCPlayerController:ClientRPC_ShowCanFly(AtHomeNum, IsSix)
    ugcprint("UGCPlayerController:ClientRPC_ShowCanFly:  "..tostring(AtHomeNum));
    ugcprint("UGCPlayerController:ClientRPC_ShowCanFly:  "..tostring(IsSix));
    if AeroplaneChessUIManager then
        AeroplaneChessUIManager.MainUI.AC_56Tips:Show(AtHomeNum, IsSix);
    end
end

-- 客户端玩家回到顶部
function UGCPlayerController:ClientRPC_FocusCameraToTop()
    ugcprint("UGCPlayerController:ClientRPC_FocusCameraToTop");
    self:SetCameraToTop(0.5)
end

-- 客户端处于观战模式
function UGCPlayerController:ClientRPC_SetWatching()
    ugcprint("UGCPlayerController:ClientRPC_SetWatching");
    if AeroplaneChessUIManager then
        AeroplaneChessUIManager.MainUI:OnPlayerContinueObserving();
    end
end

-- 通知客户端显示剩余时间
function UGCPlayerController:ClientRPC_ShowRemainTime()
    ugcprint("ClientRPC_ShowRemainTime");
    if UGCGameSystem.GameState ~= nil then
        UGCGameSystem.GameState.ShowRemainTime = true;
    end
end

-- 通知客户端第一名玩家游戏胜利
-- function UGCPlayerController:ClientRPC_FirstPlayerWin()
--     ugcprint("ClientRPC_FirstPlayerWin");
--     AeroplaneChessUIManager.MainUI:OnFirstPlayerWin()
-- end
return UGCPlayerController;