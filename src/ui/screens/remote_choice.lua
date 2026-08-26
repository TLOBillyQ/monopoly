-- remote（遥控骰子）选择屏的唯一归宿：schema 引用 + 开屏 + 点击意图。
-- 无 inert 确认键，点选项即确认。
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
    underlay = schema.underlay,
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

return M

--[[ mutate4lua-manifest
version=4
projectHash=355f59ab5259dcdd
scope.0.id=chunk:src/ui/screens/remote_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=989b16a6f0f5304b
scope.1.id=function:M.descriptor
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=21
scope.1.semanticHash=cee80d17110e9a0c
scope.2.id=function:M.open
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=25
scope.2.semanticHash=a78865feb442dcda
scope.3.id=function:M.build_route_specs
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=43
scope.3.semanticHash=a2ad56447fb5a97b
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=39
scope.4.semanticHash=bf12c3b223fcc1e1
]]
