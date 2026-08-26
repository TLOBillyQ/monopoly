---@class UIManager.EInputField : UIManager.ENode
---@field __name "UIManager.EInputField"
---@field text string 文本内容
---@field text_color Color 文本颜色，Hex值，例如0xFF0000是红色
---@field protected __protected_text string 受保护的文本内容
local Class = require("src.ui.manager.class")
local ENode = require("src.ui.manager.enode")
local push = require("src.ui.manager.host_push").push
local EInputField = Class("UIManager.EInputField", ENode)

---@param node ENode
---@param name string
function EInputField:init(node, name)
    ENode.init(self, node, name)
    self.__protected_text = ""
end

function EInputField:__get_text()
    return self.__protected_text
end

function EInputField:__set_text(value)
    self.__protected_text = value
    self:__update_text()
end

function EInputField:__update_text()
    push(function(role)
        role.set_input_field_text(self.__protected_id, self.__protected_text)
    end)
end

return EInputField

--[[ mutate4lua-manifest
version=4
projectHash=36d961a96c3ac9e9
scope.0.id=chunk:src/ui/manager/einputfield.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=34
scope.0.semanticHash=6c9a6c6f27920fc4
scope.1.id=function:EInputField:init
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=16
scope.1.semanticHash=ff8d061915b0f2b3
scope.2.id=function:EInputField:__get_text
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=c0484ae42c9068b0
scope.3.id=function:EInputField:__set_text
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=25
scope.3.semanticHash=d9865bc65df52544
scope.4.id=function:EInputField:__update_text
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=31
scope.4.semanticHash=83f74b98acb97bad
scope.5.id=function:<anonymous>
scope.5.kind=function
scope.5.startLine=28
scope.5.endLine=30
scope.5.semanticHash=713e373fad31bfcb
]]
