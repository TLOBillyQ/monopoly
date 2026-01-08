-- UI系统（独立文件）
-- 提供地块卡片、对话框、按钮等UI组件

local ui = {}

ui.data = {
    buttons = {},
    dialogs = {},
    current_dialog = nil,
    property_card = nil, -- 当前显示的地块信息卡片
    font = nil,
    title_font = nil,
    small_font = nil,
    mouse_x = 0,
    mouse_y = 0,
}

function ui.init()
    ui.load_font()
    print("UI初始化完成")
end

-- 尝试加载中文字体，若不存在则使用默认字体
function ui.load_font()
    local font_path = "assets/fonts/NotoSansSC-Regular.ttf"
    local has_font = love.filesystem.getInfo(font_path) ~= nil

    if has_font then
        ui.data.font = love.graphics.newFont(font_path, 18)
        ui.data.title_font = love.graphics.newFont(font_path, 22)
        ui.data.small_font = love.graphics.newFont(font_path, 14)
        print("已加载中文字体: " .. font_path)
    else
        ui.data.font = love.graphics.newFont(16)
        ui.data.title_font = love.graphics.newFont(20)
        ui.data.small_font = love.graphics.newFont(12)
        print("未找到中文字体 assets/fonts/NotoSansSC-Regular.ttf，使用默认字体")
        print("如需中文显示，请将支持中文的字体文件放到 assets/fonts/NotoSansSC-Regular.ttf")
    end
end

function ui.update(dt, mouse_x, mouse_y)
    ui.data.mouse_x = mouse_x or love.mouse.getX()
    ui.data.mouse_y = mouse_y or love.mouse.getY()
end

function ui.draw()
    if ui.data.font then
        love.graphics.setFont(ui.data.font)
    end

    -- 绘制地块信息卡片
    if ui.data.property_card then
        ui.draw_property_card(ui.data.property_card)
    end

    -- 绘制当前对话框
    if ui.data.current_dialog then
        ui.draw_dialog(ui.data.current_dialog)
    end
end

-- 绘制地块信息卡片
function ui.draw_property_card(card)
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

    if ui.data.title_font then
        love.graphics.setFont(ui.data.title_font)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(card.name, x + 15, y + 10)

    -- 内容区域
    if ui.data.font then
        love.graphics.setFont(ui.data.font)
    end

    local content_y = y + 55
    local line_height = 25

    -- 地块类型
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("类型: " .. (card.type_name or "未知"), x + 15, content_y)
    content_y = content_y + line_height

    -- 如果是可购买地块
    if card.price and card.price > 0 then
        love.graphics.print("购买价格: $" .. card.price, x + 15, content_y)
        content_y = content_y + line_height

        if card.owner then
            love.graphics.setColor(1, 0.8, 0.2)
            love.graphics.print("拥有者: " .. card.owner, x + 15, content_y)
            content_y = content_y + line_height

            if card.level then
                love.graphics.setColor(0.2, 1, 0.2)
                love.graphics.print("等级: " .. card.level, x + 15, content_y)
                content_y = content_y + line_height
            end

            if card.rent then
                love.graphics.setColor(1, 0.6, 0.6)
                love.graphics.print("租金: $" .. card.rent, x + 15, content_y)
                content_y = content_y + line_height
            end

            if card.upgrade_cost then
                love.graphics.setColor(0.6, 0.8, 1)
                love.graphics.print("升级费用: $" .. card.upgrade_cost, x + 15, content_y)
                content_y = content_y + line_height
            end
        else
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print("无主地块", x + 15, content_y)
            content_y = content_y + line_height
        end
    end

    -- 描述
    if card.description then
        content_y = content_y + 10
        love.graphics.setColor(0.7, 0.7, 0.7)
        if ui.data.small_font then
            love.graphics.setFont(ui.data.small_font)
        end
        love.graphics.printf(card.description, x + 15, content_y, width - 30)
    end

    -- 关闭提示
    if ui.data.small_font then
        love.graphics.setFont(ui.data.small_font)
    end
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("点击其他位置关闭", x + 15, y + height - 25)
end

function ui.draw_dialog(dialog)
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

        if ui.data.title_font then
            love.graphics.setFont(ui.data.title_font)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(dialog.title, x, y + 12, width, "center")
    end

    -- 消息内容
    if dialog.message then
        if ui.data.font then
            love.graphics.setFont(ui.data.font)
        end
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.printf(dialog.message, x + 20, y + 70, width - 40, "center")
    end

    -- 按钮
    if dialog.buttons then
        local button_count = #dialog.buttons
        local button_width = 100
        local button_height = 35
        local button_spacing = 20
        local total_width = button_count * button_width + (button_count - 1) * button_spacing
        local start_x = x + (width - total_width) / 2
        local button_y = y + height - 60

        for i, btn_text in ipairs(dialog.buttons) do
            local btn_x = start_x + (i - 1) * (button_width + button_spacing)

            -- 检测鼠标悬停
            local is_hover = ui.is_mouse_over(btn_x, button_y, button_width, button_height)

            -- 按钮背景
            if is_hover then
                love.graphics.setColor(0.4, 0.7, 1)
            else
                love.graphics.setColor(0.3, 0.6, 0.9)
            end
            love.graphics.rectangle("fill", btn_x, button_y, button_width, button_height, 6, 6)

            -- 按钮边框
            love.graphics.setColor(0.2, 0.4, 0.7)
            love.graphics.rectangle("line", btn_x, button_y, button_width, button_height, 6, 6)

            -- 按钮文字
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(btn_text, btn_x, button_y + 9, button_width, "center")

            -- 保存按钮位置用于点击检测
            if not dialog.button_positions then
                dialog.button_positions = {}
            end
            dialog.button_positions[i] = { x = btn_x, y = button_y, w = button_width, h = button_height }
        end
    end
end

-- 检测鼠标是否在区域内
function ui.is_mouse_over(x, y, width, height)
    local mx, my = ui.data.mouse_x, ui.data.mouse_y
    return mx >= x and mx <= x + width and my >= y and my <= y + height
end

function ui.handle_click(x, y)
    -- 处理对话框按钮点击
    if ui.data.current_dialog and ui.data.current_dialog.button_positions then
        for i, btn_pos in ipairs(ui.data.current_dialog.button_positions) do
            if ui.is_mouse_over(btn_pos.x, btn_pos.y, btn_pos.w, btn_pos.h) then
                if ui.data.current_dialog.callback then
                    ui.data.current_dialog.callback(i)
                end
                ui.close_dialog()
                return true
            end
        end
    end

    -- 点击对话框外部关闭
    if ui.data.current_dialog then
        ui.close_dialog()
        return true
    end

    -- 点击地块卡片外部关闭
    if ui.data.property_card then
        ui.close_property_card()
        return true
    end

    return false
end

function ui.show_dialog(title, message, buttons, callback)
    ui.data.current_dialog = {
        title = title,
        message = message,
        buttons = buttons or { "确定" },
        callback = callback
    }
end

function ui.close_dialog()
    ui.data.current_dialog = nil
end

function ui.show_property_card(property_info)
    ui.data.property_card = property_info
end

function ui.close_property_card()
    ui.data.property_card = nil
end

return ui
