local transaction_context = require("src.app.cosmetics.transaction_context")
local number_utils = require("src.foundation.number")

local state = {}

local PAGE_SIZE = 6

function state.role_key(role_id)
  if role_id == nil then
    return nil
  end
  return tostring(role_id)
end

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

function state.slot_index(panel, slot_index)
  local slot = number_utils.to_integer(slot_index) or 1
  return ((panel and panel.page_index or 1) - 1) * PAGE_SIZE + slot
end

function state.skin_at(panel, slot_index)
  return transaction_context.catalog()[state.slot_index(panel, slot_index)]
end

function state.skin_by_product(product_id)
  for _, skin in ipairs(transaction_context.catalog()) do
    if skin.product_id == product_id then
      return skin
    end
  end
  return nil
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

function state.seed_equipped(panel, role_id)
  local key = state.role_key(role_id)
  if key == nil or panel.selected_by_role[key] ~= nil then
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

function state.clamp_page(page_index)
  return number_utils.clamp(page_index, 1, number_utils.page_count(#transaction_context.catalog(), PAGE_SIZE))
end

return state

--[[ mutate4lua-manifest
version=2
projectHash=67f7e2e3abadd96c
scope.0.id=chunk:src/app/cosmetics/transaction_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=173
scope.0.semanticHash=04348c2551decb25
scope.0.lastMutatedAt=2026-06-24T16:17:17Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=10
scope.0.lastMutationKilled=10
scope.1.id=function:state.role_key:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=abfd32651262e3f4
scope.1.lastMutatedAt=2026-06-24T16:17:17Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:_new_panel:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=22
scope.2.semanticHash=a63ceda6d8c92f35
scope.2.lastMutatedAt=2026-06-24T16:17:17Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=2
scope.2.lastMutationKilled=2
scope.3.id=function:_ensure_panel_tables:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=28
scope.3.semanticHash=e1784ba56f7cc565
scope.3.lastMutatedAt=2026-06-24T16:17:17Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:state.ensure_panel:30
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=39
scope.4.semanticHash=76507f4a2d077040
scope.4.lastMutatedAt=2026-06-24T16:17:17Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=7
scope.4.lastMutationKilled=7
scope.5.id=function:state.accepted:41
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=47
scope.5.semanticHash=67693a2ea767b17f
scope.5.lastMutatedAt=2026-06-24T16:17:17Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:state.rejected:49
scope.6.kind=function
scope.6.startLine=49
scope.6.endLine=56
scope.6.semanticHash=ec6987b0b781c3c0
scope.6.lastMutatedAt=2026-06-24T16:17:17Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:state.slot_index:58
scope.7.kind=function
scope.7.startLine=58
scope.7.endLine=61
scope.7.semanticHash=5fbe96bf454430d2
scope.7.lastMutatedAt=2026-06-24T16:17:17Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=10
scope.7.lastMutationKilled=10
scope.8.id=function:state.skin_at:63
scope.8.kind=function
scope.8.startLine=63
scope.8.endLine=65
scope.8.semanticHash=634465fcbff75f70
scope.8.lastMutatedAt=2026-06-24T16:17:17Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=2
scope.8.lastMutationKilled=2
scope.9.id=function:_owned_bucket:76
scope.9.kind=function
scope.9.startLine=76
scope.9.endLine=79
scope.9.semanticHash=e88e522f1bbcc8a6
scope.9.lastMutatedAt=2026-06-24T16:17:17Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=1
scope.10.id=function:state.mark_owned:81
scope.10.kind=function
scope.10.startLine=81
scope.10.endLine=91
scope.10.semanticHash=52ad1b4690ea8cd5
scope.10.lastMutatedAt=2026-06-24T16:17:17Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=11
scope.10.lastMutationKilled=11
scope.11.id=function:state.load_owned:107
scope.11.kind=function
scope.11.startLine=107
scope.11.endLine=119
scope.11.semanticHash=d92ec4bd285f4018
scope.11.lastMutatedAt=2026-06-24T16:17:17Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=9
scope.11.lastMutationKilled=9
scope.12.id=function:state.owns_skin:121
scope.12.kind=function
scope.12.startLine=121
scope.12.endLine=125
scope.12.semanticHash=37ef79b8c2576a0f
scope.12.lastMutatedAt=2026-06-24T16:17:17Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=9
scope.12.lastMutationKilled=9
scope.13.id=function:state.apply_equip:127
scope.13.kind=function
scope.13.startLine=127
scope.13.endLine=138
scope.13.semanticHash=84d887480a842735
scope.13.lastMutatedAt=2026-06-24T16:17:17Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=6
scope.13.lastMutationKilled=6
scope.14.id=function:state.apply_unequip:140
scope.14.kind=function
scope.14.startLine=140
scope.14.endLine=149
scope.14.semanticHash=9d848443d589546d
scope.14.lastMutatedAt=2026-06-24T16:17:17Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=6
scope.14.lastMutationKilled=6
scope.15.id=function:state.seed_equipped:151
scope.15.kind=function
scope.15.startLine=151
scope.15.endLine=166
scope.15.semanticHash=6fac30690a28dfca
scope.15.lastMutatedAt=2026-06-24T16:17:17Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=12
scope.15.lastMutationKilled=12
scope.16.id=function:state.clamp_page:168
scope.16.kind=function
scope.16.startLine=168
scope.16.endLine=170
scope.16.semanticHash=c33382e722b21dfc
scope.16.lastMutatedAt=2026-06-24T16:17:17Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=1
scope.16.lastMutationKilled=1
]]
