local route_policy = require("src.presentation.interaction.UIChoiceRoutePolicy")
local runtime = require("src.presentation.api.UIRuntimePort")
local canvas = require("src.presentation.interaction.UICanvasCoordinator")

local M = {}

function M.resolve_canvas_for_screen(screen_key)
  if screen_key == "player" then
    return canvas.CANVAS_PLAYER_CHOICE
  end
  if screen_key == "target" then
    return canvas.CANVAS_TARGET_CHOICE
  end
  if screen_key == "remote" then
    return canvas.CANVAS_REMOTE_CHOICE
  end
  if screen_key == "secondary_confirm" then
    return canvas.CANVAS_SECONDARY_CONFIRM
  end
  return canvas.CANVAS_BASE
end

function M.hide_choice_screens(ui)
  local screens = ui.choice_screens or {}
  for _, screen in pairs(screens) do
    if screen.root then
      ui:set_visible(screen.root, false)
    end
    local buttons = screen.option_buttons or {}
    for _, name in ipairs(buttons) do
      ui:set_touch_enabled(name, false)
    end
    local labels = screen.slot_labels or {}
    for _, name in ipairs(labels) do
      ui:set_visible(name, false)
      ui:set_touch_enabled(name, false)
    end
    local projections = screen.slot_projections or {}
    for _, name in ipairs(projections) do
      ui:set_visible(name, false)
      ui:set_touch_enabled(name, false)
    end
    if screen.under_button then
      ui:set_visible(screen.under_button, false)
      ui:set_touch_enabled(screen.under_button, false)
    end
  end
  ui.choice_active = false
  ui.active_choice_screen_key = nil
end

function M.resolve_option_id(option)
  if type(option) == "table" then
    return option.id
  end
  return option
end

function M.resolve_option_label(option)
  if type(option) == "table" then
    if option.label then
      return option.label
    end
    if option.id ~= nil then
      return tostring(option.id)
    end
  end
  return tostring(option)
end

function M.is_under_option(option)
  local label = M.resolve_option_label(option)
  if not label then
    return false
  end
  return string.find(label, "脚下", 1, true) ~= nil
    or string.find(label, "当前位置", 1, true) ~= nil
end

function M.set_option_node(ui, node_name, option)
  if option then
    ui:set_button(node_name, M.resolve_option_label(option))
    ui:set_visible(node_name, true)
    ui:set_touch_enabled(node_name, true)
    return M.resolve_option_id(option)
  end
  ui:set_visible(node_name, false)
  ui:set_touch_enabled(node_name, false)
  return nil
end

function M.resolve_choice_title(choice, screen_key, selected_option_id)
  if screen_key == "secondary_confirm" then
    if selected_option_id == "buy_land" then
      return "购买地块"
    end
    if selected_option_id == "upgrade_land" then
      return "加盖建筑"
    end
    if choice and choice.title and choice.title ~= "" then
      return choice.title
    end
    return "地产操作"
  end
  if choice and choice.title then
    return choice.title
  end
  return "请选择"
end

local function _resolve_confirm_action_label(selected_option_id)
  if selected_option_id == "buy_land" then
    return "购买"
  end
  if selected_option_id == "upgrade_land" then
    return "加盖"
  end
  return nil
end

function M.build_secondary_confirm_body(choice, game, selected_option_id)
  if not choice or not route_policy.is_secondary_confirm_choice(choice) then
    return choice and choice.body or ""
  end
  local action_label = _resolve_confirm_action_label(selected_option_id)
  if not action_label then
    return choice.body or ""
  end
  local meta = choice.meta or {}
  local tile_id = meta.tile_id
  if not tile_id or not game or not game.board or not game.board.get_tile_by_id then
    return choice.body or ""
  end
  local tile = game.board:get_tile_by_id(tile_id)
  if not tile or not tile.name then
    return choice.body or ""
  end
  return action_label .. " " .. tile.name .. "？"
end

function M.resolve_option_label_by_id(choice, option_id)
  if not choice or not option_id then
    return nil
  end
  local options = choice.options
  if type(options) ~= "table" then
    return nil
  end
  for _, opt in ipairs(options) do
    local id = type(opt) == "table" and opt.id or opt
    if id == option_id then
      return type(opt) == "table" and opt.label or tostring(opt)
    end
  end
  return nil
end

function M.resolve_pre_confirm_title(choice, source_screen)
  if source_screen == "base_inline" or source_screen == nil then
    return "使用道具"
  end
  if choice and choice.title and choice.title ~= "" then
    return choice.title
  end
  return "请确认"
end

function M.resolve_pre_confirm_body(option_label)
  if not option_label or option_label == "" then
    return "确认选择？"
  end
  return "确认选择 " .. tostring(option_label) .. "？"
end

function M.switch_modal_canvas(state, target_canvas)
  local ui = state.ui
  runtime.for_each_role_or_global(function(role)
    local ctx = require("src.presentation.state.UIRoleContext").resolve(role, state.ui_model, { runtime = runtime })
    if ctx.can_operate == true then
      if role then
        canvas.switch_for_role(ui, target_canvas, role)
      else
        canvas.switch(ui, target_canvas)
      end
    else
      if role then
        canvas.switch_for_role(ui, canvas.CANVAS_BASE, role)
      else
        canvas.switch(ui, canvas.CANVAS_BASE)
      end
    end
  end)
  runtime.set_client_role(nil)
end

function M.resolve_screen_key(choice)
  return route_policy.resolve(choice)
end

return M
