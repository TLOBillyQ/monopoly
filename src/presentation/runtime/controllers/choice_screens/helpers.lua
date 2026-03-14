local choice_support = require("src.presentation.model.choice_support")
local runtime = require("src.presentation.runtime.ui")
local canvas = require("src.presentation.runtime.canvas_coordinator")
local runtime_state = require("src.state.state_access.runtime_state")
local role_context = require("src.presentation.model.role_context")
local ui_controls = require("src.presentation.view.support.ui_controls")

local M = {}

local screen_canvases = {
  player = canvas.CANVAS_PLAYER_CHOICE,
  target = canvas.CANVAS_TARGET_CHOICE,
  remote = canvas.CANVAS_REMOTE_CHOICE,
  secondary_confirm = canvas.CANVAS_SECONDARY_CONFIRM,
}

function M.resolve_canvas_for_screen(screen_key)
  return screen_canvases[screen_key] or canvas.CANVAS_BASE
end

function M.hide_choice_screens(ui)
  for _, screen in pairs(ui.choice_screens or {}) do
    ui_controls.reset_choice_screen(ui, screen)
  end
  ui.choice_active = false
  ui.active_choice_screen_key = nil
end

function M.resolve_option_id(option)
  return choice_support.resolve_option_id(option)
end

function M.resolve_option_label(option)
  return choice_support.resolve_option_label(option)
end

function M.resolve_option_by_id(choice, option_id)
  return choice_support.resolve_option_by_id(choice, option_id)
end

function M.resolve_option_label_by_id(choice, option_id)
  return choice_support.resolve_option_label_by_id(choice, option_id)
end

function M.is_under_option(option)
  return choice_support.is_under_option(option)
end

function M.set_option_node(ui, node_name, option)
  local option_id = M.resolve_option_id(option)
  ui_controls.set_control_state(ui, node_name, {
    visible = option ~= nil,
    touch_enabled = option ~= nil,
  })
  if option ~= nil then
    ui:set_button(node_name, M.resolve_option_label(option))
  end
  return option_id
end

function M.resolve_choice_title(choice, screen_key, selected_option_id)
  if screen_key == "secondary_confirm" then
    return M.resolve_secondary_confirm_title(choice, nil, screen_key, selected_option_id)
  end
  return choice and choice.title or "请选择"
end

function M.resolve_secondary_confirm_title(choice, _game, _source_screen, option_id)
  return choice_support.resolve_secondary_confirm_title(choice, _game, _source_screen, option_id)
end

function M.resolve_secondary_confirm_body(choice, _game, _source_screen, option_id, option_label)
  return choice_support.resolve_secondary_confirm_body(choice, _game, _source_screen, option_id, option_label)
end

function M.build_secondary_confirm_body(choice, game, selected_option_id)
  return choice_support.build_secondary_confirm_body(choice, game, selected_option_id)
end

function M.uses_item_slots(choice)
  return choice_support.uses_item_slots(choice)
end

function M.requires_item_slot_pre_confirm(choice)
  return choice_support.requires_item_slot_pre_confirm(choice)
end

function M.switch_modal_canvas(state, target_canvas)
  local ui = state.ui
  runtime.for_each_role_or_global(function(role)
    local current_model = runtime_state.get_ui_model(state)
    local ctx = role_context.resolve(role, current_model, { runtime = runtime })
    local canvas_target = ctx.can_operate == true and target_canvas or canvas.CANVAS_BASE
    if role then
      canvas.switch_for_role(ui, canvas_target, role)
    else
      canvas.switch(ui, canvas_target)
    end
  end)
  runtime.set_client_role(nil)
end

function M.resolve_screen_key(choice)
  return choice_support.resolve_screen_key(choice)
end

return M
