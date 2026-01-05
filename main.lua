-- Rebuilt main entry

local Config = require("config")
local Game = require("game")
local Render = require("render")
local Input = require("input")

function love.load()
    love.window.setMode(Config.window.width, Config.window.height)
    love.window.setTitle(Config.window.title)
    math.randomseed(os.time())

    Game.init(Config)
    Game.startNewGame(1) -- default single human + AI fill
end

function love.update(dt)
    Game.update(dt)
end

function love.draw()
    Render.draw(Game.getState())
end

function love.keypressed(key)
    Input.handleKey(key, Game)
end
