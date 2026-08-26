local base_intents = require("src.ui.input.route_base")
local popup_intents = require("src.ui.input.route_popup")
local item_slot_intents = require("src.ui.input.route_item_slots")
local screen_registry = require("src.ui.screens_registry")

local registry = {}

-- 尚未归位的面。market / skin_panel / item_atlas 已搬进 src/ui/screens/ 并向 registry
-- 自注册,故不在此列 —— 它们的 route specs 由下方 registry 按注册序发射。
local canvas_builders = {
  base_intents.build,
  popup_intents.build,
  item_slot_intents.build,
}

local function _append_specs(specs, built)
  for _, spec in ipairs(built or {}) do
    specs[#specs + 1] = spec
  end
end

function registry.build_route_specs(state)
  local specs = {}
  for _, build in ipairs(canvas_builders) do
    _append_specs(specs, build(state))
  end
  _append_specs(specs, screen_registry.build_route_specs(state))
  return specs
end

return registry

--[[ mutate4lua-manifest
version=4
projectHash=2567f8abb8bda544
scope.0.id=chunk:src/ui/input/routes.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=32
scope.0.semanticHash=21ddd722a1de74d1
scope.1.id=function:_append_specs
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=20
scope.1.semanticHash=416be15a177afa1b
scope.2.id=function:registry.build_route_specs
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=29
scope.2.semanticHash=310ac9d4e9b89004
]]
