local logger = require("src.foundation.log")
local tip_queue = require("src.foundation.tips")
local runtime_context = require("src.host.context")
local default_ports = require("src.host.default_ports")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local achievement_progress_port = require("src.rules.ports.achievement_progress")
local share_panel_port = require("src.foundation.ports.share_panel")
local host_share_panel = require("src.host.share_panel")
local host_runtime_impl = require("src.host")

-- ui 宿主能力 port 基线（#250）：镜像 app/host_install.lua 装配，
-- impl 是 src.host 表本身且槽位按名调用时查表，spec 对 src.host 字段的 patch
-- 因此保持可截获。清单单一真源见 host_ports（#251）。
local ui_host_port_slots = require("src.ui.seams.host_ports")
local screen_openers_port = require("src.ui.seams.screen_openers")
local resolver_seam = require("src.ui.seams.local_actor_resolver")

local M = {}

-- 共享全局 RNG 的统一默认种子。behavior 套共用单条 math.random 序列,套件级
-- before_each(test/helper.lua)每例按此重播,令进入每例的 RNG 状态与此前消耗无关。
-- 收敛原先散落在三处 band-aid 与 install_defaults() 里的魔法字面量 1(#45/#46)。
M.DEFAULT_SEED = 1

-- 把共享全局 RNG 重播到 DEFAULT_SEED。单一入口,取代逐 spec 硬编码 randomseed(1)。
function M.reseed_defaults()
  math.randomseed(M.DEFAULT_SEED)
end

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
    M.reseed_defaults()
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
  paid_purchase_port.configure(require("src.host.paid_purchase_gateway"))
  achievement_progress_port.reset_for_tests()
  -- #463:share_panel 纯契约 port 基线,镜像 host_install 装配(闭包调用时读
  -- 实现模块字段,spec 对 src.host.share_panel 字段的 patch 保持可截获)。
  share_panel_port.reset_for_tests()
  share_panel_port.configure({
    try_show = function(...) return host_share_panel.try_show(...) end,
  })
  for _, port in ipairs(ui_host_port_slots) do
    port.reset_for_tests()
    port.configure(host_runtime_impl)
  end
  -- #332:local_actor_resolver 接缝基线,镜像 host_install 装配(闭包调用时
  -- 读实现模块字段,spec 对实现模块字段的 patch 保持可截获)。
  resolver_seam.reset_for_tests()
  resolver_seam.configure(require("src.ui.render.support.local_actor_resolver"))
  -- #332:screen_openers 接缝基线,镜像 host_install 装配。thunk 在调用时惰性
  -- require 屏模块并读字段(屏是 require 时自注册的深模块,基线不得提前装载
  -- 扰乱 registry;字段读在调用时,spec 对屏模块字段的 patch 保持可截获)。
  screen_openers_port.reset_for_tests()
  screen_openers_port.configure({
    open_secondary_confirm = function(...)
      return require("src.ui.screens.secondary_confirm").open(...)
    end,
    open_pre_confirm = function(...)
      return require("src.ui.screens.secondary_confirm").open_pre_confirm(...)
    end,
    open_item_phase_pre_confirm = function(...)
      return require("src.ui.screens.secondary_confirm").open_item_phase_pre_confirm(...)
    end,
    refresh_secondary_confirm_copy = function(...)
      return require("src.ui.screens.secondary_confirm").refresh_copy(...)
    end,
    open_market = function(...)
      return require("src.ui.screens.market").open(...)
    end,
    close_market = function(...)
      return require("src.ui.screens.market").close(...)
    end,
  })
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
