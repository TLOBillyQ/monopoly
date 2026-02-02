local ChoiceView = require("Manager.ChoiceManager.GUI.UIChoice")
local EggyLayerUI = require("Manager.TurnManager.GUI.UIState")
local EggyLayerMarket = require("Manager.MarketManager.GUI.UIMarket")
local EggyLayerBoard = require("Manager.BoardManager.GUI.BoardView")
local MarketUI = require("Manager.MarketManager.GUI.MarketUI")

local MainView = {}

function MainView.build_ui_state()
  return EggyLayerUI.build_ui_state()
end

function MainView.refresh_panel(layer, view)
  EggyLayerUI.refresh_panel(layer, view)
end

function MainView.refresh_item_slots(layer, view)
  EggyLayerUI.refresh_item_slots(layer, view)
end

function MainView.refresh_board(layer, view, log_once, build_log_prefix)
  EggyLayerBoard.refresh_board(layer, view, log_once, build_log_prefix)
end

function MainView.on_tile_upgraded(layer, tile_id, level)
  EggyLayerBoard.on_tile_upgraded(layer, tile_id, level)
end

function MainView.on_tile_owner_changed(layer, tile_id, owner_id)
  EggyLayerBoard.on_tile_owner_changed(layer, tile_id, owner_id)
end

function MainView.select_market_option(layer, option_id)
  EggyLayerMarket.select_market_option(layer, option_id)
end

function MainView.open_market_panel(layer, pending)
  return EggyLayerMarket.open_market_panel(layer, pending)
end

function MainView.close_market_panel(layer)
  EggyLayerMarket.close_market_panel(layer)
end

function MainView.open_choice_modal(layer, pending)
  assert(pending ~= nil, "missing pending choice")
  if layer.pending_choice_id == pending.id
      and (layer.ui.choice_active or layer.ui.market_active) then
    return
  end

  if pending.kind == "market_buy" and MarketUI.is_panel_ready() then
    if layer.ui.choice_active then
      layer.ui:set_visible(layer.ui.choice.root, false)
      layer.ui.choice_active = false
    end
    MainView.open_market_panel(layer, pending)
    return
  end
  if layer.ui.market_active then
    MainView.close_market_panel(layer)
  end

  local view = ChoiceView.build_choice_view(pending, { game = layer.game })
  assert(view ~= nil, "missing choice view")

  layer.ui:set_label(layer.ui.choice.title, view.title)
  layer.ui:set_label(layer.ui.choice.body, view.body)
  layer.ui:set_visible(layer.ui.choice.root, true)

  local option_nodes = layer.ui.choice.option_buttons
  for idx, name in ipairs(option_nodes) do
    local opt = view.options[idx]
    if opt then
      layer.ui:set_button(name, opt.label)
      layer.ui:set_visible(name, true)
      layer.ui:set_touch_enabled(name, true)
    else
      layer.ui:set_visible(name, false)
      layer.ui:set_touch_enabled(name, false)
    end
  end

  if not view.allow_cancel then
    layer.ui:set_visible(layer.ui.choice.cancel, false)
    layer.ui:set_touch_enabled(layer.ui.choice.cancel, false)
  else
    layer.ui:set_button(layer.ui.choice.cancel, view.cancel_label)
    layer.ui:set_visible(layer.ui.choice.cancel, true)
    layer.ui:set_touch_enabled(layer.ui.choice.cancel, true)
  end

  layer.ui.choice_active = true
  layer.pending_choice_elapsed = 0
  layer.pending_choice_id = pending.id
end

function MainView.close_choice_modal(layer)
  if layer.ui.choice_active then
    layer.ui:set_visible(layer.ui.choice.root, false)
    layer.ui.choice_active = false
  end
  if layer.ui.market_active then
    MainView.close_market_panel(layer)
  end
  layer.market_choice_option_ids = nil
  layer.pending_choice_selected_option_id = nil
end

function MainView.push_popup(layer, payload)
  assert(payload ~= nil, "missing popup payload")
  layer.ui:set_label(layer.ui.popup.title, payload.title)
  layer.ui:set_label(layer.ui.popup.body, payload.body)
  layer.ui:set_button(layer.ui.popup.confirm, payload.button_text)
  layer.ui:set_visible(layer.ui.popup.root, true)
  layer.ui.popup_active = true
  layer.ui.popup_seq = layer.ui.popup_seq + 1
  return true
end

function MainView.close_popup(layer)
  assert(layer.ui.popup_active == true, "popup not active")
  layer.ui:set_visible(layer.ui.popup.root, false)
  layer.ui.popup_active = false
end

return MainView
