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
    local originX, originY = 80, 100
    local cell = 70
    local side = math.max(3, math.floor(#tiles / 4) + 1) -- 保证环形至少3格边

    love.graphics.setColor(colors.boardFill)
    love.graphics.rectangle("fill", originX, originY, cell * side, cell * side)
    love.graphics.setColor(colors.boardLine)
    love.graphics.rectangle("line", originX, originY, cell * side, cell * side)

    local positions = {}
    local idx = 1

    -- 上边，从左到右
    for i = 0, side - 1 do
        if idx > #tiles then break end
        local x = originX + i * cell
        local y = originY
        positions[idx] = {x = x, y = y}
        idx = idx + 1
    end

    -- 右边，从上到下（去掉右上角）
    for i = 1, side - 1 do
        if idx > #tiles then break end
        local x = originX + (side - 1) * cell
        local y = originY + i * cell
        positions[idx] = {x = x, y = y}
        idx = idx + 1
    end

    -- 下边，从右到左（去掉右下角）
    for i = side - 2, 0, -1 do
        if idx > #tiles then break end
        local x = originX + i * cell
        local y = originY + (side - 1) * cell
        positions[idx] = {x = x, y = y}
        idx = idx + 1
    end

    -- 左边，从下到上（去掉左右下、左上角）
    for i = side - 2, 1, -1 do
        if idx > #tiles then break end
        local x = originX
        local y = originY + i * cell
        positions[idx] = {x = x, y = y}
        idx = idx + 1
    end

    -- 绘制格子
    for i = 1, #tiles do
        local pos = positions[i]
        if pos then
            love.graphics.rectangle("line", pos.x, pos.y, cell, cell)
            love.graphics.print(i, pos.x + 5, pos.y + 5)
            love.graphics.print(tiles[i].name, pos.x + 5, pos.y + 25)
        end
    end

    -- players
    for idx, p in ipairs(state.players) do
        if not p.eliminated then
            local pos = positions[p.position]
            if pos then
                local px = pos.x + cell / 2
                local py = pos.y + cell / 2 + (idx - 1) * 6 - 9
                local c = colors.player[(idx - 1) % #colors.player + 1]
                love.graphics.setColor(c)
                local r = (idx == state.current) and 11 or 8
                love.graphics.circle("fill", px, py, r)
                love.graphics.setColor(colors.boardLine)
                love.graphics.circle("line", px, py, r)
            end
        end
    end
end

local function drawHud(state)
    local colors = state.cfg.colors
    local p = state.players[state.current]
    local hudX, hudY = 500, 40 -- 放在右侧，避免遮挡棋盘
    love.graphics.setColor(colors.hudText)
    love.graphics.print("当前玩家: " .. p.name .. (p.isAI and " (AI)" or ""), hudX, hudY)
    love.graphics.print("金币: " .. p.money, hudX, hudY + 20)
    love.graphics.print("位置: " .. p.position, hudX, hudY + 40)
    love.graphics.print("回合: " .. state.turn, hudX, hudY + 60)
    love.graphics.print("阶段: " .. state.phase, hudX, hudY + 80)
    if p.stay and p.stay > 0 then
        love.graphics.print("停留: " .. p.stay .. " (" .. (p.stayType or "") .. ")", hudX, hudY + 100)
    end
    if state.lastRoll then
        love.graphics.print("骰子: " .. state.lastRoll, hudX, hudY + 120)
    end
    love.graphics.print("提示: " .. (state.lastLog or ""), hudX, hudY + 150)
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

function Render.draw(state)
    ensureFont()
    love.graphics.setFont(fonts.base)
    local bg = state.cfg.colors.background
    love.graphics.clear(bg[1], bg[2], bg[3], 1)
    drawBoard(state)
    drawHud(state)
    drawPrompt(state)
end

return Render
