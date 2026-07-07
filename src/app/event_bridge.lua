local monopoly_event = require("src.foundation.events")
local runtime_context = require("src.host.context")
local landing_visual_hold = require("src.ui.visual_hold")
local runtime_event_ports = require("src.ui.ports.events")

local M = {}

function M.install(state, get_current_game)
  assert(state ~= nil, "missing state")
  assert(type(get_current_game) == "function", "missing get_current_game")
  local runtime_ctx = runtime_context.current()
  local lua_api = runtime_ctx and runtime_ctx.env and runtime_ctx.env.LuaAPI or nil
  assert(lua_api and type(lua_api.global_register_custom_event) == "function", "missing LuaAPI.global_register_custom_event")

  local function _dispatch_or_defer(data, handler)
    local current_game = get_current_game()
    state.game = current_game
    landing_visual_hold.run_or_defer(state, nil, "runtime_event", function()
      handler(data)
    end)
  end

  local function _register_event(event_name, handler_fn)
    lua_api.global_register_custom_event(event_name, function(_, _, data)
      _dispatch_or_defer(data, handler_fn)
    end)
  end

  _register_event(monopoly_event.land.tile_upgraded, function(payload)
    runtime_event_ports.on_tile_upgraded(state, payload)
  end)

  _register_event(monopoly_event.intent.need_choice, function(payload)
    runtime_event_ports.on_need_choice(state, get_current_game, payload)
  end)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=6acdba24819488fc
scope.0.id=chunk:src/app/event_bridge.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=39
scope.0.semanticHash=c0e0dbbda9dbcfb9
scope.0.lastMutatedAt=2026-07-07T04:23:05Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=4
scope.0.lastMutationKilled=4
scope.1.id=function:anonymous@18:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=20
scope.1.semanticHash=2083a5b997d7b260
scope.2.id=function:_dispatch_or_defer:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=21
scope.2.semanticHash=3059480c7a29ce20
scope.2.lastMutatedAt=2026-07-07T04:23:05Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=2
scope.2.lastMutationKilled=2
scope.3.id=function:anonymous@24:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=26
scope.3.semanticHash=0c7482ea6488692d
scope.4.id=function:_register_event:23
scope.4.kind=function
scope.4.startLine=23
scope.4.endLine=27
scope.4.semanticHash=03748623048ce18d
scope.4.lastMutatedAt=2026-07-07T04:23:05Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:anonymous@29:29
scope.5.kind=function
scope.5.startLine=29
scope.5.endLine=31
scope.5.semanticHash=de4f86e17a9880b0
scope.6.id=function:anonymous@33:33
scope.6.kind=function
scope.6.startLine=33
scope.6.endLine=35
scope.6.semanticHash=ee4cccf7aba03a84
scope.7.id=function:M.install:8
scope.7.kind=function
scope.7.startLine=8
scope.7.endLine=36
scope.7.semanticHash=9c5a4306526f7709
scope.7.lastMutatedAt=2026-07-07T04:23:05Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=9
scope.7.lastMutationKilled=9
]]
