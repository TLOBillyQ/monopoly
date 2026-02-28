local modal_state = require("src.presentation.interaction.UIModalStateCoordinator")
local canvas = require("src.presentation.interaction.UICanvasCoordinator")
local common = require("src.presentation.ui.choice_screen_service.common")
local logger = require("src.core.Logger")

local M = {}

function M.open_choice_modal(state, choice, market)
  local screen_key = common.resolve_screen_key(choice)
  if screen_key == "base_inline" then
    return false
  end
  if screen_key == "market" then
    return false
  end
  if screen_key == "player" or screen_key == "remote" then
    M.open_player_or_remote_screen(state, choice, choice.id, screen_key)
    return true
  end
  if screen_key == "secondary_confirm" then
    M.open_secondary_confirm_screen(state, choice, choice.id)
    return true
  end
  if screen_key == "target" then
    M.open_target_screen(state, choice, choice.id)
    return true
  end
  logger.warn("unsupported choice screen key:", tostring(screen_key))
  return false
end

function M.open_player_or_remote_screen(state, choice, choice_id, screen_key)
  local ui = state.ui
  local screen = ui.choice_screens[screen_key]
  assert(screen ~= nil, "missing choice screen: " .. tostring(screen_key))

  common.hide_choice_screens(ui)
  common.switch_modal_canvas(state, common.resolve_canvas_for_screen(screen_key))
  ui:set_visible(screen.root, true)

  if screen.title then
    ui:set_label(screen.title, choice.title or "请选择")
  end
  if screen.body then
    ui:set_label(screen.body, choice.body or "")
  end

  local option_ids = {}
  local selected = nil
  local options = {}
  for _, opt in ipairs(choice.options or {}) do
    if opt ~= nil then
      options[#options + 1] = opt
    end
  end
  for index, name in ipairs(screen.option_buttons or {}) do
    local option = options[index]
    local option_id = common.set_option_node(ui, name, option)
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

function M.open_target_screen(state, choice, choice_id)
  local ui = state.ui
  local screen = ui.choice_screens.target
  assert(screen ~= nil, "missing target screen")

  common.hide_choice_screens(ui)
  common.switch_modal_canvas(state, canvas.CANVAS_TARGET_CHOICE)
  ui:set_visible(screen.root, true)

  ui:set_label(screen.title, choice.title or "请选择")
  ui:set_label(screen.body, choice.body or "")

  local non_under = {}
  local under = nil
  for _, option in ipairs(choice.options or {}) do
    if common.is_under_option(option) and under == nil then
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
    local option_id = common.set_option_node(ui, name, option)
    option_ids[flat_index] = option_id
    if not selected and option_id ~= nil then
      selected = option_id
    end
  end

  if screen.under_button then
    flat_index = flat_index + 1
    local under_id = common.set_option_node(ui, screen.under_button, under)
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

  ui.choice_active = true
  ui.active_choice_screen_key = "target"
  modal_state.open_choice(state, choice_id, option_ids, selected)
end

function M.open_secondary_confirm_screen(state, choice, choice_id)
  local ui = state.ui
  local screen = ui.choice_screens.secondary_confirm
  assert(screen ~= nil, "missing secondary_confirm screen")

  common.hide_choice_screens(ui)
  common.switch_modal_canvas(state, canvas.CANVAS_SECONDARY_CONFIRM)
  ui:set_visible(screen.root, true)

  local first_option = choice.options and choice.options[1] or nil
  local selected = common.resolve_option_id(first_option)
  local title = common.resolve_choice_title(choice, "secondary_confirm", selected)
  ui:set_label(screen.title, title)
  if screen.body then
    ui:set_label(screen.body, common.build_secondary_confirm_body(choice, state.game, selected))
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
  ui.active_choice_screen_key = "secondary_confirm"
  modal_state.open_choice(state, choice_id, { selected }, selected)
end

function M.open_pre_confirm_screen(state, choice, option_id, title, body)
  local ui = state.ui
  local screen = ui.choice_screens.secondary_confirm
  assert(screen ~= nil, "missing secondary_confirm screen")

  common.hide_choice_screens(ui)
  common.switch_modal_canvas(state, canvas.CANVAS_SECONDARY_CONFIRM)
  ui:set_visible(screen.root, true)

  ui:set_label(screen.title, title or "请确认")
  if screen.body then
    ui:set_label(screen.body, body or "")
  end

  ui:set_button(screen.confirm, "")
  ui:set_visible(screen.confirm, true)
  ui:set_touch_enabled(screen.confirm, option_id ~= nil)

  ui:set_visible(screen.cancel, true)
  ui:set_touch_enabled(screen.cancel, true)
  if screen.cancel then
    ui:set_button(screen.cancel, "")
  end

  ui.choice_active = true
  ui.active_choice_screen_key = "secondary_confirm"
  modal_state.open_choice(state, choice.id, { option_id }, option_id)
end

return M
