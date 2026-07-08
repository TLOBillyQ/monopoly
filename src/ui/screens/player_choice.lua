-- player（玩家目标）选择屏的唯一归宿：schema 引用 + 开屏 + 点击意图。
-- 收编自 node_ops.build_choice_screens.player / choice_openers._open_player_or_remote_screen /
-- route_player_choice.build。开屏委托 _option_screen 共享 helper。
local registry = require("src.ui.screens.registry")
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

registry.register(M)
return M

--[[ mutate4lua-manifest
version=2
projectHash=e4340596edd4077a
scope.0.id=chunk:src/ui/screens/player_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=9a8d38449aa68200
scope.1.id=function:M.descriptor:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=19
scope.1.semanticHash=d1027e747a58f48a
scope.2.id=function:M.open:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=23
scope.2.semanticHash=b4ea9f35f98cf992
scope.3.id=function:anonymous@30:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=32
scope.3.semanticHash=152005556507b71b
]]
