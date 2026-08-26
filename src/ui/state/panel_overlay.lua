-- 弹层/结算的纯查询面（自 panel_interrupt 拆出,#162 后模块超变异点阈值）：
-- 无副作用,不触 host bridge。打断动作(closer 注册/提示/interrupt)住 panel_interrupt。
local panel_overlay = {}

local SETTLEMENT_TYPES = {
  { flag = "popup_active", name = "弹窗" },
  { flag = "market_active", name = "黑市" },
  { flag = "choice_active", name = "机会" },
  { flag = "move_active", name = "移动" },
}

function panel_overlay.settlement_type(ui)
  if ui == nil then
    return nil
  end
  for _, settlement in ipairs(SETTLEMENT_TYPES) do
    if ui[settlement.flag] == true then
      return settlement.name
    end
  end
  return nil
end

-- 基础屏取消按钮口径的遮挡判定:choice_active 豁免——followup 自己的选择屏正是
-- 取消按钮要退出的对象,不算对它的遮挡;弹窗/黑市/移动照常算。
function panel_overlay.settlement_type_excluding_choice(ui)
  if ui == nil then
    return nil
  end
  for _, settlement in ipairs(SETTLEMENT_TYPES) do
    if settlement.flag ~= "choice_active" and ui[settlement.flag] == true then
      return settlement.name
    end
  end
  return nil
end

function panel_overlay.is_settling(state)
  local ui = state and state.ui
  return panel_overlay.settlement_type(ui) ~= nil
end

-- 真弹层判定(#162):弹窗/黑市/机会是覆盖弹层;移动(move_active)与
-- input_blocked 是阶段位,不算弹层。道具槽全时段可点门只看这里。
local _OVERLAY_FLAGS = { "popup_active", "market_active", "choice_active" }

function panel_overlay.is_overlay_visible(ui)
  if ui == nil then
    return false
  end
  for _, flag in ipairs(_OVERLAY_FLAGS) do
    if ui[flag] == true then
      return true
    end
  end
  return false
end

return panel_overlay

--[[ mutate4lua-manifest
version=4
projectHash=1f2a242e6ef37c9f
scope.0.id=chunk:src/ui/state/panel_overlay.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=60
scope.0.semanticHash=6e449b85fe728f86
scope.1.id=function:panel_overlay.settlement_type
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=22
scope.1.semanticHash=c44a7608017b8ff1
scope.2.id=function:panel_overlay.settlement_type_excluding_choice
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=36
scope.2.semanticHash=f5c5e1d21b0eccf3
scope.3.id=function:panel_overlay.is_settling
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=41
scope.3.semanticHash=5b10d83a884bb44b
scope.4.id=function:panel_overlay.is_overlay_visible
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=57
scope.4.semanticHash=3f88860b4fc24a3d
]]
