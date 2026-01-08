-- UI系统（独立文件）
-- 提供地块卡片、对话框、按钮等UI组件

local UI = {}

UI.data = {
    buttons = {},
    dialogs = {},
    currentDialog = nil,
    propertyCard = nil, -- 当前显示的地块信息卡片
    font = nil,
    titleFont = nil,
    smallFont = nil,
    mouseX = 0,
    mouseY = 0,
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
        UI.data.smallFont = love.graphics.newFont(fontPath, 14)
        print("已加载中文字体: " .. fontPath)
    else
        UI.data.font = love.graphics.newFont(16)
        UI.data.titleFont = love.graphics.newFont(20)
        UI.data.smallFont = love.graphics.newFont(12)
        print("未找到中文字体 assets/fonts/NotoSansSC-Regular.ttf，使用默认字体")
        print("如需中文显示，请将支持中文的字体文件放到 assets/fonts/NotoSansSC-Regular.ttf")
    end
end

function UI.update(dt, mouseX, mouseY)
    UI.data.mouseX = mouseX or love.mouse.getX()
    UI.data.mouseY = mouseY or love.mouse.getY()
end

function UI.draw()
    if UI.data.font then
        love.graphics.setFont(UI.data.font)
    end

    -- 绘制地块信息卡片
    if UI.data.propertyCard then
        UI.drawPropertyCard(UI.data.propertyCard)
    end

    -- 绘制当前对话框
    if UI.data.currentDialog then
        UI.drawDialog(UI.data.currentDialog)
    end
end

-- 绘制地块信息卡片
function UI.drawPropertyCard(card)
    local x, y = 900, 200
    local width, height = 300, 400

    -- 半透明背景
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, width, height, 10, 10)

    -- 边框
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, 10, 10)
    love.graphics.setLineWidth(1)

    -- 标题栏
    love.graphics.setColor(0.2, 0.6, 0.9)
    love.graphics.rectangle("fill", x, y, width, 40, 10, 10)

    if UI.data.titleFont then
        love.graphics.setFont(UI.data.titleFont)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(card.name, x + 15, y + 10)

    -- 内容区域
    if UI.data.font then
        love.graphics.setFont(UI.data.font)
    end

    local contentY = y + 55
    local lineHeight = 25

    -- 地块类型
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("类型: " .. (card.typeName or "未知"), x + 15, contentY)
    contentY = contentY + lineHeight

    -- 如果是可购买地块
    if card.price and card.price > 0 then
        love.graphics.print("购买价格: $" .. card.price, x + 15, contentY)
        contentY = contentY + lineHeight

        if card.owner then
            love.graphics.setColor(1, 0.8, 0.2)
            love.graphics.print("拥有者: " .. card.owner, x + 15, contentY)
            contentY = contentY + lineHeight

            if card.level then
                love.graphics.setColor(0.2, 1, 0.2)
                love.graphics.print("等级: " .. card.level, x + 15, contentY)
                contentY = contentY + lineHeight
            end

            if card.rent then
                love.graphics.setColor(1, 0.6, 0.6)
                love.graphics.print("租金: $" .. card.rent, x + 15, contentY)
                contentY = contentY + lineHeight
            end

            if card.upgradeCost then
                love.graphics.setColor(0.6, 0.8, 1)
                love.graphics.print("升级费用: $" .. card.upgradeCost, x + 15, contentY)
                contentY = contentY + lineHeight
            end
        else
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print("无主地块", x + 15, contentY)
            contentY = contentY + lineHeight
        end
    end

    -- 描述
    if card.description then
        contentY = contentY + 10
        love.graphics.setColor(0.7, 0.7, 0.7)
        if UI.data.smallFont then
            love.graphics.setFont(UI.data.smallFont)
        end
        love.graphics.printf(card.description, x + 15, contentY, width - 30)
    end

    -- 关闭提示
    if UI.data.smallFont then
        love.graphics.setFont(UI.data.smallFont)
    end
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("点击其他位置关闭", x + 15, y + height - 25)
end

function UI.drawDialog(dialog)
    local x, y = 400, 250
    local width, height = 480, 220

    -- 背景遮罩
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- 对话框背景
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.rectangle("fill", x, y, width, height, 12, 12)

    -- 对话框边框
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, 12, 12)
    love.graphics.setLineWidth(1)

    -- 标题栏
    if dialog.title then
        love.graphics.setColor(0.3, 0.7, 1)
        love.graphics.rectangle("fill", x, y, width, 45, 12, 12)

        if UI.data.titleFont then
            love.graphics.setFont(UI.data.titleFont)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(dialog.title, x, y + 12, width, "center")
    end

    -- 消息内容
    if dialog.message then
        if UI.data.font then
            love.graphics.setFont(UI.data.font)
        end
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.printf(dialog.message, x + 20, y + 70, width - 40, "center")
    end

    -- 按钮
    if dialog.buttons then
        local buttonCount = #dialog.buttons
        local buttonWidth = 100
        local buttonHeight = 35
        local buttonSpacing = 20
        local totalWidth = buttonCount * buttonWidth + (buttonCount - 1) * buttonSpacing
        local startX = x + (width - totalWidth) / 2
        local buttonY = y + height - 60

        for i, btnText in ipairs(dialog.buttons) do
            local btnX = startX + (i - 1) * (buttonWidth + buttonSpacing)

            -- 检测鼠标悬停
            local isHover = UI.isMouseOver(btnX, buttonY, buttonWidth, buttonHeight)

            -- 按钮背景
            if isHover then
                love.graphics.setColor(0.4, 0.7, 1)
            else
                love.graphics.setColor(0.3, 0.6, 0.9)
            end
            love.graphics.rectangle("fill", btnX, buttonY, buttonWidth, buttonHeight, 6, 6)

            -- 按钮边框
            love.graphics.setColor(0.2, 0.4, 0.7)
            love.graphics.rectangle("line", btnX, buttonY, buttonWidth, buttonHeight, 6, 6)

            -- 按钮文字
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(btnText, btnX, buttonY + 9, buttonWidth, "center")

            -- 保存按钮位置用于点击检测
            if not dialog.buttonPositions then
                dialog.buttonPositions = {}
            end
            dialog.buttonPositions[i] = { x = btnX, y = buttonY, w = buttonWidth, h = buttonHeight }
        end
    end
end

-- 检测鼠标是否在区域内
function UI.isMouseOver(x, y, width, height)
    local mx, my = UI.data.mouseX, UI.data.mouseY
    return mx >= x and mx <= x + width and my >= y and my <= y + height
end

function UI.handleClick(x, y)
    -- 处理对话框按钮点击
    if UI.data.currentDialog and UI.data.currentDialog.buttonPositions then
        for i, btnPos in ipairs(UI.data.currentDialog.buttonPositions) do
            if UI.isMouseOver(btnPos.x, btnPos.y, btnPos.w, btnPos.h) then
                if UI.data.currentDialog.callback then
                    UI.data.currentDialog.callback(i)
                end
                UI.closeDialog()
                return true
            end
        end
    end

    -- 点击对话框外部关闭
    if UI.data.currentDialog then
        UI.closeDialog()
        return true
    end

    -- 点击地块卡片外部关闭
    if UI.data.propertyCard then
        UI.closePropertyCard()
        return true
    end

    return false
end

function UI.showDialog(title, message, buttons, callback)
    UI.data.currentDialog = {
        title = title,
        message = message,
        buttons = buttons or { "确定" },
        callback = callback
    }
end

function UI.closeDialog()
    UI.data.currentDialog = nil
end

function UI.showPropertyCard(propertyInfo)
    UI.data.propertyCard = propertyInfo
end

function UI.closePropertyCard()
    UI.data.propertyCard = nil
end

return UI
