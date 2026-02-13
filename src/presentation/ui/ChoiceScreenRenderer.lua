local modal_state = require("src.presentation.interaction.UIModalStateCoordinator")
local route_policy = require("src.presentation.interaction.UIChoiceRoutePolicy")
local runtime = require("src.presentation.api.UIRuntimePort")
local canvas = require("src.presentation.interaction.UICanvasCoordinator")
local ui_nodes = require("src.presentation.shared.UINodes")

local renderer = {}

local function _resolve_canvas_for_screen(screen_key)
  if screen_key == "player" then
    return canvas.CANVAS_PLAYER_CHOICE
  end
  if screen_key == "target" then
    return canvas.CANVAS_TARGET_CHOICE
  end
  if screen_key == "remote" then
    return canvas.CANVAS_REMOTE_CHOICE
  end
  if screen_key == "building" then
    return canvas.CANVAS_BUILDING_CHOICE
  end
  return canvas.CANVAS_BASE
end

local function _hide_choice_screens(ui)
  local screens = ui.choice_screens or {}
  for _, screen in pairs(screens) do
    if screen.root then
      ui:set_visible(screen.root, false)
    end
    local buttons = screen.option_buttons or {}
    for _, name in ipairs(buttons) do
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

local function _resolve_option_id(option)
  if type(option) == "table" then
    return option.id
  end
  return option
end

local function _resolve_option_label(option)
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

local function _is_under_option(option)
  local label = _resolve_option_label(option)
  if not label then
    return false
  end
  return string.find(label, "脚下", 1, true) ~= nil
    or string.find(label, "当前位置", 1, true) ~= nil
end

local function _set_option_node(ui, node_name, option)
  if option then
    ui:set_button(node_name, _resolve_option_label(option))
    ui:set_visible(node_name, true)
    ui:set_touch_enabled(node_name, true)
    return _resolve_option_id(option)
  end
  ui:set_visible(node_name, false)
  ui:set_touch_enabled(node_name, false)
  return nil
end

local function _resolve_choice_title(choice, screen_key, selected_option_id)
  if screen_key == "building" then
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

local function _switch_modal_canvas(state, target_canvas)
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

function renderer.open_choice_modal(state, choice, market)
  local screen_key = route_policy.resolve(choice)
  if screen_key == "market" then
    return false
  end
  if screen_key == "player" or screen_key == "remote" then
    renderer.open_player_or_remote_screen(state, choice, choice.id, screen_key)
    return true
  end
  if screen_key == "building" then
    renderer.open_building_screen(state, choice, choice.id)
    return true
  end
  renderer.open_target_screen(state, choice, choice.id)
  return true
end

function renderer.open_player_or_remote_screen(state, choice, choice_id, screen_key)
  local ui = state.ui
  local screen = ui.choice_screens[screen_key]
  assert(screen ~= nil, "missing choice screen: " .. tostring(screen_key))

  _hide_choice_screens(ui)
  _switch_modal_canvas(state, _resolve_canvas_for_screen(screen_key))
  ui:set_visible(screen.root, true)

  if screen.title then
    ui:set_label(screen.title, choice.title or "请选择")
  end
  if screen.body then
    ui:set_label(screen.body, choice.body or "")
  end

  local option_ids = {}
  local selected = nil
  local options = choice.options or {}
  for index, name in ipairs(screen.option_buttons or {}) do
    local option = options[index]
    local option_id = _set_option_node(ui, name, option)
    option_ids[index] = option_id
    if not selected and option_id ~= nil then
      selected = option_id
    end
  end

  if screen.confirm then
    ui:set_button(screen.confirm, "确定")
    ui:set_visible(screen.confirm, true)
    ui:set_touch_enabled(screen.confirm, true)
  end

  if screen.cancel then
    local allow_cancel = choice.allow_cancel ~= false
    ui:set_visible(screen.cancel, allow_cancel)
    ui:set_touch_enabled(screen.cancel, allow_cancel)
    if allow_cancel then
      ui:set_button(screen.cancel, choice.cancel_label or "取消")
    end
  end

  ui.choice_active = true
  ui.active_choice_screen_key = screen_key
  modal_state.open_choice(state, choice_id, option_ids, selected)
end

function renderer.open_target_screen(state, choice, choice_id)
  local ui = state.ui
  local screen = ui.choice_screens.target
  assert(screen ~= nil, "missing target screen")

  _hide_choice_screens(ui)
  _switch_modal_canvas(state, canvas.CANVAS_TARGET_CHOICE)
  ui:set_visible(screen.root, true)

  ui:set_label(screen.title, choice.title or "请选择")
  ui:set_label(screen.body, choice.body or "")

  local non_under = {}
  local under = nil
  for _, option in ipairs(choice.options or {}) do
    if _is_under_option(option) and under == nil then
      under = option
    else
      non_under[#non_under + 1] = option
    end
  end

  local option_ids = {}
  local selected = nil
  local flat_index = 0
  for _, name in ipairs(screen.option_buttons or {}) do
    flat_index = flat_index + 1
    local option = non_under[flat_index]
    local option_id = _set_option_node(ui, name, option)
    option_ids[flat_index] = option_id
    if not selected and option_id ~= nil then
      selected = option_id
    end
  end

  if screen.under_button then
    flat_index = flat_index + 1
    local under_id = _set_option_node(ui, screen.under_button, under)
    option_ids[flat_index] = under_id
    if not selected and under_id ~= nil then
      selected = under_id
    end
  end

  if screen.confirm then
    ui:set_button(screen.confirm, "确定")
    ui:set_visible(screen.confirm, true)
    ui:set_touch_enabled(screen.confirm, true)
  end

  local allow_cancel = choice.allow_cancel ~= false
  ui:set_visible(screen.cancel, allow_cancel)
  ui:set_touch_enabled(screen.cancel, allow_cancel)
  if allow_cancel then
    ui:set_button(screen.cancel, choice.cancel_label or "取消")
  end

  ui.choice_active = true
  ui.active_choice_screen_key = "target"
  modal_state.open_choice(state, choice_id, option_ids, selected)
end

function renderer.open_building_screen(state, choice, choice_id)
  local ui = state.ui
  local screen = ui.choice_screens.building
  assert(screen ~= nil, "missing building screen")

  _hide_choice_screens(ui)
  _switch_modal_canvas(state, canvas.CANVAS_BUILDING_CHOICE)
  ui:set_visible(screen.root, true)

  local first_option = choice.options and choice.options[1] or nil
  local selected = _resolve_option_id(first_option)
  local title = _resolve_choice_title(choice, "building", selected)
  ui:set_label(screen.title, title)
  if screen.body then
    ui:set_label(screen.body, choice.body or "")
  end

  ui:set_button(screen.confirm, "")
  ui:set_visible(screen.confirm, true)
  ui:set_touch_enabled(screen.confirm, selected ~= nil)

  local allow_cancel = choice.allow_cancel ~= false
  ui:set_visible(screen.cancel, allow_cancel)
  ui:set_touch_enabled(screen.cancel, allow_cancel)
  if allow_cancel then
    ui:set_button(screen.cancel, "")
  end

  ui.choice_active = true
  ui.active_choice_screen_key = "building"
  modal_state.open_choice(state, choice_id, { selected }, selected)
end

function renderer.select_choice_option(state, option_id)
  if not option_id then
    return
  end
  modal_state.select_choice_option(state, option_id)
  local ui = state and state.ui
  if not ui then
    return
  end
  if ui.active_choice_screen_key == "building" then
    local screen = ui.choice_screens and ui.choice_screens.building or nil
    local choice = state.ui_model and state.ui_model.choice or nil
    if screen and screen.title then
      ui:set_label(screen.title, _resolve_choice_title(choice, "building", option_id))
    end
  end
end

function renderer.hide_choice_screens(ui)
  _hide_choice_screens(ui)
end

function renderer.resolve_screen_key(choice)
  return route_policy.resolve(choice)
end

function renderer.resolve_canvas_for_screen(screen_key)
  return _resolve_canvas_for_screen(screen_key)
end

return renderer
