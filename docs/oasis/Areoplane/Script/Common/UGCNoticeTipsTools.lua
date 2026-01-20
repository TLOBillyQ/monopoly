UGCNoticeTipsTools = UGCNoticeTipsTools or {}

function UGCNoticeTipsTools:ControllerReg(PlayerController)
    ugcprint("UGCNoticeTipsTools:ControllerReg")
    PlayerController["ServerRPC_ShowNoticeTips"] = self.ClienNoticeTips
end

function UGCNoticeTipsTools:ServerNoticeTips(PlayerKey, TipsID)
    ugcprint("UGCNoticeTipsTools:ServerNoticeTips:"..PlayerKey.." TipsID:"..TipsID)

    local PlayerController = UGCGameSystem.GetPlayerControllerByPlayerKey(PlayerKey)
    if PlayerController == nil then
        print("UGCNoticeTipsTools:ServerNoticeTips PlayerController is nil")
        return
    end

    if PlayerController:HasAuthority() == false then
        return
    end

    UnrealNetwork.CallUnrealRPC_Unreliable(PlayerController, PlayerController, "ServerRPC_ShowNoticeTips", TipsID);
end

function UGCNoticeTipsTools:MultiCastNoticeTips(TipsID)

    if UGCGameSystem.GameState:HasAuthority() == false then
        return
    end

    UnrealNetwork.CallUnrealRPC_Multicast_Unreliable(UGCGameSystem.GameState, "MulticastRPC_ShowNoticeTips", TipsID);
end

-------------------------------------客户端逻辑部分-------------------------------------

function UGCNoticeTipsTools:ClienNoticeTips(TipsID)
    ugcprint("UGCNoticeTipsTools:ClienNoticeTips:"..TipsID)

    local Data = AeroplaneChessTipsConfig.ID2Str[TipsID]
    if Data == nil then
        return
    end

    PopUpNoticeUI.ShowFastNoticeQueue(Data.S)
end

return UGCNoticeTipsTools