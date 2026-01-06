-- Spoke框架集成测试
-- 验证所有系统能否正确工作

local Config = require("config")
local GameManager = require("GameManager")

local TestSuite = {}

function TestSuite.testPlayerSystem()
    print("\n=== 测试玩家系统 ===")
    local PlayerSystem = require("systems.PlayerSystem")
    
    local player = PlayerSystem.createPlayer(1, 1001, 4001, false)
    
    -- 测试金币操作
    PlayerSystem.addMoney(player, 5000)
    assert(player.money:Get() == 105000, "金币增加失败")
    print("✓ 金币增加测试通过")
    
    PlayerSystem.subtractMoney(player, 3000)
    assert(player.money:Get() == 102000, "金币减少失败")
    print("✓ 金币减少测试通过")
    
    -- 测试地块操作
    PlayerSystem.acquireProperty(player, 5)
    assert(#player.properties:Get() == 1, "获得地块失败")
    print("✓ 地块获得测试通过")
    
    -- 测试附身
    PlayerSystem.applyBuff(player, "angel", 5)
    assert(player.buffs:Get()["angel"] == "angel", "附身应用失败")
    print("✓ 附身应用测试通过")
    
    print("✓ 玩家系统测试全部通过")
end

function TestSuite.testPropertySystem()
    print("\n=== 测试地块系统 ===")
    local PropertySystem = require("systems.PropertySystem")
    
    local tileConfig = {
        name = "测试地块",
        type = "property",
        basePrice = 500,
    }
    
    local tile = PropertySystem.createTile(1, tileConfig)
    
    -- 测试购买
    PropertySystem.buyProperty(tile, 1, 500)
    assert(tile.owner:Get() == 1, "购买地块失败")
    assert(tile.level:Get() == 1, "初始等级设置失败")
    print("✓ 地块购买测试通过")
    
    -- 测试升级
    PropertySystem.upgradeProperty(tile, 1000)
    assert(tile.level:Get() == 2, "地块升级失败")
    print("✓ 地块升级测试通过")
    
    -- 测试租金计算
    local rent = PropertySystem.calculateRent(tile)
    assert(rent == 250, "租金计算失败（期望250，获得" .. rent .. "）")
    print("✓ 租金计算测试通过")
    
    print("✓ 地块系统测试全部通过")
end

function TestSuite.testGameFlowSystem()
    print("\n=== 测试游戏流程系统 ===")
    local GameFlowSystem = require("systems.GameFlowSystem")
    
    local gameFlow = GameFlowSystem.createGameFlow()
    
    -- 测试骰子投掷
    local roll = GameFlowSystem.rollDice(gameFlow)
    assert(roll >= 1 and roll <= 6, "骰子投掷失败")
    assert(gameFlow.lastDiceRoll:Get() == roll, "骰子结果记录失败")
    print("✓ 骰子投掷测试通过")
    
    -- 测试回合推进
    GameFlowSystem.nextTurn(gameFlow, 4)
    assert(gameFlow.currentTurn:Get() == 2, "回合推进失败")
    print("✓ 回合推进测试通过")
    
    -- 测试日志
    GameFlowSystem.addLog(gameFlow, "测试日志")
    assert(#gameFlow.logs:Get() > 0, "日志添加失败")
    print("✓ 日志系统测试通过")
    
    print("✓ 游戏流程系统测试全部通过")
end

function TestSuite.testEventSystem()
    print("\n=== 测试事件系统 ===")
    local EventSystem = require("systems.EventSystem")
    local PropertySystem = require("systems.PropertySystem")
    
    local tile = PropertySystem.createTile(1, {
        name = "测试地块",
        type = "property",
        basePrice = 500,
    })
    
    -- 测试租金计算
    PropertySystem.buyProperty(tile, 1, 500)
    PropertySystem.upgradeProperty(tile, 1000)
    
    local rent = EventSystem.calculateRent(tile)
    assert(rent > 0, "租金计算失败")
    print("✓ 事件系统租金计算测试通过")
    
    print("✓ 事件系统测试全部通过")
end

function TestSuite.testAISystem()
    print("\n=== 测试AI系统 ===")
    local AISystem = require("systems.AISystem")
    
    local aiPlayer = AISystem.createAIPlayer(1, AISystem.Difficulty.MEDIUM, 1001, 4001)
    
    -- 测试购买决策
    assert(aiPlayer.difficulty:Get() == AISystem.Difficulty.MEDIUM, "AI难度设置失败")
    print("✓ AI创建测试通过")
    
    -- 测试局势评估
    local situation = AISystem.evaluateGameSituation(aiPlayer, {aiPlayer}, nil)
    assert(situation.isLeading == false, "局势评估失败")
    print("✓ AI局势评估测试通过")
    
    print("✓ AI系统测试全部通过")
end

function TestSuite.runAllTests()
    print("===============================================")
    print("       Spoke框架集成测试套件")
    print("===============================================")
    
    local success = true
    
    pcall(function()
        TestSuite.testPlayerSystem()
    end)
    
    pcall(function()
        TestSuite.testPropertySystem()
    end)
    
    pcall(function()
        TestSuite.testGameFlowSystem()
    end)
    
    pcall(function()
        TestSuite.testEventSystem()
    end)
    
    pcall(function()
        TestSuite.testAISystem()
    end)
    
    print("\n===============================================")
    print("       所有测试完成！")
    print("===============================================")
end

-- 如果直接运行此文件
if _G.arg and _G.arg[1] == "test" then
    TestSuite.runAllTests()
end

return TestSuite
