local StickController = require("StickController")

LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, function()
	local stickController = StickController.new()

	local function onPreTick()
		stickController:update()
	end

	LuaAPI.set_tick_handler(onPreTick, nil)
end)
