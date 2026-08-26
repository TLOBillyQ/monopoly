-- target（位置）选择屏的唯一归宿：schema 引用 + 开屏 + 按钮同步 + 点击意图。
-- 确认键刻意 inert：target 屏点槽位即确认，确认/取消键被隐藏。
local schema = require("src.ui.schema.target_choice")
local canvas = require("src.ui.coord.canvas_coordinator")
local openers = require("src.ui.coord.choice_openers")        -- 共享开屏原语
local node_ops = require("src.ui.render.support.node_ops")            -- 共享按钮同步原语
local modal_state = require("src.ui.state.modal")
local logger = require("src.foundation.log")
local ui_event_intents = require("src.ui.input.event_intents")
local runtime_state = require("src.ui.state.runtime")

local M = { key = "target", canvas = canvas.CANVAS_TARGET_CHOICE }

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

function M.open(state, choice, choice_id)
  local ui, screen = openers.open_screen(state, "target", choice, choice_id)
  local option_ids, selected = openers.fill_option_nodes(
    ui, screen, openers.order_target_options(choice), { clear_button_text = true })
  openers.store_target_button_labels(screen, choice)
  modal_state.open_choice(state, choice_id, option_ids, selected)
  node_ops.sync_target_choice_buttons(state)  -- 隐藏 confirm/cancel（点槽位即确认）
end

-- 点击意图：confirm/cancel 刻意 inert；slot 建 choice_select。
function M.build_route_specs(state)
  local specs = {
    { name = schema.confirm, build_intent = function() return nil end },
    { name = schema.cancel, build_intent = function() return nil end },
  }
-- 单选项屏:选项恰好 1 个时无论点哪个槽位都选中它,否则按槽位 index 选。
local function _resolve_single_option_index(choice, index)
  local options = choice.options
  return (type(options) == "table" and #options == 1) and 1 or index
end

local function _target_choice_intent(ui_state, index)
  local model = runtime_state.get_ui_model(ui_state)
  local choice = model and model.choice or nil
  if not choice then logger.warn("target_select without choice"); return nil end
  local resolve_index = _resolve_single_option_index(choice, index)
  local option_id = ui_event_intents.resolve_option_id(choice, { index = resolve_index }, ui_state)
  if not option_id then logger.warn("target_select missing option:", tostring(resolve_index)); return nil end
  return { type = "choice_select", choice_id = choice.id, option_id = option_id }
end

  for index, name in ipairs(schema.slot_buttons or {}) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return _target_choice_intent(state, index)
      end,
    }
  end
  return specs
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=3fcab9f37e0ecbb0
scope.0.id=chunk:src/ui/screens/target_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=71
scope.0.semanticHash=1a55d67412aefce4
scope.1.id=function:M.descriptor
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=26
scope.1.semanticHash=528ba283e471a3a7
scope.2.id=function:M.open
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=35
scope.2.semanticHash=6005de4e90ac80c3
scope.3.id=function:M.build_route_specs
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=68
scope.3.semanticHash=ed1a5d9a82255736
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=40
scope.4.semanticHash=d654da5e94a5e3f3
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=41
scope.5.semanticHash=d654da5e94a5e3f3
scope.6.id=function:_resolve_single_option_index
scope.6.kind=function
scope.6.startLine=44
scope.6.endLine=47
scope.6.semanticHash=f65d81d50baef30a
scope.7.id=function:_target_choice_intent
scope.7.kind=function
scope.7.startLine=49
scope.7.endLine=57
scope.7.semanticHash=ca9ae9bac275da8a
scope.8.id=function:<anonymous>#3
scope.8.kind=function
scope.8.startLine=62
scope.8.endLine=64
scope.8.semanticHash=5076d53a4090f1e9
]]
