-- player / remote 共享的选项开屏 helper（两屏 open 委托它，避免复制）。
local openers = require("src.ui.coord.choice_openers")
local modal_state = require("src.ui.state.modal")

local M = {}

function M.open(state, screen_key, choice, choice_id)
  local ui, screen = openers.open_screen(state, screen_key, choice, choice_id)
  -- 灰底是随 canvas 显示的纯装饰 EImage,Eggy 覆盖节点默认吸触摸(先例:
  -- auto_effect / skin_label 均显式关触摸);基础屏取消按钮住下层 canvas 且是
  -- followup 唯一退出口,开屏时放行点击穿透。
  if screen.underlay then
    ui:set_touch_enabled(screen.underlay, false)
  end
  local option_ids, selected = openers.fill_option_nodes(
    ui, screen, openers.resolve_player_or_remote_options(choice, screen_key))
  openers.set_action_button(ui, screen.confirm, true, true, "确定")
  local allow_cancel = choice.allow_cancel ~= false
  openers.set_action_button(ui, screen.cancel, allow_cancel, allow_cancel, choice.cancel_label or "取消")
  modal_state.open_choice(state, choice_id, option_ids, selected)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=433b641bb581e444
scope.0.id=chunk:src/ui/screens/_option_screen.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=24
scope.0.semanticHash=9becbe3c6729f9f4
scope.1.id=function:M.open
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=21
scope.1.semanticHash=6b02bba1078e055e
]]
