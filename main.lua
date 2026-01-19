-- 蛋仔大富翁 - LÖVE2D 入口
-- 结构：Game（规则层）+ LoveLayer（UI 适配层）

require("bootstrap")()

-- 规则层：Game 负责游戏逻辑，装配由 Bootstrap 完成
local Game = require("src.game")

-- 环境检测：支持命令行参数启用全AI模式
local all_ai_mode = false
for _, v in ipairs(arg or {}) do
	if v == "--all-ai" then
		all_ai_mode = true
		break
	end
end

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
	print("=== All-AI Mode Start ===")
	
	-- 初始化日志系统
	local logger = require("src.util.logger")
	logger.clear()
	
	local game = create_game()
	print("Players: " .. #game.players .. " AI players")
	logger.info("All-AI Mode Start, player count:", #game.players)
	
	-- 自动运行直到游戏结束
	local steps = 0
	local max_steps = 10000  -- 安全上限
	local prev_alive = #game:alive_players()
	while not game.finished and steps < max_steps do
		game:advance_turn()
		steps = steps + 1
		
		-- 玩家破产时输出进度
		local alive = game:alive_players()
		if #alive < prev_alive then
			local turn_count = game.store and game.store:get({ "turn", "turn_count" }) or 0
			print("Turn: " .. turn_count .. ", Alive: " .. #alive .. " (Steps: " .. steps .. ")")
			prev_alive = #alive
		end
	end
	
	-- 输出结果
	print("\n=== Game Over ===")
	local final_turn = game.store and game.store:get({ "turn", "turn_count" }) or 0
	print("Turn count: " .. final_turn)
	print("Steps executed: " .. steps)
	if game.winner_names then
		print("Winner: " .. game.winner_names)
	else
		print("No winner")
	end
	
	-- 显示所有玩家最终状态
	print("\nPlayer status:")
	for _, p in ipairs(game.players) do
		local status = p.eliminated and "Eliminated" or "Alive"
		print("  " .. p.name .. ": " .. status .. ", Cash: " .. (p.cash or 0))
	end
else
	-- UI 适配层：LoveLayer 负责渲染、输入、动画
	local LoveLayer = require("src.adapters.love2d.love_layer")
	
	-- 启动：UI 层挂载到 LÖVE 生命周期
	LoveLayer.new({ game_factory = create_game }):attach()
end
