---@class AeroplaneAIController_C:AIController
--Edit Below--
local AeroplaneAIController = {
    -- 剩余步数
    StepLeft = 0;
    -- pawn是否正在移动
    IsPawnMoving = false;
    -- pawn已跳跃次数
    JumpCount = 0;
}; 
-- function AeroplaneAIController:ReceiveBeginPlay()

-- end
function AeroplaneAIController:ReceiveTick(DeltaTime)
    if self:HasAuthority() then
        if self.StepLeft ~= 0 and not self.IsPawnMoving then
            self:DoNormalWalk()
        elseif self.IsPawnMoving then
            self:CheckMovementFinished()
        end
    end
end

function AeroplaneAIController:DoNormalWalk()
    ugcprint("AeroplaneAIController:DoNormalWalk")
    
    -- log added. v_sbbsxia asked for checking if jumping or not
    print("v_sbbsxia : AeroplaneAIController:Jump Start 2")

    if self:K2_GetPawn().bIsTransmitting then
        return
    end

    ugcprint("AeroplaneAIController:DoNormalWalk StepLeft:"..self.StepLeft.."  curTile:"..self:K2_GetPawn().CurrentTileIndex)

    local curTile = self:K2_GetPawn():GetCurTile()
    if curTile == nil then
        print("AeroplaneAIController:DoNormalWalk curTile is nil")
        return false
    end

    local targetTileIndex = 0
    if self.IsInBackwardMovement then
        -- 碰到终点后反向移动
        targetTileIndex = UGCGameSystem.GameState:FindPrevTileIndex(self:K2_GetPawn().CurrentTileIndex)
        ugcprint("AeroplaneAIController:DoNormalWalk Move Backward, TargetIndex:"..targetTileIndex)
    else
        targetTileIndex = curTile.NextIndex
        if curTile.IsTurning and curTile.TeamID == self:K2_GetPawn().TeamIndex then
            ugcprint("AeroplaneAIController:DoNormalWalk Turn Into Finish Line")
            targetTileIndex = curTile.JumpIndex
        end
    end

    ugcprint("AeroplaneAIController:DoNormalWalk targetTile:"..targetTileIndex)
    local targetTile = UGCGameSystem.GameState.TilesList[targetTileIndex]
    if targetTile and UE.IsValid(targetTile) then
        -- 获取目标砖块已有玩家
        local TilePawnList = UGCGameSystem.GameState:GetTileStandPawnList(targetTileIndex);
        -- 移动目标砖块已有玩家位置,给移动的角色提供一个空位置
        UGCGameSystem.GameState:MakeTileHaveEmptySlot(targetTile,TilePawnList);
        -- 根据目标砖块玩家数量得到目标位置(就是MakeTileHaveEmptySlot留下的空位置)
        local endLoc = self:GetMoveTargetPosByTilePawnNum(targetTile,#TilePawnList);
        self.targetPosition = endLoc
        self.targetTileIndex = targetTileIndex
        self.IsPawnMoving = true
        -- 移动到下个地砖的位置
        ugcprint("AeroplaneAIController:DoNormalWalk MoveToLocation")
        -- self:Aaasdf()
        self:MoveToLocation(endLoc, 0, false, false, false, false, nil, false, false)
    else
        print("AeroplaneAIController:DoNormalWalk Invalid Target Tile")
    end
end

function AeroplaneAIController:CheckMovementFinished(DeltaTime)
    if self:K2_GetPawn().bIsTransmitting then
        return
    end

    local DistToDestLocation = VectorHelper.GetDistance2D(self:K2_GetPawn():K2_GetActorLocation(), self.targetPosition)
    ugcprint("Chris : AeroplaneAIController:MoveStep :SyncLocation DistToDestLocation:"..DistToDestLocation)
    if DistToDestLocation <= 200 then
        -- 移动到了位置
        self.IsPawnMoving = false
        -- 记录上一个格子
        local LastTileIndex = self:K2_GetPawn().CurrentTileIndex;
        -- 给角色设置新的当前砖块Index
        self:K2_GetPawn().CurrentTileIndex = self.targetTileIndex
        -- 将上一个格子的角色位置根据角色数量重置
        UGCGameSystem.GameState:ResetTilePawn(LastTileIndex);
        local curTile = self:K2_GetPawn():GetCurTile()
        if curTile == nil then return end
        -- 正在进行正常移动
        if self.StepLeft > 0 then
            if curTile.IsGrey and self.JumpCount == 0 then
                -- 灰块非跳跃的时候不计入步数
            else
                self.StepLeft = self.StepLeft - 1
            end
        end
        if self.StepLeft == 0 then
            UGCGameSystem.GameState:CheckIfSendOtherPlaneHome()
            -- 正常走路步数走完
            if curTile.TeamID == self:K2_GetPawn().TeamIndex and not curTile.IsTurning then
                -- 是跳跃砖块
                ugcprint("AeroplaneAIController:CheckMovementFinished StartJump")
                --处理飞行逻辑
                if curTile.IsFlying then
                    self:StartTransmitFly(curTile.JumpIndex)
                else
                    self:JumpTargetIndex(curTile.JumpIndex)
                end
            elseif curTile:IsEndPointTile() then
                -- 是终点砖块
                ugcprint("AeroplaneAIController:CheckMovementFinished Reached EndPoint")
                self:FinishMove(true)
            else
                self:FinishMove(false)
            end 
        else
            -- 没走完步数，但是走到终点时，往回走
            if curTile:IsEndPointTile() then
                ugcprint("AeroplaneAIController:CheckMovementFinished Start Move Backward")
                self.IsInBackwardMovement = true
            end
        end
    end
end

-- 根据要去的格子上面有多少个玩家确定在格子上的站位
function AeroplaneAIController:GetMoveTargetPosByTilePawnNum(Tile,TilePawnNum)
    if TilePawnNum == 0 then
        return Tile:GetOnePlayerLocation()
    elseif TilePawnNum == 1 then
        return Tile:GetTwoPlayerTileLocation(2)
    elseif TilePawnNum == 2 then
        return Tile:GetThreePlayerTileLocation(3)
    elseif TilePawnNum == 3 then
        return Tile:GetFourPlayerTileLocation(4)
    elseif TilePawnNum == 4 then
        return Tile:GetOnePlayerLocation()
    end
end

--跳到指定板块
function AeroplaneAIController:JumpTargetIndex(index)
    if self.JumpCount < 1 then
        self.JumpCount = self.JumpCount +1
        local step = self:GetStepsByTargetIndex(self:K2_GetPawn().CurrentTileIndex,index)
        self:MoveNumSteps(step)
    else
        self:FinishMove(false)
    end
end

-- 移动指定步数
function AeroplaneAIController:MoveNumSteps(step)
    -- log added. v_sbbsxia asked for checking if jumping or not
    print("v_sbbsxia : AeroplaneAIController:Jump Start 1")

    -- 开始移动时，正向移动
    self.IsInBackwardMovement = false
    self.StepLeft = step
end

-- 直升机传送
function AeroplaneAIController:StartTransmitFly(JumpIndex)
    ugcprint("AeroplaneAIController:StartTransmitFly JumpIndex: " .. JumpIndex)
    self.IsPawnMoving = true

    local targetTile = UGCGameSystem.GameState.TilesList[JumpIndex]
    -- 获取目标砖块已有玩家
    local TilePawnList = UGCGameSystem.GameState:GetTileStandPawnList(JumpIndex);
    -- 移动目标砖块已有玩家位置,给移动的角色提供一个空位置
    UGCGameSystem.GameState:MakeTileHaveEmptySlot(targetTile,TilePawnList);
    -- 根据目标砖块玩家数量得到目标位置(就是MakeTileHaveEmptySlot留下的空位置)
    local endLoc = self:GetMoveTargetPosByTilePawnNum(targetTile,#TilePawnList);
    self.targetPosition  = endLoc
    self.targetTileIndex = JumpIndex
    UGCGameSystem.GameState:StartTransmitFly(endLoc)

    -- self.targetPosition  = endLoc
    -- self.targetTileIndex = JumpIndex
end

function AeroplaneAIController:FinishMove(HasReachedEndPoint)
    self.IsInBackwardMovement = false
    self.JumpCount = 0
    UGCGameSystem.GameState:PlaneFinishedFlying(HasReachedEndPoint)
    -- 恢复相机到顶部
    UGCGameSystem.GameState:SetAllPlayerFocusToTopCamera();
end

function AeroplaneAIController:GetStepsByTargetIndex(curIndex, targetIndex)
    ugcprint("AeroplaneAIController:GetStepsByTargetIndex")

    if not UGCGameSystem.GameState or not UGCGameSystem.GameState.TilesList then
        print("AeroplaneAIController:GetStepsByTargetIndex error : UGCGameSystem.GameState or UGCGameSystem.GameState.TilesList is nil")
    end

    local step = 0
    local index = curIndex
    local curTile = UGCGameSystem.GameState.TilesList[curIndex]
    if not curTile then
        print("AeroplaneAIController:GetStepsByTargetIndex error : curTile nil curIndex is :" .. curIndex)
        return step
    end

    while index ~= targetIndex do
        index =  curTile.NextIndex
        curTile = UGCGameSystem.GameState.TilesList[index]
        if not curTile then
            print("AeroplaneAIController:GetStepsByTargetIndex error : curTile nil curIndex is :" .. index)
            return step
        end
        step = step +1
    end
    ugcprint("AeroplaneAIController:GetStepsByTargetIndex step : " .. step)

    return step
end

-- 把棋子传送回家
function AeroplaneAIController:SendPlaneHome()
    ugcprint("AeroplaneAIController:SendPlaneHome")
    local pawn = self:K2_GetPawn()
    -- 原地播一个回家特效
    local location = VectorHelper.ToLuaTable(pawn:K2_GetActorLocation())
    location.Z = location.Z - 150
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_PlayParticleEffect", UGCParticleTools.List.PlaneGetKickedHome01, location);
    
    pawn.CurrentTileIndex = pawn:GetStartTileIndex()
    local StartLoc = VectorHelper.ToLuaTable(pawn:GetCurTile():GetOnePlayerLocation())
    pawn:SetActorLocation(StartLoc)
    
    -- 回家后播一个特效
    local location = VectorHelper.ToLuaTable(pawn:K2_GetActorLocation())
    location.Z = location.Z - 150
    UnrealNetwork.CallUnrealRPC_Multicast(UGCGameSystem.GameState, "Multicast_PlayParticleEffect", UGCParticleTools.List.PlaneGetKickedHome02, location);
end

return AeroplaneAIController;
