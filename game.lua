-- 重构的游戏核心逻辑
-- Game Core - 整合Player、Chance、Item系统

local Game = {}

-- 导入模块
local Player = require("player")
local Chance = require("chance")
local Item = require("item")

-- ==================== 游戏常量 ====================
local Phase = {
    BEFORE_ACTION = "before_action",  -- 回合开始前
    ROLL_DICE = "roll_dice",          -- 投掷骰子
    MOVE = "move",                    -- 移动
    LAND_EVENT = "land_event",        -- 着陆事件
    AFTER_ACTION = "after_action"     -- 回合结束
}

-- ==================== 游戏状态 ====================
local GameState = {
    config = nil,
    
    -- 玩家和地块
    players = {},
    tiles = {},
    
    -- 游戏进度
    currentPlayerIndex = 1,
    currentTurn = 1,
    currentPhase = Phase.BEFORE_ACTION,
    
    -- 机会卡和道具
    chanceEvents = {},
    items = {},
    
    -- 游戏状态
    gameStarted = false,
    gameFinished = false,
    winner = nil,
    
    -- UI和日志
    lastLog = "",
    lastDice = 0,
    timer = 0,
    ui = nil,              -- 当前弹窗
    
    -- 游戏模式
    autoMode = false,       -- 自动模式开关
    autoSpeed = 1.0,        -- 自动模式速度（秒/步）
    waitingForInput = false, -- 等待玩家输入
    pendingAction = nil,     -- 待处理的操作
    
    -- 黑市状态
    blackMarketVisits = {}  -- 记录每个玩家造访黑市的次数
}

-- UI 辅助函数
local function showPrompt(title, message, buttons)
    GameState.ui = {
        title = title,
        message = message,
        buttons = buttons or {"Y 是", "N 否"}
    }
end

-- ==================== 初始化 ====================

-- 初始化游戏
function Game.init(config)
    GameState.config = config
    GameState.cfg = config  -- Alias for render compatibility
    
    -- 创建地块
    GameState.tiles = {}
    for i, tileConfig in ipairs(config.tiles) do
        GameState.tiles[i] = {
            id = tileConfig.id,
            name = tileConfig.name,
            type = tileConfig.type,
            price = tileConfig.price or 0,
            gridPos = tileConfig.gridPos or {1, 1},  -- 网格位置
            owner = nil,           -- 玩家ID
            building_level = 0,    -- 建筑等级 0-3（0表示无建筑）
            
            -- 特殊设置（路障、地雷等）
            roadblock = false,     -- 是否有路障
            landmine = false,      -- 是否有地雷
            landmine_owner = nil   -- 地雷放置者ID
        }
    end
    
    -- 创建机会卡事件列表
    GameState.chanceEvents = Chance.createAllEvents()
    
    -- 创建物品列表
    GameState.items = config.items
    
    GameState.gameStarted = false
    GameState.gameFinished = false
    
    return GameState
end

-- 开始新游戏
function Game.startNewGame(numHumans)
    numHumans = math.max(GameState.config.rules.minPlayers, 
                         math.min(GameState.config.rules.maxPlayers, numHumans or 2))
    
    GameState.players = {}
    GameState.currentPlayerIndex = 1
    GameState.currentTurn = 1
    GameState.currentPhase = Phase.BEFORE_ACTION
    GameState.gameStarted = true
    GameState.gameFinished = false
    GameState.timer = 0
    
    -- 创建玩家
    local characters = GameState.config.characters
    local vehicles = GameState.config.vehicles
    
    for i = 1, numHumans do
        local vehicleIdx = ((i - 1) % #vehicles) + 1
        local player = Player.new(i, characters[i].id, vehicles[vehicleIdx].id, false)
        player.name = "玩家" .. i
        table.insert(GameState.players, player)
    end
    
    -- 创建AI玩家
    for i = numHumans + 1, GameState.config.rules.maxPlayers do
        local vehicleIdx = ((i - 1) % #vehicles) + 1
        local player = Player.new(i, characters[i].id, vehicles[vehicleIdx].id, true)
        player.name = "AI" .. i
        table.insert(GameState.players, player)
    end
    
    GameState.lastLog = "游戏开始！"
    
    return GameState
end

-- ==================== 游戏逻辑 ====================

-- 获取当前活跃玩家
local function getCurrentPlayer()
    return GameState.players[GameState.currentPlayerIndex]
end

-- 获取下一个活跃玩家
local function getNextActivePlayerIndex()
    local count = #GameState.players
    local idx = GameState.currentPlayerIndex
    
    repeat
        idx = idx + 1
        if idx > count then
            idx = 1
            GameState.currentTurn = GameState.currentTurn + 1  -- 回合数增加
        end
        
        local player = GameState.players[idx]
        if not Player.isBankrupt(player) then
            return idx
        end
    until idx == GameState.currentPlayerIndex
    
    -- 只剩一个玩家时游戏结束
    return GameState.currentPlayerIndex
end

-- 统一的骰子函数，确保结果在配置范围内（默认1-6）
local function rollDice(count)
    local min = (GameState.config.constants and GameState.config.constants.DICE_MIN) or 1
    local max = (GameState.config.constants and GameState.config.constants.DICE_MAX) or 6
    local total = 0
    for i = 1, count do
        total = total + math.random(min, max)
    end
    return total
end

-- 检查游戏是否结束
local function checkGameEnd()
    local aliveCount = 0
    local lastAlive = nil
    
    for _, player in ipairs(GameState.players) do
        if not Player.isBankrupt(player) then
            aliveCount = aliveCount + 1
            lastAlive = player
        end
    end
    
    if aliveCount <= 1 then
        GameState.gameFinished = true
        GameState.winner = lastAlive
        if lastAlive then
            GameState.lastLog = lastAlive.name .. " 获胜！"
        else
            GameState.lastLog = "游戏结束（没有获胜者）"
        end
        return true
    end
    
    return false
end

-- 在地块上着陆
local function onLandTile(player, tileId)
    local tile = GameState.tiles[tileId]
    if not tile then return end
    
    local result = {log = "", events = {}}
    
    -- 检查路障
    if tile.roadblock and tile.type == "property" then
        Player.enterHospital(player, 1)  -- 停留1回合
        result.log = player.name .. " 踩中路障，停留1回合"
        return result
    end
    
    -- 检查地雷
    if tile.landmine and tile.landmine_owner then
        local owner = GameState.players[tile.landmine_owner]
        if owner and not Player.isProtectedByAngel(player) then
            Player.destroyVehicle(player)
            Player.enterHospital(player, GameState.config.rules.hospitalStay)
            result.log = player.name .. " 踩中地雷，座驾被摧毁，进入医院"
            return result
        end
    end
    
    -- 处理不同类型地块
    if tile.type == "start" then
        result.log = player.name .. " 回到起点"
        
    elseif tile.type == "property" then
        if not tile.owner then
            -- 未被购买的地块
            if not player.isAI and not GameState.autoMode and player.money >= tile.price then
                -- 玩家手动模式：弹出确认
                GameState.waitingForInput = true
                GameState.pendingAction = { type = "buy", playerId = player.id, tileId = tile.id }
                showPrompt("购买地块", tile.name .. "，价格: " .. tile.price .. "。是否购买？")
                result.log = "等待玩家确认是否购买 " .. tile.name
                result.waiting = true
            else
                -- AI 或自动模式：直接购买（如果有钱）
                if player.money >= tile.price then
                    Player.acquireProperty(player, tile.id)
                    Player.subtractMoney(player, tile.price)
                    tile.owner = player.id
                    result.log = player.name .. " 购买了 " .. tile.name .. "，花费 " .. tile.price
                else
                    result.log = player.name .. " 资金不足，无法购买 " .. tile.name
                end
            end
        elseif tile.owner == player.id then
            -- 自己的地块，可以升级
            result.log = player.name .. " 停留在自己的地块 " .. tile.name
        else
            -- 他人的地块，支付租金
            local ownerPlayer = GameState.players[tile.owner]
            if ownerPlayer and not Player.isBankrupt(ownerPlayer) then
                local rentAmount = tile.price * (0.5 * (1 + tile.building_level))
                
                -- 检查穷神附身（支付金额翻倍）
                if Player.isCursedByPoor(player) then
                    rentAmount = rentAmount * 2
                end
                
                -- 检查财神附身（收取金额翻倍）
                if Player.isBlessedByWealth(ownerPlayer) then
                    rentAmount = rentAmount * 2
                end
                
                Player.transfer(player, ownerPlayer, rentAmount)
                result.log = player.name .. " 支付租金 " .. rentAmount .. " 给 " .. ownerPlayer.name
                
                if Player.isBankrupt(player) then
                    result.log = result.log .. "（破产）"
                end
            end
        end
        
    elseif tile.type == "tax_office" then
        -- 税务局：支付50%现金
        local taxAmount = math.floor(player.money * GameState.config.rules.taxRate)
        Player.subtractMoney(player, taxAmount)
        result.log = player.name .. " 在税务局交税 " .. taxAmount
        
        if Player.isBankrupt(player) then
            result.log = result.log .. "（破产）"
        end
        
    elseif tile.type == "hospital" then
        -- 医院：支付费用后进入
        Player.enterHospital(player, GameState.config.rules.hospitalStay)
        Player.subtractMoney(player, GameState.config.rules.hospitalFee)
        result.log = player.name .. " 进入医院，停留 " .. GameState.config.rules.hospitalStay .. " 回合"
        
    elseif tile.type == "mountain" then
        -- 深山：被困
        Player.enterMountain(player, GameState.config.rules.mountainStay)
        result.log = player.name .. " 被困深山，停留 " .. GameState.config.rules.mountainStay .. " 回合"
        
    elseif tile.type == "black_market" then
        -- 黑市：可以购买道具（需要特殊货币）
        result.log = player.name .. " 到达黑市"
        
    elseif tile.type == "chance_card" then
        -- 机会卡：随机抽取机会事件
        local event = Chance.drawRandom(GameState.chanceEvents)
        if event then
            Chance.execute(event, player, GameState.players, GameState)
            result.log = player.name .. " 抽取机会卡：" .. event.description
        else
            result.log = player.name .. " 抽取机会卡（无可用事件）"
        end
        
    elseif tile.type == "item_card" then
        -- 道具卡：随机获得道具
        local itemId = Item.drawRandom(GameState.config)
        if itemId and Player.addItem(player, itemId) then
            result.log = player.name .. " 获得道具：" .. Item.getName(itemId)
        else
            result.log = player.name .. " 道具卡（已满或无可用道具）"
        end
        
    elseif tile.type == "jail" then
        -- 监狱：无事件
        result.log = player.name .. " 停留在监狱"
    end
    
    return result
end

-- 抽取机会卡
local function drawChanceCard(player)
    local event = Chance.drawRandom(GameState.chanceEvents)
    local result = Chance.execute(event, player, GameState.players, GameState)
    
    GameState.lastLog = (GameState.lastLog or "") .. "\n[机会卡] " .. result.message
    
    return result
end

-- ==================== 回合管理 ====================

-- 推进游戏一个步骤
function Game.advance()
    if GameState.gameFinished then return end
    
    local player = getCurrentPlayer()
    
    if GameState.currentPhase == Phase.BEFORE_ACTION then
        -- 回合开始
        Player.startTurn(player)
        
        -- 检查是否可以行动
        if not Player.canAct(player) then
            if Player.isBankrupt(player) then
                GameState.lastLog = player.name .. " 已破产，跳过回合"
            else
                GameState.lastLog = player.name .. " 无法行动，跳过回合"
            end
            GameState.currentPhase = Phase.AFTER_ACTION
            Game.advance()
            return
        end
        
        GameState.currentPhase = Phase.ROLL_DICE
        GameState.lastLog = player.name .. " 的回合开始"
        
    elseif GameState.currentPhase == Phase.ROLL_DICE then
        -- 投掷骰子
        local diceCount = player.hasVehicle and 2 or 1
        local diceTotal = rollDice(diceCount)
        
        GameState.lastDice = diceTotal
        GameState.lastLog = player.name .. " 投掷骰子，点数为 " .. diceTotal
        
        GameState.currentPhase = Phase.MOVE
        
    elseif GameState.currentPhase == Phase.MOVE then
        -- 移动
        local tileCount = #GameState.tiles
        Player.moveForward(player, GameState.lastDice, tileCount)
        GameState.lastLog = player.name .. " 向前移动 " .. GameState.lastDice .. " 格，现在位置为 " .. player.position
        
        -- 检查是否经过起点
        if GameState.lastDice > 0 then
            local passStart = false
            local oldPos = player.position - GameState.lastDice
            if oldPos <= 0 then oldPos = oldPos + tileCount end
            
            if oldPos > player.position or (oldPos == tileCount and player.position > 1) then
                passStart = true
            end
            
            if passStart then
                Player.addMoney(player, GameState.config.rules.passStartBonus)
                GameState.lastLog = GameState.lastLog .. "\n经过起点，获得 " .. GameState.config.rules.passStartBonus .. " 金币"
            end
        end
        
        GameState.currentPhase = Phase.LAND_EVENT
        
    elseif GameState.currentPhase == Phase.LAND_EVENT then
        -- 着陆事件
        local landResult = onLandTile(player, player.position)
        GameState.lastLog = landResult.log
        
        -- 如果需要玩家确认，则暂停推进
        if landResult.waiting then
            return
        end
        
        GameState.currentPhase = Phase.AFTER_ACTION
        
    elseif GameState.currentPhase == Phase.AFTER_ACTION then
        -- 回合结束，检查游戏是否结束
        if checkGameEnd() then
            return
        end
        
        -- 切换到下一个玩家
        GameState.currentPlayerIndex = getNextActivePlayerIndex()
        GameState.currentPhase = Phase.BEFORE_ACTION
        
        Game.advance()
    end
end

-- ==================== 获取游戏状态 ====================

function Game.getState()
    return GameState
end

function Game.getCurrentPlayer()
    return getCurrentPlayer()
end

function Game.isFinished()
    return GameState.gameFinished
end

function Game.getWinner()
    return GameState.winner
end

function Game.getLog()
    return GameState.lastLog
end

function Game.getTurn()
    return GameState.currentTurn
end

function Game.isWaitingForInput()
    return GameState.waitingForInput
end

-- 玩家选择确认/取消
function Game.chooseYes()
    if not GameState.waitingForInput or not GameState.pendingAction then return end
    local action = GameState.pendingAction
    local player = GameState.players[action.playerId]
    local tile = GameState.tiles[action.tileId]
    
    if action.type == "buy" and player and tile and not tile.owner then
        if player.money >= tile.price then
            Player.acquireProperty(player, tile.id)
            Player.subtractMoney(player, tile.price)
            tile.owner = player.id
            GameState.lastLog = player.name .. " 购买了 " .. tile.name
        else
            GameState.lastLog = "金币不足，无法购买"
        end
    end
    
    GameState.waitingForInput = false
    GameState.pendingAction = nil
    GameState.ui = nil
    GameState.currentPhase = Phase.AFTER_ACTION
    Game.advance()
end

function Game.chooseNo()
    if not GameState.waitingForInput or not GameState.pendingAction then return end
    local action = GameState.pendingAction
    local player = GameState.players[action.playerId]
    local tile = GameState.tiles[action.tileId]
    
    if action.type == "buy" and player and tile then
        GameState.lastLog = player.name .. " 放弃购买 " .. tile.name
    end
    
    GameState.waitingForInput = false
    GameState.pendingAction = nil
    GameState.ui = nil
    GameState.currentPhase = Phase.AFTER_ACTION
    Game.advance()
end

-- ==================== 游戏模式控制 ====================

-- 切换自动/手动模式
function Game.toggleAutoMode()
    GameState.autoMode = not GameState.autoMode
    GameState.lastLog = "游戏模式: " .. (GameState.autoMode and "自动" or "手动")
    return GameState.autoMode
end

-- 设置自动模式速度
function Game.setAutoSpeed(speed)
    GameState.autoSpeed = math.max(0.1, math.min(5.0, speed))
end

-- 获取当前模式
function Game.isAutoMode()
    return GameState.autoMode
end

-- 手动推进一步（手动模式使用）
function Game.nextStep()
    if not GameState.waitingForInput then
        Game.advance()
    end
end

-- ==================== 玩家交互 ====================

-- 购买地块
function Game.buyProperty()
    local player = getCurrentPlayer()
    local tile = GameState.tiles[player.position]
    
    if tile and tile.type == "property" and not tile.owner then
        if player.money >= tile.price then
            Player.acquireProperty(player, tile.id)
            Player.subtractMoney(player, tile.price)
            tile.owner = player.id
            GameState.lastLog = player.name .. " 购买了 " .. tile.name
            return true
        else
            GameState.lastLog = "金币不足，无法购买"
            return false
        end
    end
    return false
end

-- 升级地块
function Game.upgradeProperty()
    local player = getCurrentPlayer()
    local tile = GameState.tiles[player.position]
    
    if tile and tile.type == "property" and tile.owner == player.id then
        if tile.building_level < 4 then
            local upgradeCost = tile.price * (2 ^ (tile.building_level + 1))
            if player.money >= upgradeCost then
                Player.subtractMoney(player, upgradeCost)
                tile.building_level = tile.building_level + 1
                GameState.lastLog = player.name .. " 升级了 " .. tile.name .. " 到 " .. tile.building_level .. " 级"
                return true
            else
                GameState.lastLog = "金币不足，无法升级"
                return false
            end
        else
            GameState.lastLog = "已达到最高等级"
            return false
        end
    end
    return false
end

-- 使用道具
function Game.useItem(itemId)
    local player = getCurrentPlayer()
    
    if Player.hasItem(player, itemId) then
        -- TODO: 实现道具使用逻辑
        GameState.lastLog = player.name .. " 使用了道具 " .. itemId
        Player.removeItem(player, itemId)
        return true
    end
    
    GameState.lastLog = "没有该道具"
    return false
end

-- 跳过当前操作
function Game.skipAction()
    if GameState.currentPhase == Phase.LAND_EVENT then
        GameState.currentPhase = Phase.AFTER_ACTION
        GameState.lastLog = "跳过操作"
    end
end

-- ==================== 更新 ====================

function Game.update(dt)
    GameState.timer = GameState.timer + dt
    
    -- 自动模式：每隔一定时间自动推进一步
    if GameState.autoMode and not GameState.gameFinished and not GameState.waitingForInput then
        if GameState.timer > GameState.autoSpeed then
            Game.advance()
            GameState.timer = 0
        end
    end
end

return Game
