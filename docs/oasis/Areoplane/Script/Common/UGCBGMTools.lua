UGCBGMTools = UGCBGMTools or 
{
    StateData = {};
    CurState = 0;
    LastStateTime = 0;

    --客户端
    LastPlayTime = 0;
    DelayStopState = 0;
}

EBGMState = 
{
    Normal       = 1;
    Link         = 2;
    Transfom     = 3;
    Stop         = 4;
}

function UGCBGMTools:Init()
    self:RegState(EBGMState.Normal,   3600, AeroplaneChessAudioConfig.ID.BGM_NORMAL, true, 61)
    -- self:RegState(EBGMState.Link,     6,   AeroplaneChessAudioConfig.ID.BGM_LINK, false)
    -- self:RegState(EBGMState.Transfom, 200, AeroplaneChessAudioConfig.ID.BGM_TRANSFORM, true, 92)
    -- self:RegState(EBGMState.Stop,     0,   0, false)
end

function UGCBGMTools:RegState(StateId, PlayTime, BMGID, Loop, LoopTime)
    if self.StateData[StateId] ~= nil then
        --重复注册
        ugcprint("UGCBGMTools:RegState Again:"..StateId)
        return
    end

    local tab = {}
    tab.StateId         = StateId
    tab.PlayTime        = PlayTime
    tab.BMGID           = BMGID
    tab.Loop            = Loop or false
    tab.LoopTime        = LoopTime or -1

    self.StateData[StateId] = tab
end

--服务器只管持续时间
function UGCBGMTools:ServerTick()
    local Data = self.StateData[self.CurState]
    if Data == nil then
        return
    end

    local Now = GameplayStatics.GetRealTimeSeconds(UGCGameSystem.GameState)
    if Now >= self.LastStateTime + Data.PlayTime then
        self:SetState(self.CurState + 1)
    end
end

function UGCBGMTools:ClientTick()
    local Data = self.StateData[self.CurState]
    if Data == nil then
        return
    end

    local Now = GameplayStatics.GetRealTimeSeconds(UGCGameSystem.GameState)

    if Now >= self.LastPlayTime + 1 then
        local StopData = self.StateData[self.DelayStopState]
        if StopData ~= nil and StopData.BMGID > 0 then
            UGCSoundTools:ClientStopSound(StopData.BMGID)
        end
    end

    if Data.Loop == true then
        if Now >= self.LastPlayTime + Data.LoopTime then
            UGCSoundTools:ClientPlaySound2D(Data.BMGID, GameplayStatics.GetPlayerPawn(UGCGameSystem.GameState, 0))
            self.LastPlayTime = Now
        end
    end
end

function UGCBGMTools:SetState(NewState)
    if self.StateData[NewState] ~= nil then
        ugcprint("UGCBGMTools:SetState:"..NewState)
        local LastState = self.CurState
        self.CurState = NewState
        self.LastStateTime = GameplayStatics.GetRealTimeSeconds(UGCGameSystem.GameState)
        UGCGameSystem.GameState.BGMState = NewState

        if UGCGameSystem.GameState:HasAuthority() == false then
            --客户端的State逻辑
            self:PlayBGM(LastState, NewState)
        end
    end
end

function UGCBGMTools:PlayBGM(LastState, NewState)
    local NewData = self.StateData[NewState]

    if NewData.BMGID > 0 then
        self.DelayStopState = LastState
        UGCSoundTools:ClientPlaySound2D(NewData.BMGID, nil)
        self.LastPlayTime = GameplayStatics.GetRealTimeSeconds(UGCGameSystem.GameState)
    else
        UGCSoundTools:ClientStopAllSound()
    end
end

function UGCBGMTools:StopLogic()
    self.CurState = 0
    self.StateData = {}
end

return UGCBGMTools