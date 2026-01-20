---@class Chess_C:Character
---@field CrownMesh UStaticMeshComponent
---@field CharacterAvatarComp_BP UCharacterAvatarComp_BP_C
---@field ParticleSystem UParticleSystemComponent
---@field ChessCamera UCameraComponent
---@field SpringArm USpringArmComponent
---@field TeamIndex int32
---@field Index int32
---@field CrownParticleClass UParticleSystem
---@field DriveHelicopterMontage UAnimMontage
--Edit Below--
-- require("Script.Common.Bluprint.Items.Car")

local Chess = {
    -- 目前站在哪块地砖上
    CurrentTileIndex = 0;
    -- 当前状态（在家、待出发、路上、已到达）
    CurrentState = 0;

    bIsSetTeamMark = false;
    TeamMarkMaterial = nil;  -- 区分队伍的光环材质
    --是否使用载具
    bIsDriveCar = false;

    bIsTransmitting = false, -- 在直升机上

    -- 是否已经生成皇冠
    bHasShowCrown = false;
};

function Chess:GetReplicatedProperties()
    return
    "CurrentTileIndex",
    "CurrentState",
    "bIsTransmitting"
end

function Chess:GetAvailableServerRPCs()
    return 
end


function Chess:OnRep_bIsTransmitting()
    ugcprint(string.format("Chess:OnRep_bIsTransmitting " .. (self.bIsTransmitting and "true" or "false")));
    if self.bIsTransmitting then
        self:PlayDriveMontage()
    else
        self:StopDriveMontage()
    end
end


function Chess:ReceiveBeginPlay()
    ugcprint("Chess:ReceiveBeginPlay");
    -- 断线重连时，onrep有可能比这早，同步下来的数据可能会被覆盖成初始值
    if self.CurrentTileIndex == 0 then
        print("Chess:ReceiveBeginPlay CurrentTileIndex = 0");
        self.CurrentTileIndex = self:GetStartTileIndex()
    end

    -- 创建TeamIndex对应的材质
    self.TeamMarkMaterial = LoadObject(AeroplaneChessAssetConfigs.TeamMarkConfigList[self.TeamIndex].MaterialPath)
end

function Chess:ReceiveTick(DeltaTime)
    if self.TeamMarkMaterial and not self.bIsSetTeamMark then
        local DisplayMaterial = KismetMaterialLibrary.CreateDynamicMaterialInstance(self, self.TeamMarkMaterial);
        self.bIsSetTeamMark = true
        self.TeamMark:SetMaterial(0, DisplayMaterial)
    end

end

-- function Chess:ReceiveEndPlay()
 
-- end

-- 计算初始时脚下地砖的index
function Chess:GetStartTileIndex()
    return self.TeamIndex * 1000 + self.Index
end

-- 获取当前脚下的地砖对象
function Chess:GetCurTile()
    print("Chess:GetCurTile CurrentTile is:" .. tostring(self.CurrentTileIndex));
    return UGCGameSystem.GameState.TilesList[self.CurrentTileIndex]
end

-- 是否进入了终点区域
function Chess:IsInEndPointLine()
    return self.CurrentTileIndex > 100 * self.TeamIndex and self.CurrentTileIndex < 100 * self.TeamIndex + 7
end

function Chess:PawnMoveToLocation(position)
    ugcprint("Chess:PawnMoveToLocation")
    local controller = self:GetController()
    if controller == nil then
        print("Chess:PawnMoveToLocation controller is nil")
        return
    end
    controller:MoveToLocation((VectorHelper.ToLuaTable(position)), 0, false, false, false, false, nil, false, false)
end

function Chess:SetAvatar(PlayerAvatarData)

    if self.CharacterAvatarComp_BP then
        self.CharacterAvatarComp_BP.forceClientMode = false;

        for _, AvatarItemID in ipairs(PlayerAvatarData.AvatarItemIDList) do
            local SlotID = BackpackUtils.GetEquipSlotID(AvatarItemID)

            --Slot1类型为初始化模型Avatar
            if SlotID == 1 then
                self.CharacterAvatarComp_BP:InitDefaultAvatarByResID(PlayerAvatarData.Gender, 0, 0)
            else
                self.CharacterAvatarComp_BP:PutOnEquipmentByResID(AvatarItemID)
            end
        end
    end
end

function Chess:SetActorVisiable(visiable)
    ugcprint("Chess:SetActorVisiable")

    self:SetActorHiddenInGame(not visiable)
end

function Chess:SetActorLocation(loc)
    ugcprint("Chess:SetActorLocation")
    -- self.bShouldDumpCallstackWhenMovingfast = false
    local targetLoc = {X = loc.X, Y = loc.Y, Z = self:K2_GetActorLocation().Z}
    self:K2_SetActorLocation(targetLoc);
    -- self.bShouldDumpCallstackWhenMovingfast = true
    self:GetController():StopMovement()
end

-- function Chess:PlayMontage(path)
--     ugcprint("Chess:PlayMontage asset path : " .. path)
--     local animObj = UE.LoadObject(path);
--     if animObj == nil then
--         ugcprint("Chess:PlayMontage animObj is nil")
--     end
--     self:PlayAnimMontage(animObj,1.0,"Default")

--     -- local AnimInstance = self.Mesh:GetAnimInstance()
--     -- AnimInstance:Montage_Play(animObj,1.0,0,0.0)
-- end

-- function Chess:StopMontage(path)
--     ugcprint("Chess:StopMontage asset path : " .. path)
--     local animObj = UE.LoadObject(path);
--     if animObj == nil then
--         ugcprint("Chess:StopMontage animObj is nil")
--     end
--     self:StopAnimMontage(animObj)
-- end

function Chess:PlayDriveMontage()
    ugcprint("Chess:PlayDriveMontage ")
    local animObj = self.DriveHelicopterMontage;
    if animObj == nil then
        print("Chess:PlayMontage animObj is nil")
    end
    self:PlayAnimMontage(animObj,1.0,"Default")

    -- local AnimInstance = self.Mesh:GetAnimInstance()
    -- AnimInstance:Montage_Play(animObj,1.0,0,0.0)
end

function Chess:StopDriveMontage()
    ugcprint("Chess:StopDriveMontage")
    local animObj = self.DriveHelicopterMontage;
    if animObj == nil then
        print("Chess:StopMontage animObj is nil")
    end
    self:StopAnimMontage(animObj)
end


function Chess:SetCrownVisible(visible)
    ugcprint("Chess:SetCrownVisible: " .. tostring(visible))
    self.CrownMesh:SetVisibility(visible)
end

function Chess:CheckChessComplete()
    print("Chess:CheckChessComplete currentState:" .. tostring(self.CurrentState));
    if UGCGameSystem.GameState == nil then
        print("Chess:CheckChessComplete Gamestate is nil");
        return;
    end
    if self.CurrentState == 4 then
        if not self.bHasShowCrown then
            self:SetCrownVisible(true)
            local SpawnEmitterLocation = VectorHelper.Add(VectorHelper.ToLuaTable(self:K2_GetActorLocation()), {X = 0, Y = 0, Z = 200});
            -- 异步加载特效
            UGCParticleTools:AsyncLoadWithCallback(UGCParticleTools.List.CrownLight,        
            function (Particle)
                STExtraBlueprintFunctionLibrary.SpawnCustomEmitterAtLocation(self,Particle, SpawnEmitterLocation, {Roll=0, Pitch=0, Yaw=0}, false)
            end)
            self.bHasShowCrown = true;
        else
            print("Chess:CheckChessComplete bHasShowCrown is true");
        end
    end
end

function Chess:OnRep_CurrentState()
    print("Chess:OnRep_CurrentState currentState:" .. tostring(self.CurrentState));
    self:CheckChessComplete();
end

function Chess:OnRep_CurrentTileIndex()
    print("Chess:OnRep_CurrentTileIndex CurrentTileIndex:" .. tostring(self.CurrentTileIndex));
end
return Chess;