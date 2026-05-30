local host_runtime_ports = require("src.ui.host_bridge")

local panel_interrupt = {}

local TIP_TEXT = "结算中，稍后再开"
local TIP_DURATION = 2.0
local ACTION_TURN_TIP_TEXT = "轮到你行动了"

local SETTLEMENT_TYPES = {
  { flag = "popup_active", name = "弹窗" },
  { flag = "market_active", name = "黑市" },
  { flag = "choice_active", name = "机会" },
  { flag = "move_active", name = "移动" },
}

local function _same_role(left, right)
  return left ~= nil and right ~= nil and tostring(left) == tostring(right)
end

local function _market_blocks_role(ui, role_id)
  if ui == nil or ui.market_active ~= true then
    return false
  end
  if role_id == nil or ui.current_action_role_id == nil then
    return true
  end
  return _same_role(ui.current_action_role_id, role_id)
end

local function _panel_belongs_to_active_role(ui, role_id)
  if ui.current_action_role_id == nil then
    return true
  end
  return _same_role(ui.current_action_role_id, role_id)
end

local function _close_open_role_panel(state, ui, panel_key, close_fn)
  local panel = ui[panel_key]
  if panel == nil or panel.open ~= true then
    return
  end
  if not _panel_belongs_to_active_role(ui, panel.role_id) then
    return
  end
  close_fn(state, panel.role_id)
end

local function _close_visible_event_logs(state, ui, event_log_view)
  local by_role = ui.debug_visible_by_role
  if type(by_role) ~= "table" then
    return
  end
  for role_id, visible in pairs(by_role) do
    if visible == true and _panel_belongs_to_active_role(ui, role_id) then
      event_log_view.close(state, role_id)
    end
  end
end

function panel_interrupt.settlement_type(ui)
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

function panel_interrupt.is_settling(state)
  local ui = state and state.ui
  return panel_interrupt.settlement_type(ui) ~= nil
end

function panel_interrupt.block_entry(state, panel_id, actor_role_id)
  local ui = state and state.ui
  if not _market_blocks_role(ui, actor_role_id) then
    return false
  end
  host_runtime_ports.enqueue_tip({
    text = TIP_TEXT,
    duration = TIP_DURATION,
    dedupe_key = "panel_interrupt:" .. tostring(panel_id) .. ":黑市",
    blocks_inter_turn = false,
    source = "ui.panel_interrupt",
  })
  return true
end

function panel_interrupt.begin_move(state)
  local ui = state and state.ui
  if ui == nil then
    return
  end
  ui.move_active = true
  panel_interrupt.interrupt(state)
end

function panel_interrupt.end_move(state)
  local ui = state and state.ui
  if ui == nil then
    return
  end
  ui.move_active = false
end

function panel_interrupt.begin_player_action(state, role_id)
  local ui = state and state.ui
  if ui == nil then
    return
  end
  ui.current_action_role_id = role_id

  local panel = ui.skin_panel
  if panel == nil or panel.open ~= true then
    return
  end
  if tostring(panel.role_id) ~= tostring(role_id) then
    return
  end

  local skin_panel = require("src.ui.coord.skin_panel")
  skin_panel.close(state, panel.role_id, { silent = true })
  host_runtime_ports.enqueue_tip({
    text = ACTION_TURN_TIP_TEXT,
    duration = TIP_DURATION,
    dedupe_key = "panel_interrupt:skin_panel:action_turn:" .. tostring(role_id),
    blocks_inter_turn = false,
    source = "ui.panel_interrupt",
  })
end

function panel_interrupt.interrupt(state)
  local ui = state and state.ui
  if ui == nil or ui.market_active ~= true then
    return  -- silent early-return: cheap and hot, do not log
  end
  -- deferred require to avoid load-order cycles with the panel modules below
  local item_atlas = require("src.ui.coord.item_atlas")
  local skin_panel = require("src.ui.coord.skin_panel")
  local event_log_view = require("src.ui.coord.event_log_view")

  _close_open_role_panel(state, ui, "item_atlas", item_atlas.close)
  _close_open_role_panel(state, ui, "skin_panel", skin_panel.close)
  _close_visible_event_logs(state, ui, event_log_view)
end

return panel_interrupt

--[[ mutate4lua-manifest
version=2
projectHash=bb086a8c21a0cd9d
scope.0.id=chunk:src/ui/coord/panel_interrupt.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=151
scope.0.semanticHash=a70b108ddc173c75
scope.0.lastMutatedAt=2026-05-25T13:29:32Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=13
scope.0.lastMutationKilled=13
scope.1.id=function:_same_role:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=18
scope.1.semanticHash=c4c85c3c4b92c616
scope.1.lastMutatedAt=2026-05-23T16:20:37Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:_market_blocks_role:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=28
scope.2.semanticHash=dfd07ac2595d2f5d
scope.2.lastMutatedAt=2026-05-23T16:20:37Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=10
scope.2.lastMutationKilled=10
scope.3.id=function:_panel_belongs_to_active_role:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=35
scope.3.semanticHash=eb2a9c35823dd140
scope.3.lastMutatedAt=2026-05-23T16:20:37Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
scope.4.id=function:_close_open_role_panel:37
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=46
scope.4.semanticHash=aea4e94aea8e7d1f
scope.4.lastMutatedAt=2026-05-23T16:20:37Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=7
scope.4.lastMutationKilled=7
scope.5.id=function:panel_interrupt.is_settling:72
scope.5.kind=function
scope.5.startLine=72
scope.5.endLine=75
scope.5.semanticHash=9afa2fdb94089b01
scope.5.lastMutatedAt=2026-05-23T16:20:37Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:panel_interrupt.block_entry:77
scope.6.kind=function
scope.6.startLine=77
scope.6.endLine=90
scope.6.semanticHash=88884cba9c8288a9
scope.6.lastMutatedAt=2026-05-23T16:20:37Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=6
scope.6.lastMutationKilled=6
scope.7.id=function:panel_interrupt.begin_move:92
scope.7.kind=function
scope.7.startLine=92
scope.7.endLine=99
scope.7.semanticHash=c56fb451f496fb70
scope.7.lastMutatedAt=2026-05-23T16:20:37Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=4
scope.7.lastMutationKilled=4
scope.8.id=function:panel_interrupt.end_move:101
scope.8.kind=function
scope.8.startLine=101
scope.8.endLine=107
scope.8.semanticHash=fd83e2d11b2473ea
scope.8.lastMutatedAt=2026-05-23T16:20:37Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=3
scope.8.lastMutationKilled=3
scope.9.id=function:panel_interrupt.begin_player_action:109
scope.9.kind=function
scope.9.startLine=109
scope.9.endLine=133
scope.9.semanticHash=92082de323e1e23a
scope.9.lastMutatedAt=2026-05-25T13:29:32Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=12
scope.9.lastMutationKilled=12
scope.10.id=function:panel_interrupt.interrupt:135
scope.10.kind=function
scope.10.startLine=135
scope.10.endLine=148
scope.10.semanticHash=a3bb75f588d7a988
scope.10.lastMutatedAt=2026-05-23T16:20:37Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=11
scope.10.lastMutationKilled=11
]]
