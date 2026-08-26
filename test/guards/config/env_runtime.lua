-- 出生类配置(#176):env_runtime 的项目接线区——src require 与运行时服务刷新全住这里。
-- 机制体 test/env_runtime.lua 只负责 Eggy 宿主全局刷新;项目 ports/服务佐料一律在本文件维护。
require("test.bootstrap")

local logger = require("src.foundation.log")
local tip_queue = require("src.foundation.tips")
local runtime_context = require("src.host.context")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_default_ports = require("src.host.default_ports")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local share_panel_port = require("src.foundation.ports.share_panel")
local host_share_panel = require("src.host.share_panel")

local M = {}

-- refresh_context: 机制体提供的 Eggy 全局刷新回调,ctx 缺失时兜底重建。
function M.refresh_services(refresh_context)
  local ctx = runtime_context.current()
  if ctx == nil or ctx.env == nil then
    return refresh_context()
  end

  runtime_ports.reset_for_tests()
  runtime_ports.configure(runtime_default_ports.build(runtime_context))
  paid_purchase_port.reset_for_tests()
  paid_purchase_port.configure(require("src.host.paid_purchase_gateway"))
  -- #463:share_panel 纯契约 port 基线(未配置时静默降级 false,泄漏无报错,
  -- 故纳入 runtime_baseline_guard 守卫范围;接线镜像 host_install)。
  share_panel_port.reset_for_tests()
  share_panel_port.configure({
    try_show = function(...) return host_share_panel.try_show(...) end,
  })
  tip_queue.clear()
  tip_queue.configure_runtime({
    presenter = function(text, duration)
      if GlobalAPI and type(GlobalAPI.show_tips) == "function" then
        return GlobalAPI.show_tips(text, duration)
      end
      return false
    end,
    scheduler = function(delay, fn)
      if type(SetTimeOut) == "function" then
        return SetTimeOut(delay, fn)
      end
      if fn then
        fn()
        return true
      end
      return false
    end,
    test_mode = logger.is_test_mode(),
  })
  if GameAPI ~= nil
      and type(GameAPI.get_timestamp) == "function"
      and type(GameAPI.get_hour) == "function"
      and type(GameAPI.get_minute) == "function"
      and type(GameAPI.get_second) == "function" then
    logger.configure_game_time(GameAPI)
  else
    logger.reset_time_runtime()
  end
  return ctx
end

return M
