-- 示例程序：简单的单人游戏演示
-- 展示Spoke框架的基本使用方法

local PlayerSystem = require("systems.PlayerSystem")
local PropertySystem = require("systems.PropertySystem")
local GameFlowSystem = require("systems.GameFlowSystem")
local EventSystem = require("systems.EventSystem")

local TestSimple = {}

-- 创建一个简单的游戏场景
function TestSimple.createSimpleGame()
    print("=== 简单游戏示例 ===\n")
    
    -- 1. 创建玩家
    print("1. 创建玩家...")
    local player = PlayerSystem.createPlayer(1, 1001, 4001, false)
    print("   玩家ID: 1")
    print("   角色: 蛋仔")
    print("   初始金币: " .. player.money:Now())
    print()
    
    -- 2. 创建地块
    print("2. 创建地块...")
    local tile = PropertySystem.createTile(1, {
        name = "翡翠花园",
        type = "property",
        basePrice = 500,
    })
    print("   地块: " .. tile.name:Now())
    print("   类型: " .. tile.type:Now())
    print("   价格: " .. tile.basePrice:Now())
    print()
    
    -- 3. 购买地块
    print("3. 玩家购买地块...")
    EventSystem.handlePropertyPurchase(player, tile, {}, 500)
    print("   购买成功！")
    print("   玩家金币: " .. player.money:Now())
    print("   地块所有者: " .. (tile.owner:Now() or "无"))
    print()
    
    -- 4. 升级地块
    print("4. 玩家升级地块...")
    PropertySystem.upgradeProperty(tile, 1000)
    print("   升级到2级")
    print("   升级等级: " .. tile.level:Now())
    print()
    
    -- 5. 计算租金
    print("5. 计算地块租金...")
    local rent = EventSystem.calculateRent(tile)
    print("   当前租金: " .. rent .. "金币")
    print()
    
    -- 6. 获得道具
    print("6. 玩家获得道具...")
    PlayerSystem.addItem(player, 2001)
    PlayerSystem.addItem(player, 2002)
    print("   现有道具: " .. #player.items:Now() .. "张")
    print()
    
    -- 7. 应用附身
    print("7. 应用天使附身...")
    PlayerSystem.applyBuff(player, "angel", 5)
    print("   当前附身: angel")
    print("   持续回合: " .. player.buffTurns:Now()["angel"])
    print()
    
    -- 8. 创建游戏流程
    print("8. 创建游戏流程...")
    local gameFlow = GameFlowSystem.createGameFlow()
    
    -- 投掷骰子
    local diceRoll = GameFlowSystem.rollDice(gameFlow)
    print("   投掷骰子: " .. diceRoll)
    print()
    
    -- 9. 演示状态变化
    print("9. 演示状态变化监听...")
    local moneyChanges = 0
    local oldMoney = player.money:Now()
    
    -- 减少金币
    PlayerSystem.subtractMoney(player, 1000)
    if player.money:Now() ~= oldMoney then
        moneyChanges = moneyChanges + 1
        print("   玩家金币变化: " .. oldMoney .. " -> " .. player.money:Now())
    end
    print()
    
    -- 10. 显示玩家总资产
    print("10. 计算玩家总资产...")
    print("    金币: " .. player.money:Now())
    print("    地块数: " .. #player.properties:Now())
    print("    道具数: " .. #player.items:Now())
    local estimatedPropertyValue = #player.properties:Now() * 500
    print("    预估地产价值: " .. estimatedPropertyValue)
    print("    预估总资产: " .. (player.money:Now() + estimatedPropertyValue))
    print()
    
    print("=== 示例完成 ===\n")
end

-- 运行多回合的游戏循环示例
function TestSimple.runGameLoop()
    print("\n=== 游戏循环示例（5回合） ===\n")
    
    local Config = require("config")
    
    -- 创建玩家
    local player = PlayerSystem.createPlayer(1, 1001, 4001, false)
    local gameFlow = GameFlowSystem.createGameFlow()
    
    -- 创建4个地块
    local tiles = {}
    for i = 1, 4 do
        tiles[i] = PropertySystem.createTile(i, {
            name = "地块" .. i,
            type = "property",
            basePrice = 100 * i,
        })
    end
    
    -- 模拟5个回合
    for turn = 1, 5 do
        print("--- 第 " .. turn .. " 回合 ---")
        
        -- 投掷骰子
        local diceRoll = GameFlowSystem.rollDice(gameFlow)
        print("骰子: " .. diceRoll)
        
        -- 移动
        local newPos = (player.position:Now() + diceRoll - 1) % 4 + 1
        PlayerSystem.moveTo(player, newPos, 4)
        print("位置: " .. newPos)
        
        -- 处理着陆事件
        local tile = tiles[newPos]
        local owner = tile.owner:Now()
        
        if not owner then
            -- 可以购买
            local price = tile.basePrice:Now()
            if player.money:Now() >= price then
                EventSystem.handlePropertyPurchase(player, tile, {}, price)
                print("动作: 购买地块 \"" .. tile.name:Now() .. "\"，花费 " .. price)
            else
                print("动作: 无法购买（金币不足）")
            end
        elseif owner ~= player.id:Now() then
            -- 支付租金
            local rent = EventSystem.calculateRent(tile)
            if rent > 0 then
                PlayerSystem.subtractMoney(player, rent)
                print("动作: 支付租金 " .. rent)
            end
        else
            print("动作: 这是自己的地块")
        end
        
        print("金币: " .. player.money:Now())
        print("地块: " .. #player.properties:Now())
        print()
    end
    
    print("=== 游戏循环结束 ===\n")
end

-- 演示反应式特性
function TestSimple.demonstrateReactivity()
    print("\n=== 反应式特性演示 ===\n")
    
    local State = require("spoke.state")
    local Memo = require("spoke.memo")
    local SpokeTree = require("spoke.spoketree").SpokeTree
    
    -- 创建两个状态
    local baseSalary = State.Create(10000)
    local bonus = State.Create(5000)
    
    -- 创建自动计算的总薪资
    local totalSalary = Memo.new("TotalSalary", function(s)
        local base = s:D(baseSalary)
        local bon = s:D(bonus)
        return base + bon
    end, {baseSalary, bonus})

    -- 将 Memo 挂到 Spoke 树上，确保立即计算并随依赖更新
    local reactivityTree = SpokeTree.Spawn("ReactivityDemo", totalSalary)
    
    print("初始状态:")
    print("  基本薪资: " .. baseSalary:Now())
    print("  奖金: " .. bonus:Now())
    print("  总薪资: " .. totalSalary:Now())
    print()
    
    -- 修改状态
    print("修改基本薪资为 12000...")
    baseSalary:Set(12000)
    print("  基本薪资: " .. baseSalary:Now())
    print("  总薪资已自动更新: " .. totalSalary:Now())
    print()
    
    print("修改奖金为 8000...")
    bonus:Set(8000)
    print("  奖金: " .. bonus:Now())
    print("  总薪资已自动更新: " .. totalSalary:Now())
    print()
    
    -- 清理示例使用的树
    reactivityTree:Dispose()
    
    print("=== 反应式特性演示结束 ===\n")
end

-- 主函数
function TestSimple.run()
    print("\n" .. string.rep("=", 50))
    print("   Spoke框架 - 蛋仔大富翁 示例程序")
    print(string.rep("=", 50) .. "\n")
    
    TestSimple.createSimpleGame()
    TestSimple.runGameLoop()
    TestSimple.demonstrateReactivity()
    
    print("\n" .. string.rep("=", 50))
    print("   所有示例运行完成！")
    print(string.rep("=", 50) .. "\n")
end

-- 直接运行
TestSimple.run()

return TestSimple
