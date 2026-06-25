local purchase = require("src.app.cosmetics.transaction_purchase")
local completion = require("src.app.cosmetics.transaction_completion")
local transaction_context = require("src.app.cosmetics.transaction_context")
local transaction_result = require("src.app.cosmetics.transaction_result")
local transaction_state = require("src.app.cosmetics.transaction_state")

local actions = {}

local function _skin_or_rejection(panel, slot_index)
  return transaction_result.value_or_rejection(panel, transaction_state.skin_at(panel, slot_index), "missing_skin")
end

local function _open(root_state, role_id)
  local panel, rejected = transaction_result.panel_or_rejection(root_state)
  if rejected ~= nil then
    return rejected
  end
  panel.open = true
  panel.role_id = role_id
  panel.page_index = 1
  transaction_state.load_owned(panel, role_id)
  local equipped_product = transaction_state.seed_equipped(panel, role_id)
  return transaction_state.accepted(panel, {
    action = "open",
    slot_view_dirty = true,
    equipped_product = equipped_product,
    notification = "皮肤已打开",
  })
end

local function _page_delta(root_state, delta)
  local panel, rejected = transaction_result.panel_or_rejection(root_state)
  if rejected ~= nil then
    return rejected
  end
  panel.page_index = transaction_state.clamp_page((panel.page_index or 1) + delta)
  return transaction_state.accepted(panel, {
    action = "page",
    slot_view_dirty = true,
  })
end

local function _close(root_state, role_id)
  local panel, rejected = transaction_result.panel_or_rejection(root_state)
  if rejected ~= nil then
    return rejected
  end
  panel.open = false
  return transaction_state.accepted(panel, {
    action = "close",
    panel_should_close = true,
    role_id = role_id or panel.role_id,
    notification = "已关闭",
  })
end

local function _accepted_equip(panel, role_id, skin)
  return transaction_result.accepted_equipped_skin(panel, role_id, skin, {
    action = "equip",
  })
end

local function _equip_slot(root_state, role_id, slot_index)
  local panel, rejected = transaction_result.panel_or_rejection(root_state)
  if rejected ~= nil then
    return rejected
  end
  role_id = role_id or panel.role_id
  local skin, skin_rejected = _skin_or_rejection(panel, slot_index)
  if skin_rejected ~= nil then
    return skin_rejected
  end
  if not transaction_state.owns_skin(panel, role_id, skin) then
    return purchase.start(root_state, panel, role_id, skin, actions.complete_skin_purchase)
  end
  return _accepted_equip(panel, role_id, skin)
end

local function _unlock_slot(root_state, role_id, slot_index, source)
  local panel, rejected = transaction_result.panel_or_rejection(root_state)
  if rejected ~= nil then
    return rejected
  end
  role_id = role_id or panel.role_id
  local skin, skin_rejected = _skin_or_rejection(panel, slot_index)
  if skin_rejected ~= nil then
    return skin_rejected
  end
  transaction_state.mark_owned(panel, role_id, skin, source)
  return transaction_state.accepted(panel, {
    action = "unlock",
    ownership_changed = true,
    product_id = skin.product_id,
    slot_view_dirty = true,
    notification = tostring(skin.name) .. " 已解锁",
  })
end

local function _unequip(root_state, role_id)
  local panel, rejected = transaction_result.panel_or_rejection(root_state)
  if rejected ~= nil then
    return rejected
  end
  role_id = role_id or panel.role_id
  transaction_state.apply_unequip(panel, role_id)
  return transaction_state.accepted(panel, {
    action = "unequip",
    unequipped = true,
    slot_view_dirty = true,
    host_action_attempted = transaction_context.has_unequip_adapter(),
    notification = "已脱下皮肤",
  })
end

local function _request_type(request)
  if type(request) == "table" then
    return request.type or request.action
  end
  return request
end

local function _request_slot(request)
  if type(request) == "table" then
    return request.slot_index or request.index or request.slot or 1
  end
  return 1
end

local function _unlock_source(request, fallback)
  if type(request) == "table" then
    return request.source
  end
  return fallback
end

local function _unlock_handler(fallback_source)
  return function(root_state, role_id, request)
    return _unlock_slot(root_state, role_id, _request_slot(request), _unlock_source(request, fallback_source))
  end
end

local function _equip_handler(root_state, role_id, request)
  return _equip_slot(root_state, role_id, _request_slot(request))
end

local function _unknown_transaction(root_state)
  local panel = transaction_state.ensure_panel(root_state)
  return transaction_state.rejected(panel, "unknown_skin_transaction")
end

local REQUEST_HANDLERS = {
  open = function(root_state, role_id)
    return _open(root_state, role_id)
  end,
  close = function(root_state, role_id)
    return _close(root_state, role_id)
  end,
  page_next = function(root_state)
    return _page_delta(root_state, 1)
  end,
  next = function(root_state)
    return _page_delta(root_state, 1)
  end,
  page_prev = function(root_state)
    return _page_delta(root_state, -1)
  end,
  prev = function(root_state)
    return _page_delta(root_state, -1)
  end,
  unlock_slot = _unlock_handler("unlock_slot"),
  buy = _unlock_handler("buy"),
  gift = _unlock_handler("gift"),
  equip_slot = _equip_handler,
  equip = _equip_handler,
  activate_slot = _equip_handler,
  unequip = function(root_state, role_id)
    return _unequip(root_state, role_id)
  end,
}

function actions.handle_skin_transaction(root_state, role_id, request)
  local handler = REQUEST_HANDLERS[_request_type(request)]
  if handler == nil then
    return _unknown_transaction(root_state)
  end
  return handler(root_state, role_id, request)
end

function actions.complete_skin_purchase(root_state, role_id, product_id)
  return completion.complete_skin_purchase(root_state, role_id, product_id)
end

function actions.is_slot_equipped(root_state, slot_index)
  local panel = root_state and root_state.ui and root_state.ui.skin_panel or nil
  if panel == nil or panel.role_id == nil then
    return false
  end
  local skin = transaction_state.skin_at(panel, slot_index)
  if skin == nil then
    return false
  end
  local key = transaction_state.role_key(panel.role_id)
  return key ~= nil and panel.selected_by_role[key] == skin.product_id
end

return actions

--[[ mutate4lua-manifest
version=2
projectHash=66724917d18cc496
scope.0.id=chunk:src/app/cosmetics/transaction_actions.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=207
scope.0.semanticHash=7c4a4b06b2b3841d
scope.0.lastMutatedAt=2026-06-24T16:15:48Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=8
scope.0.lastMutationKilled=8
scope.1.id=function:_skin_or_rejection:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=c31135d4e0dca79b
scope.1.lastMutatedAt=2026-06-24T16:15:48Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_open:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=29
scope.2.semanticHash=b9568dcd32642406
scope.2.lastMutatedAt=2026-06-24T16:15:48Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
scope.3.id=function:_page_delta:31
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=41
scope.3.semanticHash=17a5f3c97901ae69
scope.3.lastMutatedAt=2026-06-24T16:15:48Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:_close:43
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=55
scope.4.semanticHash=6ca248ede5d790ed
scope.4.lastMutatedAt=2026-06-24T16:15:48Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=4
scope.4.lastMutationKilled=4
scope.5.id=function:_accepted_equip:57
scope.5.kind=function
scope.5.startLine=57
scope.5.endLine=61
scope.5.semanticHash=3d55f9999f7625e1
scope.5.lastMutatedAt=2026-06-24T16:15:48Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
scope.6.id=function:_equip_slot:63
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=77
scope.6.semanticHash=d6df36f71a624f3d
scope.6.lastMutatedAt=2026-06-24T16:15:48Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=9
scope.6.lastMutationKilled=9
scope.7.id=function:_unlock_slot:79
scope.7.kind=function
scope.7.startLine=79
scope.7.endLine=97
scope.7.semanticHash=b134cbec8613b2ea
scope.7.lastMutatedAt=2026-06-24T16:15:48Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=7
scope.7.lastMutationKilled=7
scope.8.id=function:_unequip:99
scope.8.kind=function
scope.8.startLine=99
scope.8.endLine=113
scope.8.semanticHash=38f3749256fa35f0
scope.8.lastMutatedAt=2026-06-24T16:15:48Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=5
scope.8.lastMutationKilled=5
scope.9.id=function:_request_type:115
scope.9.kind=function
scope.9.startLine=115
scope.9.endLine=120
scope.9.semanticHash=e78f91608ff8b006
scope.9.lastMutatedAt=2026-06-24T16:15:48Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=4
scope.9.lastMutationKilled=4
scope.10.id=function:_request_slot:122
scope.10.kind=function
scope.10.startLine=122
scope.10.endLine=127
scope.10.semanticHash=e3198cd57648fd07
scope.10.lastMutatedAt=2026-06-24T16:15:48Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=8
scope.10.lastMutationKilled=8
scope.11.id=function:_unlock_source:129
scope.11.kind=function
scope.11.startLine=129
scope.11.endLine=134
scope.11.semanticHash=736c8d43cd6d1d86
scope.11.lastMutatedAt=2026-06-24T16:15:48Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=3
scope.11.lastMutationKilled=3
scope.12.id=function:anonymous@137:137
scope.12.kind=function
scope.12.startLine=137
scope.12.endLine=139
scope.12.semanticHash=06a6a3e28adcb15f
scope.12.lastMutatedAt=2026-06-24T16:15:48Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=1
scope.12.lastMutationKilled=1
scope.13.id=function:_unlock_handler:136
scope.13.kind=function
scope.13.startLine=136
scope.13.endLine=140
scope.13.semanticHash=5007b60fc81fd2e1
scope.13.lastMutatedAt=2026-06-24T16:15:07Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=no_sites
scope.13.lastMutationSites=0
scope.13.lastMutationKilled=0
scope.14.id=function:_equip_handler:142
scope.14.kind=function
scope.14.startLine=142
scope.14.endLine=144
scope.14.semanticHash=b4f8419fa2d57e4a
scope.14.lastMutatedAt=2026-06-24T16:15:48Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=1
scope.14.lastMutationKilled=1
scope.15.id=function:_unknown_transaction:146
scope.15.kind=function
scope.15.startLine=146
scope.15.endLine=149
scope.15.semanticHash=5771a2bcf6858443
scope.15.lastMutatedAt=2026-06-24T16:15:48Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=2
scope.15.lastMutationKilled=2
scope.16.id=function:anonymous@152:152
scope.16.kind=function
scope.16.startLine=152
scope.16.endLine=154
scope.16.semanticHash=6c6254691f73251b
scope.16.lastMutatedAt=2026-06-24T16:15:48Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=1
scope.16.lastMutationKilled=1
scope.17.id=function:anonymous@155:155
scope.17.kind=function
scope.17.startLine=155
scope.17.endLine=157
scope.17.semanticHash=f65b357efa45a63d
scope.17.lastMutatedAt=2026-06-24T16:15:48Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=1
scope.17.lastMutationKilled=1
scope.18.id=function:anonymous@158:158
scope.18.kind=function
scope.18.startLine=158
scope.18.endLine=160
scope.18.semanticHash=65e448ded4436526
scope.18.lastMutatedAt=2026-06-24T16:15:48Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=1
scope.18.lastMutationKilled=1
scope.19.id=function:anonymous@161:161
scope.19.kind=function
scope.19.startLine=161
scope.19.endLine=163
scope.19.semanticHash=65e448ded4436526
scope.19.lastMutatedAt=2026-06-24T16:15:48Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=1
scope.19.lastMutationKilled=1
scope.20.id=function:anonymous@164:164
scope.20.kind=function
scope.20.startLine=164
scope.20.endLine=166
scope.20.semanticHash=339f75508ab240c1
scope.20.lastMutatedAt=2026-06-24T16:15:48Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=1
scope.20.lastMutationKilled=1
scope.21.id=function:anonymous@167:167
scope.21.kind=function
scope.21.startLine=167
scope.21.endLine=169
scope.21.semanticHash=339f75508ab240c1
scope.21.lastMutatedAt=2026-06-24T16:15:48Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=1
scope.21.lastMutationKilled=1
scope.22.id=function:anonymous@176:176
scope.22.kind=function
scope.22.startLine=176
scope.22.endLine=178
scope.22.semanticHash=9950f926525baa02
scope.22.lastMutatedAt=2026-06-24T16:15:48Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=1
scope.22.lastMutationKilled=1
scope.23.id=function:actions.handle_skin_transaction:181
scope.23.kind=function
scope.23.startLine=181
scope.23.endLine=187
scope.23.semanticHash=5897d0a4d8df518f
scope.23.lastMutatedAt=2026-06-24T16:15:48Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=4
scope.23.lastMutationKilled=4
scope.24.id=function:actions.complete_skin_purchase:189
scope.24.kind=function
scope.24.startLine=189
scope.24.endLine=191
scope.24.semanticHash=660b86a325904e6d
scope.24.lastMutatedAt=2026-06-24T16:15:48Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=passed
scope.24.lastMutationSites=1
scope.24.lastMutationKilled=1
scope.25.id=function:actions.is_slot_equipped:193
scope.25.kind=function
scope.25.startLine=193
scope.25.endLine=204
scope.25.semanticHash=aa39c4ca7c224f92
scope.25.lastMutatedAt=2026-06-24T16:15:48Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=passed
scope.25.lastMutationSites=14
scope.25.lastMutationKilled=14
]]
