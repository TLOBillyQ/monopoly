local purchase = require("src.app.cosmetics.transaction_purchase")
local completion = require("src.app.cosmetics.transaction_completion")
local transaction_context = require("src.app.cosmetics.transaction_context")
local transaction_result = require("src.app.cosmetics.transaction_result")
local transaction_state = require("src.app.cosmetics.transaction_state")
local request_shape = require("src.ui.schema.skin_request")
local queries = require("src.app.cosmetics.transaction_queries")

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

local function _unlock_handler(fallback_source)
  return function(root_state, role_id, request)
    return _unlock_slot(root_state, role_id, request_shape.slot_index(request), request_shape.unlock_source(request, fallback_source))
  end
end

local function _equip_handler(root_state, role_id, request)
  return _equip_slot(root_state, role_id, request_shape.slot_index(request))
end

local function _activate_slot(root_state, role_id, request)
  local panel, rejected = transaction_result.panel_or_rejection(root_state)
  if rejected ~= nil then
    return rejected
  end
  role_id = role_id or panel.role_id
  local slot_index = request_shape.slot_index(request)
  local view = transaction_state.slot_view_model(panel, role_id, slot_index)
  if view.status == "equipped" then
    return _unequip(root_state, role_id)
  end
  return _equip_slot(root_state, role_id, slot_index)
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
  activate_slot = _activate_slot,
  activate = _activate_slot,
  unequip = function(root_state, role_id)
    return _unequip(root_state, role_id)
  end,
}

function actions.handle_skin_transaction(root_state, role_id, request)
  local handler = REQUEST_HANDLERS[request_shape.kind(request)]
  if handler == nil then
    return _unknown_transaction(root_state)
  end
  return handler(root_state, role_id, request)
end

function actions.complete_skin_purchase(root_state, role_id, product_id)
  return completion.complete_skin_purchase(root_state, role_id, product_id)
end

-- Read-only slot/equip queries live in transaction_queries; re-exported here so
-- the transaction_actions API stays unchanged for the transaction facade.
actions.is_slot_equipped = queries.is_slot_equipped
actions.slot_view_model = queries.slot_view_model
actions.slot_view_models = queries.slot_view_models
actions.equipped_product = queries.equipped_product

return actions

--[[ mutate4lua-manifest
version=4
projectHash=bad140a6dd8eea38
scope.0.id=chunk:src/app/cosmetics/transaction_actions.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=197
scope.0.semanticHash=114d27f7bac51462
scope.1.id=function:_skin_or_rejection
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=63347b53abacc7da
scope.2.id=function:_open
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=31
scope.2.semanticHash=2e4776149cd8cd92
scope.3.id=function:_page_delta
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=43
scope.3.semanticHash=2b1faba2f7e9ef02
scope.4.id=function:_close
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=57
scope.4.semanticHash=6355ff8cddc7ec94
scope.5.id=function:_accepted_equip
scope.5.kind=function
scope.5.startLine=59
scope.5.endLine=63
scope.5.semanticHash=1c785814af04adc1
scope.6.id=function:_equip_slot
scope.6.kind=function
scope.6.startLine=65
scope.6.endLine=79
scope.6.semanticHash=919c65851916bf34
scope.7.id=function:_unlock_slot
scope.7.kind=function
scope.7.startLine=81
scope.7.endLine=99
scope.7.semanticHash=5da28f76ab1a8ce5
scope.8.id=function:_unequip
scope.8.kind=function
scope.8.startLine=101
scope.8.endLine=115
scope.8.semanticHash=c3662609b5895f22
scope.9.id=function:_unlock_handler
scope.9.kind=function
scope.9.startLine=117
scope.9.endLine=121
scope.9.semanticHash=078c309c1f937980
scope.10.id=function:<anonymous>
scope.10.kind=function
scope.10.startLine=118
scope.10.endLine=120
scope.10.semanticHash=b7cab765ecd03f0f
scope.11.id=function:_equip_handler
scope.11.kind=function
scope.11.startLine=123
scope.11.endLine=125
scope.11.semanticHash=6ff409bbc3be92f3
scope.12.id=function:_activate_slot
scope.12.kind=function
scope.12.startLine=127
scope.12.endLine=139
scope.12.semanticHash=01bac7f6f3868e64
scope.13.id=function:_unknown_transaction
scope.13.kind=function
scope.13.startLine=141
scope.13.endLine=144
scope.13.semanticHash=9e2d2e5af6d8ae33
scope.14.id=function:<anonymous>#2
scope.14.kind=function
scope.14.startLine=147
scope.14.endLine=149
scope.14.semanticHash=aba9250a8c6b104f
scope.15.id=function:<anonymous>#3
scope.15.kind=function
scope.15.startLine=150
scope.15.endLine=152
scope.15.semanticHash=aba9250a8c6b104f
scope.16.id=function:<anonymous>#4
scope.16.kind=function
scope.16.startLine=153
scope.16.endLine=155
scope.16.semanticHash=a86730835ea6493f
scope.17.id=function:<anonymous>#5
scope.17.kind=function
scope.17.startLine=156
scope.17.endLine=158
scope.17.semanticHash=a86730835ea6493f
scope.18.id=function:<anonymous>#6
scope.18.kind=function
scope.18.startLine=159
scope.18.endLine=161
scope.18.semanticHash=51ecd758125f2db0
scope.19.id=function:<anonymous>#7
scope.19.kind=function
scope.19.startLine=162
scope.19.endLine=164
scope.19.semanticHash=51ecd758125f2db0
scope.20.id=function:<anonymous>#8
scope.20.kind=function
scope.20.startLine=172
scope.20.endLine=174
scope.20.semanticHash=aba9250a8c6b104f
scope.21.id=function:actions.handle_skin_transaction
scope.21.kind=function
scope.21.startLine=177
scope.21.endLine=183
scope.21.semanticHash=a217e948af1fdb28
scope.22.id=function:actions.complete_skin_purchase
scope.22.kind=function
scope.22.startLine=185
scope.22.endLine=187
scope.22.semanticHash=d590c542c8c308c5
]]
