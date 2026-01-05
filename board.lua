-- 地图系统
-- Board System

local Board = {}

local playerColors = {
    {1, 0.3, 0.3},
    {0.3, 0.3, 1},
    {0.3, 0.9, 0.3},
    {1, 0.85, 0.3}
}

Board.data = {
    properties = {},
    gridSize = 60,
    boardWidth = 800,
    boardHeight = 600
}

-- 初始化地图
function Board.init()
    print("地图初始化完成")
end

-- 绘制地图
function Board.draw(players, currentPlayerIndex)
    -- 简单的地图绘制
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.rectangle("fill", 50, 100, 700, 400)
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", 50, 100, 700, 400)
    
    -- 绘制地块
    local tiles = {}
    local x, y = 50, 100
    for i = 1, 16 do
        tiles[i] = {x = x, y = y}
        love.graphics.rectangle("line", x, y, 60, 60)
        love.graphics.print(i, x + 25, y + 25)
        
        if i <= 4 then
            x = x + 60
        elseif i <= 8 then
            y = y + 60
        elseif i <= 12 then
            x = x - 60
        else
            y = y - 60
        end
    end

    -- 绘制玩家位置
    if players then
        for idx, player in ipairs(players) do
            local pos = player.position
            if pos == 0 then pos = 1 end
            local tile = tiles[pos]
            if tile then
                local px = tile.x + 30
                local py = tile.y + 30
                local color = playerColors[(idx - 1) % #playerColors + 1]
                love.graphics.setColor(color)
                local radius = (idx == currentPlayerIndex) and 12 or 9
                love.graphics.circle("fill", px, py, radius)
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle("line", px, py, radius)
            end
        end
    end
end

return Board
