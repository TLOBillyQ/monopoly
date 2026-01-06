-- 渲染系统 - Spoke框架实现
-- 处理游戏画面的绘制

local State = require("Spoke.State")
local Effect = require("Spoke.Effect").Effect

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

-- 绘制游戏板
function RenderSystem.drawBoard(properties, config)
    love.graphics.setColor(0.85, 0.85, 0.8)
    love.graphics.rectangle("fill", 100, 100, 600, 600)
    
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("line", 100, 100, 600, 600)
    
    -- 绘制地块
    local tileSize = 60
    for i = 1, 12 do
        local x = 100 + (i - 1) * tileSize
        local y = 100
        love.graphics.rectangle("line", x, y, tileSize, tileSize)
    end
end

-- 绘制玩家信息
function RenderSystem.drawPlayerInfo(players, gameFlow, config)
    love.graphics.setColor(0.2, 0.2, 0.2)
    local y = 20
    
    for i, player in ipairs(players) do
        local money = player.money:Get()
        local position = player.position:Get()
        local character = player.characterId:Get()
        
        local text = string.format("玩家%d: 金币=%d, 位置=%d", i, money, position)
        love.graphics.print(text, 20, y + (i - 1) * 30)
    end
end

-- 绘制游戏状态
function RenderSystem.drawGameStatus(gameFlow, config)
    love.graphics.setColor(0.2, 0.2, 0.2)
    
    local turn = gameFlow.currentTurn:Get()
    local phase = gameFlow.currentPhase:Get()
    local playerIndex = gameFlow.currentPlayerIndex:Get()
    
    love.graphics.print("回合: " .. turn, 500, 20)
    love.graphics.print("阶段: " .. phase, 500, 50)
    love.graphics.print("当前玩家: " .. playerIndex, 500, 80)
end

-- 绘制日志
function RenderSystem.drawLogs(gameFlow)
    love.graphics.setColor(0.2, 0.2, 0.2)
    
    local logs = gameFlow.logs:Get()
    local recentLogs = {}
    
    for i = math.max(1, #logs - 5), #logs do
        table.insert(recentLogs, logs[i])
    end
    
    for i, log in ipairs(recentLogs) do
        love.graphics.print(log.message, 20, 700 + i * 20)
    end
end

-- 创建完整的渲染管道
function RenderSystem.createRenderPipeline(gameFlow, players, properties, config)
    return function()
        -- 背景
        love.graphics.clear(0.92, 0.92, 0.9)
        
        -- 绘制游戏板
        RenderSystem.drawBoard(properties, config)
        
        -- 绘制玩家信息
        RenderSystem.drawPlayerInfo(players, gameFlow, config)
        
        -- 绘制游戏状态
        RenderSystem.drawGameStatus(gameFlow, config)
        
        -- 绘制日志
        RenderSystem.drawLogs(gameFlow)
        
        -- 绘制帮助信息
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("按 SPACE 推进游戏 | 按 A 自动模式 | 按 ESC 退出", 20, 660)
    end
end

return RenderSystem
