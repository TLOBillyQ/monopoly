local ui_nodes = require("src.ui.render.node_ops")
local role_id_utils = require("src.foundation.identity")
local choice_support = require("src.ui.view.choice_support")
local runtime_assets = require("src.config.runtime_assets")
local item_options = require("src.ui.coord.item_slots_options")
local item_highlight = require("src.ui.coord.item_slots_highlight")

local M = {}

local function _allow_slot_click(choice, opts, ui_model, display_player_id)
  if not choice_support.uses_item_slots(choice) then
    return false
  end
  if opts.allow_interact == false or display_player_id == nil then
    return false
  end
  local owner_id = role_id_utils.normalize(ui_model and ui_model.item_choice_owner_id or ui_model.current_player_id)
  return role_id_utils.equals(owner_id, display_player_id)
end

local _empty_items_fallback = {}

local function _resolve_item_slot_items(ui_model, display_player_id)
  local by_player = ui_model.item_slots_by_player_id or ui_model.item_slots_by_player or _empty_items_fallback
  return role_id_utils.read(by_player, display_player_id) or ui_model.item_slots or _empty_items_fallback
end

local _cached_ctx = {}
local _empty_outlines = {}
local _item_ids_pool = {}
local _nil_role_key = {}

local function _choice_from_model(ui_model)
  if ui_model == nil then
    return nil
  end
  return ui_model.choice
end

local function _display_player_id(ui_model, opts)
  return role_id_utils.normalize(opts.display_player_id or ui_model.current_player_id)
end

local function _pool_item_ids(role_id)
  local key = role_id ~= nil and role_id or _nil_role_key
  local ids = _item_ids_pool[key]
  if ids == nil then
    ids = {}
    _item_ids_pool[key] = ids
  else
    for k in pairs(ids) do ids[k] = nil end
  end
  return ids
end

local function _fill_refresh_context(ui, state, ui_model, opts, choice, display_player_id, asset_refs)
  local role_id = role_id_utils.normalize(opts.role_id)
  _cached_ctx.ui = ui
  _cached_ctx.slots = ui.item_slots
  _cached_ctx.outlines = ui.card_outlines or _empty_outlines
  _cached_ctx.item_ids = _pool_item_ids(role_id)
  _cached_ctx.role_id = role_id
  _cached_ctx.display_player_id = display_player_id
  _cached_ctx.items = _resolve_item_slot_items(ui_model, display_player_id)
  _cached_ctx.choice = choice
  _cached_ctx.allow_slot_click = _allow_slot_click(choice, opts, ui_model, display_player_id)
  _cached_ctx.option_id_set = item_options.build(choice)
  local empty_image = runtime_assets.empty_image(asset_refs)
  _cached_ctx.asset_refs = asset_refs
  _cached_ctx.empty_key = empty_image.image_key
  _cached_ctx.choice_id = choice and choice.id or nil
  _cached_ctx.suppress_flag = state._suppress_item_slot_highlight_until_pick == true
  return _cached_ctx
end

local function _build_refresh_context(state, ui_model, opts)
  local ui = state.ui
  assert(ui ~= nil and ui.item_slots ~= nil, "missing ui item slots")
  opts = opts or {}
  local choice = _choice_from_model(ui_model)
  local asset_refs = runtime_assets.asset_context(state)
  return _fill_refresh_context(ui, state, ui_model, opts, choice, _display_player_id(ui_model, opts), asset_refs)
end

local _slot_pickable = {}

local function _sync_one_slot(ctx, slot_name, item_id, slot_state, index, slot_pickable)
  if item_id then
    local image = runtime_assets.image_for_item(item_id, ctx.asset_refs)
    local image_key = image.ok == true and image.image_key or ctx.empty_key
    ui_nodes.set_item_slot_image(slot_name, image_key)
    local is_pickable = ctx.allow_slot_click and ctx.option_id_set[tostring(item_id)] == true
    ctx.ui:set_touch_enabled(slot_name, is_pickable or (slot_state and slot_state.item_id ~= nil and not slot_state.available))
    ctx.item_ids[index] = item_id
    slot_pickable[index] = is_pickable
  else
    ui_nodes.set_item_slot_image(slot_name, ctx.empty_key)
    ctx.ui:set_touch_enabled(slot_name, false)
    slot_pickable[index] = false
  end
end

local function _sync_slot_images(ctx)
  for i = 1, #_slot_pickable do _slot_pickable[i] = nil end
  local slot_pickable = _slot_pickable
  for index, slot_name in ipairs(ctx.slots) do
    local slot_state = ctx.choice and ctx.choice.slot_states and ctx.choice.slot_states[index]
    local item_id = (slot_state and slot_state.item_id) or ctx.items[index]
    _sync_one_slot(ctx, slot_name, item_id, slot_state, index, slot_pickable)
  end
  return slot_pickable
end

local function _store_item_ids(ui, role_id, item_ids)
  if role_id ~= nil then
    if type(ui.item_slot_item_ids_by_role) ~= "table" then
      ui.item_slot_item_ids_by_role = {}
    end
    role_id_utils.write(ui.item_slot_item_ids_by_role, role_id, item_ids)
  end
  ui.item_slot_item_ids = item_ids
end

function M.refresh_item_slots(state, ui_model, opts)
  item_highlight.maybe_emit_phase_advance_reset(state)
  local ctx = _build_refresh_context(state, ui_model, opts)
  local slot_pickable = _sync_slot_images(ctx)
  item_highlight.refresh_highlight_state(state, ctx, slot_pickable)
  _store_item_ids(ctx.ui, ctx.role_id, ctx.item_ids)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=1335dce76b1c54b4
scope.0.id=chunk:src/ui/coord/item_slots.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=133
scope.0.semanticHash=d18c33dfdfbfe732
scope.0.lastMutatedAt=2026-06-24T20:09:54Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=18
scope.0.lastMutationKilled=17
scope.1.id=function:_allow_slot_click:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=19
scope.1.semanticHash=3871380c222c614f
scope.1.lastMutatedAt=2026-06-24T20:09:54Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=10
scope.1.lastMutationKilled=7
scope.2.id=function:_resolve_item_slot_items:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=26
scope.2.semanticHash=ba616ef1ceb396da
scope.2.lastMutatedAt=2026-06-24T20:09:54Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_choice_from_model:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=38
scope.3.semanticHash=d83308e2abaef772
scope.3.lastMutatedAt=2026-06-24T20:09:54Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:_display_player_id:40
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=42
scope.4.semanticHash=3caaed806cfb68c0
scope.4.lastMutatedAt=2026-06-24T20:09:54Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_fill_refresh_context:56
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=74
scope.5.semanticHash=c7c3924b71c6c128
scope.5.lastMutatedAt=2026-06-24T20:09:54Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=survived
scope.5.lastMutationSites=11
scope.5.lastMutationKilled=10
scope.6.id=function:_build_refresh_context:76
scope.6.kind=function
scope.6.startLine=76
scope.6.endLine=83
scope.6.semanticHash=35514b94e4d1c576
scope.6.lastMutatedAt=2026-06-24T20:09:54Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=5
scope.6.lastMutationKilled=5
scope.7.id=function:_sync_one_slot:87
scope.7.kind=function
scope.7.startLine=87
scope.7.endLine=101
scope.7.semanticHash=7549a722bc11b7a4
scope.7.lastMutatedAt=2026-06-24T20:09:54Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=14
scope.7.lastMutationKilled=14
scope.8.id=function:_store_item_ids:114
scope.8.kind=function
scope.8.startLine=114
scope.8.endLine=122
scope.8.semanticHash=e9796614510cf9b3
scope.8.lastMutatedAt=2026-06-24T20:09:54Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=5
scope.8.lastMutationKilled=5
scope.9.id=function:M.refresh_item_slots:124
scope.9.kind=function
scope.9.startLine=124
scope.9.endLine=130
scope.9.semanticHash=d714c5d80c9dfe79
scope.9.lastMutatedAt=2026-06-24T20:09:54Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=5
scope.9.lastMutationKilled=5
]]
