local transaction = require("src.app.cosmetics.transaction")
local host_runtime_ports = require("src.ui.host_bridge")
local canvas = require("src.ui.coord.canvas_coordinator")
local base_nodes = require("src.ui.schema.base")
local skin_nodes = require("src.ui.schema.skin")
local skin_panel_view = require("src.ui.render.skin_panel")
local panel_helpers = require("src.ui.coord.panel_helpers")
local panel_state = require("src.ui.coord.skin_panel_state")
local panel_actions = require("src.ui.coord.skin_panel_actions")

local skin_panel = {}

local _catalog = transaction.catalog

local function _notify(text, key)
  host_runtime_ports.enqueue_tip({
    text = text,
    duration = 2.0,
    dedupe_key = key,
    blocks_inter_turn = false,
    source = "ui.skin_panel",
  })
end

local function _sync_catalog()
  _catalog = transaction.catalog
  skin_panel.catalog = _catalog
end

local function _refresh_slots_for_owner(state, panel)
  return panel_helpers.with_owner_role(state, panel.role_id, function()
    return skin_panel_view.refresh_slots(state, _catalog)
  end)
end

local function _panel_from_result(state, result)
  if result and result.panel then
    return result.panel
  end
  return panel_state.ensure(state)
end

local function _result_key(result, role_id)
  local product_id = result.product_id or result.equipped_product or ""
  return "skin_panel:" .. tostring(result.action or "unknown")
    .. ":" .. tostring(role_id)
    .. ":" .. tostring(product_id)
end

local function _notify_result(result, role_id, opts)
  if opts and opts.silent == true then
    return
  end
  if result == nil or result.notification == nil then
    return
  end
  _notify(result.notification, _result_key(result, role_id))
end

local function _switch_open_result(state, effective_role, result)
  if result and result.action == "open" then
    canvas.switch_by_role_id(state and state.ui, skin_nodes.canvas, effective_role)
  end
end

local function _refresh_result_slots(state, panel, result)
  if result and result.slot_view_dirty == true then
    _refresh_slots_for_owner(state, panel)
  end
end

local function _switch_close_result(state, effective_role, result)
  if result and result.panel_should_close == true then
    canvas.switch_by_role_id(state and state.ui, base_nodes.canvas, result.role_id or effective_role)
  end
end

local function _apply_transaction_result(state, role_id, result, opts)
  local panel = _panel_from_result(state, result)
  local effective_role = role_id or panel.role_id
  _switch_open_result(state, effective_role, result)
  _refresh_result_slots(state, panel, result)
  _switch_close_result(state, effective_role, result)
  _notify_result(result, effective_role, opts)
  return panel
end

local function _default_apply_transaction_result(state, result)
  return _apply_transaction_result(state, nil, result, {})
end

function skin_panel.apply_transaction_result(state, result, opts)
  return _apply_transaction_result(state, nil, result, opts or {})
end

local function _handle_transaction(state, role_id, request, opts)
  local result = transaction.handle_skin_transaction(state, role_id, request)
  return _apply_transaction_result(state, role_id, result, opts)
end

function skin_panel.is_slot_equipped(state, slot_index)
  return transaction.is_slot_equipped(state, slot_index)
end

function skin_panel.configure_equip(callback)
  transaction.configure_equip(callback)
end

function skin_panel.configure_purchase(callback)
  transaction.configure_purchase(callback)
end

function skin_panel.configure_unequip(callback)
  transaction.configure_unequip(callback)
end

function skin_panel.configure_archive(archive)
  transaction.configure_archive(archive)
end

function skin_panel.configure_catalog_for_tests(catalog)
  transaction.configure_catalog_for_tests(catalog)
  _sync_catalog()
end

function skin_panel.reset_for_tests()
  transaction.reset_for_tests()
  _sync_catalog()
  transaction.configure_transaction_result_applier(_default_apply_transaction_result)
end

function skin_panel.open(state, role_id)
  return _handle_transaction(state, role_id, { type = "open" })
end

function skin_panel.close(state, role_id, opts)
  return _handle_transaction(state, role_id, { type = "close" }, opts)
end

function skin_panel.unlock(state, role_id, source, slot_index)
  return _handle_transaction(state, role_id, {
    type = "unlock_slot",
    source = source,
    slot_index = slot_index,
  })
end

function skin_panel.equip(state, role_id, slot_index)
  return _handle_transaction(state, role_id, {
    type = "equip_slot",
    slot_index = slot_index,
  })
end

local function _unequip(state, role_id)
  return _handle_transaction(state, role_id, { type = "unequip" })
end

local function _page(state, request_type)
  return _handle_transaction(state, nil, { type = request_type }, { silent = true })
end

local _ACTION_HANDLERS = {
  close   = function(state, role_id, _)  return skin_panel.close(state, role_id) end,
  buy     = function(state, role_id, a)  return skin_panel.unlock(state, role_id, "buy", panel_actions.slot_index(a)) end,
  gift    = function(state, role_id, a)  return skin_panel.unlock(state, role_id, "gift", panel_actions.slot_index(a)) end,
  equip   = function(state, role_id, a)  return skin_panel.equip(state, role_id, panel_actions.slot_index(a)) end,
  activate_slot = function(state, role_id, a)
    return _handle_transaction(state, role_id, {
      type = "activate_slot",
      slot_index = panel_actions.slot_index(a),
    })
  end,
  unequip = function(state, role_id, _)  return _unequip(state, role_id) end,
  next    = function(state, _, _)        return _page(state, "page_next") end,
  prev    = function(state, _, _)        return _page(state, "page_prev") end,
}

function skin_panel.handle_action(state, action, role_id)
  local action_type = panel_actions.kind(action)
  local handler = _ACTION_HANDLERS[action_type]
  if handler then return handler(state, role_id, action) end
  local slot_index = panel_actions.numeric_slot(action)
  if slot_index ~= nil then return skin_panel.equip(state, role_id, slot_index) end
  return panel_state.ensure(state)
end

skin_panel.catalog = _catalog

transaction.configure_transaction_result_applier(_default_apply_transaction_result)

return skin_panel

--[[ mutate4lua-manifest
version=2
projectHash=ffe7554de2ca8013
scope.0.id=chunk:src/ui/coord/skin_panel.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=176
scope.0.semanticHash=e26a1eb0909fc29c
scope.0.lastMutatedAt=2026-06-24T16:22:45Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=9
scope.0.lastMutationKilled=9
scope.1.id=function:_notify:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=23
scope.1.semanticHash=4954ead30edb0436
scope.1.lastMutatedAt=2026-06-24T16:22:45Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_sync_catalog:25
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=28
scope.2.semanticHash=378adcf8f314e829
scope.2.lastMutatedAt=2026-06-24T16:20:47Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=no_sites
scope.2.lastMutationSites=0
scope.2.lastMutationKilled=0
scope.3.id=function:anonymous@31:31
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=33
scope.3.semanticHash=496b82e8d3606200
scope.3.lastMutatedAt=2026-06-24T16:20:47Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=no_sites
scope.3.lastMutationSites=0
scope.3.lastMutationKilled=0
scope.4.id=function:_refresh_slots_for_owner:30
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=34
scope.4.semanticHash=1a7c6ecd7c3404fe
scope.4.lastMutatedAt=2026-06-24T16:22:45Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_panel_from_result:36
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=41
scope.5.semanticHash=a4bd239e1587327c
scope.5.lastMutatedAt=2026-06-24T16:22:45Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:_result_key:43
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=48
scope.6.semanticHash=e1d7d8f165500e75
scope.6.lastMutatedAt=2026-06-24T16:22:45Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=9
scope.6.lastMutationKilled=9
scope.7.id=function:_notify_result:50
scope.7.kind=function
scope.7.startLine=50
scope.7.endLine=58
scope.7.semanticHash=1c21498ab8183ced
scope.7.lastMutatedAt=2026-06-24T16:22:45Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=7
scope.7.lastMutationKilled=7
scope.8.id=function:_switch_open_result:60
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=64
scope.8.semanticHash=fab5af464a8a125f
scope.8.lastMutatedAt=2026-06-24T16:22:45Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=4
scope.8.lastMutationKilled=4
scope.9.id=function:_refresh_result_slots:66
scope.9.kind=function
scope.9.startLine=66
scope.9.endLine=70
scope.9.semanticHash=1fe92fca342e7238
scope.9.lastMutatedAt=2026-06-24T16:22:45Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=4
scope.9.lastMutationKilled=4
scope.10.id=function:_switch_close_result:72
scope.10.kind=function
scope.10.startLine=72
scope.10.endLine=76
scope.10.semanticHash=3e72248d890c6408
scope.10.lastMutatedAt=2026-06-24T16:22:45Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=4
scope.10.lastMutationKilled=4
scope.11.id=function:_apply_transaction_result:78
scope.11.kind=function
scope.11.startLine=78
scope.11.endLine=86
scope.11.semanticHash=64def3d8a231b9e8
scope.11.lastMutatedAt=2026-06-24T16:22:45Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=6
scope.11.lastMutationKilled=6
scope.12.id=function:_handle_transaction:88
scope.12.kind=function
scope.12.startLine=88
scope.12.endLine=91
scope.12.semanticHash=8958bf9c3fcb4a07
scope.12.lastMutatedAt=2026-06-24T16:22:45Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=2
scope.12.lastMutationKilled=2
scope.13.id=function:skin_panel.is_slot_equipped:93
scope.13.kind=function
scope.13.startLine=93
scope.13.endLine=95
scope.13.semanticHash=41368e0d49e2941e
scope.13.lastMutatedAt=2026-06-24T16:22:45Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=1
scope.13.lastMutationKilled=1
scope.14.id=function:skin_panel.configure_equip:97
scope.14.kind=function
scope.14.startLine=97
scope.14.endLine=99
scope.14.semanticHash=d474ae8b37c88378
scope.14.lastMutatedAt=2026-06-24T16:22:45Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=1
scope.14.lastMutationKilled=1
scope.15.id=function:skin_panel.configure_purchase:101
scope.15.kind=function
scope.15.startLine=101
scope.15.endLine=103
scope.15.semanticHash=4b691dec9512e37e
scope.15.lastMutatedAt=2026-06-24T16:22:45Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=1
scope.15.lastMutationKilled=1
scope.16.id=function:skin_panel.configure_unequip:105
scope.16.kind=function
scope.16.startLine=105
scope.16.endLine=107
scope.16.semanticHash=c85edc3b40378042
scope.16.lastMutatedAt=2026-06-24T16:22:45Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=1
scope.16.lastMutationKilled=1
scope.17.id=function:skin_panel.configure_archive:109
scope.17.kind=function
scope.17.startLine=109
scope.17.endLine=111
scope.17.semanticHash=0d3974db85a9233a
scope.17.lastMutatedAt=2026-06-24T16:22:45Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=1
scope.17.lastMutationKilled=1
scope.18.id=function:skin_panel.configure_catalog_for_tests:113
scope.18.kind=function
scope.18.startLine=113
scope.18.endLine=116
scope.18.semanticHash=d416401f66f6bd27
scope.18.lastMutatedAt=2026-06-24T16:22:45Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=2
scope.18.lastMutationKilled=2
scope.19.id=function:skin_panel.reset_for_tests:118
scope.19.kind=function
scope.19.startLine=118
scope.19.endLine=121
scope.19.semanticHash=0348632ce5052347
scope.19.lastMutatedAt=2026-06-24T16:22:45Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=2
scope.19.lastMutationKilled=2
scope.20.id=function:skin_panel.open:123
scope.20.kind=function
scope.20.startLine=123
scope.20.endLine=125
scope.20.semanticHash=1b51c42f7eaeebb5
scope.20.lastMutatedAt=2026-06-24T16:22:45Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=1
scope.20.lastMutationKilled=1
scope.21.id=function:skin_panel.close:127
scope.21.kind=function
scope.21.startLine=127
scope.21.endLine=129
scope.21.semanticHash=0e44775dd7cd713d
scope.21.lastMutatedAt=2026-06-24T16:22:45Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=1
scope.21.lastMutationKilled=1
scope.22.id=function:skin_panel.unlock:131
scope.22.kind=function
scope.22.startLine=131
scope.22.endLine=137
scope.22.semanticHash=baf76edb5454f582
scope.22.lastMutatedAt=2026-06-24T16:22:45Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=1
scope.22.lastMutationKilled=1
scope.23.id=function:skin_panel.equip:139
scope.23.kind=function
scope.23.startLine=139
scope.23.endLine=144
scope.23.semanticHash=4a17aa7121e4e636
scope.23.lastMutatedAt=2026-06-24T16:22:45Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=1
scope.23.lastMutationKilled=1
scope.24.id=function:_unequip:146
scope.24.kind=function
scope.24.startLine=146
scope.24.endLine=148
scope.24.semanticHash=2231654b5458eaf8
scope.24.lastMutatedAt=2026-06-24T16:22:45Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=passed
scope.24.lastMutationSites=1
scope.24.lastMutationKilled=1
scope.25.id=function:_page:150
scope.25.kind=function
scope.25.startLine=150
scope.25.endLine=152
scope.25.semanticHash=227db8f6a0e88806
scope.25.lastMutatedAt=2026-06-24T16:22:45Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=passed
scope.25.lastMutationSites=1
scope.25.lastMutationKilled=1
scope.26.id=function:anonymous@155:155
scope.26.kind=function
scope.26.startLine=155
scope.26.endLine=155
scope.26.semanticHash=2b8509b5927576b5
scope.26.lastMutatedAt=2026-06-24T16:22:45Z
scope.26.lastMutationLane=behavior
scope.26.lastMutationStatus=passed
scope.26.lastMutationSites=1
scope.26.lastMutationKilled=1
scope.27.id=function:anonymous@156:156
scope.27.kind=function
scope.27.startLine=156
scope.27.endLine=156
scope.27.semanticHash=7f8d81bf9ef8d272
scope.27.lastMutatedAt=2026-06-24T16:22:45Z
scope.27.lastMutationLane=behavior
scope.27.lastMutationStatus=passed
scope.27.lastMutationSites=1
scope.27.lastMutationKilled=1
scope.28.id=function:anonymous@157:157
scope.28.kind=function
scope.28.startLine=157
scope.28.endLine=157
scope.28.semanticHash=3331fa01435529ae
scope.28.lastMutatedAt=2026-06-24T16:22:45Z
scope.28.lastMutationLane=behavior
scope.28.lastMutationStatus=passed
scope.28.lastMutationSites=1
scope.28.lastMutationKilled=1
scope.29.id=function:anonymous@158:158
scope.29.kind=function
scope.29.startLine=158
scope.29.endLine=158
scope.29.semanticHash=dbcd600f520078fe
scope.29.lastMutatedAt=2026-06-24T16:22:45Z
scope.29.lastMutationLane=behavior
scope.29.lastMutationStatus=passed
scope.29.lastMutationSites=1
scope.29.lastMutationKilled=1
scope.30.id=function:anonymous@159:159
scope.30.kind=function
scope.30.startLine=159
scope.30.endLine=159
scope.30.semanticHash=3dc0150394e77abd
scope.30.lastMutatedAt=2026-06-24T16:22:45Z
scope.30.lastMutationLane=behavior
scope.30.lastMutationStatus=passed
scope.30.lastMutationSites=1
scope.30.lastMutationKilled=1
scope.31.id=function:anonymous@160:160
scope.31.kind=function
scope.31.startLine=160
scope.31.endLine=160
scope.31.semanticHash=a33eec4d4ac99d61
scope.31.lastMutatedAt=2026-06-24T16:22:45Z
scope.31.lastMutationLane=behavior
scope.31.lastMutationStatus=passed
scope.31.lastMutationSites=1
scope.31.lastMutationKilled=1
scope.32.id=function:anonymous@161:161
scope.32.kind=function
scope.32.startLine=161
scope.32.endLine=161
scope.32.semanticHash=14db9e15eafa0779
scope.32.lastMutatedAt=2026-06-24T16:22:45Z
scope.32.lastMutationLane=behavior
scope.32.lastMutationStatus=passed
scope.32.lastMutationSites=1
scope.32.lastMutationKilled=1
scope.33.id=function:skin_panel.handle_action:164
scope.33.kind=function
scope.33.startLine=164
scope.33.endLine=171
scope.33.semanticHash=c6a84ea9baca896b
scope.33.lastMutatedAt=2026-06-24T16:22:45Z
scope.33.lastMutationLane=behavior
scope.33.lastMutationStatus=passed
scope.33.lastMutationSites=6
scope.33.lastMutationKilled=6
]]
