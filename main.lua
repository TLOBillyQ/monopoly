package.path = "src/?.lua;src/?/init.lua;?.lua;" .. package.path

local App = require("src.app")
local LoveLayer = require("src.ui.love_layer")

local default_factory = function()
	return App.new({
		players = { "玩家1", "AI2", "AI3", "AI4" },
		ai = { [2] = true, [3] = true, [4] = true },
		auto_all = true,
	})
end

LoveLayer.new({ game_factory = default_factory }):attach()
