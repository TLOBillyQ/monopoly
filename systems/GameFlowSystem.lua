-- 游戏流程系统 - Spoke框架实现
-- 管理游戏的回合制流程和阶段

local State = require("spoke.state")
local Effect = require("spoke.effect").Effect
local Reaction = require("spoke.reaction")
local LambdaEpoch = require("spoke.lambdaepoch")

local GameFlowSystem = {}

-- 游戏阶段常量
GameFlowSystem.Phase = {
    BEFORE_ACTION = "beforeAction",
    ROLL_DICE = "rollDice",
    MOVE = "move",
    LAND_EVENT = "landEvent",
    AFTER_ACTION = "afterAction",
}

-- 创建游戏流程状态
function GameFlowSystem.createGameFlow()
    return {
        -- 回合管理
        currentTurn = State.Create(1),
        currentPlayerIndex = State.Create(1),
        currentPhase = State.Create(GameFlowSystem.Phase.BEFORE_ACTION),
        
        -- 骰子和移动
        lastDiceRoll = State.Create(0),
        movementSteps = State.Create(0),
        
        -- 游戏状态
        gameFinished = State.Create(false),
        winner = State.Create(nil),
        
        -- 日志和事件
        logs = State.Create({}),
        
        -- 自动模式
        autoMode = State.Create(false),
        autoSpeed = State.Create(1.0),
        
        -- 超时
        timeoutCounter = State.Create(0),
        timeoutThreshold = State.Create(30),
    }
end

-- 前进到下一个阶段
function GameFlowSystem.nextPhase(gameFlow, players)
    local currentPhase = gameFlow.currentPhase:Now()
    
    local phaseOrder = {
        GameFlowSystem.Phase.BEFORE_ACTION,
        GameFlowSystem.Phase.ROLL_DICE,
        GameFlowSystem.Phase.MOVE,
        GameFlowSystem.Phase.LAND_EVENT,
        GameFlowSystem.Phase.AFTER_ACTION,
    }
    
    local nextPhase = nil
    for i, phase in ipairs(phaseOrder) do
        if phase == currentPhase then
            nextPhase = phaseOrder[i + 1] or GameFlowSystem.Phase.BEFORE_ACTION
            break
        end
    end
    
    if nextPhase == GameFlowSystem.Phase.BEFORE_ACTION then
        -- 进入下一个玩家的回合
        local playerCount = players and #players or 4
        GameFlowSystem.nextTurn(gameFlow, playerCount)
    else
        gameFlow.currentPhase:Set(nextPhase)
    end
end

-- 前进到下一回合
function GameFlowSystem.nextTurn(gameFlow, playerCount)
    playerCount = playerCount or 4
    
    local currentPlayerIndex = gameFlow.currentPlayerIndex:Now()
    local nextPlayerIndex = (currentPlayerIndex % playerCount) + 1
    
    gameFlow.currentPlayerIndex:Set(nextPlayerIndex)
    gameFlow.currentTurn:Set(gameFlow.currentTurn:Now() + 1)
    gameFlow.currentPhase:Set(GameFlowSystem.Phase.BEFORE_ACTION)
end

-- 投掷骰子
function GameFlowSystem.rollDice(gameFlow)
    local roll = math.random(1, 6)
    gameFlow.lastDiceRoll:Set(roll)
    gameFlow.movementSteps:Set(roll)
    return roll
end

-- 记录日志
function GameFlowSystem.addLog(gameFlow, message)
    local logs = gameFlow.logs:Now()
    table.insert(logs, {
        message = message,
        timestamp = os.time(),
    })
    -- 只保留最后100条日志
    if #logs > 100 then
        table.remove(logs, 1)
    end
    gameFlow.logs:Set(logs)
end

-- 结束游戏
function GameFlowSystem.endGame(gameFlow, winnerId)
    gameFlow.gameFinished:Set(true)
    gameFlow.winner:Set(winnerId)
end

-- 创建游戏流程Epoch
function GameFlowSystem.createGameFlowEpoch(gameFlow, players, properties)
    return LambdaEpoch.new("GameFlowEpoch", function(s)
        -- 监听当前阶段变化
        s:Call(gameFlow.currentPhase)
        
        -- 监听游戏结束状态
        s:Call(gameFlow.gameFinished)
        
        return function(s)
            -- 每帧处理游戏流程逻辑
            local phase = s:D(gameFlow.currentPhase)
            
            if phase == GameFlowSystem.Phase.ROLL_DICE then
                -- 自动投掷骰子逻辑
            elseif phase == GameFlowSystem.Phase.MOVE then
                -- 自动移动逻辑
            elseif phase == GameFlowSystem.Phase.LAND_EVENT then
                -- 着陆事件处理逻辑
            end
        end
    end)
end

return GameFlowSystem
