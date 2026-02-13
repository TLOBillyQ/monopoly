local logger = require("src.core.Logger")
local ui_event_intents = require("src.presentation.interaction.UIEventIntents")
local market_ui = require("src.presentation.shared.MarketLayout")

local intent_builder = {}

function intent_builder.build_basic_intents(state)
  return {
    {
      name = "行动按钮",
      build_intent = function()
        return { type = "ui_button", id = "next" }
      end,
    },
    {
      name = "托管按钮",
      build_intent = function()
        return { type = "ui_button", id = "auto" }
      end,
    },
    {
      name = market_ui.confirm_button,
      build_intent = function()
        local market = state.ui_model and state.ui_model.market or nil
        if not market then
          logger.warn("market_confirm without market")
          return nil
        end
        local option_id = state.pending_choice_selected_option_id
        if not option_id then
          logger.warn("market_confirm missing selected option")
          return nil
        end
        return { type = "market_confirm", choice_id = market.choice_id, option_id = option_id }
      end,
    },
    {
      name = market_ui.cancel_button,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "market_cancel")
      end,
    },
    {
      name = "关闭",
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "market_close")
      end,
    },
    {
      name = "取消按钮",
      build_intent = function()
        if state.ui and state.ui.popup_active then
          return { type = "popup_confirm" }
        end
        return ui_event_intents.choice_cancel_intent(state, "choice_cancel")
      end,
    },
    {
      name = "建筑升级_确定按钮",
      build_intent = function()
        return ui_event_intents.choice_confirm_intent(state, "building_confirm")
      end,
    },
    {
      name = "建筑升级_取消",
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "building_cancel")
      end,
    },
    {
      name = "遥控骰子_取消",
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "remote_cancel")
      end,
    },
  }
end

function intent_builder.build_popup_intents(state)
  local specs = {}
  local popup = state.ui and state.ui.popup_screen or nil
  local dismiss_nodes = popup and popup.dismiss_nodes or nil
  if type(dismiss_nodes) ~= "table" then
    return specs
  end
  for _, name in ipairs(dismiss_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        if state.ui and state.ui.popup_active then
          return { type = "popup_confirm" }
        end
        return nil
      end,
    }
  end
  return specs
end

function intent_builder.build_item_slot_intents(state)
  local specs = {}
  local item_slots = (state.ui and state.ui.item_slots) or {}
  if #item_slots == 0 then
    item_slots = { "道具槽位1", "道具槽位2", "道具槽位3", "道具槽位4", "道具槽位5" }
  end
  for index, node_name in ipairs(item_slots) do
    local action_id = "item_slot_" .. tostring(index)
    specs[#specs + 1] = {
      name = node_name,
      build_intent = function()
        local choice = state.ui_model and state.ui_model.choice or nil
        if not choice or choice.kind ~= "item_phase_choice" then
          logger.warn("item_slot click ignored:", tostring(index))
          return nil
        end
        return { type = "ui_button", id = action_id }
      end,
    }
  end
  return specs
end

function intent_builder.build_player_intents(state)
  local specs = {}
  local player_nodes = {
    "玩家选择_槽位1",
    "玩家选择_槽位2",
    "玩家选择_槽位3",
  }
  for index, name in ipairs(player_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return ui_event_intents.choice_select_intent(state, index, "player_select")
      end,
    }
  end
  return specs
end

function intent_builder.build_target_intents(state)
  local specs = {}
  local target_nodes = {
    "位置前1",
    "位置前2",
    "位置前3",
    "位置后1",
    "位置后2",
    "位置后3",
    "位置脚下",
  }
  for index, name in ipairs(target_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return ui_event_intents.choice_select_intent(state, index, "target_select")
      end,
    }
  end
  return specs
end

function intent_builder.build_remote_intents(state)
  local specs = {}
  local remote_nodes = {
    "遥控骰子_选项_01",
    "遥控骰子_选项_02",
    "遥控骰子_选项_03",
    "遥控骰子_选项_04",
    "遥控骰子_选项_05",
    "遥控骰子_选项_06",
  }
  for index, name in ipairs(remote_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local choice = state.ui_model and state.ui_model.choice or nil
        if not choice then
          logger.warn("remote_select without choice")
          return nil
        end
        local option_id = ui_event_intents.resolve_option_id(choice, { index = index }, state)
        if not option_id then
          logger.warn("remote_select missing option:", tostring(index))
          return nil
        end
        return { type = "choice_select", choice_id = choice.id, option_id = option_id }
      end,
    }
  end
  return specs
end

function intent_builder.build_market_item_intents(state)
  local specs = {}
  for index, name in ipairs(market_ui.item_buttons) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        if not market_ui.is_ready() then
          logger.warn("market ui not ready")
          return nil
        end
        local market = state.ui_model and state.ui_model.market or nil
        if not market then
          logger.warn("market_select without market")
          return nil
        end
        local option_id = ui_event_intents.resolve_option_id(market, { index = index }, state)
        if not option_id then
          logger.warn("market_select missing option:", tostring(index))
          return nil
        end
        return { type = "market_select", option_id = option_id }
      end,
    }
  end
  return specs
end

return intent_builder
