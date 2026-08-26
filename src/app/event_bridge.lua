local monopoly_event = require("src.foundation.events")
local host_runtime = require("src.host.init")
local landing_visual_hold = require("src.ui.visual_hold")
local runtime_event_ports = require("src.ui.ports.events")

local M = {}
local registered_triggers = {}

function M.install(state, get_current_game)
  assert(state ~= nil, "missing state")
  assert(type(get_current_game) == "function", "missing get_current_game")
  if #registered_triggers > 0 then
    return
  end

  local function _dispatch_or_defer(data, handler)
    local current_game = get_current_game()
    state.game = current_game
    landing_visual_hold.run_or_defer(state, nil, "runtime_event", function()
      handler(data)
    end)
  end

  -- 走 host seam 注册:宿主 LuaAPI 的取用与函数存在性校验归 src.host.init 独有,
  -- app 层不再自己穿 runtime ctx -> env -> LuaAPI(ui 侧对应面是 src.ui.seams.host_events)。
  local function _register_event(event_name, handler_fn)
    local registered, trigger = host_runtime.register_custom_event(event_name, function(_, _, data)
      _dispatch_or_defer(data, handler_fn)
    end)
    assert(registered, "missing LuaAPI.global_register_custom_event")
    registered_triggers[#registered_triggers + 1] = trigger
  end

  local ok, err = pcall(function()
    _register_event(monopoly_event.land.tile_upgraded, function(payload)
      runtime_event_ports.on_tile_upgraded(state, payload)
    end)

    _register_event(monopoly_event.intent.need_choice, function(payload)
      runtime_event_ports.on_need_choice(state, get_current_game, payload)
    end)
  end)
  if not ok then
    M.uninstall()
    error(err, 0)
  end
end

function M.uninstall()
  for index = #registered_triggers, 1, -1 do
    host_runtime.unregister_custom_event(registered_triggers[index])
    registered_triggers[index] = nil
  end
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=b80434a26c986234
scope.0.id=chunk:src/app/event_bridge.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=57
scope.0.semanticHash=3f6df5b2a0f3bb7b
scope.1.id=function:M.install
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=47
scope.1.semanticHash=4cab48b090f67826
scope.2.id=function:_dispatch_or_defer
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=22
scope.2.semanticHash=2c427660cbc2bbac
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=21
scope.3.semanticHash=600a75ce96a391b3
scope.4.id=function:_register_event
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=32
scope.4.semanticHash=af9bc6a4ba9aaf05
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=27
scope.5.endLine=29
scope.5.semanticHash=2626f9581e274a3b
scope.6.id=function:<anonymous>#3
scope.6.kind=function
scope.6.startLine=34
scope.6.endLine=42
scope.6.semanticHash=1dc304f9039eb1ab
scope.7.id=function:<anonymous>#4
scope.7.kind=function
scope.7.startLine=35
scope.7.endLine=37
scope.7.semanticHash=4bb2db60adbd91f3
scope.8.id=function:<anonymous>#5
scope.8.kind=function
scope.8.startLine=39
scope.8.endLine=41
scope.8.semanticHash=11e97ffd44326f60
scope.9.id=function:M.uninstall
scope.9.kind=function
scope.9.startLine=49
scope.9.endLine=54
scope.9.semanticHash=3fd07671ed3f16ab
]]
