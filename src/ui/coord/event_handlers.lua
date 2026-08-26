-- 自定义事件处理器装配(>100 mutation sites 拆分):结算面板 endgame_result_panels /
-- 棋盘反馈 cue board_feedback_handlers / 市场提示 market_tip_handlers 各自成模块,
-- 本文件保留安装核心(注册闭包 + 分发/延迟)与惰性装载时序。
local monopoly_event = require("src.foundation.events")
local host_events = require("src.ui.seams.host_events")
local landing_visual_hold = require("src.ui.visual_hold")
local endgame_result_panels = require("src.ui.coord.endgame_result_panels")
local board_feedback_handlers = require("src.ui.coord.board_feedback_handlers")
local market_tip_handlers = require("src.ui.coord.market_tip_handlers")
local tile_index_handlers = require("src.ui.coord.tile_index_handlers")

local event_handlers = {}
local context = { installed = false, state = nil }

function event_handlers.install(_, logger, state)
  context.state = state
  endgame_result_panels.set_context(logger, state)
  board_feedback_handlers.set_context(state)
  tile_index_handlers.set_context(state)

  if context.installed then
    return
  end
  context.installed = true

  local function _dispatch_or_defer(data, handler)
    local current_state = context.state
    if current_state == nil then
      return handler(data)
    end
    local result = nil
    landing_visual_hold.run_or_defer(current_state, nil, "runtime_event", function()
      result = handler(data)
    end)
    return result
  end

  -- handlers_by_event 登记簿已删(#262):写后无任何读者(纯记账),
  -- `#list + 1` 的下标变异不可杀;注册行为本身由 host_events 承担。
  local function _register_handler(event_name, handler)
    host_events.register_custom_event(event_name, function(_, _, data)
      return _dispatch_or_defer(data, handler)
    end)
  end

  pcall(require, "src.ui.render.anim")

  tile_index_handlers.install(_register_handler, monopoly_event)
  board_feedback_handlers.install(_register_handler, monopoly_event)
  market_tip_handlers.install(_register_handler, monopoly_event)
  endgame_result_panels.install(_register_handler, monopoly_event)
end

return event_handlers

--[[ mutate4lua-manifest
version=4
projectHash=37669d69c6691620
scope.0.id=chunk:src/ui/coord/event_handlers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=55
scope.0.semanticHash=e9ccac8f103617f8
scope.1.id=function:event_handlers.install
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=52
scope.1.semanticHash=acb97a7200c28be2
scope.2.id=function:_dispatch_or_defer
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=36
scope.2.semanticHash=0c5e385001349e6e
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=34
scope.3.semanticHash=149ac28041462fed
scope.4.id=function:_register_handler
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=44
scope.4.semanticHash=1f1c0dffa6dcbe5c
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=43
scope.5.semanticHash=3c26bf1ea8e4b724
]]
