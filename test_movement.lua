-- 测试玩家移动
local Config = require("config")
local GameManager = require("GameManager")

-- 初始化游戏
GameManager.createNewGame(Config, 4, "medium")

local ctx = GameManager.context

-- 输出初始状态
print("\n=== 初始状态 ===")
for i, player in ipairs(ctx.players:Get()) do
    print(string.format("玩家%d: 位置=%d", i, player.position:Get()))
end

-- 模拟按空格键几次
for step = 1, 6 do
    print("\n--- 按空格键 " .. step .. " ---")
    GameManager.handleInput("space")
    
    -- 检查阶段和玩家位置
    local phase = ctx.gameFlow.currentPhase:Get()
    for i, player in ipairs(ctx.players:Get()) do
        local pos = player.position:Get()
        print(string.format("玩家%d: 位置=%d", i, pos))
    end
    print("当前阶段: " .. phase)
end

print("\n完成测试")
