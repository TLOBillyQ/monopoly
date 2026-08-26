local logger = require("src.foundation.log")
local base_nodes = require("src.ui.schema.base")
local route_model = require("src.ui.input.route_model")
local choice_support = require("src.ui.view.choice_support")
local optional_action_completion = require("src.turn.optional_action_completion")
local panel_interrupt = require("src.ui.state.panel_interrupt")

local intents = {}

local function _input_blocked(state)
  local ui = state and state.ui
  if ui and ui.input_blocked == true then
    return true
  end
  return panel_interrupt.settlement_type(ui) ~= nil
end

local function _can_build_optional_completion_intent(state)
  local result = optional_action_completion.can_complete_optional_action_phase(nil, nil, state, {
    choice = route_model.choice(state),
    require_actor = false,
    gate_state = {
      input_blocked = _input_blocked(state),
    },
  })
  return result.ok == true
end

function intents.build(state)
  return {
    {
      name = base_nodes.action_button,
      build_intent = function()
        local choice = route_model.choice(state)
        if choice_support.is_pre_action_item_phase_passive(choice) then
          return { type = "complete_optional_action_phase" }
        end
        if choice_support.is_optional_action_choice(choice) then
          return nil
        end
        return { type = "ui_button", id = "next" }
      end,
    },
    {
      name = base_nodes.end_button,
      build_intent = function()
        if not _can_build_optional_completion_intent(state) then
          return nil
        end
        return { type = "complete_optional_action_phase" }
      end,
    },
    {
      name = base_nodes.cancel_button,
      build_intent = function()
        local choice = route_model.choice(state)
        -- 与渲染显隐同一口径(choice_support.is_base_cancel_choice):按钮亮即有 intent。
        -- 口径外的点击说明按钮陈旧或模型失步,留 warn 供真机排查(此前是全链路唯一零日志吞点)。
        if not choice_support.is_base_cancel_choice(choice) then
          logger.warn("基础屏取消按钮点击被忽略: 当前无可取消的道具后续选择",
            choice and ("choice_kind=" .. tostring(choice.kind)) or "choice=nil")
          return nil
        end
        return {
          type = "choice_cancel",
          choice_id = choice.id,
        }
      end,
    },
    {
      name = base_nodes.auto_button,
      build_intent = function()
        return { type = "ui_button", id = "auto" }
      end,
    },
    {
      name = base_nodes.action_log_button,
      build_intent = function()
        return { type = "toggle_action_log" }
      end,
    },
    {
      name = base_nodes.skin_button,
      build_intent = function()
        return { type = "open_skin_panel" }
      end,
    },
    {
      name = base_nodes.gallery_button,
      build_intent = function()
        return { type = "open_gallery_panel" }
      end,
    },
    {
      name = base_nodes.share_button,
      build_intent = function()
        return { type = "open_share_panel" }
      end,
    },
  }
end

return intents

--[[ mutate4lua-manifest
version=4
projectHash=7acd622202bbfa08
scope.0.id=chunk:src/ui/input/route_base.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=104
scope.0.semanticHash=262582be10b8fa57
scope.1.id=function:_input_blocked
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=16
scope.1.semanticHash=8be74bf1f54179cb
scope.2.id=function:_can_build_optional_completion_intent
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=27
scope.2.semanticHash=9af3029c6a644631
scope.3.id=function:intents.build
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=101
scope.3.semanticHash=5756948aabc7e9fb
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=42
scope.4.semanticHash=d9d876a9c80f0d7e
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=51
scope.5.semanticHash=de4b3ec437645436
scope.6.id=function:<anonymous>#3
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=68
scope.6.semanticHash=1af518b73e9ab69e
scope.7.id=function:<anonymous>#4
scope.7.kind=function
scope.7.startLine=72
scope.7.endLine=74
scope.7.semanticHash=7bc951751d3de932
scope.8.id=function:<anonymous>#5
scope.8.kind=function
scope.8.startLine=78
scope.8.endLine=80
scope.8.semanticHash=d85e0d1244ba474f
scope.9.id=function:<anonymous>#6
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=86
scope.9.semanticHash=d85e0d1244ba474f
scope.10.id=function:<anonymous>#7
scope.10.kind=function
scope.10.startLine=90
scope.10.endLine=92
scope.10.semanticHash=d85e0d1244ba474f
scope.11.id=function:<anonymous>#8
scope.11.kind=function
scope.11.startLine=96
scope.11.endLine=98
scope.11.semanticHash=d85e0d1244ba474f
]]
