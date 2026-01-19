-- 蛋仔大富翁 - LÖVE2D 入口
-- 结构：Game（规则层）+ LoveLayer（UI 适配层）

package.path = "src/?.lua;src/?/init.lua;?.lua;" .. package.path

-- 规则层：Game 负责游戏逻辑，装配由 Bootstrap 完成
local Game = require("src.game")

-- 环境检测：支持 ALL_AI=1 环境变量启用全AI模式
local all_ai_mode = os.getenv("ALL_AI") == "1"

-- 游戏工厂：配置玩家和 AI
local function create_game()
	if all_ai_mode then
		return Game.new({
			players = { "AI1", "AI2", "AI3", "AI4" },
			ai = { [1] = true, [2] = true, [3] = true, [4] = true },
			auto_all = true,
		})
	else
		return Game.new({
			players = { "玩家1", "AI2", "AI3", "AI4" },
			ai = { [2] = true, [3] = true, [4] = true },
			auto_all = true,
		})
	end
end

if all_ai_mode then
	-- 全AI模式：无UI运行
	print("=== 全AI模式启动 ===")
	local game = create_game()
	print("玩家配置: " .. #game.players .. " 个AI玩家")
	
	-- 自动运行直到游戏结束
	local steps = 0
	local max_steps = 10000  -- 安全上限
	while not game.finished and steps < max_steps do
		game:advance_turn()
		steps = steps + 1
		
		-- 每10步输出一次进度
		if steps % 10 == 0 then
			local turn_count = game.store and game.store:get({ "turn", "turn_count" }) or 0
			local alive = game:alive_players()
			print("游戏回合: " .. turn_count .. ", 存活玩家: " .. #alive .. " (步骤: " .. steps .. ")")
		end
	end
	
	-- 输出结果
	print("\n=== 游戏结束 ===")
	local final_turn = game.store and game.store:get({ "turn", "turn_count" }) or 0
	print("游戏回合数: " .. final_turn)
	print("执行步骤数: " .. steps)
	if game.winner_names then
		print("胜者: " .. game.winner_names)
	else
		print("无胜者")
	end
	
	-- 显示所有玩家最终状态
	print("\n玩家状态:")
	for _, p in ipairs(game.players) do
		local status = p.eliminated and "已淘汰" or "存活"
		print("  " .. p.name .. ": " .. status .. ", 现金: " .. (p.cash or 0))
	end
else
	-- UI 适配层：LoveLayer 负责渲染、输入、动画
	local LoveLayer = require("src.adapters.love2d.love_layer")
	
	-- 启动：UI 层挂载到 LÖVE 生命周期
	LoveLayer.new({ game_factory = create_game }):attach()
end
