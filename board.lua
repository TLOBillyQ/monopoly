-- 地图系统（基于 9x9 网格的数据渲染）

local Config = require("config")

local Board = {}

local player_colors = {
    { 1,   0.3,  0.3 },
    { 0.3, 0.3,  1 },
    { 0.3, 0.9,  0.3 },
    { 1,   0.85, 0.3 }
}

Board.data = {
    tiles = Config.tiles,
    grid_size = (Config.constants and Config.constants.GRID_SIZE) or 9,
    board_width = 800,
    board_height = 600
}

-- 初始化地图
function Board.init()
    Board.data.tiles = Config.tiles
    print("地图初始化完成，共 " .. tostring(#(Board.data.tiles or {})) .. " 个格子")
end

-- 绘制地图（简单调试用，实际绘制交由 render.lua）
function Board.draw(players, current_player_index)
    local tiles = Board.data.tiles or {}
    local colors = Config.colors or {}
    local grid_size = Board.data.grid_size or 9
    local cell_size = 60
    local origin_x, origin_y = 50, 80

    -- 计算实际网格尺寸
    for _, t in ipairs(tiles) do
        if t.grid_pos then
            grid_size = math.max(grid_size, t.grid_pos[1], t.grid_pos[2])
        end
    end

    love.graphics.setColor(colors.board_fill or { 0.8, 0.8, 0.8 })
    love.graphics.rectangle("fill", origin_x, origin_y, cell_size * grid_size, cell_size * grid_size)
    love.graphics.setColor(colors.board_line or { 0, 0, 0 })
    love.graphics.rectangle("line", origin_x, origin_y, cell_size * grid_size, cell_size * grid_size)

    -- 网格线
    love.graphics.setColor(0.7, 0.7, 0.7, 0.3)
    for i = 1, grid_size - 1 do
        love.graphics.line(origin_x + i * cell_size, origin_y, origin_x + i * cell_size, origin_y + grid_size * cell_size)
        love.graphics.line(origin_x, origin_y + i * cell_size, origin_x + grid_size * cell_size, origin_y + i * cell_size)
    end

    -- 绘制地块
    for _, tile in ipairs(tiles) do
        if tile.grid_pos then
            local gx, gy = tile.grid_pos[1], tile.grid_pos[2]
            local x = origin_x + (gx - 1) * cell_size
            local y = origin_y + (gy - 1) * cell_size

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
            love.graphics.rectangle("fill", x + 1, y + 1, cell_size - 2, cell_size - 2)
            love.graphics.setColor(colors.board_line or { 0, 0, 0 })
            love.graphics.rectangle("line", x, y, cell_size, cell_size)
            love.graphics.printf(tile.name or "", x + 2, y + 5, cell_size - 4, "center")
            if tile.price and tile.price > 0 then
                love.graphics.printf("¥" .. tile.price, x + 2, y + cell_size - 18, cell_size - 4, "center")
            end
        end
    end

    -- 绘制玩家位置
    for idx, player in ipairs(players or {}) do
        if player and player.position then
            local tile = tiles[player.position]
            if tile and tile.grid_pos then
                local gx, gy = tile.grid_pos[1], tile.grid_pos[2]
                local px = origin_x + (gx - 1) * cell_size + cell_size / 2
                local py = origin_y + (gy - 1) * cell_size + cell_size / 2 + (idx - 1) * 8 - 12
        local color = player_colors[(idx - 1) % #player_colors + 1]
        love.graphics.setColor(color)
        local radius = (idx == current_player_index) and 10 or 7
        love.graphics.circle("fill", px, py, radius)
                love.graphics.setColor(colors.board_line or { 0, 0, 0 })
                love.graphics.circle("line", px, py, radius)
            end
        end
    end
end

return Board
