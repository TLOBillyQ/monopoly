local choice_ui_state = require("src.ui.ports.ui_sync")._choice_state
local modal = require("src.ui.coord.modal")
local runtime_state = require("src.ui.state.runtime")
local choice_slice = require("src.ui.view.choice_slice")

local runtime_event_ports = {}

local function _build_choice_view(state, current_game)
  local choice, market = choice_slice.build_choice_and_market(current_game, {
    game = current_game,
  }, state.ui)
  return choice, market
end

-- 事件路径开屏：与 ui_sync.model._should_open_choice_modal 的判定保持一致，
-- 避免 AI/托管 owner 与非交互 phase 在事件触达时被强行弹屏（这些场景由 ui_sync
-- reconcile 与 auto_runner 决议负责）。
local function _should_open_modal_for_event(game, state, choice)
  local route_key = choice_ui_state.resolve_route_key(choice)
  if route_key == "base_inline" or route_key == "item_phase_passive" then
    return true
  end
  local gate = choice_ui_state.resolve_gate_state(game, state, choice)
  return gate.expects_ui
end

function runtime_event_ports.on_tile_upgraded(state, payload)
  if payload and payload.tile_id and state.on_board_visual_sync then
    state:on_board_visual_sync({
      tile_ids = { payload.tile_id },
    })
  end
end

function runtime_event_ports.on_need_choice(state, get_current_game, payload)
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
  if built_choice and _should_open_modal_for_event(current_game, state, built_choice) then
    modal.open_choice_modal(state, built_choice, built_market)
  end
end

return runtime_event_ports
