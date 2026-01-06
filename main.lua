-- 使用Spoke反应式框架重构

-- Ensure Spoke modules are discoverable when required from within the Spoke folder
package.path = package.path .. ";./Spoke/?.lua;./Spoke/?/init.lua"

local Config = require("config")
local GameManager = require("GameManager")

function love.load()
    love.window.setMode(Config.window.width, Config.window.height)
    love.window.setTitle(Config.window.title)
    math.randomseed(os.time())
    love.keyboard.setKeyRepeat(true)

    -- 初始化游戏管理器
    GameManager.createNewGame(Config, 4, "medium")
    
    print("=== 蛋仔大富翁 (Spoke Edition) ===")
    print("游戏已启动！")
    print("按 SPACE 推进游戏")
    print("按 A 切换自动模式")
    print("按 H 查看帮助")
    print("按 ESC 退出游戏")
end

function love.update(dt)
    -- Spoke框架自动处理反应式更新
end

function love.draw()
    GameManager.draw()
end

function love.keypressed(key, scancode)
    GameManager.handleInput(key)
end

