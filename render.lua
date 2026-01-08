-- Rendering module for Monopoly prototype

local Render = {}

local fonts = {
    base = nil,
    title = nil
}

local function calculate_board_metrics(tiles)
    local origin_x, origin_y = 20, 40
    local cell_size = 70
    local grid_size = 5
    for _, t in ipairs(tiles) do
        if t.grid_pos then
            grid_size = math.max(grid_size, t.grid_pos[1], t.grid_pos[2])
        end
    end
    return {
        origin_x = origin_x,
        origin_y = origin_y,
        cell_size = cell_size,
        grid_size = grid_size,
        width = cell_size * grid_size,
        height = cell_size * grid_size
    }
end

local function ensure_font()
    if fonts.base then return end
    local font_path = "assets/fonts/NotoSansSC-Regular.ttf"
    local has_font = love.filesystem.getInfo(font_path) ~= nil
    if has_font then
        fonts.base = love.graphics.newFont(font_path, 18)
        fonts.title = love.graphics.newFont(font_path, 22)
        print("已加载中文字体: " .. font_path)
    else
        fonts.base = love.graphics.newFont(16)
        fonts.title = love.graphics.newFont(20)
        print("未找到中文字体 assets/fonts/NotoSansSC-Regular.ttf，使用默认字体")
    end
end

local function draw_board(state, board)
    local colors = state.cfg.colors
    local tiles = state.tiles
    local origin_x, origin_y = board.origin_x, board.origin_y
    local cell_size, grid_size = board.cell_size, board.grid_size

    -- 绘制棋盘背景
    love.graphics.setColor(colors.board_fill)
    love.graphics.rectangle("fill", origin_x, origin_y, cell_size * grid_size, cell_size * grid_size)
    love.graphics.setColor(colors.board_line)
    love.graphics.rectangle("line", origin_x, origin_y, cell_size * grid_size, cell_size * grid_size)

    -- 绘制网格线
    love.graphics.setColor(0.7, 0.7, 0.7, 0.3)
    for i = 1, grid_size - 1 do
        -- 竖线
        love.graphics.line(origin_x + i * cell_size, origin_y, origin_x + i * cell_size, origin_y + grid_size * cell_size)
        -- 横线
        love.graphics.line(origin_x, origin_y + i * cell_size, origin_x + grid_size * cell_size, origin_y + i * cell_size)
    end

    -- 绘制地块信息和玩家
    love.graphics.setColor(colors.board_line)
    for _, tile in ipairs(tiles) do
        if tile.grid_pos then
            local gx, gy = tile.grid_pos[1], tile.grid_pos[2]
            local x = origin_x + (gx - 1) * cell_size
            local y = origin_y + (gy - 1) * cell_size

            -- 绘制地块边框
            love.graphics.rectangle("line", x, y, cell_size, cell_size)

            -- 根据类型着色
            if tile.type == "property" then
                love.graphics.setColor(0.8, 0.9, 1)    -- 浅蓝色
            elseif tile.type == "start" then
                love.graphics.setColor(0.9, 1, 0.9)    -- 浅绿色
            elseif tile.type == "hospital" then
                love.graphics.setColor(1, 0.8, 0.8)    -- 浅红色
            elseif tile.type == "mountain" then
                love.graphics.setColor(0.95, 0.9, 0.7) -- 浅黄色
            elseif tile.type == "black_market" then
                love.graphics.setColor(0.2, 0.2, 0.2)  -- 深灰色
            elseif tile.type == "tax_office" then
                love.graphics.setColor(1, 0.9, 0.7)    -- 橙色
            elseif tile.type == "chance_card" then
                love.graphics.setColor(1, 0.95, 0.7)   -- 淡黄色
            elseif tile.type == "item_card" then
                love.graphics.setColor(0.95, 0.8, 1)   -- 淡紫色
            elseif tile.type == "rest" then
                love.graphics.setColor(0.85, 0.95, 1)
            end
            love.graphics.rectangle("fill", x + 1, y + 1, cell_size - 2, cell_size - 2)

            -- 绘制地块名称
            love.graphics.setColor(colors.board_line)
            love.graphics.printf(tile.name, x + 2, y + 5, cell_size - 4, "center")

            -- 绘制价格（如果有）
            if tile.price > 0 then
                love.graphics.printf("¥" .. tile.price, x + 2, y + cell_size - 18, cell_size - 4, "center")
            end

            -- 绘制所有权
            if tile.owner then
                local owner_color = colors.player[(tile.owner - 1) % #colors.player + 1]
                love.graphics.setColor(owner_color)
                love.graphics.rectangle("fill", x + 4, y + cell_size - 10, cell_size - 8, 6)
                love.graphics.setColor(colors.board_line)
                love.graphics.printf("P" .. tile.owner, x + 2, y + cell_size - 24, cell_size - 4, "center")
            end
        end
    end

    -- 绘制玩家棋子
    for idx, p in ipairs(state.players) do
        if p and p.state ~= "bankrupt" then
            local tile = tiles[p.position]
            if tile and tile.grid_pos then
                local gx, gy = tile.grid_pos[1], tile.grid_pos[2]
                local x = origin_x + (gx - 1) * cell_size + cell_size / 2
                local y = origin_y + (gy - 1) * cell_size + cell_size / 2 + (idx - 1) * 8 - 12
                local c = colors.player[(idx - 1) % #colors.player + 1]
                love.graphics.setColor(c)
                local r = (idx == state.current_player_index) and 8 or 6
                love.graphics.circle("fill", x, y, r)
                love.graphics.setColor(colors.board_line)
                love.graphics.circle("line", x, y, r)
            end
        end
    end
end

local function draw_hud(state, start_x, start_y, width)
    local colors = state.cfg.colors
    local p = state.players[state.current_player_index]
    local hud_x = start_x or 680
    local hud_y = start_y or 40
    local wrap_width = width or 560

    if not p then
        love.graphics.setColor(colors.hud_text)
        love.graphics.print("未初始化玩家", hud_x, hud_y)
        return hud_y
    end

    local line_height = 22
    local current_y = hud_y

    -- 玩家基本信息
    love.graphics.setColor(colors.hud_text)
    love.graphics.print("═══ 当前玩家 ═══", hud_x, current_y)
    current_y = current_y + line_height
    love.graphics.print("姓名: " .. (p.name or "玩家") .. (p.is_ai and " (AI)" or ""), hud_x, current_y)
    current_y = current_y + line_height
    love.graphics.print("金币: ¥" .. (p.money or 0), hud_x, current_y)
    current_y = current_y + line_height
    love.graphics.print("位置: " .. (p.position or 1) .. " 号格", hud_x, current_y)
    current_y = current_y + line_height

    -- 资产信息
    love.graphics.print("═══ 资产状态 ═══", hud_x, current_y)
    current_y = current_y + line_height
    local property_count = p.properties and #p.properties or 0
    love.graphics.print("地块数量: " .. property_count .. " 块", hud_x, current_y)
    current_y = current_y + line_height

    local item_count = p.items and #p.items or 0
    love.graphics.print("道具数量: " .. item_count .. " / 5", hud_x, current_y)
    current_y = current_y + line_height

    -- 显示持有的道具
    if item_count > 0 and p.items then
        love.graphics.print("持有道具:", hud_x, current_y)
        current_y = current_y + line_height
        for i, item_id in ipairs(p.items) do
            if i <= 3 then -- 只显示前3个
                love.graphics.print("  • " .. (item_id or "未知"), hud_x, current_y)
                current_y = current_y + line_height - 2
            end
        end
        if item_count > 3 then
            love.graphics.print("  ...还有 " .. (item_count - 3) .. " 个", hud_x, current_y)
            current_y = current_y + line_height - 2
        end
    end

    -- 附身状态
    if p.buff_type and p.buff_turns and p.buff_turns > 0 then
        current_y = current_y + 5
        love.graphics.print("═══ 附身状态 ═══", hud_x, current_y)
        current_y = current_y + line_height
        local buff_name = p.buff_type == "angel" and "天使保护"
            or p.buff_type == "wealth" and "财神附身"
            or p.buff_type == "poor" and "穷神诅咒"
            or "未知"
        love.graphics.print("状态: " .. buff_name, hud_x, current_y)
        current_y = current_y + line_height
        love.graphics.print("剩余: " .. p.buff_turns .. " 回合", hud_x, current_y)
        current_y = current_y + line_height
    end

    -- 特殊状态
    if p.stay_turns and p.stay_turns > 0 then
        current_y = current_y + 5
        local state_text = p.state == "in_hospital" and "医院"
            or p.state == "in_mountain" and "深山"
            or p.state == "in_jail" and "监狱"
            or "未知"
        love.graphics.print("停留: " .. state_text .. " (" .. p.stay_turns .. " 回合)", hud_x, current_y)
        current_y = current_y + line_height
    end

    -- 游戏进度
    current_y = current_y + 10
    love.graphics.print("═══ 游戏进度 ═══", hud_x, current_y)
    current_y = current_y + line_height
    love.graphics.print("回合: " .. (state.current_turn or 1), hud_x, current_y)
    current_y = current_y + line_height
    local phase_names = {
        ROLL = "掷骰",
        MOVE = "移动",
        RESOLVE = "结算",
        END = "回合结束"
    }
    love.graphics.print("阶段: " .. (phase_names[state.current_phase] or state.current_phase or "未知"), hud_x, current_y)
    current_y = current_y + line_height
    if state.last_dice then
        love.graphics.print("骰子点数: " .. state.last_dice, hud_x, current_y)
        current_y = current_y + line_height
    end

    -- 提示信息
    current_y = current_y + 10
    love.graphics.print("═══ 提示信息 ═══", hud_x, current_y)
    current_y = current_y + line_height
    local log_text = state.last_log or ""
    local _, lines = love.graphics.getFont():getWrap(log_text, wrap_width)
    local log_lines = math.max(#lines, 1)
    love.graphics.printf(log_text, hud_x, current_y, wrap_width, "left")
    current_y = current_y + line_height * log_lines

    return current_y
end

local function draw_prompt(state)
    if not state.ui then return end
    local w, h = 420, 180
    local x = (love.graphics.getWidth() - w) / 2
    local y = (love.graphics.getHeight() - h) / 2
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.print(state.ui.title or "", x + 20, y + 20)
    love.graphics.print(state.ui.message or "", x + 20, y + 60)
    if state.ui.buttons then
        love.graphics.print(table.concat(state.ui.buttons, "    "), x + 20, y + 120)
    end
end

-- 绘制所有玩家排名
local function draw_player_ranking(state, start_x, start_y)
    local colors = state.cfg.colors
    local line_height = 20
    local current_y = start_y or 680

    love.graphics.setColor(colors.hud_text)
    love.graphics.print("═══ 玩家排行榜 ═══", start_x, current_y)
    current_y = current_y + line_height

    -- 按金币排序玩家
    local sorted_players = {}
    for i, p in ipairs(state.players) do
        if p and p.state ~= "bankrupt" then
            table.insert(sorted_players, { index = i, player = p })
        end
    end
    table.sort(sorted_players, function(a, b)
        return (a.player.money or 0) > (b.player.money or 0)
    end)

    -- 显示玩家信息
    for rank, data in ipairs(sorted_players) do
        local i = data.index
        local p = data.player
        local y = current_y + (rank - 1) * line_height
        local c = colors.player[(i - 1) % #colors.player + 1]

        -- 颜色标记
        love.graphics.setColor(c)
        love.graphics.circle("fill", start_x + 10, y + 8, 6)

        -- 玩家信息
        love.graphics.setColor(colors.hud_text)
        local is_current = (i == state.current_player_index) and "→ " or "  "
        local property_count = p.properties and #p.properties or 0
        local text = string.format("%s%s: ¥%d (%d块地)",
            is_current, p.name or "玩家" .. i, p.money or 0, property_count)
        love.graphics.print(text, start_x + 25, y)
    end

    return current_y + line_height * (#sorted_players + 1)
end

-- 绘制控制提示
local function draw_controls(state, start_x, start_y)
    local colors = state.cfg.colors
    local start_x = start_x or 680
    local start_y = start_y or 720
    local line_height = 18

    love.graphics.setColor(colors.hud_text)

    -- 显示当前模式
    local mode_text = state.auto_mode and "【自动模式】" or "【手动模式】"
    love.graphics.print(mode_text, start_x, start_y)

    -- 显示快捷键提示
    local y = start_y + line_height + 5
    love.graphics.print("快捷键:", start_x, y)
    y = y + line_height

    if state.auto_mode then
        love.graphics.print("  A - 切换手动", start_x, y)
        y = y + line_height - 2
        love.graphics.print("  +/- - 调速度", start_x, y)
    else
        love.graphics.print("  空格 - 下一步", start_x, y)
        y = y + line_height - 2
        love.graphics.print("  A - 切换自动", start_x, y)
        y = y + line_height - 2
        love.graphics.print("  B - 买地块", start_x, y)
        y = y + line_height - 2
        love.graphics.print("  U - 升级", start_x, y)
        y = y + line_height - 2
        love.graphics.print("  S - 跳过", start_x, y)
    end
    y = y + line_height - 2
    love.graphics.print("  H - 帮助", start_x, y)

    return y + line_height
end

function Render.draw(state)
    ensure_font()
    love.graphics.setFont(fonts.base)
    local bg = state.cfg.colors.background
    love.graphics.clear(bg[1], bg[2], bg[3], 1)

    local board = calculate_board_metrics(state.tiles)
    local padding = 16
    local panel_x = board.origin_x + board.width + padding
    local panel_y = board.origin_y
    local panel_width = math.max(love.graphics.getWidth() - panel_x - padding, 240)
    local panel_height = love.graphics.getHeight() - panel_y - padding

    draw_board(state, board)

    -- 侧边信息面板背景，防止文字贴边或被遮挡
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.rectangle("fill", panel_x - 12, panel_y - 12, panel_width + 24, panel_height + 24, 10, 10)
    love.graphics.setColor(state.cfg.colors.board_line)
    love.graphics.rectangle("line", panel_x - 12, panel_y - 12, panel_width + 24, panel_height + 24, 10, 10)

    local current_y = panel_y
    current_y = draw_hud(state, panel_x, current_y, panel_width) + 12
    current_y = draw_player_ranking(state, panel_x, current_y) + 12
    draw_controls(state, panel_x, current_y)
    draw_prompt(state)
end

return Render
