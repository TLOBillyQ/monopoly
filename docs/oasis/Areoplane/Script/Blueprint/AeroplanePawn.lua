-- ---@class AeroplanePawn_C:BP_PlayerPawn_C
-- ---@field ChessCamera UCameraComponent
-- ---@field TeamMark UStaticMeshComponent
-- ---@field TeamIndex int32
-- ---@field Index int32
-- --Edit Below--
-- local AeroplanePawn = {
--     -- 目前站在哪块地砖上
--     CurrentTileIndex = 0;
--     -- 当前状态（在家、待出发、路上、已到达）
--     CurrentState = 0;

--     bIsSetTeamMark = false;
--     TeamMarkMaterial = nil;  -- 区分队伍的光环材质
-- };

-- function AeroplanePawn:GetReplicatedProperties()
--     return
-- end

-- function AeroplanePawn:GetAvailableServerRPCs()
--     return 
-- end

-- function AeroplanePawn:ReceiveBeginPlay()
--     self.CurrentTileIndex = self:GetStartTileIndex()

--     -- 创建TeamIndex对应的材质
--     self.TeamMarkMaterial = LoadObject(AeroplaneChessAssetConfigs.TeamMarkConfigList[self.TeamIndex].MaterialPath)
-- end

-- function AeroplanePawn:ReceiveTick(DeltaTime)
--     if self.TeamMarkMaterial and not self.bIsSetTeamMark then
--         local DisplayMaterial = KismetMaterialLibrary.CreateDynamicMaterialInstance(self, self.TeamMarkMaterial);
--         self.bIsSetTeamMark = true
--         self.TeamMark:SetMaterial(0, DisplayMaterial)
--     end
-- end

-- -- function AeroplanePawn:ReceiveEndPlay()

-- -- end

-- -- 计算初始时脚下地砖的index
-- function AeroplanePawn:GetStartTileIndex()
--     return self.TeamIndex * 1000 + self.Index
-- end

-- -- 获取当前脚下的地砖对象
-- function AeroplanePawn:GetCurTile()
--     return UGCGameSystem.GameState.TilesList[self.CurrentTileIndex]
-- end

-- -- 是否进入了终点区域
-- function AeroplanePawn:IsInEndPointLine()
--     return self.CurrentTileIndex > 100 * self.TeamIndex and self.CurrentTileIndex < 100 * self.TeamIndex + 7
-- end

-- -- 距离终点还有几步
-- function AeroplanePawn:NumStepsFromEndPoint()
--     if not self:IsInEndPointLine() then
--         return false
--     end
--     return 100 * self.TeamIndex + 6 - self.CurrentTileIndex
-- end

-- function AeroplanePawn:PawnMoveToLocation(position)
--     local controller = self:GetController()
--     if controller == nil then
--         print("AeroplanePawn:PawnMoveToLocation controller is nil")
--         return
--     end
--     controller:MoveToLocation((VectorHelper.ToLuaTable(position)))
-- end

-- return AeroplanePawn;