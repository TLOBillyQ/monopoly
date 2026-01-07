local Config = require("config")
local GameManager = require("GameManager")

function love.load()
    love.window.setMode(Config.window.width, Config.window.height)
    love.window.setTitle(Config.window.title)
    love.keyboard.setKeyRepeat(true)
    math.randomseed(os.time())
    
    GameManager.createNewGame(Config, 4)
    
    print("=== 蛋仔大富翁（无 Spoke 版） ===")
    print("空格: 下一步 | A: 自动/手动 | B: 买地 | U: 升级 | S: 跳过 | H: 帮助 | ESC: 退出")
end

function love.update(dt)
    GameManager.update(dt)
end

function love.draw()
    GameManager.draw()
end

function love.keypressed(key)
    GameManager.handleInput(key)
end
