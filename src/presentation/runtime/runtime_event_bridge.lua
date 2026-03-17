local monopoly_event = require("src.core.events.monopoly_events")
local modal_controller = require("src.ui.ctl.modal_controller")
local runtime_state = require("src.state.state_access.runtime_state")
local runtime_context = require("src.host.eggy.context")
local choice_slice = require("src.ui.pres.choice_slice")
local landing_visual_hold = require("src.state.state_access.landing_visual_hold")

local M = {}

local function _build_choice_view(state, current_game)
  local choice, market = choice_slice.build_choice_and_market(current_game, {
    game = current_game,
  }, state.ui)
  return choice, market
end

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
      if payload and payload.tile_id and state.on_board_visual_sync then
        state:on_board_visual_sync({
          tile_ids = { payload.tile_id },
        })
      end
    end)
  end)

  lua_api.global_register_custom_event(monopoly_event.intent.need_choice, function(_, _, data)
    _dispatch_or_defer(monopoly_event.intent.need_choice, data, function(payload)
      local choice = payload and payload.choice or nil
      if not choice then
        return
      end
      runtime_state.set_pending_choice(state, choice, {
        choice_id = choice.id,
        elapsed_seconds = 0,
      })
      runtime_state.set_ui_dirty(state, true)
      local current_game = get_current_game()
      assert(current_game ~= nil, "missing current_game")
      local built_choice, built_market = _build_choice_view(state, current_game)
      if built_choice then
        modal_controller.open_choice_modal(state, built_choice, built_market)
      end
    end)
  end)
end

return M
