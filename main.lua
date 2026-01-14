-- 蛋仔大富翁 - LÖVE2D 入口
-- 结构：Game（规则层）+ LoveLayer（UI 适配层）

package.path = "src/?.lua;src/?/init.lua;?.lua;" .. package.path

-- 规则层：Game 负责游戏逻辑，装配由 Bootstrap 完成
local Game = require("src.game")

-- UI 适配层：LoveLayer 负责渲染、输入、动画
local LoveLayer = require("src.adapters.love2d.love_layer")

-- 游戏工厂：配置玩家和 AI
local function create_game()
	return Game.new({
		players = { "玩家1", "AI2", "AI3", "AI4" },
		ai = { [2] = true, [3] = true, [4] = true },
		auto_all = true,
	})
end

-- 启动：UI 层挂载到 LÖVE 生命周期
LoveLayer.new({ game_factory = create_game }):attach()
