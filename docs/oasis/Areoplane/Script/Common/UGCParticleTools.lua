UGCParticleTools = UGCParticleTools or {

}

local Path = function(Str)
    return UGCMapInfoLib.GetRootLongPackagePath()..Str
end

UGCParticleTools.List = 
{
    -- 棋子被踢回家的两个特效
    PlaneGetKickedHome01        = 1;
    PlaneGetKickedHome02        = 2;
    -- 选择了某个棋子后，地板亮起来的特效
    TileHighlight               = 3;
    -- 棋子完成比赛后皇冠的发光特效
    CrownLight               = 4;
}

UGCParticleTools.ID2List = 
{
    [UGCParticleTools.List.PlaneGetKickedHome01]        = Path("Asset/Arts_Effect/Particle/P_convey_01.P_convey_01");
    [UGCParticleTools.List.PlaneGetKickedHome02]        = Path("Asset/Arts_Effect/Particle/P_convey_02.P_convey_02");
    [UGCParticleTools.List.TileHighlight]               = Path("Asset/Arts_Effect/Particle/P_lattice_01.P_lattice_01");
    [UGCParticleTools.List.CrownLight]               = Path("Asset/Arts_Effect/Particle/P_Crown_lights_01.P_Crown_lights_01");
}

function UGCParticleTools:PreLoad()
    ugcprint("UGCParticleTools:PreLoad")
    for k, _ in pairs(self.ID2List) do
        self:Load(k)
    end
end

function UGCParticleTools:Load(ParticleId)
    -- local PlayerController = GameplayStatics.GetPlayerController(UGCGameSystem.GameState, 0);
    -- local ParticleIns = nil;
    -- CommonUtils:AsyncLoadObject(PlayerController, self.ID2List[ParticleId], 
    --     function (Particle)
    --         ParticleIns = Particle;
    --     end
    -- )
    --UE.LoadObject(self.ID2List[ParticleId]);
    return UE.LoadObject(self.ID2List[ParticleId])
end

function UGCParticleTools:AsyncLoadWithCallback(ParticleId, Callback)
    local PlayerController = GameplayStatics.GetPlayerController(UGCGameSystem.GameState, 0);
    UGCAsyncLoadTools:LoadObject(self.ID2List[ParticleId], 
        function (Particle)
            Callback(Particle);
        end
    )
end


return UGCParticleTools