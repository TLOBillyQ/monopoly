local route_policy = require("src.presentation.input.ui_choice_route_policy")
local runtime = require("src.presentation.runtime.ui_runtime_port")
local canvas = require("src.presentation.input.ui_canvas_coordinator")
local runtime_state = require("src.core.state_access.runtime_state")
local role_context = require("src.presentation.model.ui_role_context")
local ui_controls = require("src.presentation.view.support.ui_controls")

local M = {}

local screen_canvases = {
  player = canvas.CANVAS_PLAYER_CHOICE,
  target = canvas.CANVAS_TARGET_CHOICE,
  remote = canvas.CANVAS_REMOTE_CHOICE,
  secondary_confirm = canvas.CANVAS_SECONDARY_CONFIRM,
}

local function _find_option(choice, predicate)
  local options = choice and choice.options or nil
  if type(options) ~= "table" then
    return nil
  end
  for _, option in ipairs(options) do
    local option_id = type(option) == "table" and option.id or option
    if predicate(option, option_id) then
      return option, option_id
    end
  end
  return nil
end

local function _fallback_confirm_body(option_label)
  if option_label and option_label ~= "" then
    return "你选的是：" .. tostring(option_label)
  end
  return "请再确认一次"
end

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
  return type(option) == "table" and option.id or option
end

function M.resolve_option_label(option)
  if type(option) == "table" then
    return option.label or (option.id ~= nil and tostring(option.id)) or tostring(option)
  end
  return tostring(option)
end

function M.resolve_option_by_id(choice, option_id)
  if not choice or option_id == nil then
    return nil
  end
  local option = _find_option(choice, function(_, current_option_id)
    return current_option_id == option_id
  end)
  return type(option) == "table" and option or nil
end

function M.resolve_option_label_by_id(choice, option_id)
  local option, matched_option_id = _find_option(choice, function(_, current_option_id)
    return current_option_id == option_id
  end)
  if option == nil then
    return nil
  end
  return type(option) == "table" and option.label or tostring(matched_option_id)
end

function M.is_under_option(option)
  local label = M.resolve_option_label(option)
  return label ~= nil and (
    string.find(label, "脚下", 1, true) ~= nil
    or string.find(label, "当前位置", 1, true) ~= nil
  )
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
  local option = M.resolve_option_by_id(choice, option_id)
  if option and type(option.confirm_title) == "string" and option.confirm_title ~= "" then
    return option.confirm_title
  end
  if choice and type(choice.confirm_title) == "string" and choice.confirm_title ~= "" then
    return choice.confirm_title
  end
  return "请确认"
end

function M.resolve_secondary_confirm_body(choice, _game, _source_screen, option_id, option_label)
  if not choice then
    return _fallback_confirm_body(option_label)
  end

  local option = M.resolve_option_by_id(choice, option_id)
  if option and type(option.confirm_body) == "string" and option.confirm_body ~= "" then
    return option.confirm_body
  end
  if type(choice.confirm_body) == "string" and choice.confirm_body ~= "" then
    return choice.confirm_body
  end
  return _fallback_confirm_body(option_label or M.resolve_option_label_by_id(choice, option_id))
end

function M.build_secondary_confirm_body(choice, game, selected_option_id)
  return M.resolve_secondary_confirm_body(
    choice,
    game,
    "secondary_confirm",
    selected_option_id,
    M.resolve_option_label_by_id(choice, selected_option_id)
  )
end

function M.resolve_pre_confirm_title(choice, source_screen)
  return M.resolve_secondary_confirm_title(choice, nil, source_screen, nil)
end

function M.resolve_pre_confirm_body(option_label, choice, game, source_screen, option_id)
  if choice then
    return M.resolve_secondary_confirm_body(choice, game, source_screen, option_id, option_label)
  end
  return _fallback_confirm_body(option_label)
end

function M.uses_item_slots(choice)
  return choice ~= nil and choice.uses_item_slots == true
end

function M.requires_item_slot_pre_confirm(choice)
  return choice ~= nil and choice.pre_confirm_before_slot_pick == true
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
  return route_policy.resolve(choice)
end

return M
