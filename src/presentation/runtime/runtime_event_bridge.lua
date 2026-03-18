local monopoly_event = require("src.core.events.monopoly_events")
local runtime_context = require("src.host.eggy.context")
local landing_visual_hold = require("src.ui.runtime.landing_visual_hold")
local runtime_event_ports = require("src.presentation.runtime.ports.events")

local M = {}

function M.install(state, get_current_game)
  assert(state ~= nil, "missing state")
  assert(type(get_current_game) == "function", "missing get_current_game")
  local runtime_ctx = runtime_context.current()
  local lua_api = runtime_ctx and runtime_ctx.env and runtime_ctx.env.LuaAPI or nil
  assert(lua_api and type(lua_api.global_register_custom_event) == "function", "missing LuaAPI.global_register_custom_event")

  local function _dispatch_or_defer(event_name, data, handler)
    local current_game = get_current_game()
    state.game = current_game
    landing_visual_hold.sync_state_from_game(state, current_game)
    if landing_visual_hold.is_active_state(state) and not landing_visual_hold.is_flushing_state(state) then
      landing_visual_hold.defer_runtime_event(state, event_name, data, function(payload)
        handler(payload)
      end)
      return
    end
    handler(data)
  end

  lua_api.global_register_custom_event(monopoly_event.land.tile_upgraded, function(_, _, data)
    _dispatch_or_defer(monopoly_event.land.tile_upgraded, data, function(payload)
      runtime_event_ports.on_tile_upgraded(state, payload)
    end)
  end)

  lua_api.global_register_custom_event(monopoly_event.intent.need_choice, function(_, _, data)
    _dispatch_or_defer(monopoly_event.intent.need_choice, data, function(payload)
      runtime_event_ports.on_need_choice(state, get_current_game, payload)
    end)
  end)
end

return M
