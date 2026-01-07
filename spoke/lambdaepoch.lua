-- LambdaEpoch.lua
-- Define epochs in a functional composition style

local LambdaEpoch = {}
LambdaEpoch.__index = LambdaEpoch

local Epoch = require("spoke.epoch")
setmetatable(LambdaEpoch, { __index = Epoch })

function LambdaEpoch.new(name, block)
    local self = Epoch.new()
    setmetatable(self, LambdaEpoch)
    
    self.Name = name or "LambdaEpoch"
    self.block = block
    
    return self
end

function LambdaEpoch:Init(s)
    return self.block(s)
end

return LambdaEpoch
