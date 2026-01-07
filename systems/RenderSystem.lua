-- 渲染系统 - Spoke框架实现
-- 处理游戏画面的绘制

local State = require("spoke.state")
local Effect = require("spoke.effect").Effect

local RenderSystem = {}

-- 创建渲染状态
function RenderSystem.createRenderState()
    return {
        cameraX = State.Create(0),
        cameraY = State.Create(0),
        scale = State.Create(1.0),
        showDebug = State.Create(false),
        selectedTile = State.Create(nil),
        hoverTile = State.Create(nil),
    }
end

-- 创建渲染Epoch
function RenderSystem.createRenderEpoch(gameFlow, players, properties, renderState, config)
    return Effect.new("RenderEpoch", function(s)
        -- 监听游戏状态变化
        local phase = s:D(gameFlow.currentPhase)
        local playerIndex = s:D(gameFlow.currentPlayerIndex)
        
        -- 根据阶段和玩家索引更新渲染
        
    end, {gameFlow.currentPhase, gameFlow.currentPlayerIndex})
end

-- 辅助函数：获取地块的屏幕坐标
function RenderSystem.getTileScreenPos(tileId, config)
    local tile = config.tiles[tileId]
    if not tile then return 50, 50 end
    
    local gridX, gridY = tile.gridPos[1], tile.gridPos[2]
    local cellSize = 65
    local boardX = 50
    local boardY = 50
    
    local x = boardX + (gridX - 1) * cellSize
    local y = boardY + (gridY - 1) * cellSize
    
    return x, y
end

-- 获取地块颜色
function RenderSystem.getTileColor(tile, property)
    if tile.type == "start" then
        return {0.3, 0.8, 0.3}  -- 绿色
    elseif tile.type == "hospital" then
        return {1, 0.4, 0.4}  -- 红色
    elseif tile.type == "mountain" then
        return {0.6, 0.4, 0.2}  -- 棕色
    elseif tile.type == "tax_office" then
        return {0.8, 0.8, 0.2}  -- 黄色
    elseif tile.type == "black_market" then
        return {0.3, 0.3, 0.3}  -- 灰色
    elseif tile.type == "item_card" or tile.type == "chance_card" then
        return {0.5, 0.5, 1}  -- 蓝色
    elseif tile.type == "property" then
        if property and property.ownerId and property.ownerId:Now() > 0 then
            local level = property.level and property.level:Now() or 0
            local intensity = 0.5 + level * 0.1
            return {intensity, 0.7, intensity}  -- 根据等级变化
        else
            return {0.9, 0.9, 0.9}  -- 白色（无主）
        end
    end
    return {0.85, 0.85, 0.8}
end

-- 绘制游戏板
function RenderSystem.drawBoard(properties, config, renderState)
    -- 绘制背景网格
    local cellSize = 65
    local boardX = 50
    local boardY = 50
    local gridSize = 9
    
    -- 绘制所有地块
    for i, tile in ipairs(config.tiles) do
        local x, y = RenderSystem.getTileScreenPos(i, config)
        local property = properties[i]
        
        -- 地块背景
        local color = RenderSystem.getTileColor(tile, property)
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.rectangle("fill", x, y, cellSize - 2, cellSize - 2)
        
        -- 地块边框
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("line", x, y, cellSize - 2, cellSize - 2)
        
        -- 如果是地产，显示等级
        if tile.type == "property" and property and property.ownerId then
            local ownerId = property.ownerId:Now()
            if ownerId and ownerId > 0 then
                local level = (property.level and property.level:Now()) or 0
                love.graphics.setColor(0.1, 0.1, 0.1)
                love.graphics.print("Lv" .. level, x + 5, y + 5)
                
                -- 显示拥有者颜色标记
                local ownerColor = config.colors.player[ownerId] or {0.5, 0.5, 0.5}
                love.graphics.setColor(ownerColor[1], ownerColor[2], ownerColor[3])
                love.graphics.rectangle("fill", x + cellSize - 15, y + 5, 10, 10)
            end
        end
        
        -- 地块名称（缩略）
        love.graphics.setColor(0.1, 0.1, 0.1)
        local shortName = tile.name:sub(1, 6)
        love.graphics.print(shortName, x + 5, y + cellSize - 20, 0, 0.7, 0.7)
    end
end


-- 绘制玩家棋子（基础版本）
function RenderSystem.drawPlayers(players, config)
    local cellSize = 65
    local playersOnTile = {}  -- 按地块分组玩家
    
    -- 先收集所有玩家的位置信息
    for i, player in ipairs(players) do
        if not player then goto next_player end
        if not player.position or not player.money then goto next_player end
        
        -- 检查是否破产或淘汰
        local playerState = player.state:Now()
        local money = player.money:Now()
        local isBankrupt = playerState == "bankrupt" or money < 0
        
        if not isBankrupt then
            local position = player.position:Now()
            if not playersOnTile[position] then
                playersOnTile[position] = {}
            end
            table.insert(playersOnTile[position], i)
        end
        
        ::next_player::
    end
    
    -- 在每个地块绘制该地块上的玩家
    for position, playerIndices in pairs(playersOnTile) do
        local x, y = RenderSystem.getTileScreenPos(position, config)
        local count = #playerIndices
        
        -- 计算布局：最多4个玩家，分别放在地块的四个角
        local layout = {
            {offsetX = 15, offsetY = 15},   -- 左上
            {offsetX = cellSize - 25, offsetY = 15},   -- 右上
            {offsetX = 15, offsetY = cellSize - 25},   -- 左下
            {offsetX = cellSize - 25, offsetY = cellSize - 25}   -- 右下
        }
        
        for idx, playerIdx in ipairs(playerIndices) do
            local player = players[playerIdx]
            if player then
                local offset = layout[idx] or {offsetX = 30, offsetY = 30}
                local px = x + offset.offsetX
                local py = y + offset.offsetY
                
                -- 绘制玩家圆形棋子
                local playerColor = config.colors.player[playerIdx] or {0.5, 0.5, 0.5}
                love.graphics.setColor(playerColor[1], playerColor[2], playerColor[3])
                love.graphics.circle("fill", px, py, 12)
                
                -- 绘制玩家编号
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(playerIdx, px - 4, py - 6, 0, 1, 1)
                
                -- 绘制边框
                love.graphics.setColor(0.1, 0.1, 0.1)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", px, py, 12)
                love.graphics.setLineWidth(1)
                
                -- 绘制金币显示（简化版，显示金币数量等级）
                local money = player.money:Now()
                local moneyLevel = 0
                if money > 200000 then moneyLevel = 3
                elseif money > 100000 then moneyLevel = 2
                elseif money > 50000 then moneyLevel = 1
                end
                
                if moneyLevel > 0 then
                    love.graphics.setColor(1, 0.84, 0, 0.8)  -- 金色
                    local barWidth = moneyLevel * 3
                    love.graphics.rectangle("fill", px - barWidth/2, py - 20, barWidth, 3)
                end
            end
        end
    end
end

-- 绘制玩家信息
function RenderSystem.drawPlayerInfo(players, gameFlow, config)
    if not gameFlow then return end
    if not gameFlow.currentPlayerIndex then return end
    
    local panelX = 650
    local panelY = 50
    local panelWidth = 560
    local panelHeight = 650
    
    -- 背景面板
    love.graphics.setColor(0.95, 0.95, 0.95, 0.9)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 10, 10)
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 10, 10)
    
    -- 标题
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.print("玩家信息", panelX + 20, panelY + 15, 0, 1.3, 1.3)
    
    if not gameFlow.currentPlayerIndex or not gameFlow.currentPlayerIndex.Get then
        return
    end
    
    local currentPlayer = gameFlow.currentPlayerIndex:Now()
    local playerCount = 0
    local displayIndex = 0
    
    -- 先数一遍有多少个活跃玩家
    for i, player in ipairs(players) do
        if player and player.position and player.money then
            local playerState = player.state:Now()
            local money = player.money:Now()
            local isBankrupt = playerState == "bankrupt" or money < 0
            if not isBankrupt then
                playerCount = playerCount + 1
            end
        end
    end
    
    -- 动态调整卡片高度
    local cardHeight = math.floor((panelHeight - 80) / 4)  -- 4个玩家 + 标题空间
    
    for i, player in ipairs(players) do
        if not player then goto next_player end
        if not player.position or not player.money then goto next_player end
        
        -- 检查是否破产或淘汰
        local playerState = player.state:Now()
        local money = player.money:Now()
        local isBankrupt = playerState == "bankrupt" or money < 0
        if isBankrupt then goto next_player end
        
        displayIndex = displayIndex + 1
        local yPos = panelY + 60 + (displayIndex - 1) * cardHeight
        local position = player.position:Now()
        
        -- 计算总资产（金币 + 地块价值）
        local propertyCount = (player.properties and #player.properties:Now()) or 0
        local propertyValue = propertyCount * 1000  -- 简化：每块地 1000 金币
        local totalAsset = money + propertyValue
        
        local itemCount = (player.items and #player.items:Now()) or 0
        
        -- 玩家卡片背景
        local cardColor = config.colors.player[i] or {0.5, 0.5, 0.5}
        love.graphics.setColor(cardColor[1], cardColor[2], cardColor[3], 0.25)
        love.graphics.rectangle("fill", panelX + 15, yPos, panelWidth - 30, cardHeight - 8, 6, 6)
        
        -- 当前玩家高亮
        if i == currentPlayer then
            love.graphics.setColor(cardColor[1], cardColor[2], cardColor[3], 0.7)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", panelX + 15, yPos, panelWidth - 30, cardHeight - 8, 6, 6)
            love.graphics.setLineWidth(1)
            
            -- 添加"当前玩家"标签
            love.graphics.setColor(cardColor[1], cardColor[2], cardColor[3])
            love.graphics.rectangle("fill", panelX + 15, yPos - 18, 60, 18)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("当前回合", panelX + 20, yPos - 16, 0, 0.85, 0.85)
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.rectangle("line", panelX + 15, yPos, panelWidth - 30, cardHeight - 8, 6, 6)
        end
        
        -- 玩家编号圆圈
        love.graphics.setColor(cardColor[1], cardColor[2], cardColor[3])
        love.graphics.circle("fill", panelX + 35, yPos + 15, 12)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(i, panelX + 31, yPos + 9, 0, 1.0, 1.0)
        
        -- 玩家基本信息
        love.graphics.setColor(0.15, 0.15, 0.15)
        local character = config.characters[i] or {name = "玩家"}
        love.graphics.print(character.name, panelX + 60, yPos + 6, 0, 0.9, 0.9)
        
        -- 游戏币显示（带颜色）
        love.graphics.setColor(1, 0.84, 0)  -- 金色
        love.graphics.print("💰", panelX + 60, yPos + 22)
        love.graphics.setColor(0.15, 0.15, 0.15)
        love.graphics.print(string.format("%d", money), panelX + 80, yPos + 24, 0, 0.85, 0.85)
        
        -- 总资产
        love.graphics.setColor(0.4, 0.7, 0.4)  -- 绿色
        love.graphics.print("资产:", panelX + 280, yPos + 22)
        love.graphics.setColor(0.15, 0.15, 0.15)
        love.graphics.print(string.format("%d", totalAsset), panelX + 330, yPos + 22, 0, 0.85, 0.85)
        
        -- 位置信息
        love.graphics.setColor(0.15, 0.15, 0.15)
        love.graphics.print(string.format("位置: %d", position), panelX + 60, yPos + 40, 0, 0.85, 0.85)
        
        -- 地块和道具数量
        love.graphics.setColor(0.4, 0.5, 0.8)  -- 蓝色
        love.graphics.print(string.format("🏠 %d  🎁 %d", propertyCount, itemCount), panelX + 280, yPos + 40, 0, 0.85, 0.85)
        
        -- 状态栏（如果有特殊状态）
        if playerState ~= "normal" then
            local stateText = ""
            if playerState == "hospital" then
                stateText = "🏥 在医院"
                love.graphics.setColor(1, 0.5, 0.5)
            elseif playerState == "mountain" then
                stateText = "⛰️ 在深山"
                love.graphics.setColor(0.6, 0.4, 0.2)
            elseif playerState == "jail" then
                stateText = "🚔 在监狱"
                love.graphics.setColor(0.5, 0.5, 0.5)
            end
            
            love.graphics.print(stateText, panelX + 60, yPos + 55, 0, 0.85, 0.85)
        end
        
        ::next_player::
    end
end


-- 绘制游戏状态
function RenderSystem.drawGameStatus(gameFlow, config)
    local statusX = 50
    local statusY = 650
    local statusWidth = 550
    
    -- 状态背景
    love.graphics.setColor(0.95, 0.95, 0.95, 0.9)
    love.graphics.rectangle("fill", statusX, statusY, statusWidth, 60, 8, 8)
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", statusX, statusY, statusWidth, 60, 8, 8)
    
    love.graphics.setColor(0.2, 0.2, 0.2)
    
    local turn = gameFlow.currentTurn:Now()
    local phase = gameFlow.currentPhase:Now()
    local playerIndex = gameFlow.currentPlayerIndex:Now()
    
    -- 使用更友好的阶段名称
    local phaseNames = {
        waitForRoll = "等待投骰子",
        rolling = "投骰子中",
        moving = "移动中",
        landed = "着陆处理",
        turnEnd = "回合结束"
    }
    local phaseName = phaseNames[phase] or phase
    
    love.graphics.print(string.format("回合: %d  |  阶段: %s  |  当前玩家: %d", turn, phaseName, playerIndex), statusX + 20, statusY + 15, 0, 1.1, 1.1)
    love.graphics.print("按 SPACE 推进游戏  |  A 自动模式  |  ESC 退出", statusX + 20, statusY + 35, 0, 0.9, 0.9)
end

-- 绘制日志
function RenderSystem.drawLogs(gameFlow)
    -- 日志已集成到游戏状态面板中，这里可以选择性显示最新日志
    local logs = gameFlow.logs:Now()
    if #logs == 0 then return end
    
    local recentLog = logs[#logs]
    if recentLog then
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.print("最新: " .. recentLog.message, 50, 615, 0, 0.85, 0.85)
    end
end

-- 绘制骰子动画
function RenderSystem.drawDice(animationState)
    if not animationState or not animationState.diceRolling:Now() then 
        return 
    end
    
    local diceX = 640 - 40
    local diceY = 360 - 40
    local diceSize = 80
    
    -- 骰子阴影
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", diceX + 5, diceY + 5, diceSize, diceSize, 10, 10)
    
    -- 骰子背景
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", diceX, diceY, diceSize, diceSize, 10, 10)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", diceX, diceY, diceSize, diceSize, 10, 10)
    love.graphics.setLineWidth(1)
    
    -- 骰子点数
    local value = animationState.diceValue:Now()
    love.graphics.setColor(0.9, 0.2, 0.2)
    love.graphics.print(tostring(value), diceX + 28, diceY + 18, 0, 3, 3)
    
    -- 滚动提示
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.print("投骰中...", diceX - 10, diceY + diceSize + 15, 0, 1.2, 1.2)
end

-- 创建完整的渲染管道
function RenderSystem.createRenderPipeline(gameFlow, players, properties, config, renderState, animationState)
    return function()
        -- 背景
        love.graphics.clear(0.92, 0.92, 0.9)
        
        -- 绘制游戏板
        RenderSystem.drawBoard(properties, config, renderState)
        
        -- 绘制玩家棋子（传递 gameFlow 用于高亮当前玩家）
        local function drawPlayersWithContext()
            local cellSize = 65
            local playersOnTile = {}  -- 按地块分组玩家
            
            -- 先收集所有玩家的位置信息
            for i, player in ipairs(players) do
                if not player then goto next_player end
                if not player.position or not player.money then goto next_player end
                
                -- 检查是否破产或淘汰
                local playerState = player.state:Now()
                local money = player.money:Now()
                local isBankrupt = playerState == "bankrupt" or money < 0
                
                if not isBankrupt then
                    local position = player.position:Now()
                    if not playersOnTile[position] then
                        playersOnTile[position] = {}
                    end
                    table.insert(playersOnTile[position], i)
                end
                
                ::next_player::
            end
            
            -- 在每个地块绘制该地块上的玩家
            for position, playerIndices in pairs(playersOnTile) do
                local x, y = RenderSystem.getTileScreenPos(position, config)
                local count = #playerIndices
                
                -- 计算布局：最多4个玩家，分别放在地块的四个角
                local layout = {
                    {offsetX = 15, offsetY = 15},   -- 左上
                    {offsetX = cellSize - 25, offsetY = 15},   -- 右上
                    {offsetX = 15, offsetY = cellSize - 25},   -- 左下
                    {offsetX = cellSize - 25, offsetY = cellSize - 25}   -- 右下
                }
                
                local currentPlayerIdx = gameFlow and gameFlow.currentPlayerIndex:Now() or nil
                
                for idx, playerIdx in ipairs(playerIndices) do
                    local player = players[playerIdx]
                    if player then
                        local offset = layout[idx] or {offsetX = 30, offsetY = 30}
                        local px = x + offset.offsetX
                        local py = y + offset.offsetY
                        
                        -- 绘制玩家圆形棋子
                        local playerColor = config.colors.player[playerIdx] or {0.5, 0.5, 0.5}
                        love.graphics.setColor(playerColor[1], playerColor[2], playerColor[3])
                        love.graphics.circle("fill", px, py, 12)
                        
                        -- 绘制玩家编号
                        love.graphics.setColor(1, 1, 1)
                        love.graphics.print(playerIdx, px - 4, py - 6, 0, 1, 1)
                        
                        -- 绘制边框（当前玩家更粗）
                        if playerIdx == currentPlayerIdx then
                            love.graphics.setColor(1, 0.84, 0)  -- 金色边框表示当前玩家
                            love.graphics.setLineWidth(3)
                        else
                            love.graphics.setColor(0.1, 0.1, 0.1)
                            love.graphics.setLineWidth(2)
                        end
                        love.graphics.circle("line", px, py, 12)
                        love.graphics.setLineWidth(1)
                        
                        -- 绘制状态指示器
                        local playerState = player.state:Now()
                        if playerState ~= "normal" then
                            local stateIcon = ""
                            local stateColor = {0.5, 0.5, 0.5}
                            
                            if playerState == "hospital" then
                                stateIcon = "H"
                                stateColor = {1, 0.5, 0.5}  -- 红色
                            elseif playerState == "mountain" then
                                stateIcon = "M"
                                stateColor = {0.6, 0.4, 0.2}  -- 棕色
                            elseif playerState == "jail" then
                                stateIcon = "J"
                                stateColor = {0.5, 0.5, 0.5}  -- 灰色
                            end
                            
                            -- 在棋子右下角绘制状态标记
                            love.graphics.setColor(stateColor)
                            love.graphics.circle("fill", px + 14, py + 10, 6)
                            love.graphics.setColor(1, 1, 1)
                            love.graphics.print(stateIcon, px + 11, py + 6, 0, 0.8, 0.8)
                        end
                        
                        -- 绘制金币显示（简化版，显示金币数量等级）
                        local money = player.money:Now()
                        local moneyLevel = 0
                        if money > 200000 then moneyLevel = 3
                        elseif money > 100000 then moneyLevel = 2
                        elseif money > 50000 then moneyLevel = 1
                        end
                        
                        if moneyLevel > 0 then
                            love.graphics.setColor(1, 0.84, 0, 0.8)  -- 金色
                            local barWidth = moneyLevel * 3
                            love.graphics.rectangle("fill", px - barWidth/2, py - 20, barWidth, 3)
                        end
                    end
                end
            end
        end
        
        drawPlayersWithContext()
        
        -- 绘制玩家信息面板
        RenderSystem.drawPlayerInfo(players, gameFlow, config)
        
        -- 绘制游戏状态
        RenderSystem.drawGameStatus(gameFlow, config)
        
        -- 绘制日志
        RenderSystem.drawLogs(gameFlow)
        
        -- 绘制骰子动画
        if animationState then
            RenderSystem.drawDice(animationState)
        end
    end
end

return RenderSystem
