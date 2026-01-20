---@class Helicopter_C:Actor
---@field SkeletalMesh USkeletalMeshComponent
---@field DefaultSceneRoot USceneComponent
---@field TeamID int32
---@field TargetLocation FVector
---@field KillTileID int32
--Edit Below--
local Helicopter = {
    currentState = 0,
    orderToFly = false,
    RISING_HEIGHT = 400,
    originLocation = nil,
    moveTargetLocation = {X =0,Y=0,Z=0},
    TargetLocation = nil,
    TargetRotation = nil,
    time=0,
    OrderSendLocation = nil,
    KillTileLocation = nil,
    TransmitPlane = nil
}; 

-- floatingmovement
local State = {
    Waitting = 1,
    Rising = 2,
    Flying = 3,
    Landing = 4,
    ReturningRising = 5,
    Returning = 6,
    ReturningLanding = 7
}
function Helicopter:ReceiveBeginPlay()
    self.currentState = State.Waitting
    self.originLocation = self:K2_GetActorLocation()
end

function Helicopter:ReceiveTick(DeltaTime)
    if self.currentState == State.Waitting then
        if self.orderToFly then
            self.orderToFly = false
            self:setMoveTargetLocation(self.originLocation.X,self.originLocation.Y, self.originLocation.Z + self.RISING_HEIGHT)
            self:ChangeState(State.Rising)
        end
    elseif self.currentState == State.Rising then
        self:Move(DeltaTime,200)
        if self:IsArrived() then
            self:setMoveTargetLocation(self.TargetLocation.X,self.TargetLocation.Y, self.TargetLocation.Z + self.RISING_HEIGHT)
            self:ChangeState(State.Flying)
        end
    elseif self.currentState == State.Flying then
        self:Move(DeltaTime,1000)
        if self:IsArrived() then
            self:setMoveTargetLocation(self.TargetLocation.X,self.TargetLocation.Y, self.TargetLocation.Z)
            self:ChangeState(State.Landing)
        else
            if self:HasAuthority() then
                if not self.KillTileLocation then
                    if UGCGameSystem.GameState then
                        self.KillTileLocation = UGCGameSystem.GameState.TilesList[self.KillTileID].Pos:K2_GetComponentLocation()
                    end
                end

                if self.KillTileLocation then
                    local dis = VectorHelper.GetDistance2D(self:K2_GetActorLocation(), self.KillTileLocation)
                    if dis < 50 then
                        if UGCGameSystem.GameState then
                            ugcprint("Helicopter:SendPlaneHomeByTileID")
                            UGCGameSystem.GameState:SendPlaneHomeByTileID(self.KillTileID)
                        end
                    end
                end
            end
        end
    elseif self.currentState == State.Landing then 
        self:Move(DeltaTime,200)
        if self:IsArrived() then
            self:setMoveTargetLocation(self.TargetLocation.X,self.TargetLocation.Y, self.TargetLocation.Z + self.RISING_HEIGHT)
            self:ChangeState(State.ReturningRising)
            if self:HasAuthority() then
                if UGCGameSystem.GameState then
                    UGCGameSystem.GameState:DetachChessFromHelicopter(UGCGameSystem.GameState:GetCurrentRoundPlane(),self.OrderSendLocation)
                end
            end

            local Rotation = Rotator.New(0,self:K2_GetActorRotation().Yaw + 180,0)
            self.TargetRotation = Rotation
        end
    elseif self.currentState == State.ReturningRising then 
        self:Move(DeltaTime,200)
        self:Turn(DeltaTime)
        if self:IsArrived() then
            self:setMoveTargetLocation(self.originLocation.X,self.originLocation.Y, self.originLocation.Z + self.RISING_HEIGHT)
            self:ChangeState(State.Returning)
        end   
    elseif self.currentState == State.Returning then 
        self:Move(DeltaTime,1000)
        if self:IsArrived() then
            self:setMoveTargetLocation(self.originLocation.X,self.originLocation.Y, self.originLocation.Z)
            self:ChangeState(State.ReturningLanding)
            local Rotation = Rotator.New(0,self:K2_GetActorRotation().Yaw + 180,0)
            self.TargetRotation = Rotation
        end   
    elseif self.currentState == State.ReturningLanding then 
        self:Move(DeltaTime,200)
        self:Turn(DeltaTime)
        if self:IsArrived() then
            self:ChangeState(State.Waitting)
            self:StopEffect()
        end   
    end
end

function Helicopter:setMoveTargetLocation(x,y,z)
    self.moveTargetLocation.X = x
    self.moveTargetLocation.Y = y
    self.moveTargetLocation.Z = z
end

function Helicopter:Move(DeltaTime,Speed)
    if self.moveTargetLocation == nil then
        print("ERROR!!Helicopter:Move self.moveTargetLocation == nil")
        return
    end
    local interpToLocation = KismetMathLibrary.VInterpTo_Constant(self:K2_GetActorLocation(), self.moveTargetLocation, DeltaTime, Speed)
    ugcprint("Helicopter:interpToLocation location: " .. VectorHelper.ToString(interpToLocation))
    self.bShouldDumpCallstackWhenMovingfast = false

    self:K2_SetActorLocation(interpToLocation);
    self.bShouldDumpCallstackWhenMovingfast = true

end

function Helicopter:Turn(DeltaTime)
    if not self.TargetRotation then
        print("Helicopter:Turn self.TargetRotation is null ")
        return
    end

    local Rotation = KismetMathLibrary.RInterpTo_Constant(self:K2_GetActorRotation(), self.TargetRotation, DeltaTime, 150)
    self:K2_SetActorRotation(Rotation);
end

function Helicopter:IsArrived()
    if self.moveTargetLocation == nil then
        print("ERROR!!Helicopter:Helicopter self.moveTargetLocation == nil")
        return
    end
    local disToTargetLocation = VectorHelper.GetDistance(self:K2_GetActorLocation(), self.moveTargetLocation)
    ugcprint("Helicopter:IsArrived: disToTargetLocation" .. disToTargetLocation)

    if disToTargetLocation < 30 then
        return true
    end
    return false
end

function Helicopter:ChangeState(newState)
    ugcprint("Helicopter:ChangeState oldState:"..self.currentState .. "  to newState: "..newState)
    self.currentState = newState
end

-- function Helicopter:ReceiveEndPlay()
 
-- end

function Helicopter:StartTransmit(loc)
    ugcprint("Helicopter:StartTransmit")
    self.orderToFly = true
    self.OrderSendLocation = loc
    self:PlayEffect()
end


function Helicopter:PlayAnimation()
    ugcprint("Helicopter:PlayAnimation")

    local animPath = UGCMapInfoLib.GetRootLongPackagePath().. "Asset/Blueprint/NewAnimMontage.NewAnimMontage"
    local animObj = UE.LoadObject(animPath);
    self:PlayAnimMontage(animObj,1.0,"Default")
    if animObj == nil then
        print("Helicopter:PlayAnimation animObj is nil")
    end
    local AnimInstance = self.Mesh:GetAnimInstance()
    AnimInstance:Montage_Play(animObj,1.0,0,0.0)
    
    -- UGCAsyncLoadTools:LoadObject(animPath, function(Montage)
    --     if Montage ~= nil then
    --         local AnimInstance = self.Mesh:GetAnimInstance()
    --         AnimInstance:Montage_Play(Montage,1.0,0,0.0)
    --         ugcprint("Helicopter:PlayAnimation AsyncLoad end")

    --     end
    -- end)
    ugcprint("Helicopter:PlayAnimation end")

end

function Helicopter:PlayEffect()
    if UE_SERVER then
        return
    end
    ugcprint(" Helicopter:PlayEffect")
    local path  = "/Game/Arts_Timeliness/CG014_Version_Future/CG014_Version_Event/CG014_Event01/Arts_Effect/P_MotorTrail.P_MotorTrail"
    local softObjPath = KismetSystemLibrary.MakeSoftObjectPath(path)
    local asset = STExtraBlueprintFunctionLibrary.GetAssetByAssetReference(softObjPath)

    local location = Vector.New(-180,0,40)
	local rotator = Rotator.New(0, 0, 0)
	local scale = Vector.New(1, 1, 1)

    local mesh = self.SkeletalMesh
    local attachName = "EngineEffect"

    self.effectObj = GameplayStatics.SpawnEmitterAttachedToActor(asset, mesh, attachName, location, rotator,scale,EAttachLocation.KeepRelativeOffset,true)
end

function Helicopter:StopEffect()
    ugcprint(" Helicopter:StopEffect")
    if self.effectObj and UE.IsValid(self.effectObj) then
        self.effectObj:SetVisibility(false,true,true)
        self:K2_DestroyComponent(self.effectObj)
        self.effectObj = nil
    end
end

return Helicopter;