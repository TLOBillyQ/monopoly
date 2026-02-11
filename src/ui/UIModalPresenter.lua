local market_view = require("src.ui.MarketView")
local market_ui = require("src.ui.MarketLayout")
local modal_state = require("src.ui.UIModalStateCoordinator")
local route_policy = require("src.ui.UIChoiceRoutePolicy")
local runtime = require("src.ui.UIRuntimePort")
local canvas = require("src.ui.UICanvasCoordinator")
local logger = require("src.core.Logger")

local modal_presenter = {}

local function _resolve_popup_image_key(state, payload)
  if not payload then
    return nil
  end
  if payload.image_key ~= nil then
    return payload.image_key
  end
  local image_ref = payload.image_ref
  if image_ref == nil then
    return nil
  end
  local refs = state and state.ui_refs or nil
  if not refs then
    return nil
  end
  return refs[tostring(image_ref)] or refs[image_ref]
end

local function _set_popup_card_image(state, payload)
  local ui = state and state.ui
  local popup = ui and ui.popup_screen or nil
  if not ui or not popup or not popup.card then
    return
  end
  local card_name = popup.card
  local card_node = ui.query_node(card_name)
  local image_key = _resolve_popup_image_key(state, payload)
  if image_key ~= nil then
    runtime.set_node_texture_keep_size(card_node, image_key)
    ui:set_visible(card_name, true)
    return
  end
  local refs = state and state.ui_refs or nil
  local empty_key = refs and refs["空"] or nil
  if empty_key ~= nil then
    runtime.set_node_texture_keep_size(card_node, empty_key)
  end
  ui:set_visible(card_name, false)
end

local function _set_popup_dismiss_touch(ui, enabled)
  local popup = ui and ui.popup_screen or nil
  if not popup then
    return
  end
  local nodes = popup.dismiss_nodes
  if type(nodes) ~= "table" then
    return
  end
  for _, name in ipairs(nodes) do
    ui:set_touch_enabled(name, enabled == true)
  end
end

local function _resolve_bankruptcy_text(payload)
  if payload and payload.text and payload.text ~= "" then
    return payload.text
  end
  if payload and payload.reason and payload.reason ~= "" then
    return payload.reason
  end
  if payload and payload.player_name and payload.player_name ~= "" then
    return payload.player_name .. " 破产出局"
  end
  return "破产出局"
end

local function _resolve_bankruptcy_avatar_key(payload)
  if not payload then
    return nil
  end
  if payload.avatar_key ~= nil then
    return payload.avatar_key
  end
  local player_id = payload.player_id
  if not player_id or not GameAPI or not GameAPI.get_role then
    return nil
  end
  local ok, role = pcall(GameAPI.get_role, player_id)
  if not ok or not role or type(role.get_head_icon) ~= "function" then
    return nil
  end
  local ok_icon, icon = pcall(role.get_head_icon)
  if not ok_icon then
    return nil
  end
  return icon
end

local function _set_bankruptcy_avatar_image(state, payload)
  local ui = state and state.ui
  local screen = ui and ui.bankruptcy_screen or nil
  if not ui or not screen or not screen.avatar then
    return
  end
  local avatar_node = ui.query_node(screen.avatar)
  local image_key = _resolve_bankruptcy_avatar_key(payload)
  if image_key ~= nil then
    runtime.set_node_texture_keep_size(avatar_node, image_key)
    ui:set_visible(screen.avatar, true)
    return
  end
  local refs = state and state.ui_refs or nil
  local empty_key = refs and refs["空"] or nil
  if empty_key ~= nil then
    runtime.set_node_texture_keep_size(avatar_node, empty_key)
    ui:set_visible(screen.avatar, true)
    return
  end
  ui:set_visible(screen.avatar, false)
end

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

local function _open_market_panel(state, choice, choice_id, market)
  local ui = state.ui
  canvas.switch(ui, canvas.CANVAS_MARKET)
  _hide_choice_screens(ui)
  local market_payload = market or {
    choice_id = choice_id,
    options = choice.options,
    allow_cancel = choice.allow_cancel,
    cancel_label = choice.cancel_label,
    selected_option_id = state.pending_choice_selected_option_id,
  }
  market_view.refresh_market(state, market_payload)
end

local function _open_player_or_remote_screen(state, choice, choice_id, screen_key)
  local ui = state.ui
  local screen = ui.choice_screens[screen_key]
  assert(screen ~= nil, "missing choice screen: " .. tostring(screen_key))

  if ui.market_active then
    market_view.close_market_panel(state)
  end

  _hide_choice_screens(ui)
  canvas.switch(ui, _resolve_canvas_for_screen(screen_key))
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

local function _open_target_screen(state, choice, choice_id)
  local ui = state.ui
  local screen = ui.choice_screens.target
  assert(screen ~= nil, "missing target screen")

  if ui.market_active then
    market_view.close_market_panel(state)
  end

  _hide_choice_screens(ui)
  canvas.switch(ui, canvas.CANVAS_TARGET_CHOICE)
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

local function _open_building_screen(state, choice, choice_id)
  local ui = state.ui
  local screen = ui.choice_screens.building
  assert(screen ~= nil, "missing building screen")

  if ui.market_active then
    market_view.close_market_panel(state)
  end

  _hide_choice_screens(ui)
  canvas.switch(ui, canvas.CANVAS_BUILDING_CHOICE)
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

function modal_presenter.select_choice_option(state, option_id)
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

function modal_presenter.open_choice_modal(state, choice, market)
  if not choice then
    logger.warn("open_choice_modal missing choice")
    return
  end
  if not choice.id then
    logger.warn("open_choice_modal missing choice id")
    return
  end
  local choice_id = choice.id
  if state.pending_choice_id == choice_id
      and (state.ui.choice_active or state.ui.market_active) then
    return
  end
  state.ui_dirty = true

  if choice.kind == "market_buy" and market_ui.is_panel_ready() then
    _open_market_panel(state, choice, choice_id, market)
    return
  end

  local screen_key = route_policy.resolve(choice)
  if screen_key == "market" then
    _open_market_panel(state, choice, choice_id, market)
    return
  end
  if screen_key == "player" or screen_key == "remote" then
    _open_player_or_remote_screen(state, choice, choice_id, screen_key)
    return
  end
  if screen_key == "building" then
    _open_building_screen(state, choice, choice_id)
    return
  end
  _open_target_screen(state, choice, choice_id)
end

function modal_presenter.close_choice_modal(state)
  local ui = state.ui
  if ui.choice_active then
    local key = ui.active_choice_screen_key
    local screen = key and ui.choice_screens and ui.choice_screens[key] or nil
    if screen and screen.root then
      ui:set_visible(screen.root, false)
    end
    ui.choice_active = false
    ui.active_choice_screen_key = nil
  end
  if ui.market_active then
    market_view.close_market_panel(state)
  end
  modal_state.close_choice(state)
  if ui.popup_active then
    canvas.switch(ui, canvas.CANVAS_POPUP)
  else
    canvas.switch(ui, canvas.CANVAS_BASE)
  end
  state.ui_dirty = true
end

function modal_presenter.push_popup(state, payload)
  assert(payload ~= nil, "missing popup payload")
  local ui = state.ui
  ui.popup_return_canvas = canvas.resolve_popup_return_canvas(ui)
  local kind = payload.kind or "card"
  ui.popup_kind = kind
  if kind == "bankruptcy" then
    local screen = ui.bankruptcy_screen
    canvas.switch(ui, canvas.CANVAS_BANKRUPTCY)
    if screen and screen.text then
      ui:set_label(screen.text, _resolve_bankruptcy_text(payload))
    end
    _set_bankruptcy_avatar_image(state, payload)
    if screen and screen.root then
      ui:set_visible(screen.root, true)
    end
  else
    local popup = ui.popup_screen
    canvas.switch(ui, canvas.CANVAS_POPUP)
    ui:set_label(popup.title, payload.title)
    ui:set_button(popup.confirm, payload.button_text or "确认")
    _set_popup_card_image(state, payload)
    ui:set_visible(popup.root, true)
  end
  _set_popup_dismiss_touch(ui, true)
  modal_state.open_popup(state, payload)
  state.ui_dirty = true
  return true
end

function modal_presenter.close_popup(state)
  local ui = state.ui
  if not (ui and ui.popup_active) then
    logger.warn("close_popup ignored: popup not active")
    return
  end
  local kind = ui.popup_kind or "card"
  if kind == "bankruptcy" then
    local screen = ui.bankruptcy_screen
    if screen and screen.root then
      ui:set_visible(screen.root, false)
    end
    _set_bankruptcy_avatar_image(state, nil)
  else
    ui:set_visible(ui.popup_screen.root, false)
    _set_popup_card_image(state, nil)
  end
  _set_popup_dismiss_touch(ui, false)
  modal_state.close_popup(state)
  ui.popup_kind = nil
  local target = ui.popup_return_canvas
  ui.popup_return_canvas = nil
  canvas.switch(ui, canvas.resolve_canvas_after_popup(ui, target))
  state.ui_dirty = true
end

return modal_presenter
