---@class TopCamera_C:CameraActor
--Edit Below--
local TopCamera = {
    PlayerController = nil;

    -- 初始位置
    CameraOriLocation = nil;
    -- 是否进行摄像机视野边缘检测
    IsCheckCameraEdge = true;
    Channel = EObjectTypeQuery.ObjectTypeQuery7;

    -- 离地面最高高度 为摄像机初始高度
    CameraMaxHeight = 5500;
    CameraMinHeight = 750;
}; 


function TopCamera:ReceiveBeginPlay()
    -- 在客户端本地跑
    if self:HasAuthority() ~= true then 
        self.PlayerController = GameplayStatics.GetPlayerController(self, 0);
        self.CameraOriLocation = self:K2_GetActorLocation();
    end

end

function TopCamera:ReceiveTick(DeltaTime)
    -- 在客户端本地跑
    if self:HasAuthority() ~= true then 
        if self.IsCheckCameraEdge then 
            if not UE.IsValid(self.PlayerController) then
                print("TopCamera:ReceiveTick self.PlayerController is InValid");
                return;
            end
            -- 摄像机位置
            local CameraLocation = VectorHelper.ToLuaTable(self:K2_GetActorLocation());
            -- 摄像机右方向
            local RightVector = self:GetActorRightVector();
            -- 摄像机上方向
            local UpVector = self:GetActorUpVector();
            -- 获取摄像机位置沿摄像机前方向10000单位的点
            local ForwardVector = VectorHelper.ToLuaTable(VectorHelper.MulNumber(KismetMathLibrary.Normal(self:GetActorForwardVector()),10000));
            -- 水平FOV的一半的角度
            local HalfHFov = self.CameraComponent.FieldOfView / 2;
            -- 摄像机视野长宽比
            local AspectRatio = self.CameraComponent.AspectRatio;
            -- 垂直FOV的一半的角度
            local HalfVFov = KismetMathLibrary.DegAtan(KismetMathLibrary.DegTan(HalfHFov) / AspectRatio);
            -- 开始向四个方向发射射线 按前后左右 射线通道待定
            local HitResult = nil;
            local IsHitEdge = false;
            --前
            local EndLocation = VectorHelper.Add(CameraLocation,KismetMathLibrary.RotateAngleAxis(ForwardVector,HalfVFov * -1,RightVector));
            IsHitEdge, HitResult = KismetSystemLibrary.LineTraceSingleForObjects(self, CameraLocation, EndLocation, { self.Channel }, false, {})
            --IsHitEdge = KismetSystemLibrary.LineTraceSingle(self, CameraLocation, EndLocation, ETraceTypeQuery.TraceTypeQuery3, false, {}, EDrawDebugTrace.None, true, self.linearColor,self.linearColor,0);
            --HitResult,IsHitEdge = KismetSystemLibrary.LineTraceSingle(self, CameraLocation, EndLocation, ETraceTypeQuery.TraceTypeQuery3, false, {});
            self.PlayerController.CanMoveForward = not IsHitEdge;
            --后
            EndLocation =  VectorHelper.Add(CameraLocation,KismetMathLibrary.RotateAngleAxis(ForwardVector,HalfVFov,RightVector))
            IsHitEdge, HitResult = KismetSystemLibrary.LineTraceSingleForObjects(self, CameraLocation, EndLocation, { self.Channel }, false, {})
            self.PlayerController.CanMoveBack = not IsHitEdge;
            -- 左
            EndLocation =  VectorHelper.Add(CameraLocation,KismetMathLibrary.RotateAngleAxis(ForwardVector,HalfHFov * -1,UpVector))
            IsHitEdge, HitResult = KismetSystemLibrary.LineTraceSingleForObjects(self, CameraLocation, EndLocation, { self.Channel }, false, {})
            self.PlayerController.CanMoveLeft = not IsHitEdge;
            -- 右
            EndLocation =  VectorHelper.Add(CameraLocation,KismetMathLibrary.RotateAngleAxis(ForwardVector,HalfHFov,UpVector))
            IsHitEdge, HitResult = KismetSystemLibrary.LineTraceSingleForObjects(self, CameraLocation, EndLocation, { self.Channel }, false, {})
            self.PlayerController.CanMoveRight = not IsHitEdge;
        end
    end
end

-- 摄像头拉近拉远
function TopCamera:ScaleCamera(ScaleValue)
    -- 当镜头在边缘禁止继续拉远
    if self:CameraAtEdge() and ScaleValue < 0 then
        return;
    end
    ugcprint("TopCamera:ScaleCamera ScaleValue is :" .. ScaleValue)
    local ForwardVector = VectorHelper.ToLuaTable(KismetMathLibrary.Normal(self:GetActorForwardVector()));
    -- 摄像机当前位置
    local CameraLocation = VectorHelper.ToLuaTable(self:K2_GetActorLocation());
    local AfterMoveLocation = VectorHelper.Add(CameraLocation,VectorHelper.MulNumber(ForwardVector, ScaleValue));
    -- 检测高度，如果高度处于区间外 则将Scalevalue缩小一半再次尝试
    local CameraHeight = self:GetHeight(AfterMoveLocation);
    ugcprint("Camera Pre Height is :" .. tostring(CameraHeight))
    if CameraHeight <= self.CameraMinHeight  or CameraHeight >= self.CameraMaxHeight then
        return;
    end
    self:K2_SetActorLocation(AfterMoveLocation);
end

-- 摄像机是否在边缘
function TopCamera:CameraAtEdge()
    if not UE.IsValid(self.PlayerController) then
        return false;
    end

    return self.PlayerController.CanMoveForward == false or self.PlayerController.CanMoveBack == false or self.PlayerController.CanMoveLeft == false or self.PlayerController.CanMoveRight == false
end


-- 获得高度
function TopCamera:GetHeight(Location)
    local StartLocation = Location;
    local EndLocation = VectorHelper.Add(StartLocation,VectorHelper.MulNumber({X=0,Y=0,Z=1},-10000));
    local IsHitEdge, HitResult = KismetSystemLibrary.LineTraceSingleForObjects(self, VectorHelper.ToLuaTable(StartLocation), EndLocation, { EObjectTypeQuery.ObjectTypeQuery1 }, false, {self})
    if IsHitEdge then
        local HitLocation = VectorHelper.ToLuaTable(HitResult.Location);
        local Dis = VectorHelper.GetDistance(StartLocation,HitLocation);
        ugcprint("CameraHeight is:" .. Dis)
        return Dis;
    else
        ugcprint("CameraHeight Ray Trace does not hit a object:")
        return 0;
    end
end


-- function TopCamera:ReceiveEndPlay()

-- end
 

return TopCamera;