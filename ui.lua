-- UI系统（独立文件）
-- 如果需要，可以将UI从board.lua中分离出来

local UI = {}

UI.data = {
    buttons = {},
    dialogs = {},
    currentDialog = nil,
    font = nil,
    titleFont = nil
}

function UI.init()
    UI.loadFont()
    print("UI初始化完成")
end

-- 尝试加载中文字体，若不存在则使用默认字体
function UI.loadFont()
    local fontPath = "assets/fonts/NotoSansSC-Regular.ttf"
    local hasFont = love.filesystem.getInfo(fontPath) ~= nil

    if hasFont then
        UI.data.font = love.graphics.newFont(fontPath, 18)
        UI.data.titleFont = love.graphics.newFont(fontPath, 22)
        print("已加载中文字体: " .. fontPath)
    else
        UI.data.font = love.graphics.newFont(16)
        UI.data.titleFont = love.graphics.newFont(20)
        print("未找到中文字体 assets/fonts/NotoSansSC-Regular.ttf，使用默认字体")
        print("如需中文显示，请将支持中文的字体文件放到 assets/fonts/NotoSansSC-Regular.ttf")
    end
end

function UI.update(dt)
    -- UI更新逻辑
end

function UI.draw()
    if UI.data.font then
        love.graphics.setFont(UI.data.font)
    end

    -- 绘制按钮
    love.graphics.setColor(0.2, 0.6, 0.9)
    love.graphics.rectangle("fill", 650, 520, 120, 40)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("投骰子(空格)", 660, 530)
    
    -- 绘制当前对话框
    if UI.data.currentDialog then
        UI.drawDialog(UI.data.currentDialog)
    end
end

function UI.drawDialog(dialog)
    if UI.data.font then
        love.graphics.setFont(UI.data.font)
    end
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 200, 200, 400, 200)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 200, 200, 400, 200)
    
    if UI.data.titleFont then
        love.graphics.setFont(UI.data.titleFont)
    end
    love.graphics.print(dialog.title, 220, 220)
    if UI.data.font then
        love.graphics.setFont(UI.data.font)
    end
    love.graphics.print(dialog.message, 220, 260)
    if dialog.buttons then
        local btnText = table.concat(dialog.buttons, "    ")
        love.graphics.print(btnText, 220, 300)
    end
end

function UI.handleClick(x, y)
    if x >= 650 and x <= 770 and y >= 520 and y <= 560 then
        print("投骰子按钮被点击")
    end
end

function UI.showDialog(title, message, buttons)
    UI.data.currentDialog = {
        title = title,
        message = message,
        buttons = buttons or {"确定"}
    }
end

function UI.closeDialog()
    UI.data.currentDialog = nil
end

return UI
