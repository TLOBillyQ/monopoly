local board_view = require("src.presentation.render.BoardView")
local market_view = require("src.presentation.render.MarketView")
local panel_presenter = require("src.presentation.ui.UIPanelPresenter")
local input_lock_policy = require("src.presentation.interaction.UIInputLockPolicy")
local role_control_lock_policy = require("src.presentation.interaction.UIRoleControlLockPolicy")
local modal_presenter = require("src.presentation.ui.UIModalPresenter")
local runtime = require("src.presentation.api.UIRuntimePort")
local logger = require("src.core.Logger")

local ui_view = {}

local function _query_node(name)
  return runtime.query_node(name)
end

local function _set_text(_, name, text)
  local node = _query_node(name)
  node.text = text or ""
end

local function _set_visible(_, name, visible)
  local node = _query_node(name)
  node.visible = visible == true
end

local function _set_touch_enabled(_, name, enabled)
  local node = _query_node(name)
  node.disabled = not enabled
end

local function _set_debug_log(_, text)
  _set_text(nil, "日志", text)
end

local function _set_debug_visible(ui, visible)
  if ui then
    ui.debug_visible = visible == true
  end
  _set_visible(nil, "调试屏", visible)
end

local function _set_item_slot_image(slot_name, image_key)
  assert(slot_name ~= nil, "missing slot name")
  assert(image_key ~= nil, "missing image key for slot: " .. tostring(slot_name))
  local nodes = runtime.query_nodes(slot_name)
  for _, node in ipairs(nodes) do
    runtime.set_node_texture_keep_size(node, image_key)
  end
end

local function _build_choice_screens()
  return {
    player = {
      key = "player",
      root = "玩家选择屏",
      title = "玩家选择_标题",
      body = "玩家选择_副标题",
      option_buttons = {
        "玩家选择_槽位1",
        "玩家选择_槽位2",
        "玩家选择_槽位3",
      },
      cancel = "取消按钮",
    },
    target = {
      key = "target",
      root = "位置选择屏",
      title = "位置_副标题",
      body = "位置_放置文本",
      option_buttons = {
        "位置前1",
        "位置前2",
        "位置前3",
        "位置后1",
        "位置后2",
        "位置后3",
      },
      under_button = "位置脚下",
      cancel = "取消按钮",
    },
    remote = {
      key = "remote",
      root = "遥控骰子屏",
      title = "遥控骰子_标题",
      body = "遥控骰子_正文",
      option_buttons = {
        "遥控骰子_选项_01",
        "遥控骰子_选项_02",
        "遥控骰子_选项_03",
        "遥控骰子_选项_04",
        "遥控骰子_选项_05",
        "遥控骰子_选项_06",
      },
      cancel = "遥控骰子_取消",
    },
    building = {
      key = "building",
      root = "建筑升级屏",
      title = "建筑升级_标题",
      body = "建筑升级_文本",
      confirm = "建筑升级_确定按钮",
      cancel = "建筑升级_取消",
    },
  }
end

function ui_view.build_ui_state()
  local item_slots = {
    "道具槽位1",
    "道具槽位2",
    "道具槽位3",
    "道具槽位4",
    "道具槽位5",
  }
  local base_hidden_nodes = { "行动按钮" }
  for _, name in ipairs(item_slots) do
    table.insert(base_hidden_nodes, name)
  end
  return {
    auto_play = false,
    auto_interval = 0.1,
    input_blocked = false,
    role_control_lock = { by_role = {}, warn_once = {} },
    debug_visible = false,
    debug_log_enabled_override = nil,
    debug_toggle_first_click_timestamp = nil,
    debug_toggle_click_count = 0,
    item_slots = item_slots,
    base_hidden_nodes = base_hidden_nodes,
    base_hidden_labels = {},
    auto_control_nodes = { "托管按钮", "托管_文本" },
    market_active = false,
    choice_active = false,
    active_choice_screen_key = nil,
    choice_screens = _build_choice_screens(),
    popup_screen = {
      root = "卡牌展示屏",
      title = "卡牌展示_标题",
      confirm = "取消按钮",
      card = "卡牌展示_图片",
      dismiss_nodes = { "卡牌展示_灰底", "卡牌展示_图片" },
    },
    bankruptcy_screen = {
      root = "破产展示屏",
      text = "破产_文字",
      avatar = "破产玩家头像",
    },
    popup_kind = nil,
    popup_seq = 0,
    popup_return_canvas = nil,
    item_slot_item_ids_by_role = {},
    query_node = _query_node,
    set_label = _set_text,
    set_button = _set_text,
    set_visible = _set_visible,
    set_touch_enabled = _set_touch_enabled,
    set_debug_log = _set_debug_log,
    set_debug_visible = _set_debug_visible,
  }
end

function ui_view.init_ui_assets(state)
  assert(state ~= nil, "missing state")
  local refs = require("Config.RuntimeRefs")
  state.ui_refs = refs

  runtime.for_each_role_or_global(function()
    for index = 1, 5 do
      local ref_id = tostring(3000 + index)
      local image_key = refs[ref_id]
      assert(image_key ~= nil, "missing item icon: " .. tostring(ref_id))
      _set_item_slot_image("道具槽位" .. tostring(index), image_key)
    end
  end)
  runtime.set_client_role(nil)
end

function ui_view.refresh_panel(state, ui_model)
  panel_presenter.refresh(state, ui_model, {
    runtime = runtime,
    refresh_item_slots = ui_view.refresh_item_slots,
  })
end

function ui_view.refresh_turn_label(state, label_text)
  local ui = state.ui
  if not ui or not ui.set_label then
    return
  end
  runtime.for_each_role_or_global(function()
    ui:set_label("倒计时", label_text)
  end)
  runtime.set_client_role(nil)
end

function ui_view.refresh_item_slots(state, ui_model, opts)
  local ui = state.ui
  assert(ui ~= nil and ui.item_slots ~= nil, "missing ui item slots")
  opts = opts or {}

  local slots = ui.item_slots
  local item_ids = {}
  local role_id = opts.role_id
  local display_player_id = opts.display_player_id or ui_model.current_player_id
  local allow_interact = opts.allow_interact ~= false
  local by_player = ui_model.item_slots_by_player_id or ui_model.item_slots_by_player or {}
  local items = by_player[display_player_id] or ui_model.item_slots or {}
  local allow_use = ui_model and ui_model.choice and ui_model.choice.kind == "item_phase_choice"
  local choice_owner_id = ui_model and ui_model.item_choice_owner_id or ui_model.current_player_id
  local refs = state.ui_refs
  local empty_key = refs["空"]
  local allow_slot_click = allow_use == true
    and allow_interact == true
    and display_player_id ~= nil
    and choice_owner_id == display_player_id

  for index, slot_name in ipairs(slots) do
    local item_id = items[index]
    if item_id then
      local image_key = refs[tostring(item_id)] or refs[item_id] or empty_key
      _set_item_slot_image(slot_name, image_key)
      ui:set_touch_enabled(slot_name, allow_slot_click)
      item_ids[index] = item_id
    else
      _set_item_slot_image(slot_name, empty_key)
      ui:set_touch_enabled(slot_name, false)
    end
  end

  if role_id ~= nil then
    if type(ui.item_slot_item_ids_by_role) ~= "table" then
      ui.item_slot_item_ids_by_role = {}
    end
    ui.item_slot_item_ids_by_role[role_id] = item_ids
  end
  ui.item_slot_item_ids = item_ids
end

function ui_view.apply_input_lock(state)
  input_lock_policy.apply(state, { runtime = runtime })
end

function ui_view.apply_role_control_lock(state, enabled)
  role_control_lock_policy.sync(state, enabled, { runtime = runtime })
end

function ui_view.render(state, ui_model, log_once, build_log_prefix)
  ui_view.refresh_panel(state, ui_model)
  board_view.refresh_board(state, ui_model, log_once, build_log_prefix)
end

function ui_view.set_debug_log(state, text)
  local ui = state and state.ui
  if not ui or not ui.set_debug_log then
    return
  end
  ui:set_debug_log(text or "")
end

function ui_view.set_debug_visible(state, visible)
  local ui = state and state.ui
  if not ui or not ui.set_debug_visible then
    return
  end
  ui:set_debug_visible(visible == true)
end

function ui_view.select_market_option(state, option_id)
  if not option_id then
    logger.warn("select_market_option missing option_id")
    return
  end
  market_view.select_market_option(state, option_id)
end

function ui_view.select_choice_option(state, option_id)
  if not option_id then
    logger.warn("select_choice_option missing option_id")
    return
  end
  modal_presenter.select_choice_option(state, option_id)
end

function ui_view.open_choice_modal(state, choice, market)
  modal_presenter.open_choice_modal(state, choice, market)
end

function ui_view.close_choice_modal(state)
  modal_presenter.close_choice_modal(state)
end

function ui_view.push_popup(state, payload)
  return modal_presenter.push_popup(state, payload)
end

function ui_view.close_popup(state)
  modal_presenter.close_popup(state)
end

return ui_view
