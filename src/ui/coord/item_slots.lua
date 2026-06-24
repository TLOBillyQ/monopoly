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
  local empty_image = runtime_assets.empty_image({ refs = asset_refs })
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
  local asset_refs = state.ui_refs or {}
  return _fill_refresh_context(ui, state, ui_model, opts, choice, _display_player_id(ui_model, opts), asset_refs)
end

local _slot_pickable = {}

local function _sync_one_slot(ctx, slot_name, item_id, slot_state, index, slot_pickable)
  if item_id then
    local image = runtime_assets.image_for_item(item_id, { refs = ctx.asset_refs })
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
projectHash=944eb3b6ed3f8bf9
scope.0.id=chunk:src/ui/coord/item_slots.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=332
scope.0.semanticHash=031da152ae092f81
scope.0.lastMutatedAt=2026-06-01T12:37:08Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=58
scope.0.lastMutationKilled=57
scope.1.id=function:anonymous@39:39
scope.1.kind=function
scope.1.startLine=39
scope.1.endLine=43
scope.1.semanticHash=05a8e8375f6932b3
scope.1.lastMutatedAt=2026-06-01T12:37:08Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=2
scope.2.id=function:_outline_setter:38
scope.2.kind=function
scope.2.startLine=38
scope.2.endLine=44
scope.2.semanticHash=860102431601b34f
scope.3.id=function:_emit_ui_event:51
scope.3.kind=function
scope.3.startLine=51
scope.3.endLine=58
scope.3.semanticHash=351fb5ff63da3387
scope.3.lastMutatedAt=2026-06-01T12:37:08Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=survived
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=2
scope.4.id=function:_emit_slot_animation:60
scope.4.kind=function
scope.4.startLine=60
scope.4.endLine=62
scope.4.semanticHash=07854e5fa8cb20f3
scope.4.lastMutatedAt=2026-06-01T12:37:08Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_emit_global_reset_animation:64
scope.5.kind=function
scope.5.startLine=64
scope.5.endLine=66
scope.5.semanticHash=c3fce68a00b83e20
scope.5.lastMutatedAt=2026-06-01T12:37:08Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
scope.6.id=function:_resolve_gate_key:84
scope.6.kind=function
scope.6.startLine=84
scope.6.endLine=86
scope.6.semanticHash=b1bc7b5f345bc691
scope.6.lastMutatedAt=2026-06-01T12:37:08Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=5
scope.6.lastMutationKilled=5
scope.7.id=function:_ensure_gate_store:88
scope.7.kind=function
scope.7.startLine=88
scope.7.endLine=95
scope.7.semanticHash=f22f6488e2bbb859
scope.7.lastMutatedAt=2026-06-01T12:37:08Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=3
scope.8.id=function:_allow_slot_click:121
scope.8.kind=function
scope.8.startLine=121
scope.8.endLine=130
scope.8.semanticHash=3871380c222c614f
scope.8.lastMutatedAt=2026-06-01T12:37:08Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=survived
scope.8.lastMutationSites=10
scope.8.lastMutationKilled=7
scope.9.id=function:_resolve_item_slot_items:134
scope.9.kind=function
scope.9.startLine=134
scope.9.endLine=137
scope.9.semanticHash=ba616ef1ceb396da
scope.9.lastMutatedAt=2026-06-01T12:37:08Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=5
scope.9.lastMutationKilled=5
scope.10.id=function:_fill_refresh_context:156
scope.10.kind=function
scope.10.startLine=156
scope.10.endLine=172
scope.10.semanticHash=403ab31ba8476917
scope.10.lastMutatedAt=2026-06-01T12:37:08Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=survived
scope.10.lastMutationSites=11
scope.10.lastMutationKilled=10
scope.11.id=function:_build_refresh_context:174
scope.11.kind=function
scope.11.startLine=174
scope.11.endLine=183
scope.11.semanticHash=f2b0ab0352b0722f
scope.11.lastMutatedAt=2026-06-01T12:37:08Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=8
scope.11.lastMutationKilled=8
scope.12.id=function:_sync_one_slot:187
scope.12.kind=function
scope.12.startLine=187
scope.12.endLine=200
scope.12.semanticHash=d1b6f42781dd4857
scope.12.lastMutatedAt=2026-06-01T12:37:08Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=13
scope.12.lastMutationKilled=13
scope.13.id=function:anonymous@215:215
scope.13.kind=function
scope.13.startLine=215
scope.13.endLine=221
scope.13.semanticHash=b8995c6da87c4c89
scope.14.id=function:_schedule_highlight_ready:213
scope.14.kind=function
scope.14.startLine=213
scope.14.endLine=222
scope.14.semanticHash=e6edfa6e783b4a10
scope.14.lastMutatedAt=2026-06-01T12:37:08Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=survived
scope.14.lastMutationSites=2
scope.14.lastMutationKilled=1
scope.15.id=function:_refresh_item_phase_gate:224
scope.15.kind=function
scope.15.startLine=224
scope.15.endLine=243
scope.15.semanticHash=f77d6eae0c08384a
scope.15.lastMutatedAt=2026-06-01T12:37:08Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=survived
scope.15.lastMutationSites=14
scope.15.lastMutationKilled=9
scope.16.id=function:_should_skip_highlight_replay:245
scope.16.kind=function
scope.16.startLine=245
scope.16.endLine=249
scope.16.semanticHash=d8f7e191ec60f817
scope.16.lastMutatedAt=2026-06-01T12:37:08Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=7
scope.16.lastMutationKilled=7
scope.17.id=function:_refresh_item_phase_ask_highlight:251
scope.17.kind=function
scope.17.startLine=251
scope.17.endLine=254
scope.17.semanticHash=84b175a10b55fb71
scope.17.lastMutatedAt=2026-06-01T12:37:08Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=2
scope.17.lastMutationKilled=2
scope.18.id=function:_should_replay_passive_animation:256
scope.18.kind=function
scope.18.startLine=256
scope.18.endLine=265
scope.18.semanticHash=535cdcfdc16a641f
scope.18.lastMutatedAt=2026-06-01T12:37:08Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=5
scope.18.lastMutationKilled=5
scope.19.id=function:_update_passive_gate:267
scope.19.kind=function
scope.19.startLine=267
scope.19.endLine=282
scope.19.semanticHash=7a4b272a55d46a5a
scope.19.lastMutatedAt=2026-06-01T12:37:08Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=survived
scope.19.lastMutationSites=11
scope.19.lastMutationKilled=10
scope.20.id=function:_refresh_highlight_state:284
scope.20.kind=function
scope.20.startLine=284
scope.20.endLine=297
scope.20.semanticHash=478a6ac6ef355da5
scope.20.lastMutatedAt=2026-06-01T12:37:08Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=10
scope.20.lastMutationKilled=10
scope.21.id=function:_store_item_ids:299
scope.21.kind=function
scope.21.startLine=299
scope.21.endLine=307
scope.21.semanticHash=e9796614510cf9b3
scope.21.lastMutatedAt=2026-06-01T12:37:08Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=5
scope.21.lastMutationKilled=5
scope.22.id=function:_maybe_emit_phase_advance_reset:309
scope.22.kind=function
scope.22.startLine=309
scope.22.endLine=320
scope.22.semanticHash=0c6f7612e7ab137d
scope.22.lastMutatedAt=2026-06-01T12:37:08Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=9
scope.22.lastMutationKilled=9
scope.23.id=function:M.refresh_item_slots:322
scope.23.kind=function
scope.23.startLine=322
scope.23.endLine=329
scope.23.semanticHash=379add66338b1239
scope.23.lastMutatedAt=2026-06-01T12:37:08Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=7
scope.23.lastMutationKilled=7
]]
