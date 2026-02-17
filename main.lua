local context = require("core.context")
local game = require("game")
local gameplay_loop = require("turn")
local gameplay_loop_ports = require("turn.ports")
local logger = require("core.logger")
local map_cfg = require("cfg.Map")
local tiles_cfg = require("cfg.Generated.Tiles")

local app = {
	initialized = false,
	started = false,
	state = nil,
	game = nil,
	tick_handler_bound = false,
}

local function _noop()
end

local function _default_auto_runner()
	return {
		set_enabled = _noop,
		reset_timer = _noop,
		next_action = function()
			return nil
		end,
	}
end

local function _build_state()
	return {
		ui = nil,
		ui_dirty = false,
		pending_choice = nil,
		pending_choice_elapsed = 0,
		pending_choice_id = nil,
		ui_modal_elapsed = 0,
		ui_modal_ref = nil,
		board_last_phase = nil,
		next_turn_locked = false,
		next_turn_last_click = nil,
		next_turn_lock_phase = nil,
		role_control_lock_active = false,
		role_control_lock_suppress = 0,
		_log_once = {},
		gameplay_loop_ports = gameplay_loop_ports.resolve(nil),
		auto_runner = _default_auto_runner(),
	}
end

local function _resolve_player_names()
	local names = {}
	local roles = all_roles
	if type(roles) == "table" then
		for _, role in ipairs(roles) do
			if role and role.get_name then
				local ok, role_name = pcall(role.get_name)
				if ok and role_name and role_name ~= "" then
					table.insert(names, role_name)
				end
			end
		end
	end
	if #names == 0 then
		names = { "玩家1", "玩家2", "玩家3", "玩家4" }
	end
	if #names == 1 then
		names = { names[1], "玩家2", "玩家3", "玩家4" }
	end
	return names
end

local function _start_game_once()
	if app.started then
		logger.info("[Main] 启动已完成，忽略重复初始化")
		return app.game
	end

	local state = _build_state()
	local setup_ok, setup_err = pcall(function()
		game.setup({
			players = _resolve_player_names(),
			ai = {},
			auto_all = false,
			map = map_cfg,
			tiles = tiles_cfg,
		})
	end)
	if not setup_ok then
		logger.error("[Main] game.setup failed", tostring(setup_err))
		return nil, setup_err
	end

	local set_ok, set_err = pcall(function()
		gameplay_loop.set_game(state, game)
	end)
	if not set_ok then
		logger.error("[Main] gameplay_loop.set_game failed", tostring(set_err))
		return nil, set_err
	end

	app.state = state
	app.game = game
	app.started = true
	logger.info("[Main] 启动完成")
	return game
end

local function _tick(dt)
	if not app.started or not app.game or not app.state then
		return
	end
	local delta = dt
	if type(delta) ~= "number" then
		delta = 1 / 30
	end
	local ok, err = pcall(function()
		gameplay_loop.tick(app.game, app.state, delta)
	end)
	if not ok then
		logger.error("[Main] tick failed", tostring(err))
	end
end

local function _bind_tick_handler_once()
	if app.tick_handler_bound then
		return
	end
	if not (LuaAPI and LuaAPI.set_tick_handler) then
		logger.warn("[Main] missing LuaAPI.set_tick_handler")
		return
	end
	LuaAPI.set_tick_handler(nil, function(_, _, dt)
		_tick(dt)
	end)
	app.tick_handler_bound = true
	logger.info("[Main] tick handler 已绑定")
end

local function _bootstrap()
	if app.initialized then
		return
	end
	local ctx = context.new({
		GameAPI = GameAPI,
		LuaAPI = LuaAPI,
	})
	context.set_current(ctx)
	context.install_globals(ctx)
	app.initialized = true
	logger.info("[Main] runtime context 已安装")
end

local function _on_game_init()
	_bootstrap()
	local _, err = _start_game_once()
	if err then
		return
	end
	_bind_tick_handler_once()
end

local function _register_game_init_handler()
	if not (LuaAPI and LuaAPI.global_register_trigger_event and EVENT and EVENT.GAME_INIT) then
		logger.warn("[Main] missing GAME_INIT trigger env, fallback to immediate init")
		_on_game_init()
		return
	end
	LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
		_on_game_init()
	end)
	logger.info("[Main] GAME_INIT handler 已注册")
end

_register_game_init_handler()

return app
