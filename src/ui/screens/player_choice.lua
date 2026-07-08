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
