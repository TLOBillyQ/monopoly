local base_intents = require("src.ui.input.route_base")
local popup_intents = require("src.ui.input.route_popup")
local item_slot_intents = require("src.ui.input.route_item_slots")
local market_intents = require("src.ui.input.route_market")
local skin_panel_intents = require("src.ui.input.route_skin_panel")
local item_atlas_intents = require("src.ui.input.route_item_atlas")
local screen_registry = require("src.ui.screens.registry")

local registry = {}

local canvas_builders = {
  base_intents.build,
  popup_intents.build,
  item_slot_intents.build,
  market_intents.build_items,
  market_intents.build_controls,
  skin_panel_intents.build,
  item_atlas_intents.build,
}

function registry.build_route_specs(state)
  local specs = {}
  for _, build in ipairs(canvas_builders) do
    local built = build(state)
    for _, spec in ipairs(built or {}) do
      specs[#specs + 1] = spec
    end
  end
  -- 已迁移屏的 route specs 由 registry 按注册序统一拼接。
  for _, spec in ipairs(screen_registry.build_route_specs(state) or {}) do
    specs[#specs + 1] = spec
  end
  return specs
end

return registry

--[[ mutate4lua-manifest
version=2
projectHash=897a9388d42fe6dc
scope.0.id=chunk:src/ui/input/routes.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=37
scope.0.semanticHash=dc84bbc404825bfc
]]
