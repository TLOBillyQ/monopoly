-- 蛋仔大富翁游戏主入口

local Config = require("config")
local Game = require("game")
local Render = require("render")

local gameState = nil

function love.load()
    love.window.setMode(Config.window.width, Config.window.height)
    love.window.setTitle(Config.window.title)
    math.randomseed(os.time())
    love.keyboard.setKeyRepeat(true)

    -- 初始化游戏
    gameState = Game.init(Config)
    Game.startNewGame(4)
    
    print("=== 蛋仔大富翁 ===")
    print("游戏已启动！")
    print("按 SPACE 推进游戏")
    print("按 A 切换自动模式")
    print("按 H 查看帮助")
    print("按 ESC 退出游戏")
end

function love.update(dt)
    -- 更新游戏逻辑（处理自动模式）
    Game.update(dt)
end

function love.draw()
    local state = Game.getState()
    Render.draw(state)
end

function love.keypressed(key, scancode)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        Game.nextStep()
    elseif key == "a" then
        Game.toggleAutoMode()
    elseif key == "y" then
        Game.chooseYes()
    elseif key == "n" then
        Game.chooseNo()
    elseif key == "b" then
        Game.buyProperty()
    elseif key == "u" then
        Game.upgradeProperty()
    elseif key == "s" then
        Game.skipAction()
    elseif key == "h" then
        print("快捷键:")
        print("  SPACE - 推进游戏")
        print("  A - 切换自动/手动模式")
        print("  Y - 确认")
        print("  N - 取消")
        print("  B - 购买地块")
        print("  U - 升级地块")
        print("  S - 跳过操作")
        print("  H - 帮助")
        print("  ESC - 退出")
    end
end

