---@class UGCGameState_C:BP_UGCGameState_C

require("Script.Common.UGCEventSystem");
require("Script.GameConfigs.AeroplaneChessAssetConfigs");
require("Script.GameConfigs.AeroplaneChessGlobalConfigs");
require("Script.GameConfigs.AeroplaneChessUIManager");
require("Script.GameConfigs.AeroplaneChessEventDefine");
require("Script.GameConfigs.AeroplaneChessAnimationConfigs");
require("Script.GameConfigs.AeroplaneChessMode");
require("Script.GameConfigs.AeroplaneChessAudioConfig");
require("Script.Common.VectorHelper");
require("Script.Common.TableHelper");
require("Script.Common.UGCBGMTools");
require("Script.Common.UGCSoundTools");
require("Script.Common.UGCParticleTools");
require("Script.Common.UGCAsyncLoadTools");
UGCGameSystem.UGCRequire('Script.Common.ue_enum_custom')
local UGCGameState = {
    -- 每个位置的信息数据
    PlayerInfos = {};
    -- 准备阶段剩余时间
    PrepareStageRemainTime = 0;
    -- 当前游戏状态
    CurrentGamestate = 0;
    -- 当前正在进行回合的位置(1-4)
    CurRoundTeamIndex = 0;
    -- 当前回合剩余时间
    CurRoundRemainTime = 0;
    -- 当前回合剩余时间提示
    ShowRemainTime = false;
    -- 当前投掷时间是否暂停
    IsStopDiceTimer = false;
    -- 当前回合投掷提示
    ShowThrowTips = false;
    -- 当前回合摇出的骰子值
    CurRoundDiceResult = 0;
    -- 当前回合状态
    CurRoundStatus = 0;
    -- 对局骰子
    DiceActor = nil;
    -- 当前回合的玩家是否可以再掷一次骰子
    CanPlayerStartAnotherRound = false;
    -- 是否是第一次起飞
    FirstFly = true;
    -- [C]客户端玩家面板
    PlayerPanelDatas = {};
    TilesList = {};
    HelicopterList = {};
    CurRoundFlyPlaneIndex = 0;
    -- BGM相关
    BGMState = 0;
    PlayingSound = {};
    -- 托管时长 放在PlayerInfos里会导致每帧同步，因此单独拿出来
    AutoPlayTotalTime = {};
}; 

function UGCGameState:GetReplicatedProperties()
    return 
    "PrepareStageRemainTime",
    "CurRoundRemainTime",
    "PlayerInfos",
    "CurRoundTeamIndex",
    "CurRoundStatus",
    "CurrentGamestate",
    "CurRoundFlyPlaneIndex",
    "BGMState",
    "DiceActor"
end

function UGCGameState:GetAvailableServerRPCs()
    return
end

function UGCGameState:ReceiveBeginPlay()
    print("UGCGameState:ReceiveBeginPlay")
	self.SuperClass.ReceiveBeginPlay(self);

    if self:HasAuthority() == true then 
        -- GameplayStatics.LoadStreamLevel(self,"ChrisTestMap",true,true);
        for TeamIndex = 1, 4 do
            self.AutoPlayTotalTime[TeamIndex] = 0
        end
    else
        -- 客户端初始化UI
        AeroplaneChessUIManager:Init()
        -- 预加载粒子效果
        -- if not AeroplaneChessMode.OwnerController then
        --     AeroplaneChessMode.OwnerController = GameplayStatics.GetPlayerController(self, 0);
        --     if UE.IsValid(AeroplaneChessMode.OwnerController) then
        --         AeroplaneChessMode.OwnerPlayerKey = AeroplaneChessMode.OwnerController.PlayerKey;
        --     end
        -- end
        -- 预加载粒子效果
        UGCParticleTools:PreLoad()
    end

    -- 初始化骰子
    local DicePath = UGCMapInfoLib.GetRootLongPackagePath().. "Asset/Blueprint/Items/Dice.Dice_C"
    local DiceClass = UE.LoadClass(DicePath)
    local DiceActor = ScriptGameplayStatics.SpawnActor(self, DiceClass, { X = 0, Y = 0, Z = 0 }, { Roll = 0, Pitch = 0, Yaw = 0 }, { X = 1, Y = 1, Z = 1 })
    self.DiceActor = DiceActor

    -- 对于客户端，PlayerInfos的Onrep可能早于此处调用，此时不能再用初始数据覆盖
    if #self.PlayerInfos ~= 4 then 
        -- 初始化四个位置的信息
        for TeamIndex = 1, 4 do
            self.PlayerInfos[TeamIndex] = {
                PlayerKey = nil,        -- 对应的玩家
                IsInAutoPlay = true,    -- 是否托管
                PlaneInfos = {},        -- 4个棋子的Pawn
                -- 结算相关
                UID = nil;
                PlayerName = nil;
                Gender = nil;
                EntryNum = 0;
                EliminateNum = 0;
                CompletionTime = 9999;
                InWatching = false;  -- 是否处于观战
                -- tlog上报
                GetKickedTimes = 0;       -- 棋子被淘汰次数
            }
        end
        self:FindAllAeroplanePawn()
    end
    self:FindAllTills()
    self:FindAllHelicopters()
    UGCBGMTools:Init()

    if self:HasAuthority() ~= true then 
        -- 检查棋子是否完成，如果完成则加上皇冠
        for TeamIndex = 1, 4 do
            for PlaneIndex = 1, 4 do
                UGCGameSystem.GameState.PlayerInfos[TeamIndex].PlaneInfos[PlaneIndex]:CheckChessComplete();
            end
        end
    end
end

function UGCGameState:ReceiveEndPlay()
    -- 释放引用
    self.TilesList = {}
    self.HelicopterList = {}
end

function UGCGameState:ReceiveTick(DeltaTime)
    if self:HasAuthority() then 
        UGCBGMTools:ServerTick()
        -- 累计托管时长
        if self.CurrentGamestate == EGameStatus.Gaming then
            for TeamIndex = 1, 4 do
                if self:HasTeamFinishedGame(TeamIndex) == false then
                    if self.PlayerInfos[TeamIndex].IsInAutoPlay == true then
                        self.AutoPlayTotalTime[TeamIndex] = self.AutoPlayTotalTime[TeamIndex] + DeltaTime
                    end
                end
            end
        end
    else
        UGCBGMTools:ClientTick()
    end
end

-- （DS、客户端）获取当前回合的玩家信息
function UGCGameState:GetCurRoundPlayerInfo()
    return self.PlayerInfos[self.CurRoundTeamIndex];
end

-- （DS）执行摇骰子逻辑
function UGCGameState:DoRollDice()
    if self.CurRoundStatus ~= ERoundStatus.WaitForRollDice then return end
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_ShowThrowTips", false);
    -- 随机获取骰子结果
    local DiceResult = self.DiceActor:GetRandomResult();
    if self.GMSetDiceResult ~= nil and self.GMSetDiceResult >= 1 and self.GMSetDiceResult <= 6 then
        DiceResult = self.GMSetDiceResult
        self.GMSetDiceResult = nil
    end
    print("UGCGameState:DoRollDice Result "..tostring(DiceResult));
    self.CurRoundDiceResult = DiceResult
    -- 回合进入骰子动画中状态
    self.CurRoundStatus = ERoundStatus.DiceRolling
    UnrealNetwork.CallUnrealRPC_Multicast(self, "Multicast_RollDiceResult", self.CurRoundTeamIndex, DiceResult);
    -- 标记，回合结束时可再掷一次骰子
    if DiceResult == 6 then
        self.CanPlayerStartAnotherRound = true
    end
    
    -- 等待骰子动画
    local DiceRollingTimerDelegate = ObjectExtend.CreateDelegate(self, 
        function()
            if self.CurRoundStatus == ERoundStatus.DiceRolling then
                -- 回合进入等待选择棋子状态
                self.CurRoundStatus = ERoundStatus.WaitForPlaneSelection
                self:SelectPlaneAndFly()
            end
        end
    )
    KismetSystemLibrary.K2_SetTimerDelegateForLua(DiceRollingTimerDelegate, self, AeroplaneChessAnimationConfigs.DiceRollingTime, false)
end

-- （DS）自动选择棋子移动，或等待玩家选择棋子移动
function UGCGameState:SelectPlaneAndFly()
    if self.CurRoundStatus ~= ERoundStatus.WaitForPlaneSelection then return end
    local SelectedPlaneIndex = self:GetAutoPlaneSelection(self.CurRoundDiceResult)
    -- 无可移动的棋子时，直接结束回合
    if SelectedPlaneIndex == false then
        ugcprint("UGCGameState:SelectPlaneAndFly, No Plane Can Move, Round End!")
        self.CurRoundStatus = ERoundStatus.RoundEnd
        LuaQuickFireEvent("PlayerRoundEnd", self)
        return
    end
    local PlayerInfo = self:GetCurRoundPlayerInfo()
    -- 有可移动的棋子，分自动和手动选择两种情况，自动选择条件：
    -- 1、玩家开启托管
    -- 2、回合时间结束
    -- 3、该位置无玩家
    -- 4、已有三个棋子到达终点，只剩一个棋子可移动
    if PlayerInfo.IsInAutoPlay or self.CurRoundRemainTime <= 0 or PlayerInfo.PlayerKey == nil or PlayerInfo.EntryNum == 3 then
        ugcprint("UGCGameState:SelectPlaneAndFly, Auto Select Plane:"..SelectedPlaneIndex)
        self:DoFlyPlane(SelectedPlaneIndex)
    else
        ugcprint("UGCGameState:SelectPlaneAndFly, Wait For Player To Select Plane")
        local CanChoosePlaneIndex = {}
        
        local PlaneInfos = PlayerInfo.PlaneInfos
        local AtHomeNum = 0;
        for i, plane in pairs(PlaneInfos) do
            -- 对于已经到达的棋子，以及未摇到56无法出发的棋子，按钮不可用
            if plane.CurrentState ~= EPlaneState.Finished and (self.CurRoundDiceResult >= 5 or plane.CurrentState ~= EPlaneState.AtHome) then
                table.insert(CanChoosePlaneIndex, i)
            end
            if plane.CurrentState == EPlaneState.AtHome then
                AtHomeNum = AtHomeNum + 1;
            end
        end
        
        -- 通知客户端显示选择棋子面板
        local PlayerKey = self.PlayerInfos[self.CurRoundTeamIndex].PlayerKey
        local PlayerController = UGCGameSystem.GetPlayerControllerByPlayerKey(PlayerKey)
        UnrealNetwork.CallUnrealRPC(PlayerController, PlayerController, "ClientRPC_StartPlaneSelection", CanChoosePlaneIndex)

        --通知客户端显示起飞、再投一次提示
        if self.CurRoundDiceResult >=5 then
            if self.CurRoundDiceResult == 6 then
                UnrealNetwork.CallUnrealRPC(PlayerController, PlayerController, "ClientRPC_ShowCanFly", AtHomeNum, true);
            else
                UnrealNetwork.CallUnrealRPC(PlayerController, PlayerController, "ClientRPC_ShowCanFly", AtHomeNum, false);
            end
        end
    end
end


-- （DS）执行棋子移动逻辑
function UGCGameState:DoFlyPlane(PlaneIndex)
    print("UGCGameState:DoFlyPlane "..PlaneIndex);
    if self.CurRoundStatus ~= ERoundStatus.WaitForPlaneSelection then return end
    -- 改变棋子状态
    local plane = self:GetCurRoundPlayerInfo().PlaneInfos[PlaneIndex]
    if plane == nil then
        print("ERROR: UGCGameState:DoFlyPlane plane is nil!")
        return
    end
    if plane.CurrentState == EPlaneState.AtHome then
        if self.CurRoundDiceResult < 5 then
            -- 点数不足以起飞时，不允许移动AtHome的棋子
            print("ERROR: UGCGameState:DoFlyPlane DiceResult lower than 5, cannot takeoff!");
            return
        else
            -- 起飞~
            plane.CurrentState = EPlaneState.Ready
        end
    elseif plane.CurrentState == EPlaneState.Ready then
        -- 从待机区飞出
        plane.CurrentState = EPlaneState.InFlight
    elseif plane.CurrentState == EPlaneState.InFlight then
    end
    self.CurRoundFlyPlaneIndex = PlaneIndex

    self.CurRoundStatus = ERoundStatus.PlaneFlying
    -- 通知客户端棋子开始移动
    UnrealNetwork.CallUnrealRPC_Multicast(self, "Multicast_PlayerFlyPlane", self.CurRoundTeamIndex, PlaneIndex, self.CurRoundDiceResult);
    UnrealNetwork.CallUnrealRPC_Multicast(self, "Multicast_ShowRemainTimeTips", false);
    -- 起飞时，只能从家里到待机区，走一步
    local step = plane.CurrentTileIndex == plane:GetStartTileIndex() and 1 or self.CurRoundDiceResult
    local AIController = plane:GetController()
    if AIController == nil then
        print('ERROR: UGCGameState:DoFlyPlane AIController is nil ')
        return
    end
    AIController:MoveNumSteps(step)

    -- local PlayerKey = self:GetCurRoundPlayerInfo().PlayerKey
    -- local PlayerController = UGCGameSystem.GetPlayerControllerByPlayerKey(PlayerKey)
    -- if PlayerController then
    --     -- 过渡相机到角色第一人称
    --     PlayerController:SetCameraToPawn(plane)
    -- end
end

-- （DS）根据当前进度，自动完成回合
function UGCGameState:AutoCompleteRound()
    -- local PlayerKey = self.PlayerInfos[self.CurRoundTeamIndex].PlayerKey
    -- local PlayerController = UGCGameSystem.GetPlayerControllerByPlayerKey(PlayerKey)
    
    -- 本回合还没操作完，则进行自动回合
    if self.CurRoundStatus == ERoundStatus.WaitForRollDice then 
        self:DoRollDice()
    elseif self.CurRoundStatus == ERoundStatus.WaitForPlaneSelection then 
        self:SelectPlaneAndFly()
    end
end

-- （DS）棋子结束飞行
function UGCGameState:PlaneFinishedFlying(HasReachedEndPoint)
    ugcprint("UGCGameState:PlaneFinishedFlying");
    local playerInfo = self:GetCurRoundPlayerInfo()
    local plane = playerInfo.PlaneInfos[self.CurRoundFlyPlaneIndex]
    if HasReachedEndPoint then
        print("UGCGameState:PlaneFinishedFlying Plane HasReachedEndPoint Index:"..tostring(self.CurRoundFlyPlaneIndex));
        -- 棋子到达终点
        plane.CurrentState = EPlaneState.Finished
        playerInfo.EntryNum = playerInfo.EntryNum + 1
        plane.CompletionTime = GameplayStatics.GetRealTimeSeconds(self) - UGCGameSystem.GameState.AeroplaneChessGameStartTime
        plane:GetController():SendPlaneHome()
        -- 广播通知客户端
        UnrealNetwork.CallUnrealRPC_Multicast(self, "Multicast_PlaneReachedEndPoint", self.CurRoundTeamIndex, self.CurRoundFlyPlaneIndex);
    end
    self.CurRoundStatus = ERoundStatus.RoundEnd
    LuaQuickFireEvent("PlayerRoundEnd", self)
end

function UGCGameState:CheckIfSendOtherPlaneHome()
    ugcprint("UGCGameState:CheckIfSendOtherPlaneHome");

    -- 是否踩到别的棋子
    local playerInfo = self:GetCurRoundPlayerInfo()
    local plane = playerInfo.PlaneInfos[self.CurRoundFlyPlaneIndex]
    local planesOnTile = plane:GetCurTile():GetPlanesOnThisTile()
    if #planesOnTile > 1 then
        print("UGCGameState:PlaneFinishedFlying #planesOnTile:"..#planesOnTile);
        local hasKickedPlane = false
        for _, planeToKick in pairs(planesOnTile) do
            -- 可不能把自己踩回家了
            if planeToKick.TeamIndex ~= plane.TeamIndex then
                planeToKick.CurrentState = EPlaneState.AtHome
                planeToKick:GetController():SendPlaneHome()
                hasKickedPlane = true
                -- 记录淘汰棋子数
                playerInfo.EliminateNum = playerInfo.EliminateNum + 1
                -- 记录被淘汰棋子数
                self.PlayerInfos[planeToKick.TeamIndex].GetKickedTimes = self.PlayerInfos[planeToKick.TeamIndex].GetKickedTimes + 1
                -- 淘汰棋子
                UnrealNetwork.CallUnrealRPC_Multicast(self, "Multicast_PlaneKillPlane", plane.TeamIndex, planeToKick.TeamIndex);
            end
        end
        if hasKickedPlane then
            self:ResetTilePawn(plane.CurrentTileIndex);
        end
    end
end


function UGCGameState:SendPlaneHomeByTileID(tileID)
    ugcprint("UGCGameState:SendPlaneHomeByTileID");

    local playerInfo = self:GetCurRoundPlayerInfo()
    local plane = playerInfo.PlaneInfos[self.CurRoundFlyPlaneIndex]
    local planesOnTile = self.TilesList[tileID]:GetPlanesOnThisTile()
    if #planesOnTile > 0 then
        print("UGCGameState:SendPlaneHomeByTileID #planesOnTile:"..#planesOnTile);
        for _, planeToKick in pairs(planesOnTile) do
            -- 可不能把自己踩回家了
            if planeToKick.TeamIndex ~= plane.TeamIndex then
                planeToKick.CurrentState = EPlaneState.AtHome
                planeToKick:GetController():SendPlaneHome()
                -- 记录淘汰棋子数
                playerInfo.EliminateNum = playerInfo.EliminateNum + 1
                -- 记录被淘汰棋子数
                self.PlayerInfos[planeToKick.TeamIndex].GetKickedTimes = self.PlayerInfos[planeToKick.TeamIndex].GetKickedTimes + 1
                -- 淘汰棋子
                UnrealNetwork.CallUnrealRPC_Multicast(self, "Multicast_PlaneKillPlane", plane.TeamIndex, planeToKick.TeamIndex);
            end
        end
    end
end

function UGCGameState:FindAllTills()
    print("Chris : UGCGameState:FindAllTills")
    local classPath = UGCMapInfoLib.GetRootLongPackagePath().. "Asset/Blueprint/SceneObjects/Tile.Tile_C"
    local actorClass = UE.LoadClass(classPath)

    if actorClass then
        local actorList = GameplayStatics.GetAllActorsOfClass(self, actorClass, {})
        for _, actor in pairs(actorList) do
            self.TilesList[actor.Index] = actor
        end
        -- log_tree("Chris : UGCGameState:FindAllTills" , self.TilesList)
    end
end

function UGCGameState:FindAllHelicopters()
    print("Chris : UGCGameState:FindAllHelicopters")
    local classPath = UGCMapInfoLib.GetRootLongPackagePath().. "Asset/Blueprint/SceneObjects/Helicopter.Helicopter_C"
    local actorClass = UE.LoadClass(classPath)

    if actorClass then
        local actorList = GameplayStatics.GetAllActorsOfClass(self, actorClass, {})
        for _, actor in pairs(actorList) do
            self.HelicopterList[actor.TeamID] = actor
        end
        -- log_tree("Chris : UGCGameState:FindAllHelicopterList" , self.HelicopterList)
    end
end

-- （客户端）找到某个地砖的上一块地砖
function UGCGameState:FindPrevTileIndex(TileIndex)
    for _, tile in pairs(self.TilesList) do
        if tile.NextIndex == TileIndex then
            return tile.Index
        end
    end
    return false
end

function UGCGameState:FindAllAeroplanePawn()
    print("Chris : UGCGameState:FindAllAeroplanePawn")
    -- local classPath = UGCMapInfoLib.GetRootLongPackagePath().."Asset/Blueprint/AeroplanePawn.AeroplanePawn_C"
    local classPath = UGCMapInfoLib.GetRootLongPackagePath().."Asset/Blueprint/Items/Chess.Chess_C"
    local actorClass = UE.LoadClass(classPath)

    if actorClass then
        local actorList = GameplayStatics.GetAllActorsOfClass(self, actorClass, {})
        if actorList ~= nil and #actorList > 0 then
            for _, actor in pairs(actorList) do
                if AeroplaneChessMode.IsTeamIndexValid(actor.TeamIndex) and self:IsPlaneIndexValid(actor.Index) then
                    self.PlayerInfos[actor.TeamIndex].PlaneInfos[actor.Index] = actor
                    if self:HasAuthority() == true then 
                        -- 初始化棋子状态
                        actor.CurrentState = EPlaneState.AtHome
                    end
                end
            end
        end
        log_tree("Chris : UGCGameState:FindAllAeroplanePawn" , self.PlayerInfos)
    end
end

-- （DS）给指定玩家分配一个位置
function UGCGameState:DisTributeTeamForPlayer(PlayerState)
    if PlayerState.TeamIndex ~= 0 then return end
    -- 随机找一个未占用的位置
    local availableTeamIndex = {}
    for TeamIndex = 1, 4 do 
        if self.PlayerInfos[TeamIndex].PlayerKey == nil then
            table.insert(availableTeamIndex, TeamIndex)
        end
    end
    if #availableTeamIndex <= 0 then return end

    local teamIndex = availableTeamIndex[math.random(#availableTeamIndex)]
    local PlayerInfo = self.PlayerInfos[teamIndex]
    -- 找第一个未分配过的位置分配
    if PlayerInfo.PlayerKey == nil then
        print(string.format("UGCGameState:DisTributeTeamForPlayer:Player[%d] -> TeamIndex[%d]", PlayerState.PlayerKey, teamIndex))
        PlayerInfo.PlayerKey = PlayerState.PlayerKey
        PlayerInfo.IsInAutoPlay = PlayerState.bIsInactive
        PlayerState.TeamIndex = teamIndex
        -- 结算相关数据
        local PlayerAccountInfo = UGCPlayerStateSystem.GetPlayerAccountInfo(PlayerState.PlayerKey):Copy();
        PlayerInfo.UID = PlayerState.UID;
        PlayerInfo.PlayerName = PlayerState.PlayerName;
        PlayerInfo.Gender = PlayerAccountInfo.PlatformGender;
        PlayerInfo.IconURL = PlayerState.IconURL;
        PlayerInfo.PlayerLevel = PlayerState.PlayerLevel;
        PlayerInfo.FrameLevel = PlayerState.SegmentLevel;
        -- 修改avatar
        local PlayerController = UGCGameSystem.GetPlayerControllerByPlayerKey(PlayerState.PlayerKey)
        if PlayerController ~= nil then
            PlayerController:ServerRPC_SetChessAvatar();
        end
        
    end
end

--[[------------------------------------------Getter------------------------------------------------------]]--
-- （DS）根据骰子结果，选择一个移动的棋子
function UGCGameState:GetAutoPlaneSelection(DiceResult)
    ugcprint("UGCGameState:GetAutoPlaneSelection"..DiceResult);
    local AllPlanes = self:GetCurRoundPlayerInfo().PlaneInfos
    local PlanesAtHome = {}
    local PlanesInFlight = {}
    for i, plane in pairs(AllPlanes) do
        if plane.CurrentState == EPlaneState.AtHome then
			table.insert(PlanesAtHome, i)
        elseif plane.CurrentState == EPlaneState.Ready or plane.CurrentState == EPlaneState.InFlight then
			table.insert(PlanesInFlight, i)
        end
    end

    -- 某个棋子能到达终点时，移动该棋子
    for _, planeIndex in pairs(PlanesInFlight) do
        local curTile = AllPlanes[planeIndex]:GetCurTile()
        for i = 1, self.CurRoundDiceResult do
            curTile = UGCGameSystem.GameState.TilesList[curTile.NextIndex]
            if curTile == nil then break end
        end
        if curTile ~= nil and curTile:IsEndPointTile() then
            print("UGCGameState:GetAutoPlaneSelection Choose Plane That Can Reach EndPoint");
            return planeIndex
        end
    end

    -- 能起飞时，起飞在家的棋子
    if DiceResult >= 5 and #PlanesAtHome > 0 then
        return PlanesAtHome[math.random(#PlanesAtHome)]
    end

    -- 移动未到达的棋子
    if #PlanesInFlight > 0 then
        return PlanesInFlight[math.random(#PlanesInFlight)]
    end
    -- 无可移动的棋子
    return false
end

-- (DS)返回目标砖块已有玩家Pawn
function UGCGameState:GetTileStandPawnList(TargetTileIndex)
    local Tile = self.TilesList[TargetTileIndex];
    local PawnList = Tile:GetPlanesOnThisTile();
    print(string.format("UGCGameState:GetTileStandPawnList:TargetTileIndex[%s] PawnNum[%s]", tostring(TargetTileIndex), tostring(#PawnList)))
    return PawnList;
end

-- （Ds）将目标砖块的pawn移动到对应位置，给将要到来的Pawn留出最后一个空位置
function UGCGameState:MakeTileHaveEmptySlot(Tile,PawnList)
    -- 砖块上原本有多少玩家
    local PawnNum = #PawnList;
    print("UGCGameState:MakeTileHaveEmptySlot,PawnNum is ".. tostring(PawnNum))
    if PawnNum == 1 then
        PawnList[1]:PawnMoveToLocation(Tile:GetTwoPlayerTileLocation(1));
    elseif PawnNum == 2 then
        PawnList[1]:PawnMoveToLocation(Tile:GetThreePlayerTileLocation(1));
        PawnList[2]:PawnMoveToLocation(Tile:GetThreePlayerTileLocation(2));
    elseif PawnNum == 3 then
        PawnList[1]:PawnMoveToLocation(Tile:GetFourPlayerTileLocation(1));
        PawnList[2]:PawnMoveToLocation(Tile:GetFourPlayerTileLocation(2));
        PawnList[3]:PawnMoveToLocation(Tile:GetFourPlayerTileLocation(3));
    end
end

-- （Ds）将目标砖块上的玩家重置到对应位置
function UGCGameState:ResetTilePawn(TileIndex)
    print("UGCGameState:ResetTilePawn,TileIndex is ".. tostring(TileIndex))
    local PawnList = self:GetTileStandPawnList(TileIndex);
    local Tile = self.TilesList[TileIndex];
    -- 砖块上有多少玩家
    local PawnNum = #PawnList;
    if PawnNum == 1 then
        PawnList[1]:PawnMoveToLocation(Tile:GetOnePlayerLocation());
    elseif PawnNum == 2 then
        PawnList[1]:PawnMoveToLocation(Tile:GetTwoPlayerTileLocation(1));
        PawnList[2]:PawnMoveToLocation(Tile:GetTwoPlayerTileLocation(2));
    elseif PawnNum == 3 then
        PawnList[1]:PawnMoveToLocation(Tile:GetThreePlayerTileLocation(1));
        PawnList[2]:PawnMoveToLocation(Tile:GetThreePlayerTileLocation(2));
        PawnList[3]:PawnMoveToLocation(Tile:GetThreePlayerTileLocation(3));
    elseif PawnNum == 4 then
        PawnList[1]:PawnMoveToLocation(Tile:GetFourPlayerTileLocation(1));
        PawnList[2]:PawnMoveToLocation(Tile:GetFourPlayerTileLocation(2));
        PawnList[3]:PawnMoveToLocation(Tile:GetFourPlayerTileLocation(3));
        PawnList[4]:PawnMoveToLocation(Tile:GetFourPlayerTileLocation(4));
    end
end

-- （DS）获取当前结算数据
function UGCGameState:GetSettlementData()
	ugcprint("UGCGameState:GetSettlementData")
    local PlayerResultDatas = {}
	for _, playerInfo in pairs(self.PlayerInfos) do
        local PlayerResultData = 
        {
            UID = playerInfo.UID;
            PlayerKey = playerInfo.PlayerKey;
            PlayerName = playerInfo.PlayerName;
            Gender = playerInfo.Gender;
            EntryNum = playerInfo.EntryNum;
            EliminateNum = playerInfo.EliminateNum;
            CompletionTime = playerInfo.CompletionTime;
            IconURL = playerInfo.IconURL;
            PlayerLevel = playerInfo.PlayerLevel;
            FrameLevel = playerInfo.SegmentLevel;
            PlaneCompletionTime = { }
        };
        for i = 1, 4 do
            PlayerResultData.PlaneCompletionTime[i] = playerInfo.PlaneInfos[i].CompletionTime
        end
        table.insert(PlayerResultDatas, PlayerResultData)
    end
    return PlayerResultDatas
end

-- （DS、客户端）根据PlayerKey获取玩家信息
function UGCGameState:GetPlayerInfoWithPlayerKey(PlayerKey)
    for TeamIndex = 1, 4 do
        if self.PlayerInfos[TeamIndex].PlayerKey == PlayerKey then
            return self.PlayerInfos[TeamIndex]
        end
    end
    return nil
end

-- （DS、客户端）根据PlayerKey获取玩家队伍
function UGCGameState:GetTeamIndexWithPlayerKey(PlayerKey)
    for TeamIndex = 1, 4 do
        if self.PlayerInfos[TeamIndex].PlayerKey == PlayerKey then
            return TeamIndex
        end
    end
    return nil
end

-- （DS）玩家是否在线
function UGCGameState:IsValidOnlinePlayer(PlayerKey)
    if PlayerKey == nil then return false end
	local PlayerState = UGCGameSystem.GetPlayerStateByPlayerKey(PlayerKey)
    if PlayerState == nil or PlayerState.bIsInactive then return false end
    return true
end

--[[------------------------------------------Checker------------------------------------------------------]]--
-- （DS、客户端）骰子结果是否正常
function UGCGameState:IsDiceResultValid(DiceResult)
    return DiceResult >= 1 and DiceResult <= 6
end

-- （DS、客户端）棋子index是否正常
function UGCGameState:IsPlaneIndexValid(Index)
    return Index >= 1 and Index <= 4
end

-- （DS、客户端）游戏是否结束（3个玩家结束游戏）
function UGCGameState:IsAeroplaneChessGameFinished()
    local FinishedPlayerNum = 0
    for TeamIndex = 1, 4 do
        if self:HasTeamFinishedGame(TeamIndex) then
            FinishedPlayerNum = FinishedPlayerNum + 1
        end
	end
    return FinishedPlayerNum >= 3
end

-- （DS、客户端）某个位置的玩家是否已经结束游戏
function UGCGameState:HasTeamFinishedGame(TeamIndex)
    return self.PlayerInfos[TeamIndex].EntryNum == 4
end

-- (DS)将所有玩家的视角聚焦于顶部摄像机
function UGCGameState:SetAllPlayerFocusToTopCamera()
    print("UGCGameState:SetAllPlayerFocusToTopCamera")
    local PlayerControllerList = UGCGameSystem.GetAllPlayerController()
	for _, PlayerController in ipairs(PlayerControllerList) do
		if PlayerController then
            -- 所有playercontroller执行clint函数将视角拉到TopCamera
            UnrealNetwork.CallUnrealRPC(PlayerController, PlayerController, "ClientRPC_FocusCameraToTop", nil)
        end
    end
end


function UGCGameState:StartTransmitFly(loc)
    print("UGCGameState:StartTransmitFly")
    self:AttachChessToHelicopter(self:GetCurrentRoundPlane(),self.HelicopterList[self.CurRoundTeamIndex])

    UnrealNetwork.CallUnrealRPC_Multicast(self,"Multicast_StartTransmitFly")
    self:Multicast_StartTransmitFly(loc) --DS也跑，DS模拟行为
    -- self:SetCurrentTransmitActorVisiable(false)
    -- self:TransmitPlane(loc)
end

function UGCGameState:AttachChessToHelicopter(chess,helicopter)
    print("UGCGameState:AttachChessToHelicopter")

    chess.bIsTransmitting = true
    local movementCompoent = chess.CharacterMovement
    movementCompoent:SetMovementMode(EMovementMode.MOVE_None)
    movementCompoent:Deactivate()


    -- local animPath = UGCMapInfoLib.GetRootLongPackagePath().. "Asset/Blueprint/Animation/ChessDriveMontage.ChessDriveMontage"
    -- UnrealNetwork.CallUnrealRPC_Multicast(self,"Multicast_PlayChessDriveMontage",chess) -- 改成bIsTransmitting去值同步

    chess:K2_AttachToComponent(helicopter.SkeletalMesh, "EnterDriverSocket",EDetachmentRule.KeepRelative, EDetachmentRule.KeepRelative, EDetachmentRule.KeepRelative);
    chess:K2_SetActorRelativeLocation(Vector.New(-30,0,140));
    chess:K2_SetActorRelativeRotation(Rotator.New(0,0,0))
    chess:SetReplicateMovement(false)
    chess:GetController():StopMovement()

end

function UGCGameState:DetachChessFromHelicopter(chess,setLoc)
    print("UGCGameState:DetachChessFromHelicopter")

    local movementCompoent = chess.CharacterMovement
    movementCompoent:SetMovementMode(EMovementMode.MOVE_Falling)
    movementCompoent:Activate()

    chess:K2_DetachFromActor(EDetachmentRule.KeepWorld, EDetachmentRule.KeepWorld, EDetachmentRule.KeepWorld);
    chess:SetActorLocation(setLoc)
    chess:SetReplicateMovement(true)

    -- local animPath = UGCMapInfoLib.GetRootLongPackagePath().. "Asset/Blueprint/Animation/ChessDriveMontage.ChessDriveMontage"
    -- UnrealNetwork.CallUnrealRPC_Multicast(self,"Multicast_StopChessDriveMontage",chess) -- 改成bIsTransmitting去值同步

    chess.bIsTransmitting = false
end


function UGCGameState:TransmitPlane(loc)
    ugcprint("UGCGameState:TransmitPlane JumpIndex");
    local plane = self:GetCurrentRoundPlane()
    if plane ~= nil then
        plane:SetActorLocation(loc)
    end
end

function UGCGameState:GetCurrentRoundPlane()
    ugcprint("UGCGameState:GetCurrentRoundPlane");

    if self.PlayerInfos[self.CurRoundTeamIndex] == nil then
        print("UGCGameState:GetCurrentRoundPlane ERROR : self.PlayerInfos is nil which  index is :" .. self.CurRoundTeamIndex);
        return
    end
    if self.PlayerInfos[self.CurRoundTeamIndex].PlaneInfos[self.CurRoundFlyPlaneIndex] == nil then
        print("UGCGameState:GetCurrentRoundPlane ERROR : self.PlaneInfos is nil which  index is :" .. self.CurRoundFlyPlaneIndex);
        return
    end

    return self.PlayerInfos[self.CurRoundTeamIndex].PlaneInfos[self.CurRoundFlyPlaneIndex]
end

--[[------------------------------------------客户端接收到游戏状态数据更新------------------------------------------------------]]--
function UGCGameState:OnRep_CurrentGamestate()
    print("UGCGameState:OnRep_CurrentGamestate,currentState is" .. tostring(self.CurrentGamestate));
    if self.CurrentGamestate == EGameStatus.WaitReady then
        local PlayerController = GameplayStatics.GetPlayerController(UGCGameSystem.GameState, 0);
        if PlayerController ~= nil then
            local PlayerState = PlayerController.PlayerState;
            if PlayerState ~= nil then
                PlayerState:TrySendTeamIndexAssignEvent();
            else
                print("UGCGameState:OnRep_CurrentGamestate PlayerState is nil ");
            end
        else
            print("UGCGameState:OnRep_CurrentGamestate PlayerController is nil ");
        end
    end
end

function UGCGameState:OnRep_PrepareStageRemainTime()
    ugcprint(string.format("UGCGameState:OnRep_PrepareStageRemainTime[%f]", self.PrepareStageRemainTime));
    UGCEventSystem:SendEvent(AeroplaneChessEventType.PrepareStageRemainTimeChanged, self.PrepareStageRemainTime);
end

function UGCGameState:OnRep_CurRoundRemainTime()
    ugcprint(string.format("UGCGameState:OnRep_CurRoundRemainTime[%f]", self.CurRoundRemainTime));
    UGCEventSystem:SendEvent(AeroplaneChessEventType.CurRoundRemainTimeChanged, self.CurRoundRemainTime);
end

function UGCGameState:OnRep_PlayerInfos()
    log_tree_dev("UGCGameState:OnRep_PlayerInfos", self.PlayerInfos);
    UGCEventSystem:SendEvent(AeroplaneChessEventType.PlayerInfosChanged, self.PlayerInfos);
end

function UGCGameState:OnRep_BGMState(LastBGMState)
    ugcprint(string.format("UGCGameState:OnRep_BGMState[%d]", self.BGMState));
    UGCBGMTools:SetState(self.BGMState)
end

function UGCGameState:OnRep_CurRoundStatus()
    ugcprint(string.format("UGCGameState:OnRep_CurRoundStatus[%d]", self.CurRoundStatus));
    UGCEventSystem:SendEvent(AeroplaneChessEventType.CurRoundStatusChanged, self.CurRoundStatus);
end

function UGCGameState:OnRep_CurRoundTeamIndex()
    ugcprint(string.format("UGCGameState:OnRep_CurRoundTeamIndex[%d]", self.CurRoundTeamIndex));
    UGCEventSystem:SendEvent(AeroplaneChessEventType.CurTeamIndexChanged, self.CurRoundTeamIndex);
end

--[[------------------------------------------广播给客户端的方法------------------------------------------------------]]--
-- 开始新回合
function UGCGameState:Multicast_NewRoundStart(TeamIndex, PlayerKey, IsPlayAnotherRound)
    ugcprint(string.format("Multicast_NewRoundStart: P[%d]", TeamIndex));
    UGCEventSystem:SendEvent(AeroplaneChessEventType.PlayerStartNewRound, TeamIndex, PlayerKey, IsPlayAnotherRound);
end

-- 掷骰子的结果，客户端收到后播动画
function UGCGameState:Multicast_RollDiceResult(TeamIndex, DiceResult)
    ugcprint(string.format("Multicast_RollDiceResult: P[%d] Result[%d]", TeamIndex, DiceResult));
    UGCEventSystem:SendEvent(AeroplaneChessEventType.ReceivedDiceResult, TeamIndex, DiceResult);
end

-- 玩家移动了棋子，客户端收到后播动画
function UGCGameState:Multicast_PlayerFlyPlane(TeamIndex, PlaneIndex, NumSteps)
    ugcprint(string.format("Multicast_PlayerFlyPlane: P[%d] Plane[%d] Step[%d]", TeamIndex, PlaneIndex, NumSteps));    
    UGCEventSystem:SendEvent(AeroplaneChessEventType.PlayerFlyPlane, TeamIndex, PlaneIndex, NumSteps);
end

-- 某个棋子到达了终点
function UGCGameState:Multicast_PlaneReachedEndPoint(TeamIndex, PlaneIndex)
    ugcprint(string.format("Multicast_PlaneReachedEndPoint: P[%d] Plane[%d]", TeamIndex, PlaneIndex));
    UGCEventSystem:SendEvent(AeroplaneChessEventType.PlaneReachedEndPoint, TeamIndex, PlaneIndex);
end

-- 某个棋子淘汰另一架棋子
function UGCGameState:Multicast_PlaneKillPlane(TeamIndex1, TeamIndex2)
    ugcprint(string.format("Multicast_PlaneKillPlane: P[%d] Plane[%d]", TeamIndex1, TeamIndex2));
    UGCEventSystem:SendEvent(AeroplaneChessEventType.Kill, TeamIndex1, TeamIndex2);
end

-- 玩家数据同步到客户端
function UGCGameState:Multicast_PlayerPanel(PlayerInfos)
    ugcprint("Multicast_PlayerPanel: ");
    self.PlayerPanelDatas = PlayerInfos
    UGCEventSystem:SendEvent(AeroplaneChessEventType.PlayerPanelChange, PlayerInfos);
end

-- 游戏开始提示
function UGCGameState:Multicast_ShowStartTips()
    ugcprint("Multicast_ShowStartTips: ");
    UGCEventSystem:SendEvent(AeroplaneChessEventType.GameStartChanged);
end

-- 开启当前回合剩余时间提示
function UGCGameState:Multicast_ShowRemainTimeTips(IsShow)
    ugcprint("Multicast_ShowRemainTimeTips: ");
    self.ShowRemainTime = IsShow;
end

-- 开启当前回合投掷提示
function UGCGameState:Multicast_ShowThrowTips(IsShow)
    ugcprint("Multicast_ShowThrowTips: ");
    self.ShowThrowTips = IsShow;
end


-- 某个玩家结束游戏（棋子全部到达）
function UGCGameState:Multicast_PlayerFinishedGame(TeamIndex, SettlementData, IsShowVictory)
    ugcprint(string.format("Multicast_PlayerFinishedGame: P[%d]", TeamIndex));
    AeroplaneChessMode.GameResultData.PlayerResultDatas = SettlementData
    UGCEventSystem:SendEvent(AeroplaneChessEventType.PlayerFinishedGame, TeamIndex, IsShowVictory);
end

-- 整局游戏结束（3个玩家结束游戏）
function UGCGameState:Multicast_AeroplaneChessGameFinished(SettlementData)
    ugcprint("Multicast_AeroplaneChessGameFinished");
    AeroplaneChessMode.GameResultData.PlayerResultDatas = SettlementData
    UGCEventSystem:SendEvent(AeroplaneChessEventType.AeroplaneChessGameFinished);
end

-- 直升机传送玩家
function UGCGameState:Multicast_StartTransmitFly(loc)
    ugcprint("Multicast_StartTransmitFly");

    local helicopter = self.HelicopterList[self.CurRoundTeamIndex]
    if not helicopter then
        ugcprint("Multicast_StartTransmitFly ERROR: helicopter is null" );
    end
    helicopter:StartTransmit(loc)

    -- self:SetCurrentTransmitActorVisiable(false)
end

-- -- 播放玩家蒙太奇
-- function UGCGameState:Multicast_PlayChessMontage(path , chess)
--     ugcprint("Multicast_PlayChessMontage")
--     if not chess then
--         ugcprint("Multicast_PlayChessMontage ERROR: chess is null" );
--     end 

--     chess:PlayMontage(path)
-- end

-- -- 终止玩家蒙太奇
-- function UGCGameState:Multicast_StopChessMontage(path, chess)
--     ugcprint("Multicast_StopChessMontage")
--     if not chess then
--         ugcprint("Multicast_StopChessMontage ERROR: chess is null" );
--     end 

--     chess:StopMontage(path)
-- end

-- 播放玩家开直升机蒙太奇
function UGCGameState:Multicast_PlayChessDriveMontage(chess)
    ugcprint("Multicast_PlayChessDriveMontage")
    if not chess then
        ugcprint("Multicast_PlayChessMontage ERROR: chess is null" );
    end 

    chess:PlayDriveMontage()
end

-- 终止玩家开直升机蒙太奇
function UGCGameState:Multicast_StopChessDriveMontage(chess)
    ugcprint("Multicast_StopChessDriveMontage")
    if not chess then
        ugcprint("Multicast_StopChessMontage ERROR: chess is null" );
    end 

    chess:StopDriveMontage()
end

function UGCGameState:SetCurrentTransmitActorVisiable(visiable)
    ugcprint("UGCGameState:SetCurrentTransmitActorVisiable visiable : " .. tostring(visiable));
    local actor = self:GetCurrentRoundPlane()
    if actor then
        actor:SetActorVisiable(visiable)
    end
end

-- 在客户端播放特效
function UGCGameState:Multicast_PlayParticleEffect(particleId, location)
    ugcprint("UGCGameState:Multicast_PlayParticleEffect");
    UGCParticleTools:AsyncLoadWithCallback(particleId,        
    function (Particle)
        STExtraBlueprintFunctionLibrary.SpawnCustomEmitterAtLocation(self, Particle, location)
    end)
end

return UGCGameState;
