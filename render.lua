-- Rendering module for Monopoly prototype

local Render = {}

local fonts = {
    base = nil,
    title = nil
}

local function ensureFont()
    if fonts.base then return end
    local fontPath = "assets/fonts/NotoSansSC-Regular.ttf"
    local hasFont = love.filesystem.getInfo(fontPath) ~= nil
    if hasFont then
        fonts.base = love.graphics.newFont(fontPath, 18)
        fonts.title = love.graphics.newFont(fontPath, 22)
        print("已加载中文字体: " .. fontPath)
    else
        fonts.base = love.graphics.newFont(16)
        fonts.title = love.graphics.newFont(20)
        print("未找到中文字体 assets/fonts/NotoSansSC-Regular.ttf，使用默认字体")
    end
end

local function drawBoard(state)
    local colors = state.cfg.colors
    local tiles = state.tiles
    local originX, originY = 20, 40
    local cellSize = 70
    local gridSize = 9  -- 9x9 grid
    
    -- 绘制棋盘背景
    love.graphics.setColor(colors.boardFill)
    love.graphics.rectangle("fill", originX, originY, cellSize * gridSize, cellSize * gridSize)
    love.graphics.setColor(colors.boardLine)
    love.graphics.rectangle("line", originX, originY, cellSize * gridSize, cellSize * gridSize)
    
    -- 绘制网格线
    love.graphics.setColor(0.7, 0.7, 0.7, 0.3)
    for i = 1, gridSize - 1 do
        -- 竖线
        love.graphics.line(originX + i * cellSize, originY, originX + i * cellSize, originY + gridSize * cellSize)
        -- 横线
        love.graphics.line(originX, originY + i * cellSize, originX + gridSize * cellSize, originY + i * cellSize)
    end
    
    -- 绘制地块信息和玩家
    love.graphics.setColor(colors.boardLine)
    for _, tile in ipairs(tiles) do
        if tile.gridPos then
            local gx, gy = tile.gridPos[1], tile.gridPos[2]
            local x = originX + (gx - 1) * cellSize
            local y = originY + (gy - 1) * cellSize
            
            -- 绘制地块边框
            love.graphics.rectangle("line", x, y, cellSize, cellSize)
            
            -- 根据类型着色
            local tileColor = colors.boardLine
            if tile.type == "property" then
                love.graphics.setColor(0.8, 0.9, 1)  -- 浅蓝色
            elseif tile.type == "start" then
                love.graphics.setColor(0.9, 1, 0.9)  -- 浅绿色
            elseif tile.type == "hospital" then
                love.graphics.setColor(1, 0.8, 0.8)  -- 浅红色
            elseif tile.type == "mountain" then
                love.graphics.setColor(0.95, 0.9, 0.7)  -- 浅黄色
            elseif tile.type == "black_market" then
                love.graphics.setColor(0.2, 0.2, 0.2)  -- 深灰色
            elseif tile.type == "tax_office" then
                love.graphics.setColor(1, 0.9, 0.7)  -- 橙色
            elseif tile.type == "chance_card" then
                love.graphics.setColor(1, 0.95, 0.7)  -- 淡黄色
            elseif tile.type == "item_card" then
                love.graphics.setColor(0.95, 0.8, 1)  -- 淡紫色
            end
            love.graphics.rectangle("fill", x + 1, y + 1, cellSize - 2, cellSize - 2)
            
            -- 绘制地块名称
            love.graphics.setColor(colors.boardLine)
            love.graphics.printf(tile.name, x + 2, y + 5, cellSize - 4, "center")
            
            -- 绘制价格（如果有）
            if tile.price > 0 then
                love.graphics.printf("¥" .. tile.price, x + 2, y + cellSize - 18, cellSize - 4, "center")
            end
        end
    end
    
    -- 绘制玩家棋子
    for idx, p in ipairs(state.players) do
        if p and p.state ~= "bankrupt" then
            local tile = tiles[p.position]
            if tile and tile.gridPos then
                local gx, gy = tile.gridPos[1], tile.gridPos[2]
                local x = originX + (gx - 1) * cellSize + cellSize / 2
                local y = originY + (gy - 1) * cellSize + cellSize / 2 + (idx - 1) * 8 - 12
                local c = colors.player[(idx - 1) % #colors.player + 1]
                love.graphics.setColor(c)
                local r = (idx == state.currentPlayerIndex) and 8 or 6
                love.graphics.circle("fill", x, y, r)
                love.graphics.setColor(colors.boardLine)
                love.graphics.circle("line", x, y, r)
            end
        end
    end
end

local function drawHud(state)
    local colors = state.cfg.colors
    local p = state.players[state.currentPlayerIndex]
    
    if not p then
        love.graphics.setColor(colors.hudText)
        love.graphics.print("未初始化玩家", 680, 40)
        return
    end
    
    local hudX, hudY = 680, 40 -- 放在右侧，避免遮挡棋盘
    local lineHeight = 22
    local currentY = hudY
    
    -- 玩家基本信息
    love.graphics.setColor(colors.hudText)
    love.graphics.print("═══ 当前玩家 ═══", hudX, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("姓名: " .. (p.name or "玩家") .. (p.isAI and " (AI)" or ""), hudX, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("金币: ¥" .. (p.money or 0), hudX, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("位置: " .. (p.position or 1) .. " 号格", hudX, currentY)
    currentY = currentY + lineHeight
    
    -- 资产信息
    love.graphics.print("═══ 资产状态 ═══", hudX, currentY)
    currentY = currentY + lineHeight
    local propertyCount = p.properties and #p.properties or 0
    love.graphics.print("地块数量: " .. propertyCount .. " 块", hudX, currentY)
    currentY = currentY + lineHeight
    
    local itemCount = p.items and #p.items or 0
    love.graphics.print("道具数量: " .. itemCount .. " / 5", hudX, currentY)
    currentY = currentY + lineHeight
    
    -- 显示持有的道具
    if itemCount > 0 and p.items then
        love.graphics.print("持有道具:", hudX, currentY)
        currentY = currentY + lineHeight
        for i, itemId in ipairs(p.items) do
            if i <= 3 then  -- 只显示前3个
                love.graphics.print("  • " .. (itemId or "未知"), hudX, currentY)
                currentY = currentY + lineHeight - 2
            end
        end
        if itemCount > 3 then
            love.graphics.print("  ...还有 " .. (itemCount - 3) .. " 个", hudX, currentY)
            currentY = currentY + lineHeight - 2
        end
    end
    
    -- 附身状态
    if p.buff and p.buff.type and p.buff.duration and p.buff.duration > 0 then
        currentY = currentY + 5
        love.graphics.print("═══ 附身状态 ═══", hudX, currentY)
        currentY = currentY + lineHeight
        local buffName = p.buff.type == "angel" and "天使保护" 
                      or p.buff.type == "wealth" and "财神附身"
                      or p.buff.type == "poor" and "穷神诅咒"
                      or "未知"
        love.graphics.print("状态: " .. buffName, hudX, currentY)
        currentY = currentY + lineHeight
        love.graphics.print("剩余: " .. p.buff.duration .. " 回合", hudX, currentY)
        currentY = currentY + lineHeight
    end
    
    -- 座驾状态
    if p.vehicle then
        currentY = currentY + 5
        love.graphics.print("座驾: " .. (p.vehicle.broken and "已损坏" or "完好"), hudX, currentY)
        currentY = currentY + lineHeight
    end
    
    -- 特殊状态
    if p.stayTurns and p.stayTurns > 0 then
        currentY = currentY + 5
        local stateText = p.state == "in_hospital" and "医院"
                       or p.state == "in_mountain" and "深山"
                       or p.state == "in_jail" and "监狱"
                       or "未知"
        love.graphics.print("停留: " .. stateText .. " (" .. p.stayTurns .. " 回合)", hudX, currentY)
        currentY = currentY + lineHeight
    end
    
    -- 游戏进度
    currentY = currentY + 10
    love.graphics.print("═══ 游戏进度 ═══", hudX, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("回合: " .. (state.currentTurn or 1), hudX, currentY)
    currentY = currentY + lineHeight
    love.graphics.print("阶段: " .. (state.currentPhase or "未知"), hudX, currentY)
    currentY = currentY + lineHeight
    if state.lastDice then
        love.graphics.print("骰子点数: " .. state.lastDice, hudX, currentY)
        currentY = currentY + lineHeight
    end
    
    -- 提示信息
    currentY = currentY + 10
    love.graphics.print("═══ 提示信息 ═══", hudX, currentY)
    currentY = currentY + lineHeight
    love.graphics.printf(state.lastLog or "", hudX, currentY, 560, "left")
end

local function drawPrompt(state)
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
local function drawPlayerRanking(state)
    local colors = state.cfg.colors
    local startX, startY = 20, 680
    local lineHeight = 20
    
    love.graphics.setColor(colors.hudText)
    love.graphics.print("═══ 玩家排行榜 ═══", startX, startY)
    
    -- 按金币排序玩家
    local sortedPlayers = {}
    for i, p in ipairs(state.players) do
        if p and p.state ~= "bankrupt" then
            table.insert(sortedPlayers, {index = i, player = p})
        end
    end
    table.sort(sortedPlayers, function(a, b) 
        return (a.player.money or 0) > (b.player.money or 0)
    end)
    
    -- 显示玩家信息
    for rank, data in ipairs(sortedPlayers) do
        local i = data.index
        local p = data.player
        local y = startY + lineHeight + (rank - 1) * lineHeight
        local c = colors.player[(i - 1) % #colors.player + 1]
        
        -- 颜色标记
        love.graphics.setColor(c)
        love.graphics.circle("fill", startX + 10, y + 8, 6)
        
        -- 玩家信息
        love.graphics.setColor(colors.hudText)
        local isCurrent = (i == state.currentPlayerIndex) and "→ " or "  "
        local propertyCount = p.properties and #p.properties or 0
        local text = string.format("%s%s: ¥%d (%d块地)", 
            isCurrent, p.name or "玩家" .. i, p.money or 0, propertyCount)
        love.graphics.print(text, startX + 25, y)
    end
end

-- 绘制控制提示
local function drawControls(state)
    local colors = state.cfg.colors
    local startX, startY = 680, 720
    local lineHeight = 18
    
    love.graphics.setColor(colors.hudText)
    
    -- 显示当前模式
    local modeText = state.autoMode and "【自动模式】" or "【手动模式】"
    love.graphics.print(modeText, startX, startY)
    
    -- 显示快捷键提示
    local y = startY + lineHeight + 5
    love.graphics.print("快捷键:", startX, y)
    y = y + lineHeight
    
    if state.autoMode then
        love.graphics.print("  A - 切换手动", startX, y)
        y = y + lineHeight - 2
        love.graphics.print("  +/- - 调速度", startX, y)
    else
        love.graphics.print("  空格 - 下一步", startX, y)
        y = y + lineHeight - 2
        love.graphics.print("  A - 切换自动", startX, y)
        y = y + lineHeight - 2
        love.graphics.print("  B - 买地块", startX, y)
        y = y + lineHeight - 2
        love.graphics.print("  U - 升级", startX, y)
        y = y + lineHeight - 2
        love.graphics.print("  S - 跳过", startX, y)
    end
    y = y + lineHeight - 2
    love.graphics.print("  H - 帮助", startX, y)
end

function Render.draw(state)
    ensureFont()
    love.graphics.setFont(fonts.base)
    local bg = state.cfg.colors.background
    love.graphics.clear(bg[1], bg[2], bg[3], 1)
    drawBoard(state)
    drawHud(state)
    drawPlayerRanking(state)
    drawControls(state)
    drawPrompt(state)
end

return Render
