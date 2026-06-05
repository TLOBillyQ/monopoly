local base_intents = require("src.ui.input.route_base")
local popup_intents = require("src.ui.input.route_popup")
local item_slot_intents = require("src.ui.input.route_item_slots")
local player_choice_intents = require("src.ui.input.route_player_choice")
local target_choice_intents = require("src.ui.input.route_target_choice")
local remote_choice_intents = require("src.ui.input.route_remote_choice")
local market_intents = require("src.ui.input.route_market")
local skin_panel_intents = require("src.ui.input.route_skin_panel")
local item_atlas_intents = require("src.ui.input.route_item_atlas")
local secondary_confirm_intents = require("src.ui.input.route_secondary_confirm")

local registry = {}

local canvas_builders = {
  base_intents.build,
  popup_intents.build,
  item_slot_intents.build,
  player_choice_intents.build,
  target_choice_intents.build,
  remote_choice_intents.build,
  market_intents.build_items,
  market_intents.build_controls,
  skin_panel_intents.build,
  item_atlas_intents.build,
  secondary_confirm_intents.build,
}

function registry.build_route_specs(state)
  local specs = {}
  for _, build in ipairs(canvas_builders) do
    local built = build(state)
    for _, spec in ipairs(built or {}) do
      specs[#specs + 1] = spec
    end
  end
  return specs
end

return registry

--[[ mutate4lua-manifest
version=2
projectHash=6fd986ec8af95f6a
scope.0.id=chunk:src/ui/input/routes.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=2c0d89b309d33a3f
]]
