-- Rebuilt main entry

local Config = require("config")
local Game = require("game")
local Render = require("render")
local Input = require("input")

function love.load()
    love.window.setMode(Config.window.width, Config.window.height)
    love.window.setTitle(Config.window.title)
    math.randomseed(os.time())
    love.keyboard.setKeyRepeat(true)

    Game.init(Config)
    Game.startNewGame(1) -- default single human + AI fill
    
    -- 打印欢迎信息和帮助
    print("=== 蛋仔大富翁 ===")
    print("按 H 键查看操作帮助")
    print("按 A 键切换自动/手动模式")
    print("默认为手动模式，按空格推进游戏")
end

function love.update(dt)
    Game.update(dt)
end

function love.draw()
    Render.draw(Game.getState())
end

function love.keypressed(key, scancode)
    Input.handleKey(key or scancode, Game)
end
