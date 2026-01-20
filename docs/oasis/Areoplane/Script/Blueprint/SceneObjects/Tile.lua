---@class Tile_C:Actor
---@field PosLeftBottom USceneComponent
---@field PosRightBottom USceneComponent
---@field PosRightTop USceneComponent
---@field PosLeftTop USceneComponent
---@field Pos USceneComponent
---@field StaticMesh UStaticMeshComponent
---@field DefaultSceneRoot USceneComponent
---@field Index int32
---@field NextIndex int32
---@field JumpIndex int32
---@field IsFlying bool
---@field IsTurning bool
---@field TeamID int32
---@field IsGrey bool
--Edit Below--
local Tile = {
    MiddleLocation = nil;
    PosLeftTop = nil;
    RightTopLocation = nil;
    LeftBottomLocation = nil;
    RightBottomLocation = nil;
}; 
function Tile:ReceiveBeginPlay()
    -- ugcprint("Tile:ReceiveBeginPlay");
    self.MiddleLocation = VectorHelper.ToLuaTable(self.Pos:K2_GetComponentLocation());
    self.LeftTopLocation = VectorHelper.ToLuaTable(self.PosLeftTop:K2_GetComponentLocation());
    self.RightTopLocation = VectorHelper.ToLuaTable(self.PosRightTop:K2_GetComponentLocation());
    self.LeftBottomLocation = VectorHelper.ToLuaTable(self.PosLeftBottom:K2_GetComponentLocation());
    self.RightBottomLocation = VectorHelper.ToLuaTable(self.PosRightBottom:K2_GetComponentLocation());
end

function Tile:ReceiveEndPlay()
 
end

function Tile:GetLocation()
    return self.Pos:K2_GetComponentLocation()
end

function Tile:GetOnePlayerLocation()
    return self.Pos:K2_GetComponentLocation()
end

function Tile:GetTwoPlayerTileLocation(index)
    local LeftSideMiddlePointLocation = VectorHelper.GetMiddlePoint(self.LeftTopLocation,self.LeftBottomLocation);
    local RightSideMiddlePointLocation = VectorHelper.GetMiddlePoint(self.RightTopLocation,self.RightBottomLocation);
    if index == 1 then
        return VectorHelper.GetMiddlePoint(self.MiddleLocation,LeftSideMiddlePointLocation);
    elseif index == 2 then
        return VectorHelper.GetMiddlePoint(self.MiddleLocation,RightSideMiddlePointLocation);
    end
end

function Tile:GetThreePlayerTileLocation(index)
    local BottomSideMiddlePointLocation = VectorHelper.GetMiddlePoint(self.LeftBottomLocation,self.RightBottomLocation);
    if index == 1 then
        return VectorHelper.GetMiddlePoint(self.MiddleLocation,self.LeftTopLocation);
    elseif index == 2 then
        return VectorHelper.GetMiddlePoint(self.MiddleLocation,self.RightTopLocation);
    elseif index == 3 then
        return VectorHelper.GetMiddlePoint(self.MiddleLocation,BottomSideMiddlePointLocation);
    end
end

function Tile:GetFourPlayerTileLocation(index)
    local BottomSideMiddlePointLocation = VectorHelper.GetMiddlePoint(self.LeftBottomLocation,self.RightBottomLocation);
    if index == 1 then
        return VectorHelper.GetMiddlePoint(self.MiddleLocation,self.LeftTopLocation);
    elseif index == 2 then
        return VectorHelper.GetMiddlePoint(self.MiddleLocation,self.RightTopLocation);
    elseif index == 3 then
        return VectorHelper.GetMiddlePoint(self.MiddleLocation,self.LeftBottomLocation);
    elseif index == 4 then
        return VectorHelper.GetMiddlePoint(self.MiddleLocation,self.RightBottomLocation);
    end
end

-- 获取站在此地砖上的所有棋子
function Tile:GetPlanesOnThisTile()
    ugcprint("Tile:GetPlanesOnThisTile");

    local result = {}
    for _, PlayerInfo in pairs(UGCGameSystem.GameState.PlayerInfos) do
        for _, PlaneInfo in pairs(PlayerInfo.PlaneInfos) do
            if PlaneInfo.CurrentTileIndex == self.Index then
                table.insert(result, PlaneInfo)
            end
        end
    end
    return result
end

-- 此块地砖是否是终点
function Tile:IsEndPointTile()
    return self.Index == 81 or self.Index == 82 or self.Index == 83 or self.Index == 84
end

-- 高亮此地砖
function Tile:SetTileHighlight(bHightlight)
    ugcprint("Tile:SetTileHighlight"..tostring(bHightlight));
    if bHightlight then
        if self.HighlightParticle == nil then
            -- 这里不用self.MiddleLocation 因为此函数可能在tile的beginplay之前调用
            local location = VectorHelper.ToLuaTable(self.Pos:K2_GetComponentLocation())
            -- 提高一点，以防被地板挡住
            location.Z = location.Z + 20
            -- 异步加载特效
            UGCParticleTools:AsyncLoadWithCallback(UGCParticleTools.List.TileHighlight,        
            function (Particle)
                if self.HighlightParticle ~= nil then
                    return;
                end
                self.HighlightParticle = STExtraBlueprintFunctionLibrary.SpawnCustomEmitterAtLocation(self, Particle, location, {Roll=0, Pitch=0, Yaw=0}, false)
                -- 根据TeamIndex设置地板特效颜色
                if AeroplaneChessMode.OwnerPlayerState then
                    ugcprint("AeroplaneChessMode.OwnerPlayerState TeamId is:" .. tostring(AeroplaneChessMode.OwnerPlayerState.TeamIndex));
                    ugcprint("AeroplaneChessMode.OwnerPlayerState TeamColorStr is:" .. ETeameColor[AeroplaneChessMode.OwnerPlayerState.TeamIndex]);
                    log_tree("TeamColorRGB",ETeameColorRGB[ETeameColor[AeroplaneChessMode.OwnerPlayerState.TeamIndex]]);
                    self.HighlightParticle:SetColorParameter("Color", ETeameColorRGB[ETeameColor[AeroplaneChessMode.OwnerPlayerState.TeamIndex]]);
                    ugcprint("AeroplaneChessMode.OwnerPlayerState SetColor Done");
                else
                    print("AeroplaneChessMode.OwnerPlayerState is Nil");
                end
            end)
        end
    elseif self.HighlightParticle ~= nil then
        self.HighlightParticle:K2_DestroyComponent()
        self.HighlightParticle = nil
    end
end


return Tile;