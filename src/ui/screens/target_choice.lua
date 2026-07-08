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
