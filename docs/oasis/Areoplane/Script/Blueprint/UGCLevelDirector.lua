---@class UGCLevelDirector_C:STExtraLevelDirector
---@field DefaultSceneRoot USceneComponent
--Edit Below--
local UGCLevelDirector = {}
 
--[[
function UGCLevelDirector:ReceiveBeginPlay()
    UGCLevelDirector.SuperClass.ReceiveBeginPlay(self)
end
--]]

--[[
function UGCLevelDirector:ReceiveTick(DeltaTime)
    UGCLevelDirector.SuperClass.ReceiveTick(self, DeltaTime)
end
--]]

--[[
function UGCLevelDirector:ReceiveEndPlay()
    UGCLevelDirector.SuperClass.ReceiveEndPlay(self) 
end
--]]

--[[
function UGCLevelDirector:GetReplicatedProperties()
    return
end
--]]

--[[
function UGCLevelDirector:GetAvailableServerRPCs()
    return
end
--]]

return UGCLevelDirector