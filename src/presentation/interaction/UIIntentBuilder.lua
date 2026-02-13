local basic_intents = require("src.presentation.interaction.intent_builders.BasicIntents")
local action_log_intents = require("src.presentation.interaction.intent_builders.ActionLogIntents")
local popup_intents = require("src.presentation.interaction.intent_builders.PopupIntents")
local item_slot_intents = require("src.presentation.interaction.intent_builders.ItemSlotIntents")
local choice_intents = require("src.presentation.interaction.intent_builders.ChoiceIntents")
local market_intents = require("src.presentation.interaction.intent_builders.MarketIntents")

local intent_builder = {}

function intent_builder.build_basic_intents(state)
  return basic_intents.build(state)
end

function intent_builder.build_action_log_intents()
  return action_log_intents.build()
end

function intent_builder.build_popup_intents(state)
  return popup_intents.build(state)
end

function intent_builder.build_item_slot_intents(state)
  return item_slot_intents.build(state)
end

function intent_builder.build_player_intents(state)
  return choice_intents.build_player(state)
end

function intent_builder.build_target_intents(state)
  return choice_intents.build_target(state)
end

function intent_builder.build_remote_intents(state)
  return choice_intents.build_remote(state)
end

function intent_builder.build_market_item_intents(state)
  return market_intents.build_items(state)
end

return intent_builder
