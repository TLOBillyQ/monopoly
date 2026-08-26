local state = require("src.config.runtime_assets.state")
local images = require("src.config.runtime_assets.images")
local board_feedback = require("src.config.runtime_assets.board_feedback")

local M = {}

local function _add_error(errors, reason, message, fields)
  local entry = fields
  entry.reason = reason
  entry.message = message
  errors[#errors + 1] = entry
end

local function _validate_startup_item_icons(errors, refs)
  for slot in ipairs(state.startup_item_ids()) do
    local icon = images.startup_item_slot_icon(slot, { refs = refs })
    if icon.ok ~= true then
      _add_error(errors, "missing_startup_item_icon", "missing startup item icon: " .. tostring(icon.lookup_key), {
        lookup_key = icon.lookup_key,
        slot_index = slot,
      })
    end
  end
end

local function _skin_product_id(skin)
  return skin and skin.product_id or nil
end

local function _validate_skin_card(errors, refs, product_id)
  local card = images.image_for_skin_card(product_id, { refs = refs })
  if card.ok ~= true then
    _add_error(errors, "missing_skin_card_image", "missing skin card image: " .. tostring(product_id), {
      product_id = product_id,
    })
  end
end

local function _validate_skin_model(errors, refs, product_id)
  local model = images.skin_model_for_product(product_id, { refs = refs })
  if model.ok ~= true then
    _add_error(errors, "missing_skin_model", "missing skin model: " .. tostring(product_id), {
      product_id = product_id,
    })
  end
end

local function _validate_skins(errors, refs)
  for _, skin in ipairs(state.skins() or {}) do
    local product_id = _skin_product_id(skin)
    _validate_skin_card(errors, refs, product_id)
    _validate_skin_model(errors, refs, product_id)
  end
end

local function _validate_cue_ref(errors, refs, cue_name, ref, kind, reason, label)
  if ref == nil then
    return
  end
  if board_feedback.resolve_asset_ref(refs, kind, ref) ~= nil then
    return
  end
  _add_error(
    errors,
    reason,
    "board feedback " .. label .. " references unknown " .. kind .. "_id_ref: " .. tostring(ref) .. " (cue_name=" .. tostring(cue_name) .. ")",
    { cue_name = cue_name, ref = ref }
  )
end

local function _validate_followup_sound(errors, refs, cue_name, entry)
  local followup_ref = entry and entry.sound_id_ref or nil
  _validate_cue_ref(
    errors,
    refs,
    cue_name,
    followup_ref,
    "sound",
    "missing_board_feedback_followup_sound",
    "followup"
  )
end

local function _validate_board_feedback(errors, refs)
  for cue_name, cue in pairs(refs.board_feedback or {}) do
    _validate_cue_ref(errors, refs, cue_name, cue.effect_id_ref, "effect", "missing_board_feedback_effect", "cue")
    _validate_cue_ref(errors, refs, cue_name, cue.sound_id_ref, "sound", "missing_board_feedback_sound", "cue")
    for _, entry in ipairs(cue.followup_sounds or {}) do
      _validate_followup_sound(errors, refs, cue_name, entry)
    end
  end
end

function M.validate_catalog(opts)
  local refs = state.refs(opts)
  local errors = {}
  _validate_board_feedback(errors, refs)
  _validate_skins(errors, refs)
  _validate_startup_item_icons(errors, refs)
  return {
    ok = #errors == 0,
    errors = errors,
  }
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=20c370b871056067
scope.0.id=chunk:src/config/runtime_assets/validation.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=107
scope.0.semanticHash=c8aa58e584dfcf29
scope.1.id=function:_add_error
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=12
scope.1.semanticHash=49fb2133f27d5b75
scope.2.id=function:_validate_startup_item_icons
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=24
scope.2.semanticHash=465cea55861e2dc6
scope.3.id=function:_skin_product_id
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=28
scope.3.semanticHash=616a2ca60599c94f
scope.4.id=function:_validate_skin_card
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=37
scope.4.semanticHash=961d1452bf17364c
scope.5.id=function:_validate_skin_model
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=46
scope.5.semanticHash=961d1452bf17364c
scope.6.id=function:_validate_skins
scope.6.kind=function
scope.6.startLine=48
scope.6.endLine=54
scope.6.semanticHash=691eb4c5b44d9233
scope.7.id=function:_validate_cue_ref
scope.7.kind=function
scope.7.startLine=56
scope.7.endLine=69
scope.7.semanticHash=95835e3517fdffe3
scope.8.id=function:_validate_followup_sound
scope.8.kind=function
scope.8.startLine=71
scope.8.endLine=82
scope.8.semanticHash=a11c92f6ba1b7412
scope.9.id=function:_validate_board_feedback
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=92
scope.9.semanticHash=fdc6647381175ea8
scope.10.id=function:M.validate_catalog
scope.10.kind=function
scope.10.startLine=94
scope.10.endLine=104
scope.10.semanticHash=d9ea3b787eaf4e3a
]]
