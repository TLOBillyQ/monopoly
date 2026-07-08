-- target（位置）选择屏的唯一归宿：schema 引用 + 开屏 + 按钮同步 + 点击意图。
-- 收编自 node_ops.build_choice_screens.target / choice_openers._open_target_screen
-- (+ _store_target_button_labels) / node_ops.sync_target_choice_buttons /
-- route_target_choice.build。确认键刻意 inert：target 屏点槽位即确认，确认/取消键被隐藏。
local registry = require("src.ui.screens.registry")
local schema = require("src.ui.schema.target_choice")
local canvas = require("src.ui.coord.canvas_coordinator")
local openers = require("src.ui.coord.choice_openers")        -- 共享开屏原语
local node_ops = require("src.ui.render.node_ops")            -- 共享按钮同步原语
local modal_state = require("src.ui.state.modal")
local logger = require("src.foundation.log")
local ui_event_intents = require("src.ui.input.event_intents")
local runtime_state = require("src.ui.state.runtime")

local M = { key = "target", canvas = canvas.CANVAS_TARGET_CHOICE }

-- 屏描述符：逐字段等价 node_ops.build_choice_screens.target（node_ops_spec 钉死）。
function M.descriptor()
  return {
    key = "target",
    root = schema.canvas,
    title = schema.title,
    body = schema.body,
    option_buttons = schema.slot_buttons,
    slot_labels = schema.slot_labels,
    slot_projections = schema.slot_projections,
    confirm = schema.confirm,
    cancel = schema.cancel,
  }
end

-- 开屏：逐句保留 _open_target_screen 的副作用序列。
function M.open(state, choice, choice_id)
  local ui, screen = openers.open_screen(state, "target", choice, choice_id)
  local option_ids, selected = openers.fill_option_nodes(
    ui, screen, openers.order_target_options(choice), { clear_button_text = true })
  openers.store_target_button_labels(screen, choice)
  modal_state.open_choice(state, choice_id, option_ids, selected)
  node_ops.sync_target_choice_buttons(state)  -- 隐藏 confirm/cancel（点槽位即确认）
end

-- 点击意图：confirm/cancel 刻意 inert；slot 建 choice_select。等价 route_target_choice.build。
function M.build_route_specs(state)
  local specs = {
    { name = schema.confirm, build_intent = function() return nil end },
    { name = schema.cancel, build_intent = function() return nil end },
  }
  for index, name in ipairs(schema.slot_buttons or {}) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local model = runtime_state.get_ui_model(state)
        local choice = model and model.choice or nil
        if not choice then logger.warn("target_select without choice"); return nil end
        local options = choice.options
        local resolve_index = (type(options) == "table" and #options == 1) and 1 or index
        local option_id = ui_event_intents.resolve_option_id(choice, { index = resolve_index }, state)
        if not option_id then logger.warn("target_select missing option:", tostring(resolve_index)); return nil end
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
projectHash=44d54c26b34d8020
scope.0.id=chunk:src/ui/screens/target_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=68
scope.0.semanticHash=4b7d42ade477eeaa
scope.1.id=function:M.descriptor:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=30
scope.1.semanticHash=5b15919933e5e3ef
scope.2.id=function:M.open:33
scope.2.kind=function
scope.2.startLine=33
scope.2.endLine=40
scope.2.semanticHash=da53323613975ebf
scope.3.id=function:anonymous@45:45
scope.3.kind=function
scope.3.startLine=45
scope.3.endLine=45
scope.3.semanticHash=d8269153568043a6
scope.4.id=function:anonymous@46:46
scope.4.kind=function
scope.4.startLine=46
scope.4.endLine=46
scope.4.semanticHash=d8269153568043a6
scope.5.id=function:anonymous@51:51
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=60
scope.5.semanticHash=1fe3f5cf480f2cbb
]]
