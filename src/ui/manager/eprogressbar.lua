---@class UIManager.EProgressbar : UIManager.ENode
---@field __name "UIManager.EProgressbar"
---@field value integer 进度值
---@field max_value integer 最大进度值
---@field min_value integer 最小进度值
---@field transition_time Fixed 样式变化时间
---@field protected __protected_value integer 进度值
---@field protected __protected_max_value integer 最大进度值
---@field protected __protected_min_value integer 最小进度值
---@field protected __protected_transition_time Fixed 受保护的样式变化时间
local Class = require("src.ui.manager.class")
local ENode = require("src.ui.manager.enode")
local push = require("src.ui.manager.host_push").push
local EProgressbar = Class("UIManager.EProgressbar", ENode)

---@param node ENode
---@param name string
function EProgressbar:init(node, name)
    ENode.init(self, node, name)
    self.__protected_transition_time = 0.0
end

function EProgressbar:__get_value()
    return self.__protected_value
end

function EProgressbar:__set_value(value)
    self.__protected_value = value
    self:__update_value()
end

function EProgressbar:__update_value()
    push(function(role)
        role.set_progressbar_transition(self.__protected_id, self.__protected_value, self.__protected_transition_time)
    end)
end

function EProgressbar:__get_max_value()
    return self.__protected_max_value
end

function EProgressbar:__set_max_value(value)
    self.__protected_max_value = value
    self:__update_max_value()
end

function EProgressbar:__update_max_value()
    push(function(role)
        role.set_progressbar_max(self.__protected_id, self.__protected_max_value)
    end)
end

function EProgressbar:__get_min_value()
    return self.__protected_min_value
end

function EProgressbar:__set_min_value(value)
    self.__protected_min_value = value
    self:__update_min_value()
end

function EProgressbar:__update_min_value()
    push(function(role)
        role.set_progressbar_min(self.__protected_id, self.__protected_min_value)
    end)
end

function EProgressbar:__get_transition_time()
    return self.__protected_transition_time
end

function EProgressbar:__set_transition_time(value)
    self.__protected_transition_time = value
end

return EProgressbar

--[[ mutate4lua-manifest
version=4
projectHash=9b8af9bed3f91f7b
scope.0.id=chunk:src/ui/manager/eprogressbar.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=77
scope.0.semanticHash=fe2984c62ec787e4
scope.1.id=function:EProgressbar:init
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=21
scope.1.semanticHash=66b43f92b5bf3203
scope.2.id=function:EProgressbar:__get_value
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=25
scope.2.semanticHash=c0484ae42c9068b0
scope.3.id=function:EProgressbar:__set_value
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=30
scope.3.semanticHash=d9865bc65df52544
scope.4.id=function:EProgressbar:__update_value
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=36
scope.4.semanticHash=1769398f7a96b855
scope.5.id=function:<anonymous>
scope.5.kind=function
scope.5.startLine=33
scope.5.endLine=35
scope.5.semanticHash=af10c7ccfb55253d
scope.6.id=function:EProgressbar:__get_max_value
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=40
scope.6.semanticHash=c0484ae42c9068b0
scope.7.id=function:EProgressbar:__set_max_value
scope.7.kind=function
scope.7.startLine=42
scope.7.endLine=45
scope.7.semanticHash=d9865bc65df52544
scope.8.id=function:EProgressbar:__update_max_value
scope.8.kind=function
scope.8.startLine=47
scope.8.endLine=51
scope.8.semanticHash=83f74b98acb97bad
scope.9.id=function:<anonymous>#2
scope.9.kind=function
scope.9.startLine=48
scope.9.endLine=50
scope.9.semanticHash=713e373fad31bfcb
scope.10.id=function:EProgressbar:__get_min_value
scope.10.kind=function
scope.10.startLine=53
scope.10.endLine=55
scope.10.semanticHash=c0484ae42c9068b0
scope.11.id=function:EProgressbar:__set_min_value
scope.11.kind=function
scope.11.startLine=57
scope.11.endLine=60
scope.11.semanticHash=d9865bc65df52544
scope.12.id=function:EProgressbar:__update_min_value
scope.12.kind=function
scope.12.startLine=62
scope.12.endLine=66
scope.12.semanticHash=83f74b98acb97bad
scope.13.id=function:<anonymous>#3
scope.13.kind=function
scope.13.startLine=63
scope.13.endLine=65
scope.13.semanticHash=713e373fad31bfcb
scope.14.id=function:EProgressbar:__get_transition_time
scope.14.kind=function
scope.14.startLine=68
scope.14.endLine=70
scope.14.semanticHash=c0484ae42c9068b0
scope.15.id=function:EProgressbar:__set_transition_time
scope.15.kind=function
scope.15.startLine=72
scope.15.endLine=74
scope.15.semanticHash=e66f374cdcfa7616
]]
