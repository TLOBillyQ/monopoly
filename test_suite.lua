local Config = require("config")
local GameManager = require("GameManager")
local Property = require("property")

local TestSuite = {}

local function resetGame()
    math.randomseed(42)
    return GameManager.createNewGame(Config, 2)
end

function TestSuite.testInitialization()
    local state = resetGame()
    assert(state.tileCount == 16, "棋盘应有 16 个格子")
    assert(#state.players == 2, "应创建 2 名玩家")
    assert(state.tileIndexByType.hospital, "应能找到医院位置")
    assert(state.tileIndexByType.tax_office, "应能找到税务局位置")
    print("✓ 初始化测试通过")
end

function TestSuite.testBuyAndRent()
    local state = resetGame()
    local p1 = state.players[1]
    local p2 = state.players[2]
    
    -- 玩家1购买第二块地
    p1.position = 2
    GameManager.buyProperty()
    assert(state.tiles[2].owner == p1.id, "购买失败，地块未标记拥有者")
    assert(#p1.properties == 1, "玩家1 应记录拥有的地块")
    
    -- 玩家2落在该地块并支付租金
    state.currentPlayerIndex = 2
    p2.position = 2
    state.currentPhase = "RESOLVE"
    GameManager.nextStep()
    assert(p2.money < Config.rules.startMoney, "玩家2 金币未减少，租金未生效")
    assert(p1.money > Config.rules.startMoney - state.tiles[2].price, "玩家1 金币未增加租金收益")
    print("✓ 购买与收租测试通过")
end

function TestSuite.testChanceCard()
    local state = resetGame()
    local p1 = state.players[1]
    state.currentPlayerIndex = 1
    p1.position = state.tileIndexByType.chance_card or 4
    state.currentPhase = "RESOLVE"
    local beforeMoney = p1.money
    GameManager.nextStep()
    assert(state.lastLog ~= nil, "机会卡未产生日志")
    assert(p1.money ~= beforeMoney or state.currentPhase ~= "RESOLVE", "机会卡未产生任何效果")
    print("✓ 机会卡测试通过")
end

function TestSuite.runAllTests()
    print("运行新架构测试...")
    TestSuite.testInitialization()
    TestSuite.testBuyAndRent()
    TestSuite.testChanceCard()
    print("所有测试完成")
end

TestSuite.runAllTests()

return TestSuite
