-- player（玩家目标）选择屏的唯一归宿：schema 引用 + 开屏 + 点击意图。
-- 开屏委托 _option_screen 共享 helper。
local schema = require("src.ui.schema.player_choice")
local canvas = require("src.ui.coord.canvas_coordinator")
local option_screen = require("src.ui.screens._option_screen")
local ui_event_intents = require("src.ui.input.event_intents")

local M = { key = "player", canvas = canvas.CANVAS_PLAYER_CHOICE }

function M.descriptor()
  return {
    key = "player",
    root = schema.canvas,
    title = schema.title,
    underlay = schema.underlay,
    option_buttons = schema.slots,
  }
end

function M.open(state, choice, choice_id)
  option_screen.open(state, "player", choice, choice_id)
end

function M.build_route_specs(state)
  local specs = {}
  for index, name in ipairs(schema.slots) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return ui_event_intents.choice_select_intent(state, index, "player_select")
      end,
    }
  end
  return specs
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=5bc56033131a5799
scope.0.id=chunk:src/ui/screens/player_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=38
scope.0.semanticHash=14b81f27f485c1c0
scope.1.id=function:M.descriptor
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=18
scope.1.semanticHash=ce898401ee878933
scope.2.id=function:M.open
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=22
scope.2.semanticHash=a78865feb442dcda
scope.3.id=function:M.build_route_specs
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=35
scope.3.semanticHash=833156ea68da286d
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=31
scope.4.semanticHash=c525e32e1ce9f4a3
]]
