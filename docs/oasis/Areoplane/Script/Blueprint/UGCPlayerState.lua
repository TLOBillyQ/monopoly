---@class UGCPlayerState_C:BP_PlayerState_C
--Edit Below--
local UGCPlayerState = {
    -- 玩家的位置（P1-P4）
    TeamIndex = 0;
}; 

function UGCPlayerState:GetReplicatedProperties()
    return 
    "TeamIndex"
end

function UGCPlayerState:ReceiveBeginPlay()
    ugcprint(string.format("UGCPlayerState:ReceiveBeginPlay[%s]", self.PlayerName));
    self.SuperClass.ReceiveBeginPlay(self);
    
    if self:HasAuthority() == true then 
    else
        if self:GetOwner() == GameplayStatics.GetPlayerController(self, 0) then
            ugcprint("UGCPlayerState:ReceiveBeginPlay Set AeroplaneChessMode.OwnerPlayerState");
            AeroplaneChessMode.OwnerPlayerState = self;
        end
        self.hasBegunPlay = true
        self:TrySendTeamIndexAssignEvent();
    end
end

function UGCPlayerState:OnRep_TeamIndex()
    ugcprint(string.format("UGCPlayerState:OnRep_TeamIndex %d", self.TeamIndex));
    self:TrySendTeamIndexAssignEvent();
end

-- 如果onrep在beginplay之前调用会有问题，这样规避一下
function UGCPlayerState:TrySendTeamIndexAssignEvent()
    if self.hasBegunPlay and self.TeamIndex ~= 0 then
        print(string.format("UGCPlayerState:TrySendTeamIndexAssignEvent %d", self.TeamIndex));
        UGCEventSystem:SendEvent(AeroplaneChessEventType.TeamIndexAssigned, self.TeamIndex, self.PlayerKey);
    end
end

-- function UGCPlayerState:ReceiveTick(DeltaTime)

-- end
-- function UGCPlayerState:ReceiveEndPlay()
 
-- end
return UGCPlayerState;