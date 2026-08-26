local transaction_context = require("src.app.cosmetics.transaction_context")
local read_model = require("src.app.cosmetics.transaction_read_model")

local state = {}

-- Catalog indexing and slot view-model projections live in
-- transaction_read_model; re-exported here so the transaction_state API stays
-- unchanged for existing callers.
state.role_key = read_model.role_key
state.slot_index = read_model.slot_index
state.skin_at = read_model.skin_at
state.skin_by_product = read_model.skin_by_product
state.clamp_page = read_model.clamp_page
state.slot_view_model = read_model.slot_view_model
state.slot_view_models = read_model.slot_view_models

local function _new_panel()
  return {
    open = false,
    page_index = 1,
    owned_by_role = {},
    selected_by_role = {},
  }
end

local function _ensure_panel_tables(panel)
  panel.owned_by_role = panel.owned_by_role or {}
  panel.selected_by_role = panel.selected_by_role or {}
  panel.pending_skin_purchase_by_role = panel.pending_skin_purchase_by_role or {}
end

function state.ensure_panel(root_state)
  local ui = root_state and root_state.ui or nil
  if ui == nil then
    return nil, "missing_state"
  end
  ui.skin_panel = ui.skin_panel or _new_panel()
  local panel = ui.skin_panel
  _ensure_panel_tables(panel)
  return panel, nil
end

function state.accepted(panel, fields)
  local result = fields or {}
  result.accepted = true
  result.ok = true
  result.panel = panel
  return result
end

function state.rejected(panel, reason, fields)
  local result = fields or {}
  result.accepted = false
  result.ok = false
  result.reason = reason
  result.panel = panel
  return result
end

local function _owned_bucket(panel, key)
  panel.owned_by_role[key] = panel.owned_by_role[key] or {}
  return panel.owned_by_role[key]
end

function state.mark_owned(panel, role_id, skin, source)
  local key = state.role_key(role_id)
  if key == nil or skin == nil then
    return false
  end
  _owned_bucket(panel, key)[skin.product_id] = true
  if source == "purchase" then
    transaction_context.archive_call("mark_owned", role_id, skin.product_id)
  end
  return true
end

local function _load_owned_list(bucket, owned)
  for _, product_id in ipairs(owned) do
    bucket[product_id] = true
  end
end

local function _load_owned_map(bucket, owned)
  for product_id, is_owned in pairs(owned) do
    if is_owned == true then
      bucket[product_id] = true
    end
  end
end

function state.load_owned(panel, role_id)
  local key = state.role_key(role_id)
  if key == nil then
    return
  end
  local owned = transaction_context.archive_call("load_owned", role_id)
  if type(owned) ~= "table" then
    return
  end
  local bucket = _owned_bucket(panel, key)
  _load_owned_list(bucket, owned)
  _load_owned_map(bucket, owned)
end

function state.owns_skin(panel, role_id, skin)
  local key = state.role_key(role_id)
  local bucket = key and panel.owned_by_role[key] or nil
  return bucket ~= nil and skin ~= nil and bucket[skin.product_id] == true
end

local function _effective_role_id(panel, role_id)
  return role_id or (panel and panel.role_id)
end

function state.equipped_product(panel, role_id)
  local key = state.role_key(_effective_role_id(panel, role_id))
  if key == nil or panel == nil or panel.selected_by_role == nil then
    return nil
  end
  return panel.selected_by_role[key]
end

function state.apply_equip(panel, role_id, skin)
  local key = state.role_key(role_id)
  if key == nil then
    return false
  end
  local applied = transaction_context.call_equip_adapter(role_id, skin)
  panel.last_equip_ok_by_role = panel.last_equip_ok_by_role or {}
  panel.last_equip_ok_by_role[key] = applied
  panel.selected_by_role[key] = skin.product_id
  transaction_context.archive_call("save_equipped", role_id, skin.product_id)
  return applied
end

function state.apply_unequip(panel, role_id)
  local key = state.role_key(role_id)
  if key == nil then
    return false
  end
  panel.selected_by_role[key] = nil
  transaction_context.archive_call("save_equipped", role_id, nil)
  transaction_context.call_unequip_adapter(role_id)
  return true
end

local function _needs_seed(panel, key)
  return key ~= nil and panel.selected_by_role[key] == nil
end

function state.seed_equipped(panel, role_id)
  local key = state.role_key(role_id)
  if not _needs_seed(panel, key) then
    return nil
  end
  local product_id = transaction_context.archive_call("load_equipped", role_id)
  if product_id == nil then
    return nil
  end
  local skin = state.skin_by_product(product_id)
  if skin == nil or not state.owns_skin(panel, role_id, skin) then
    return nil
  end
  state.apply_equip(panel, role_id, skin)
  return skin.product_id
end

return state

--[[ mutate4lua-manifest
version=4
projectHash=7d0e7bb1b74cb5f4
scope.0.id=chunk:src/app/cosmetics/transaction_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=169
scope.0.semanticHash=4e351b0c64ee5825
scope.1.id=function:_new_panel
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=24
scope.1.semanticHash=77324e028a8321dd
scope.2.id=function:_ensure_panel_tables
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=30
scope.2.semanticHash=9a496b0ec2439ef9
scope.3.id=function:state.ensure_panel
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=41
scope.3.semanticHash=48e9f67cb824be8c
scope.4.id=function:state.accepted
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=49
scope.4.semanticHash=de6b276d90724955
scope.5.id=function:state.rejected
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=58
scope.5.semanticHash=e567144210684a74
scope.6.id=function:_owned_bucket
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=63
scope.6.semanticHash=ab89aad3c16bd12f
scope.7.id=function:state.mark_owned
scope.7.kind=function
scope.7.startLine=65
scope.7.endLine=75
scope.7.semanticHash=9ef0ffce060137d2
scope.8.id=function:_load_owned_list
scope.8.kind=function
scope.8.startLine=77
scope.8.endLine=81
scope.8.semanticHash=6072abcc0e9cc930
scope.9.id=function:_load_owned_map
scope.9.kind=function
scope.9.startLine=83
scope.9.endLine=89
scope.9.semanticHash=23f7a77c8121bc64
scope.10.id=function:state.load_owned
scope.10.kind=function
scope.10.startLine=91
scope.10.endLine=103
scope.10.semanticHash=116c2a02ad6c268e
scope.11.id=function:state.owns_skin
scope.11.kind=function
scope.11.startLine=105
scope.11.endLine=109
scope.11.semanticHash=fb7f241cfe332af8
scope.12.id=function:_effective_role_id
scope.12.kind=function
scope.12.startLine=111
scope.12.endLine=113
scope.12.semanticHash=6c82c3388b24bf4e
scope.13.id=function:state.equipped_product
scope.13.kind=function
scope.13.startLine=115
scope.13.endLine=121
scope.13.semanticHash=ac77c6ec72b73cc9
scope.14.id=function:state.apply_equip
scope.14.kind=function
scope.14.startLine=123
scope.14.endLine=134
scope.14.semanticHash=180d85e4c22e563f
scope.15.id=function:state.apply_unequip
scope.15.kind=function
scope.15.startLine=136
scope.15.endLine=145
scope.15.semanticHash=972f122cf735711e
scope.16.id=function:_needs_seed
scope.16.kind=function
scope.16.startLine=147
scope.16.endLine=149
scope.16.semanticHash=642c658f20bdc84f
scope.17.id=function:state.seed_equipped
scope.17.kind=function
scope.17.startLine=151
scope.17.endLine=166
scope.17.semanticHash=801b7117c21cb45d
]]
