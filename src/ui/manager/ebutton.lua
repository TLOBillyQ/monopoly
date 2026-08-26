---@class UIManager.EButton : UIManager.ENode
---@field __name "UIManager.EButton"
---@field text string 按钮文本
---@field text_color Color 文本颜色，Hex值，例如0xFF0000是红色
---@field font_size Fixed 字体大小
---@field normal_image ImageKey 常态图片
---@field pressed_image ImageKey 按下图片
---@field protected __protected_text string 受保护的文本内容
---@field protected __protected_text_color Color 受保护的文本颜色
---@field protected __protected_font_size Fixed 受保护的字体大小
---@field protected __protected_normal_image ImageKey 常态图片
---@field protected __protected_pressed_image ImageKey 按下图片
local Class = require("src.ui.manager.class")
local ENode = require("src.ui.manager.enode")
local push = require("src.ui.manager.host_push").push
local EButton = Class("UIManager.EButton", ENode)

---@param node ENode
---@param name string
function EButton:init(node, name)
    ENode.init(self, node, name)
    self.__protected_text = ""
end

function EButton:__set_disabled(value)
    self.__protected_disabled = value
    self:__update_disabled()
end

function EButton:__update_disabled()
    -- 两个宿主方法按角色成对下发(touch 后 enabled),顺序与拆成两次 push 不同,故合在一个 apply 内。
    push(function(role)
        role.set_node_touch_enabled(self.__protected_id, not self.__protected_disabled)
        role.set_button_enabled(self.__protected_id, not self.__protected_disabled)
    end)
end

function EButton:__get_text()
    return self.__protected_text
end

function EButton:__set_text(value)
    self.__protected_text = value
    self:__update_text()
end

function EButton:__update_text()
    push(function(role)
        role.set_button_text(self.__protected_id, self.__protected_text)
    end)
end

function EButton:__get_text_color()
    return self.__protected_text_color
end

function EButton:__set_text_color(value)
    self.__protected_text_color = value
    self:__update_text_color()
end

function EButton:__update_text_color()
    push(function(role)
        role.set_button_text_color(self.__protected_id, self.__protected_text_color)
    end)
end

function EButton:__get_font_size()
    return self.__protected_font_size
end

function EButton:__set_font_size(value)
    self.__protected_font_size = math.tofixed(value)
    self:__update_font_size()
end

function EButton:__update_font_size()
    push(function(role)
        role.set_button_font_size(self.__protected_id, self.__protected_font_size)
    end)
end

return EButton

--[[ mutate4lua-manifest
version=4
projectHash=125eb9d78256a346
scope.0.id=chunk:src/ui/manager/ebutton.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=84
scope.0.semanticHash=d70beb57e91ef217
scope.1.id=function:EButton:init
scope.1.kind=function
scope.1.startLine=20
scope.1.endLine=23
scope.1.semanticHash=ff8d061915b0f2b3
scope.2.id=function:EButton:__set_disabled
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=28
scope.2.semanticHash=d9865bc65df52544
scope.3.id=function:EButton:__update_disabled
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=36
scope.3.semanticHash=08189454c8b6e1d9
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=35
scope.4.semanticHash=b2b62d4d51c62647
scope.5.id=function:EButton:__get_text
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=40
scope.5.semanticHash=c0484ae42c9068b0
scope.6.id=function:EButton:__set_text
scope.6.kind=function
scope.6.startLine=42
scope.6.endLine=45
scope.6.semanticHash=d9865bc65df52544
scope.7.id=function:EButton:__update_text
scope.7.kind=function
scope.7.startLine=47
scope.7.endLine=51
scope.7.semanticHash=83f74b98acb97bad
scope.8.id=function:<anonymous>#2
scope.8.kind=function
scope.8.startLine=48
scope.8.endLine=50
scope.8.semanticHash=713e373fad31bfcb
scope.9.id=function:EButton:__get_text_color
scope.9.kind=function
scope.9.startLine=53
scope.9.endLine=55
scope.9.semanticHash=c0484ae42c9068b0
scope.10.id=function:EButton:__set_text_color
scope.10.kind=function
scope.10.startLine=57
scope.10.endLine=60
scope.10.semanticHash=d9865bc65df52544
scope.11.id=function:EButton:__update_text_color
scope.11.kind=function
scope.11.startLine=62
scope.11.endLine=66
scope.11.semanticHash=83f74b98acb97bad
scope.12.id=function:<anonymous>#3
scope.12.kind=function
scope.12.startLine=63
scope.12.endLine=65
scope.12.semanticHash=713e373fad31bfcb
scope.13.id=function:EButton:__get_font_size
scope.13.kind=function
scope.13.startLine=68
scope.13.endLine=70
scope.13.semanticHash=c0484ae42c9068b0
scope.14.id=function:EButton:__set_font_size
scope.14.kind=function
scope.14.startLine=72
scope.14.endLine=75
scope.14.semanticHash=fbcaee375518918e
scope.15.id=function:EButton:__update_font_size
scope.15.kind=function
scope.15.startLine=77
scope.15.endLine=81
scope.15.semanticHash=83f74b98acb97bad
scope.16.id=function:<anonymous>#4
scope.16.kind=function
scope.16.startLine=78
scope.16.endLine=80
scope.16.semanticHash=713e373fad31bfcb
]]
