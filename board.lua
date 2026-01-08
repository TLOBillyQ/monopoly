-- 地图系统（基于 9x9 网格的数据渲染）

local Config = require("config")

local Board = {}

local playerColors = {
    {1, 0.3, 0.3},
    {0.3, 0.3, 1},
    {0.3, 0.9, 0.3},
    {1, 0.85, 0.3}
}

Board.data = {
    tiles = Config.tiles,
    gridSize = (Config.constants and Config.constants.GRID_SIZE) or 9,
    boardWidth = 800,
    boardHeight = 600
}

-- 初始化地图
function Board.init()
    Board.data.tiles = Config.tiles
    print("地图初始化完成，共 " .. tostring(#(Board.data.tiles or {})) .. " 个格子")
end

-- 绘制地图（简单调试用，实际绘制交由 render.lua）
function Board.draw(players, currentPlayerIndex)
    local tiles = Board.data.tiles or {}
    local colors = Config.colors or {}
    local gridSize = Board.data.gridSize or 9
    local cellSize = 60
    local originX, originY = 50, 80

    -- 计算实际网格尺寸
    for _, t in ipairs(tiles) do
        if t.gridPos then
            gridSize = math.max(gridSize, t.gridPos[1], t.gridPos[2])
        end
    end

    love.graphics.setColor(colors.boardFill or {0.8, 0.8, 0.8})
    love.graphics.rectangle("fill", originX, originY, cellSize * gridSize, cellSize * gridSize)
    love.graphics.setColor(colors.boardLine or {0, 0, 0})
    love.graphics.rectangle("line", originX, originY, cellSize * gridSize, cellSize * gridSize)

    -- 网格线
    love.graphics.setColor(0.7, 0.7, 0.7, 0.3)
    for i = 1, gridSize - 1 do
        love.graphics.line(originX + i * cellSize, originY, originX + i * cellSize, originY + gridSize * cellSize)
        love.graphics.line(originX, originY + i * cellSize, originX + gridSize * cellSize, originY + i * cellSize)
    end

    -- 绘制地块
    for _, tile in ipairs(tiles) do
        if tile.gridPos then
            local gx, gy = tile.gridPos[1], tile.gridPos[2]
            local x = originX + (gx - 1) * cellSize
            local y = originY + (gy - 1) * cellSize

            if tile.type == "property" then
                love.graphics.setColor(0.8, 0.9, 1)
            elseif tile.type == "start" then
                love.graphics.setColor(0.9, 1, 0.9)
            elseif tile.type == "hospital" then
                love.graphics.setColor(1, 0.8, 0.8)
            elseif tile.type == "mountain" then
                love.graphics.setColor(0.95, 0.9, 0.7)
            elseif tile.type == "black_market" then
                love.graphics.setColor(0.2, 0.2, 0.2)
            elseif tile.type == "tax_office" then
                love.graphics.setColor(1, 0.9, 0.7)
            elseif tile.type == "chance_card" then
                love.graphics.setColor(1, 0.95, 0.7)
            elseif tile.type == "item_card" then
                love.graphics.setColor(0.95, 0.8, 1)
            else
                love.graphics.setColor(0.85, 0.85, 0.85)
            end
            love.graphics.rectangle("fill", x + 1, y + 1, cellSize - 2, cellSize - 2)
            love.graphics.setColor(colors.boardLine or {0, 0, 0})
            love.graphics.rectangle("line", x, y, cellSize, cellSize)
            love.graphics.printf(tile.name or "", x + 2, y + 5, cellSize - 4, "center")
            if tile.price and tile.price > 0 then
                love.graphics.printf("¥" .. tile.price, x + 2, y + cellSize - 18, cellSize - 4, "center")
            end
        end
    end

    -- 绘制玩家位置
    for idx, player in ipairs(players or {}) do
        if player and player.position then
            local tile = tiles[player.position]
            if tile and tile.gridPos then
                local gx, gy = tile.gridPos[1], tile.gridPos[2]
                local px = originX + (gx - 1) * cellSize + cellSize / 2
                local py = originY + (gy - 1) * cellSize + cellSize / 2 + (idx - 1) * 8 - 12
                local color = playerColors[(idx - 1) % #playerColors + 1]
                love.graphics.setColor(color)
                local radius = (idx == currentPlayerIndex) and 10 or 7
                love.graphics.circle("fill", px, py, radius)
                love.graphics.setColor(colors.boardLine or {0, 0, 0})
                love.graphics.circle("line", px, py, radius)
            end
        end
    end
end

return Board
