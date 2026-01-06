-- 蛋仔大富翁游戏主入口

local Config = require("config")
local GameManager = require("GameManager")
local UI = require("ui")

function love.load()
    love.window.setMode(Config.window.width, Config.window.height)
    love.window.setTitle(Config.window.title)
    math.randomseed(os.time())
    love.keyboard.setKeyRepeat(true)

    -- 初始化UI系统
    UI.init()

    -- 初始化游戏管理器
    GameManager.createNewGame(Config, 4, "medium")
    
    print("=== 蛋仔大富翁 ===")
    print("游戏已启动！")
    print("按 SPACE 推进游戏")
    print("按 A 切换自动模式")
    print("按 H 查看帮助")
    print("按 ESC 退出游戏")
end

function love.update(dt)
    -- Spoke框架自动处理反应式更新
    -- 更新游戏动画
    GameManager.update(dt)
    
    -- 更新UI系统
    UI.update(dt)
end

function love.draw()
    GameManager.draw()
    
    -- 绘制UI层（对话框、卡片等）
    UI.draw()
end

function love.keypressed(key, scancode)
    GameManager.handleInput(key)
end

function love.mousepressed(x, y, button)
    -- 先让UI处理点击
    if UI.handleClick(x, y) then
        return  -- UI已处理
    end
    
    -- 否则传递给游戏管理器
    GameManager.handleMouseClick(x, y, button)
end

