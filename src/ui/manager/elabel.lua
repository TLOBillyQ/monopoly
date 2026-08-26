---@class UIManager.ELabel : UIManager.ENode
---@field __name "UIManager.ELabel"
---@field text string 文本内容
---@field label_background_color Color 背景颜色
---@field label_background_opacity Fixed 背景不透明度
---@field text_color Color 文本颜色，Hex值，例如0xFF0000是红色
---@field transition_time Fixed 样式变化时间
---@field font_family FontKey 字体
---@field font_size integer 字体大小
---@field outline_color Color 描边颜色
---@field outline boolean 是否描边
---@field outline_opacity Fixed 描边不透明度
---@field outline_width Fixed 描边宽度
---@field shadow_color Color 阴影颜色
---@field shadow boolean 是否阴影
---@field shadow_x_offset Fixed 阴影x偏移
---@field shadow_y_offset Fixed 阴影y偏移
---@field protected __protected_text string 受保护的文本内容
---@field protected __protected_label_background_color Color 背景颜色
---@field protected __protected_label_background_opacity Fixed 背景不透明度
---@field protected __protected_text_color Color 受保护的文本颜色
---@field protected __protected_transition_time Fixed 受保护的样式变化时间
---@field protected __protected_font_family FontKey 字体
---@field protected __protected_font_size integer 字体大小
---@field protected __protected_outline_color Color 描边颜色
---@field protected __protected_outline boolean 是否描边
---@field protected __protected_outline_opacity Fixed 描边不透明度
---@field protected __protected_outline_width Fixed 描边宽度
---@field protected __protected_shadow_color Color 阴影颜色
---@field protected __protected_shadow boolean 是否阴影
---@field protected __protected_shadow_x_offset Fixed 阴影x偏移
---@field protected __protected_shadow_y_offset Fixed 阴影y偏移
local Class = require("src.ui.manager.class")
local ENode = require("src.ui.manager.enode")
local push = require("src.ui.manager.host_push").push
local ELabel = Class("UIManager.ELabel", ENode)

---@param node ENode
---@param name string
function ELabel:init(node, name)
    ENode.init(self, node, name)
    self.__protected_text = ""
    self.__protected_transition_time = 0.0
end

function ELabel:__get_text()
    return self.__protected_text
end

function ELabel:__set_text(value)
    self.__protected_text = value
    self:__update_text()
end

function ELabel:__update_text()
    push(function(role)
        role.set_label_text(self.__protected_id, self.__protected_text)
    end)
end

function ELabel:__get_label_background_color()
    return self.__protected_label_background_color
end

function ELabel:__set_label_background_color(value)
    self.__protected_label_background_color = value
    self:__update_label_background_color()
end

function ELabel:__update_label_background_color()
    push(function(role)
        role.set_label_background_color(self.__protected_id, self.__protected_label_background_color,
            self.__protected_transition_time)
    end)
end

function ELabel:__get_label_background_opacity()
    return self.__protected_label_background_opacity
end

function ELabel:__set_label_background_opacity(value)
    self.__protected_label_background_opacity = math.tofixed(value)
    self:__update_label_background_opacity()
end

function ELabel:__update_label_background_opacity()
    push(function(role)
        role.set_label_background_opacity(self.__protected_id, self.__protected_label_background_opacity,
            self.__protected_transition_time)
    end)
end

function ELabel:__get_text_color()
    return self.__protected_text_color
end

function ELabel:__set_text_color(value)
    self.__protected_text_color = value
    self:__update_text_color()
end

function ELabel:__update_text_color()
    push(function(role)
        role.set_label_color(self.__protected_id, self.__protected_text_color, self.__protected_transition_time)
    end)
end

function ELabel:__get_transition_time()
    return self.__protected_transition_time
end

function ELabel:__set_transition_time(value)
    self.__protected_transition_time = math.tofixed(value)
end

function ELabel:__get_font_family()
    return self.__protected_font_family
end

function ELabel:__set_font_family(value)
    self.__protected_font_family = value
    self:__update_font_family()
end

function ELabel:__update_font_family()
    push(function(role)
        role.set_label_font(self.__protected_id, self.__protected_font_family)
    end)
end

function ELabel:__get_font_size()
    return self.__protected_font_size
end

function ELabel:__set_font_size(value)
    self.__protected_font_size = math.tointeger(value)
    self:__update_font_size()
end

function ELabel:__update_font_size()
    push(function(role)
        role.set_label_font_size(self.__protected_id, self.__protected_font_size, self.__protected_transition_time)
    end)
end

function ELabel:__get_outline_color()
    return self.__protected_outline_color
end

function ELabel:__set_outline_color(value)
    self.__protected_outline_color = value
    self:__update_outline_color()
end

function ELabel:__update_outline_color()
    push(function(role)
        role.set_label_outline_color(self.__protected_id, self.__protected_outline_color)
    end)
end

function ELabel:__get_outline()
    return self.__protected_outline
end

function ELabel:__set_outline(value)
    self.__protected_outline = value
    self:__update_outline()
end

function ELabel:__update_outline()
    push(function(role)
        role.set_label_outline_enabled(self.__protected_id, self.__protected_outline)
    end)
end

function ELabel:__get_outline_opacity()
    return self.__protected_outline_opacity
end

function ELabel:__set_outline_opacity(value)
    self.__protected_outline_opacity = math.tofixed(value)
    self:__update_outline_opacity()
end

function ELabel:__update_outline_opacity()
    push(function(role)
        role.set_label_outline_opacity(self.__protected_id, self.__protected_outline_opacity)
    end)
end

function ELabel:__get_outline_width()
    return self.__protected_outline_width
end

function ELabel:__set_outline_width(value)
    self.__protected_outline_width = math.tofixed(value)
    self:__update_outline_width()
end

function ELabel:__update_outline_width()
    push(function(role)
        role.set_label_outline_width(self.__protected_id, self.__protected_outline_width)
    end)
end

function ELabel:__get_shadow_color()
    return self.__protected_shadow_color
end

function ELabel:__set_shadow_color(value)
    self.__protected_shadow_color = value
    self:__update_shadow_color()
end

function ELabel:__update_shadow_color()
    push(function(role)
        role.set_label_shadow_color(self.__protected_id, self.__protected_shadow_color)
    end)
end

function ELabel:__get_shadow()
    return self.__protected_shadow
end

function ELabel:__set_shadow(value)
    self.__protected_shadow = value
    self:__update_shadow()
end

function ELabel:__update_shadow()
    push(function(role)
        role.set_label_shadow_enabled(self.__protected_id, self.__protected_shadow)
    end)
end

function ELabel:__get_shadow_x_offset()
    return self.__protected_shadow_x_offset
end

function ELabel:__set_shadow_x_offset(value)
    self.__protected_shadow_x_offset = math.tofixed(value)
    self:__update_shadow_x_offset()
end

function ELabel:__update_shadow_x_offset()
    push(function(role)
        role.set_label_shadow_x_offset(self.__protected_id, self.__protected_shadow_x_offset)
    end)
end

function ELabel:__get_shadow_y_offset()
    return self.__protected_shadow_y_offset
end

function ELabel:__set_shadow_y_offset(value)
    self.__protected_shadow_y_offset = math.tofixed(value)
    self:__update_shadow_y_offset()
end

function ELabel:__update_shadow_y_offset()
    push(function(role)
        role.set_label_shadow_y_offset(self.__protected_id, self.__protected_shadow_y_offset)
    end)
end

return ELabel

--[[ mutate4lua-manifest
version=4
projectHash=2721f9f389236b57
scope.0.id=chunk:src/ui/manager/elabel.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=267
scope.0.semanticHash=245ae1d231ec49f4
scope.1.id=function:ELabel:init
scope.1.kind=function
scope.1.startLine=40
scope.1.endLine=44
scope.1.semanticHash=09f837e8a6b1d33c
scope.2.id=function:ELabel:__get_text
scope.2.kind=function
scope.2.startLine=46
scope.2.endLine=48
scope.2.semanticHash=c0484ae42c9068b0
scope.3.id=function:ELabel:__set_text
scope.3.kind=function
scope.3.startLine=50
scope.3.endLine=53
scope.3.semanticHash=d9865bc65df52544
scope.4.id=function:ELabel:__update_text
scope.4.kind=function
scope.4.startLine=55
scope.4.endLine=59
scope.4.semanticHash=83f74b98acb97bad
scope.5.id=function:<anonymous>
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=58
scope.5.semanticHash=713e373fad31bfcb
scope.6.id=function:ELabel:__get_label_background_color
scope.6.kind=function
scope.6.startLine=61
scope.6.endLine=63
scope.6.semanticHash=c0484ae42c9068b0
scope.7.id=function:ELabel:__set_label_background_color
scope.7.kind=function
scope.7.startLine=65
scope.7.endLine=68
scope.7.semanticHash=d9865bc65df52544
scope.8.id=function:ELabel:__update_label_background_color
scope.8.kind=function
scope.8.startLine=70
scope.8.endLine=75
scope.8.semanticHash=1769398f7a96b855
scope.9.id=function:<anonymous>#2
scope.9.kind=function
scope.9.startLine=71
scope.9.endLine=74
scope.9.semanticHash=af10c7ccfb55253d
scope.10.id=function:ELabel:__get_label_background_opacity
scope.10.kind=function
scope.10.startLine=77
scope.10.endLine=79
scope.10.semanticHash=c0484ae42c9068b0
scope.11.id=function:ELabel:__set_label_background_opacity
scope.11.kind=function
scope.11.startLine=81
scope.11.endLine=84
scope.11.semanticHash=fbcaee375518918e
scope.12.id=function:ELabel:__update_label_background_opacity
scope.12.kind=function
scope.12.startLine=86
scope.12.endLine=91
scope.12.semanticHash=1769398f7a96b855
scope.13.id=function:<anonymous>#3
scope.13.kind=function
scope.13.startLine=87
scope.13.endLine=90
scope.13.semanticHash=af10c7ccfb55253d
scope.14.id=function:ELabel:__get_text_color
scope.14.kind=function
scope.14.startLine=93
scope.14.endLine=95
scope.14.semanticHash=c0484ae42c9068b0
scope.15.id=function:ELabel:__set_text_color
scope.15.kind=function
scope.15.startLine=97
scope.15.endLine=100
scope.15.semanticHash=d9865bc65df52544
scope.16.id=function:ELabel:__update_text_color
scope.16.kind=function
scope.16.startLine=102
scope.16.endLine=106
scope.16.semanticHash=1769398f7a96b855
scope.17.id=function:<anonymous>#4
scope.17.kind=function
scope.17.startLine=103
scope.17.endLine=105
scope.17.semanticHash=af10c7ccfb55253d
scope.18.id=function:ELabel:__get_transition_time
scope.18.kind=function
scope.18.startLine=108
scope.18.endLine=110
scope.18.semanticHash=c0484ae42c9068b0
scope.19.id=function:ELabel:__set_transition_time
scope.19.kind=function
scope.19.startLine=112
scope.19.endLine=114
scope.19.semanticHash=018f9c51ceaf9c9c
scope.20.id=function:ELabel:__get_font_family
scope.20.kind=function
scope.20.startLine=116
scope.20.endLine=118
scope.20.semanticHash=c0484ae42c9068b0
scope.21.id=function:ELabel:__set_font_family
scope.21.kind=function
scope.21.startLine=120
scope.21.endLine=123
scope.21.semanticHash=d9865bc65df52544
scope.22.id=function:ELabel:__update_font_family
scope.22.kind=function
scope.22.startLine=125
scope.22.endLine=129
scope.22.semanticHash=83f74b98acb97bad
scope.23.id=function:<anonymous>#5
scope.23.kind=function
scope.23.startLine=126
scope.23.endLine=128
scope.23.semanticHash=713e373fad31bfcb
scope.24.id=function:ELabel:__get_font_size
scope.24.kind=function
scope.24.startLine=131
scope.24.endLine=133
scope.24.semanticHash=c0484ae42c9068b0
scope.25.id=function:ELabel:__set_font_size
scope.25.kind=function
scope.25.startLine=135
scope.25.endLine=138
scope.25.semanticHash=fbcaee375518918e
scope.26.id=function:ELabel:__update_font_size
scope.26.kind=function
scope.26.startLine=140
scope.26.endLine=144
scope.26.semanticHash=1769398f7a96b855
scope.27.id=function:<anonymous>#6
scope.27.kind=function
scope.27.startLine=141
scope.27.endLine=143
scope.27.semanticHash=af10c7ccfb55253d
scope.28.id=function:ELabel:__get_outline_color
scope.28.kind=function
scope.28.startLine=146
scope.28.endLine=148
scope.28.semanticHash=c0484ae42c9068b0
scope.29.id=function:ELabel:__set_outline_color
scope.29.kind=function
scope.29.startLine=150
scope.29.endLine=153
scope.29.semanticHash=d9865bc65df52544
scope.30.id=function:ELabel:__update_outline_color
scope.30.kind=function
scope.30.startLine=155
scope.30.endLine=159
scope.30.semanticHash=83f74b98acb97bad
scope.31.id=function:<anonymous>#7
scope.31.kind=function
scope.31.startLine=156
scope.31.endLine=158
scope.31.semanticHash=713e373fad31bfcb
scope.32.id=function:ELabel:__get_outline
scope.32.kind=function
scope.32.startLine=161
scope.32.endLine=163
scope.32.semanticHash=c0484ae42c9068b0
scope.33.id=function:ELabel:__set_outline
scope.33.kind=function
scope.33.startLine=165
scope.33.endLine=168
scope.33.semanticHash=d9865bc65df52544
scope.34.id=function:ELabel:__update_outline
scope.34.kind=function
scope.34.startLine=170
scope.34.endLine=174
scope.34.semanticHash=83f74b98acb97bad
scope.35.id=function:<anonymous>#8
scope.35.kind=function
scope.35.startLine=171
scope.35.endLine=173
scope.35.semanticHash=713e373fad31bfcb
scope.36.id=function:ELabel:__get_outline_opacity
scope.36.kind=function
scope.36.startLine=176
scope.36.endLine=178
scope.36.semanticHash=c0484ae42c9068b0
scope.37.id=function:ELabel:__set_outline_opacity
scope.37.kind=function
scope.37.startLine=180
scope.37.endLine=183
scope.37.semanticHash=fbcaee375518918e
scope.38.id=function:ELabel:__update_outline_opacity
scope.38.kind=function
scope.38.startLine=185
scope.38.endLine=189
scope.38.semanticHash=83f74b98acb97bad
scope.39.id=function:<anonymous>#9
scope.39.kind=function
scope.39.startLine=186
scope.39.endLine=188
scope.39.semanticHash=713e373fad31bfcb
scope.40.id=function:ELabel:__get_outline_width
scope.40.kind=function
scope.40.startLine=191
scope.40.endLine=193
scope.40.semanticHash=c0484ae42c9068b0
scope.41.id=function:ELabel:__set_outline_width
scope.41.kind=function
scope.41.startLine=195
scope.41.endLine=198
scope.41.semanticHash=fbcaee375518918e
scope.42.id=function:ELabel:__update_outline_width
scope.42.kind=function
scope.42.startLine=200
scope.42.endLine=204
scope.42.semanticHash=83f74b98acb97bad
scope.43.id=function:<anonymous>#10
scope.43.kind=function
scope.43.startLine=201
scope.43.endLine=203
scope.43.semanticHash=713e373fad31bfcb
scope.44.id=function:ELabel:__get_shadow_color
scope.44.kind=function
scope.44.startLine=206
scope.44.endLine=208
scope.44.semanticHash=c0484ae42c9068b0
scope.45.id=function:ELabel:__set_shadow_color
scope.45.kind=function
scope.45.startLine=210
scope.45.endLine=213
scope.45.semanticHash=d9865bc65df52544
scope.46.id=function:ELabel:__update_shadow_color
scope.46.kind=function
scope.46.startLine=215
scope.46.endLine=219
scope.46.semanticHash=83f74b98acb97bad
scope.47.id=function:<anonymous>#11
scope.47.kind=function
scope.47.startLine=216
scope.47.endLine=218
scope.47.semanticHash=713e373fad31bfcb
scope.48.id=function:ELabel:__get_shadow
scope.48.kind=function
scope.48.startLine=221
scope.48.endLine=223
scope.48.semanticHash=c0484ae42c9068b0
scope.49.id=function:ELabel:__set_shadow
scope.49.kind=function
scope.49.startLine=225
scope.49.endLine=228
scope.49.semanticHash=d9865bc65df52544
scope.50.id=function:ELabel:__update_shadow
scope.50.kind=function
scope.50.startLine=230
scope.50.endLine=234
scope.50.semanticHash=83f74b98acb97bad
scope.51.id=function:<anonymous>#12
scope.51.kind=function
scope.51.startLine=231
scope.51.endLine=233
scope.51.semanticHash=713e373fad31bfcb
scope.52.id=function:ELabel:__get_shadow_x_offset
scope.52.kind=function
scope.52.startLine=236
scope.52.endLine=238
scope.52.semanticHash=c0484ae42c9068b0
scope.53.id=function:ELabel:__set_shadow_x_offset
scope.53.kind=function
scope.53.startLine=240
scope.53.endLine=243
scope.53.semanticHash=fbcaee375518918e
scope.54.id=function:ELabel:__update_shadow_x_offset
scope.54.kind=function
scope.54.startLine=245
scope.54.endLine=249
scope.54.semanticHash=83f74b98acb97bad
scope.55.id=function:<anonymous>#13
scope.55.kind=function
scope.55.startLine=246
scope.55.endLine=248
scope.55.semanticHash=713e373fad31bfcb
scope.56.id=function:ELabel:__get_shadow_y_offset
scope.56.kind=function
scope.56.startLine=251
scope.56.endLine=253
scope.56.semanticHash=c0484ae42c9068b0
scope.57.id=function:ELabel:__set_shadow_y_offset
scope.57.kind=function
scope.57.startLine=255
scope.57.endLine=258
scope.57.semanticHash=fbcaee375518918e
scope.58.id=function:ELabel:__update_shadow_y_offset
scope.58.kind=function
scope.58.startLine=260
scope.58.endLine=264
scope.58.semanticHash=83f74b98acb97bad
scope.59.id=function:<anonymous>#14
scope.59.kind=function
scope.59.startLine=261
scope.59.endLine=263
scope.59.semanticHash=713e373fad31bfcb
]]
