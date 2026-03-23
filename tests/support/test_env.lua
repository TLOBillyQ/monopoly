local logger = require("src.core.utils.logger")
local tip_queue = require("src.core.utils.tip_queue")
local runtime_context = require("src.host.eggy.context")
local default_ports = require("src.host.eggy.default_ports")
local runtime_ports = require("src.core.ports.runtime_ports")
local paid_purchase_port = require("src.rules.market.ports.paid_purchase_port")

local M = {}

function M.install_defaults()
  if not math.tofixed then
    function math.tofixed(value)
      return value
    end
  end

  if not math.Vector3 then
    function math.Vector3(x, y, z)
      return { x = x, y = y, z = z }
    end
  end

  if not math.Quaternion then
    function math.Quaternion(x, y, z)
      return { x = x, y = y, z = z }
    end
  end

  LuaAPI = LuaAPI or {}
  LuaAPI.rand = LuaAPI.rand or function()
    return math.random()
  end

  GameAPI = GameAPI or {}
  UIManager = UIManager or {}
  Enums = Enums or {}
  Enums.BuffState = Enums.BuffState or {}
  if not UIManager.query_nodes_by_name then
    UIManager.query_nodes_by_name = function(name)
      local node = {
        name = name,
        set_texture_keep_size = function() end,
        set_texture_native_size = function() end,
      }
      return { node }
    end
  end

  if not GameAPI.random_int then
    math.randomseed(1)
    GameAPI.random_int = function(min, max)
      return math.random(min, max)
    end
  end
  if not GameAPI.play_3d_sound then
    GameAPI.play_3d_sound = function(sound_id, ...)
      return sound_id
    end
  end
  if not GameAPI.play_sfx_by_key then
    GameAPI.play_sfx_by_key = function(sfx_key, ...)
      return sfx_key
    end
  end
  if Enums.BuffState.BUFF_FORBID_CONTROL == nil then
    Enums.BuffState.BUFF_FORBID_CONTROL = 32
  end

  TriggerCustomEvent = TriggerCustomEvent or function() end
  logger.set_test_mode(true)
end

function M.refresh_runtime_context_for_tests(opts)
  opts = opts or {}
  local lua_api = {}
  local set_timeout = opts.SetTimeOut or SetTimeOut
  if type(opts.LuaAPI) == "table" then
    for key, value in pairs(opts.LuaAPI) do
      lua_api[key] = value
    end
  elseif type(LuaAPI) == "table" then
    for key, value in pairs(LuaAPI) do
      lua_api[key] = value
    end
  end

  if type(set_timeout) == "function" then
    lua_api.call_delay_time = function(delay, fn)
      return set_timeout(delay, fn)
    end
  elseif type(lua_api.call_delay_time) ~= "function" then
    lua_api.call_delay_time = function(_, fn)
      if fn then
        fn()
        return true
      end
      return false
    end
  end

  local register_custom_event = opts.RegisterCustomEvent or RegisterCustomEvent
  local trigger_custom_event = opts.TriggerCustomEvent or TriggerCustomEvent
  if type(lua_api.global_register_custom_event) ~= "function" and type(register_custom_event) == "function" then
    lua_api.global_register_custom_event = function(event_name, handler)
      return register_custom_event(event_name, handler)
    end
  end
  if type(lua_api.global_send_custom_event) ~= "function" and type(trigger_custom_event) == "function" then
    lua_api.global_send_custom_event = function(event_name, payload)
      return trigger_custom_event(event_name, payload)
    end
  end

  local ctx = runtime_context.new({
    GameAPI = opts.GameAPI or GameAPI,
    LuaAPI = lua_api,
  })
  if type(opts.all_roles) == "table" then
    ctx.roles = opts.all_roles
  elseif type(opts.ALLROLES) == "table" then
    ctx.roles = opts.ALLROLES
  elseif type(all_roles) == "table" then
    ctx.roles = all_roles
  elseif type(ALLROLES) == "table" then
    ctx.roles = ALLROLES
  end
  if type(opts.vehicle_helper) == "table" then
    ctx.vehicle_helper = opts.vehicle_helper
  elseif type(vehicle_helper) == "table" then
    ctx.vehicle_helper = vehicle_helper
  end
  if type(opts.camera_helper) == "table" then
    ctx.camera_helper = opts.camera_helper
  elseif type(camera_helper) == "table" then
    ctx.camera_helper = camera_helper
  end

  runtime_context.install_runtime_helpers(ctx, { install_globals = false })
  runtime_context.set_current(ctx)
  runtime_ports.reset_for_tests()
  runtime_ports.configure(default_ports.build(runtime_context))
  paid_purchase_port.reset_for_tests()
  paid_purchase_port.configure(require("src.host.eggy.paid_purchase_gateway"))
  tip_queue.configure_runtime({
    presenter = function(text, duration)
      local global_api = opts.GlobalAPI or GlobalAPI
      if global_api and type(global_api.show_tips) == "function" then
        return global_api.show_tips(text, duration)
      end
      return false
    end,
    scheduler = function(delay, fn)
      if type(set_timeout) == "function" then
        return set_timeout(delay, fn)
      end
      if fn then
        fn()
        return true
      end
      return false
    end,
    test_mode = logger.is_test_mode(),
  })
  local game_api = opts.GameAPI or GameAPI
  if game_api ~= nil
      and type(game_api.get_timestamp) == "function"
      and type(game_api.get_hour) == "function"
      and type(game_api.get_minute) == "function"
      and type(game_api.get_second) == "function" then
    logger.configure_game_time(game_api)
  else
    logger.reset_time_runtime()
  end
  return ctx
end

return M
