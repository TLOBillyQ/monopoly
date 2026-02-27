local basic_intents = require("src.presentation.interaction.intent_builders.BasicIntents")
local action_log_intents = require("src.presentation.interaction.intent_builders.ActionLogIntents")
local popup_intents = require("src.presentation.interaction.intent_builders.PopupIntents")
local item_slot_intents = require("src.presentation.interaction.intent_builders.ItemSlotIntents")
local choice_intents = require("src.presentation.interaction.intent_builders.ChoiceIntents")
local market_intents = require("src.presentation.interaction.intent_builders.MarketIntents")

local registry = {}

local canvas_specs = {
  { key = "base", build = function(state) return basic_intents.build(state) end },
  { key = "always_show", build = function() return action_log_intents.build() end },
  { key = "popup", build = function(state) return popup_intents.build(state) end },
  { key = "item_slots", build = function(state) return item_slot_intents.build(state) end },
  { key = "player_choice", build = function(state) return choice_intents.build_player(state) end },
  { key = "target_choice", build = function(state) return choice_intents.build_target(state) end },
  { key = "remote_choice", build = function(state) return choice_intents.build_remote(state) end },
  { key = "market", build = function(state) return market_intents.build_items(state) end },
}

function registry.build_route_specs(state)
  local specs = {}
  for _, entry in ipairs(canvas_specs) do
    local built = entry.build and entry.build(state) or nil
    for _, spec in ipairs(built or {}) do
      specs[#specs + 1] = spec
    end
  end
  return specs
end

function registry.list_canvas_specs()
  return canvas_specs
end

return registry
