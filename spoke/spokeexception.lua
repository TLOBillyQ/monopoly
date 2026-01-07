-- SpokeException.lua
-- Exception wrapper with virtual call stack snapshot

local SpokeException = {}
SpokeException.__index = SpokeException

function SpokeException.new(msg, inner, frames)
    local self = setmetatable({}, SpokeException)
    self.message = msg
    self.inner = inner
    self.stackSnapshot = {}
    self.SkipMarkFaulted = false
    
    -- Copy stack frames
    if frames then
        for i = 1, #frames do
            table.insert(self.stackSnapshot, frames[i])
        end
    end
    
    self.innerTrace = inner and tostring(inner) or ""
    return self
end

function SpokeException:ToString()
    local trace = ""
    for i = 1, #self.stackSnapshot do
        trace = trace .. tostring(self.stackSnapshot[i]) .. "\n"
    end
    return string.format("%s\n%s", trace, self.innerTrace)
end

function SpokeException:__tostring()
    return self:ToString()
end

return SpokeException
