require "eca"

local init = require "init"

LuaAPI.global_register_trigger_event({ EVENT.GAME_INIT }, init)