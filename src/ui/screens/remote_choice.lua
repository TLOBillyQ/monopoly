-- remote（遥控骰子）选择屏的唯一归宿：schema 引用 + 开屏 + 点击意图。
-- 收编自 node_ops.build_choice_screens.remote / choice_openers._open_player_or_remote_screen /
-- route_remote_choice.build。无 inert 确认键，点选项即确认。
local registry = require("src.ui.screens.registry")
local schema = require("src.ui.schema.remote_choice")
local canvas = require("src.ui.coord.canvas_coordinator")
local option_screen = require("src.ui.screens._option_screen")
local logger = require("src.foundation.log")
local ui_event_intents = require("src.ui.input.event_intents")
local runtime_state = require("src.ui.state.runtime")

local M = { key = "remote", canvas = canvas.CANVAS_REMOTE_CHOICE }

function M.descriptor()
  return {
    key = "remote",
    root = schema.canvas,
    title = schema.title,
    body = schema.body,
    option_buttons = schema.options,
  }
end

function M.open(state, choice, choice_id)
  option_screen.open(state, "remote", choice, choice_id)
end

function M.build_route_specs(state)
  local specs = {}
  for index, name in ipairs(schema.options) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local model = runtime_state.get_ui_model(state)
        local choice = model and model.choice or nil
        if not choice then logger.warn("remote_select without choice"); return nil end
        local option_id = ui_event_intents.resolve_option_id(choice, { index = index }, state)
        if not option_id then logger.warn("remote_select missing option:", tostring(index)); return nil end
        return { type = "choice_select", choice_id = choice.id, option_id = option_id }
      end,
    }
  end
  return specs
end

registry.register(M)
return M

--[[ mutate4lua-manifest
version=2
projectHash=0a11ea699282cf90
scope.0.id=chunk:src/ui/screens/remote_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=48
scope.0.semanticHash=eb7c8e9a05e27189
scope.1.id=function:M.descriptor:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=22
scope.1.semanticHash=0163adf1a4c64a9e
scope.2.id=function:M.open:24
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=26
scope.2.semanticHash=2a2c4c155208d0b1
scope.3.id=function:anonymous@33:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=40
scope.3.semanticHash=a34858d1a1c4da35
]]
