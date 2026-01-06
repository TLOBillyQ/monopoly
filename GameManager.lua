-- 主游戏管理器 - Spoke框架实现
-- 整合所有游戏系统并协调运行

local SpokeTree = require("Spoke.SpokeTree").SpokeTree
local State = require("Spoke.State")
local Reaction = require("Spoke.Reaction")
local Effect = require("Spoke.Effect").Effect
local LambdaEpoch = require("Spoke.LambdaEpoch")

local PlayerSystem = require("systems.PlayerSystem")
local PropertySystem = require("systems.PropertySystem")
local GameFlowSystem = require("systems.GameFlowSystem")
local ItemSystem = require("systems.ItemSystem")
local EventSystem = require("systems.EventSystem")
local AISystem = require("systems.AISystem")
local RenderSystem = require("systems.RenderSystem")
local InputSystem = require("systems.InputSystem")
local AnimationSystem = require("systems.AnimationSystem")

local GameManager = {}

-- 游戏上下文
GameManager.context = {}

-- 初始化游戏
function GameManager.initialize(config)
    GameManager.context = {
        -- 配置
        config = State.Create(config),
        
        -- 游戏流程
        gameFlow = GameFlowSystem.createGameFlow(),
        
        -- 玩家
        players = State.Create({}),
        
        -- 地块
        properties = State.Create({}),
        
        -- 物品数据库
        itemDatabase = ItemSystem.createItemDatabase(config.items),
        chanceDatabase = ItemSystem.createChanceDatabase(config.chanceEvents),
        
        -- 输入和渲染
        inputState = InputSystem.createInputState(),
        renderState = RenderSystem.createRenderState(),
        animationState = AnimationSystem.createAnimationState(),
        
        -- 游戏统计
        statistics = State.Create({
            totalTurns = 0,
            totalEvents = 0,
        }),
    }
    
    print("游戏管理器初始化完成")
    return GameManager.context
end

-- 创建新游戏
function GameManager.createNewGame(config, playerCount, aiDifficulty)
    playerCount = playerCount or 4
    aiDifficulty = aiDifficulty or "medium"
    
    local context = GameManager.initialize(config)
    
    -- 创建玩家
    local players = {}
    for i = 1, playerCount do
        local characterId = config.characters[i].id
        local vehicleId = config.vehicles[1].id
        
        if i == 1 then
            -- 第一个玩家是人类
            local player = PlayerSystem.createPlayer(i, characterId, vehicleId, false)
            table.insert(players, player)
        else
            -- 其他玩家是AI
            local aiPlayer = AISystem.createAIPlayer(i, aiDifficulty, characterId, vehicleId)
            table.insert(players, aiPlayer)
        end
    end
    context.players:Set(players)
    
    -- 创建地块
    local tiles = {}
    for i, tileConfig in ipairs(config.tiles) do
        tiles[i] = PropertySystem.createTile(i, tileConfig)
    end
    context.properties:Set(tiles)
    
    -- 创建游戏Epoch
    context.gameEpoch = GameManager.createGameEpoch(context)
    
    -- 启动Spoke树
    context.spokeTree = SpokeTree.Spawn("MonopolyGame", context.gameEpoch)
    
    print(string.format("游戏已创建：%d个玩家，%d个地块", playerCount, #tiles))
end

-- 创建游戏主Epoch
function GameManager.createGameEpoch(context)
    return LambdaEpoch.new("GameEpoch", function(s)
        -- 监听游戏流程状态
        s:Call(context.gameFlow.currentPhase)
        s:Call(context.gameFlow.currentPlayerIndex)
        s:Call(context.gameFlow.currentTurn)
        
        -- 监听玩家状态
        s:Call(context.players)
        
        -- 监听游戏结束
        s:Call(context.gameFlow.gameFinished)
        
        -- 设置游戏循环
        return function(s)
            local phase = s:D(context.gameFlow.currentPhase)
            local playerIndex = s:D(context.gameFlow.currentPlayerIndex)
            local players = s:D(context.players)
            
            if not players[playerIndex] then return end
            
            local currentPlayer = players[playerIndex]
            local isAI = currentPlayer.isAI:Get()
            
            -- 根据阶段执行逻辑
            if phase == GameFlowSystem.Phase.BEFORE_ACTION then
                -- 行动前：检查物品使用、附身持续等
                if isAI then
                    -- AI的行动前逻辑
                else
                    -- 人类玩家：等待输入
                end
                
            elseif phase == GameFlowSystem.Phase.ROLL_DICE then
                -- 投掷骰子
                local roll = GameFlowSystem.rollDice(context.gameFlow)
                
                -- 启动骰子动画
                if context.animationState then
                    AnimationSystem.startDiceAnimation(context.animationState, roll)
                end
                
                GameFlowSystem.nextPhase(context.gameFlow, players)
                
            elseif phase == GameFlowSystem.Phase.MOVE then
                -- 移动
                GameManager.executeMovement(context, currentPlayer)
                GameFlowSystem.nextPhase(context.gameFlow, players)
                
            elseif phase == GameFlowSystem.Phase.LAND_EVENT then
                -- 着陆事件
                GameManager.executeLandEvent(context, currentPlayer)
                GameFlowSystem.nextPhase(context.gameFlow, players)
                
            elseif phase == GameFlowSystem.Phase.AFTER_ACTION then
                -- 行动后
                GameManager.executeAfterAction(context, currentPlayer)
                GameFlowSystem.nextPhase(context.gameFlow, players)
            end
        end
    end)
end

-- 执行移动
function GameManager.executeMovement(context, player)
    local steps = context.gameFlow.movementSteps:Get()
    local currentPos = player.position:Get()
    local newPos = (currentPos + steps - 1) % 45 + 1
    
    -- 如果经过起点
    if newPos < currentPos then
        local reward = context.config:Get().rules.passStartBonus
        PlayerSystem.addMoney(player, reward)
        GameFlowSystem.addLog(context.gameFlow, "经过起点，获得" .. reward .. "金币")
    end
    
    PlayerSystem.moveTo(player, newPos, 45)
end

-- 执行着陆事件
function GameManager.executeLandEvent(context, player)
    local properties = context.properties:Get()
    local position = player.position:Get()
    local tile = properties[position]
    
    if not tile then return end
    
    local event = EventSystem.handleLandEvent(player, tile, context)
    
    if event.event == "passStart" then
        PlayerSystem.addMoney(player, event.reward)
    elseif event.event == "canBuyProperty" then
        -- 提示购买
        if not player.isAI:Get() then
            InputSystem.promptBuyProperty(context.inputState, tile.name:Get(), tile.basePrice:Get())
        else
            -- AI决定购买
            if AISystem.decideToBuyProperty(player, tile.basePrice:Get(), tile.type:Get(), context) then
                EventSystem.handlePropertyPurchase(player, tile, context, tile.basePrice:Get())
            end
        end
    elseif event.event == "payRent" then
        local owner = nil
        for _, p in ipairs(context.players:Get()) do
            if p.id:Get() == event.owner then
                owner = p
                break
            end
        end
        if owner then
            PlayerSystem.subtractMoney(player, event.amount)
            PlayerSystem.addMoney(owner, event.amount)
        end
    end
end

-- 执行行动后处理
function GameManager.executeAfterAction(context, player)
    -- 减少附身时间
    PlayerSystem.reduceBuff(player)
    
    -- 检查破产
    if EventSystem.checkBankruptcy(player) then
        GameFlowSystem.addLog(context.gameFlow, "玩家" .. player.id:Get() .. "破产了")
    end
    
    -- 检查游戏结束
    GameManager.checkGameEnd(context)
end

-- 检查游戏是否结束
function GameManager.checkGameEnd(context)
    local players = context.players:Get()
    local activePlayers = 0
    local lastActivePlayer = nil
    
    for _, player in ipairs(players) do
        if player.state:Get() ~= "bankrupt" then
            activePlayers = activePlayers + 1
            lastActivePlayer = player
        end
    end
    
    if activePlayers <= 1 and lastActivePlayer then
        GameFlowSystem.endGame(context.gameFlow, lastActivePlayer.id:Get())
        GameFlowSystem.addLog(context.gameFlow, "玩家" .. lastActivePlayer.id:Get() .. "胜利了！")
    end
end

-- 处理输入
function GameManager.handleInput(key)
    local ctx = GameManager.context
    if not ctx or not ctx.players or not ctx.players.Get then
        return
    end

    InputSystem.handleKeyPress(key, ctx.inputState, ctx.gameFlow, ctx.players:Get())
end

-- 处理鼠标点击
function GameManager.handleMouseClick(x, y, button)
    local ctx = GameManager.context
    if not ctx then return end
    
    -- 尝试处理UI点击（对话框、按钮等）
    -- 这里可以集成UI.handleClick
    
    -- TODO: 添加地块点击显示详情的功能
end

-- 更新游戏动画
function GameManager.update(dt)
    local ctx = GameManager.context
    if not ctx then
        return
    end
    
    -- 确保动画状态存在
    if not ctx.animationState then
        return
    end
    
    -- 获取当前骰子值用于动画
    local diceValue = nil
    if ctx.gameFlow and ctx.gameFlow.lastDiceRoll and ctx.gameFlow.lastDiceRoll.Get then
        diceValue = ctx.gameFlow.lastDiceRoll:Get()
    end
    
    -- 更新所有动画
    AnimationSystem.updateAll(ctx.animationState, dt, diceValue)
end

-- 绘制游戏
function GameManager.draw()
    local ctx = GameManager.context
    if not ctx or not ctx.config or not ctx.gameFlow then
        return
    end

    local renderPipeline = RenderSystem.createRenderPipeline(
        ctx.gameFlow,
        ctx.players:Get(),
        ctx.properties:Get(),
        ctx.config:Get(),
        ctx.renderState,
        ctx.animationState
    )
    
    if renderPipeline then
        renderPipeline()
    end
end

return GameManager
