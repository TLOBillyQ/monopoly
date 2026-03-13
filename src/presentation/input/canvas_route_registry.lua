local base_intents = require("src.presentation.input.canvas_routes.base")
local popup_intents = require("src.presentation.input.canvas_routes.popup")
local item_slot_intents = require("src.presentation.input.canvas_routes.item_slots")
local player_choice_intents = require("src.presentation.input.canvas_routes.player_choice")
local target_choice_intents = require("src.presentation.input.canvas_routes.target_choice")
local remote_choice_intents = require("src.presentation.input.canvas_routes.remote_choice")
local market_intents = require("src.presentation.input.canvas_routes.market")
local always_show_intents = require("src.presentation.input.canvas_routes.always_show")
local secondary_confirm_intents = require("src.presentation.input.canvas_routes.secondary_confirm")

local registry = {}

local canvas_specs = {
  { key = "base", build = function(state) return base_intents.build(state) end },
  { key = "always_show", build = function() return always_show_intents.build() end },
  { key = "popup", build = function(state) return popup_intents.build(state) end },
  { key = "item_slots", build = function(state) return item_slot_intents.build(state) end },
  { key = "player_choice", build = function(state) return player_choice_intents.build(state) end },
  { key = "target_choice", build = function(state) return target_choice_intents.build(state) end },
  { key = "remote_choice", build = function(state) return remote_choice_intents.build(state) end },
  { key = "market", build = function(state) return market_intents.build_items(state) end },
  { key = "market_controls", build = function(state) return market_intents.build_controls(state) end },
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

function registry.list_canvas_specs()
  return canvas_specs
end

return registry
