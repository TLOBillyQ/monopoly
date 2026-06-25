local state = require("src.config.runtime_assets.state")
local images = require("src.config.runtime_assets.images")
local board_feedback = require("src.config.runtime_assets.board_feedback")

local M = {}

local function _add_error(errors, reason, message, fields)
  local entry = fields or {}
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

local function _validate_skins(errors, refs)
  for _, skin in ipairs(state.skins() or {}) do
    local product_id = skin and skin.product_id or nil
    local card = images.image_for_skin_card(product_id, { refs = refs })
    if card.ok ~= true then
      _add_error(errors, "missing_skin_card_image", "missing skin card image: " .. tostring(product_id), {
        product_id = product_id,
      })
    end
    local model = images.skin_model_for_product(product_id, { refs = refs })
    if model.ok ~= true then
      _add_error(errors, "missing_skin_model", "missing skin model: " .. tostring(product_id), {
        product_id = product_id,
      })
    end
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
version=2
projectHash=f7455a2fa95e15e3
scope.0.id=chunk:src/config/runtime_assets/validation.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=95
scope.0.semanticHash=13503b5d51e66f30
scope.0.lastMutatedAt=2026-06-24T20:09:37Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=24
scope.0.lastMutationKilled=24
scope.1.id=function:_add_error:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=12
scope.1.semanticHash=d3bf182cedba7019
scope.1.lastMutatedAt=2026-06-24T20:09:37Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=2
scope.2.id=function:_validate_cue_ref:44
scope.2.kind=function
scope.2.startLine=44
scope.2.endLine=57
scope.2.semanticHash=858ac6aa7ab104ed
scope.2.lastMutatedAt=2026-06-24T20:09:37Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_validate_followup_sound:59
scope.3.kind=function
scope.3.startLine=59
scope.3.endLine=70
scope.3.semanticHash=a80970767283763a
scope.3.lastMutatedAt=2026-06-24T20:09:37Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:M.validate_catalog:82
scope.4.kind=function
scope.4.startLine=82
scope.4.endLine=92
scope.4.semanticHash=8747823cfe883dd7
scope.4.lastMutatedAt=2026-06-24T20:09:37Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=6
scope.4.lastMutationKilled=6
]]
