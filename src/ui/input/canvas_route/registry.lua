local base_intents = require("src.ui.input.canvas_route.base")
local popup_intents = require("src.ui.input.canvas_route.popup")
local item_slot_intents = require("src.ui.input.canvas_route.item_slots")
local player_choice_intents = require("src.ui.input.canvas_route.player_choice")
local target_choice_intents = require("src.ui.input.canvas_route.target_choice")
local remote_choice_intents = require("src.ui.input.canvas_route.remote_choice")
local market_intents = require("src.ui.input.canvas_route.market")
local skin_panel_intents = require("src.ui.input.canvas_route.skin_panel")
local item_atlas_intents = require("src.ui.input.canvas_route.item_atlas")
local secondary_confirm_intents = require("src.ui.input.canvas_route.secondary_confirm")

local registry = {}

local canvas_specs = {
  { key = "base", build = function(state) return base_intents.build(state) end },
  { key = "popup", build = function(state) return popup_intents.build(state) end },
  { key = "item_slots", build = function(state) return item_slot_intents.build(state) end },
  { key = "player_choice", build = function(state) return player_choice_intents.build(state) end },
  { key = "target_choice", build = function(state) return target_choice_intents.build(state) end },
  { key = "remote_choice", build = function(state) return remote_choice_intents.build(state) end },
  { key = "market", build = function(state) return market_intents.build_items(state) end },
  { key = "market_controls", build = function(state) return market_intents.build_controls(state) end },
  { key = "skin_panel", build = function(state) return skin_panel_intents.build(state) end },
  { key = "item_atlas", build = function(state) return item_atlas_intents.build(state) end },
  { key = "secondary_confirm", build = function(state) return secondary_confirm_intents.build(state) end },
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

return registry
