local monopoly_event = require("src.core.events.monopoly_events")
local ui_view = require("src.presentation.runtime.view_service")
local runtime_state = require("src.core.state_access.runtime_state")
local runtime_context = require("src.infrastructure.runtime.runtime_context")
local choice_slice = require("src.presentation.model.model.choice_slice")

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

  lua_api.global_register_custom_event(monopoly_event.land.tile_upgraded, function(_, _, data)
    if data and data.tile_id and data.level and state.on_tile_upgraded then
      state:on_tile_upgraded(data.tile_id, data.level)
    end
  end)

  lua_api.global_register_custom_event(monopoly_event.intent.need_choice, function(_, _, data)
    local choice = data and data.choice or nil
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
      ui_view.open_choice_modal(state, built_choice, built_market)
    end
  end)
end

return M
