local default_refs = require("src.config.content.runtime_refs")
local default_skins = require("src.config.content.skins")
local default_constants = require("src.config.gameplay.runtime_constants")
local number_utils = require("src.foundation.number")

local runtime_assets = {}

local active_refs = default_refs
local active_skins = default_skins
local active_constants = default_constants
local active_startup_item_ids = { 3001, 3002, 3003, 3004, 3005 }

local function _key(value)
  if value == nil then
    return nil
  end
  return tostring(value)
end

local function _refs(opts)
  if type(opts) == "table" and type(opts.refs) == "table" then
    return opts.refs
  end
  if type(opts) == "table" and type(opts.images) == "table" then
    return opts
  end
  return active_refs
end

local function _images(opts)
  return _refs(opts).images or {}
end

local function _result(meaning, fields)
  local out = fields or {}
  out.meaning = meaning
  out.ok = out.ok ~= false
  return out
end

local function _missing(meaning, reason, fields)
  local out = fields or {}
  out.meaning = meaning
  out.ok = false
  out.reason = reason
  return out
end

local function _image_result(meaning, raw_key, reason, opts)
  local image_key = raw_key ~= nil and _images(opts)[_key(raw_key)] or nil
  if image_key == nil then
    return _missing(meaning, reason, {
      lookup_key = _key(raw_key),
    })
  end
  return _result(meaning, {
    image_key = image_key,
    asset_id = image_key,
    lookup_key = _key(raw_key),
    fallback_used = false,
  })
end

function runtime_assets.image_for_item(item_id, opts)
  return _image_result("item.icon", item_id, "missing_item_icon", opts)
end

function runtime_assets.image_for_chance_card(card_id, opts)
  return _image_result("chance.icon", card_id, "missing_chance_card_icon", opts)
end

function runtime_assets.image_for_skin_card(product_id, opts)
  return _image_result("skin.card_image", product_id, "missing_skin_card_image", opts)
end

function runtime_assets.empty_image(opts)
  return _image_result("empty.image", "Empty", "missing_empty_image", opts)
end

function runtime_assets.image_for_popup_card(kind, image_ref, opts)
  local meaning = kind == "item_card" and "popup.item_card_image" or "popup.chance_card_image"
  return _image_result(meaning, image_ref, "missing_popup_card_image", opts)
end

function runtime_assets.image_for_market_item(product_id, display_name, opts)
  local primary = _image_result("market.item_icon", product_id, "missing_market_item_icon", opts)
  if primary.ok == true or display_name == nil or display_name == "" then
    return primary
  end
  local fallback = _image_result("market.item_icon", display_name, "missing_market_item_icon", opts)
  fallback.primary_lookup_key = primary.lookup_key
  fallback.fallback_used = fallback.ok == true
  return fallback
end

function runtime_assets.image_for_market_rarity(ref_key, opts)
  return _image_result("market.rarity_frame", ref_key, "missing_market_rarity_frame", opts)
end

function runtime_assets.startup_item_slot_icon(slot_index, opts)
  local slot = number_utils.to_integer(slot_index)
  local raw_key = slot and active_startup_item_ids[slot] or nil
  return _image_result("ui.startup_item_slot_icon", raw_key, "missing_startup_item_icon", opts)
end

function runtime_assets.skin_model_for_product(product_id, opts)
  local refs = _refs(opts)
  local asset_id = product_id ~= nil and (refs.skins or {})[_key(product_id)] or nil
  if asset_id == nil then
    return _missing("skin.model", "missing_skin_model", {
      lookup_key = _key(product_id),
    })
  end
  return _result("skin.model", {
    asset_id = asset_id,
    lookup_key = _key(product_id),
    fallback_used = false,
  })
end

function runtime_assets.default_skin_model(opts)
  local asset_id = _refs(opts).default_creature
  if asset_id == nil then
    return _missing("skin.default_model", "missing_default_skin_model")
  end
  return _result("skin.default_model", {
    asset_id = asset_id,
    fallback_used = false,
  })
end

local function _synthetic_name(slot_index, cfg)
  local names = cfg.names or {}
  return names[slot_index] or ("AI" .. tostring(slot_index))
end

function runtime_assets.synthetic_ai_profile(slot_index, opts)
  local slot = number_utils.to_integer(slot_index) or 1
  local refs = _refs(opts)
  local cfg = refs.synthetic_ai or {}
  local unit_key = type(opts) == "table" and opts.unit_key or nil
  if unit_key == nil then
    unit_key = (cfg.unit_keys or {})[slot]
  end
  local avatar = runtime_assets.image_for_chance_card("AI" .. tostring(slot), opts)
  local fallback_used = false
  local reason = nil
  if avatar.ok ~= true then
    avatar = runtime_assets.empty_image(opts)
    fallback_used = true
    reason = "missing_synthetic_ai_avatar"
  end
  return _result("synthetic_ai.profile", {
    slot_index = slot,
    name = _synthetic_name(slot, cfg),
    unit_key = unit_key,
    avatar_image_key = avatar.image_key,
    avatar_result = avatar,
    fallback_used = fallback_used,
    reason = reason,
  })
end

function runtime_assets.synthetic_ai_unit_key_pool(opts)
  local refs = _refs(opts)
  local unit_keys = ((refs.synthetic_ai or {}).unit_keys) or {}
  local out = {}
  for index, unit_key in ipairs(unit_keys) do
    out[index] = unit_key
  end
  return out
end

local function _warn_invalid_number(cue_name, field, value, reason)
  local logger = require("src.foundation.log")
  logger.warn(
    "board_feedback",
    "invalid cue config",
    "cue_name=" .. tostring(cue_name),
    "field=" .. tostring(field),
    "value=" .. tostring(value),
    "reason=" .. tostring(reason)
  )
end

local function _resolve_numeric_field(cue_name, field, value)
  if value == nil then
    return nil
  end
  if number_utils.is_numeric(value) then
    return value + 0
  end
  local reason = type(value) == "table" and "vector_like_not_allowed" or "non_numeric"
  _warn_invalid_number(cue_name, field, value, reason)
  return nil
end

local function _cue_value(cue, payload, field)
  if type(payload) == "table" and payload[field] ~= nil then
    return payload[field]
  end
  return cue and cue[field] or nil
end

local function _cue_numeric(cue_name, cue, payload, field)
  return _resolve_numeric_field(cue_name, field, _cue_value(cue, payload, field))
end

local function _resolve_asset_ref(refs, kind, ref_name)
  if type(ref_name) ~= "string" or ref_name == "" then
    return nil
  end
  local table_name = kind == "effect" and "effects" or "audio"
  return number_utils.to_integer((refs[table_name] or {})[ref_name])
end

local function _cue_asset_id(refs, cue, payload, kind)
  local explicit = number_utils.to_integer(type(payload) == "table" and payload[kind .. "_id"] or nil)
  if explicit ~= nil then
    return explicit
  end
  local ref_name = _cue_value(cue, payload, kind .. "_id_ref")
  return _resolve_asset_ref(refs, kind, ref_name), ref_name
end

local function _resolve_bind_offset(value, constants)
  if type(value) == "string" then
    return constants[value]
  end
  return value
end

local function _followup_sound(refs, cue_name, entry)
  if type(entry) ~= "table" then
    return nil
  end
  local explicit = number_utils.to_integer(entry.sound_id)
  local sound_id = explicit or _resolve_asset_ref(refs, "sound", entry.sound_id_ref)
  return {
    cue_name = cue_name,
    sound_id = sound_id,
    sound_id_ref = entry.sound_id_ref,
    delay = _resolve_numeric_field(cue_name, "followup_sounds.delay", entry.delay),
    duration = _resolve_numeric_field(cue_name, "followup_sounds.duration", entry.duration),
    volume = _resolve_numeric_field(cue_name, "followup_sounds.volume", entry.volume),
  }
end

local function _followup_sounds(refs, cue_name, cue, payload)
  local entries = type(payload) == "table" and payload.followup_sounds or nil
  if entries == nil then
    entries = cue and cue.followup_sounds or nil
  end
  if type(entries) ~= "table" then
    return nil
  end
  local out = {}
  for _, entry in ipairs(entries) do
    local resolved = _followup_sound(refs, cue_name, entry)
    if resolved ~= nil then
      out[#out + 1] = resolved
    end
  end
  return out
end

function runtime_assets.board_feedback_cue(cue_name, payload, opts)
  local refs = _refs(opts)
  local cue = type(cue_name) == "string" and (refs.board_feedback or {})[cue_name] or nil
  if cue == nil then
    return _missing("board_feedback.cue", "missing_board_feedback_cue", {
      cue_name = cue_name,
    })
  end
  return _result("board_feedback.cue", {
    cue_name = cue_name,
    effect_id = _cue_asset_id(refs, cue, payload, "effect"),
    effect_lookup_key = _cue_value(cue, payload, "effect_id_ref"),
    sound_id = _cue_asset_id(refs, cue, payload, "sound"),
    sound_lookup_key = _cue_value(cue, payload, "sound_id_ref"),
    scale = _cue_numeric(cue_name, cue, payload, "scale"),
    rate = _cue_numeric(cue_name, cue, payload, "rate"),
    duration = _cue_numeric(cue_name, cue, payload, "duration"),
    volume = _cue_numeric(cue_name, cue, payload, "volume"),
    delay = _cue_numeric(cue_name, cue, payload, "delay"),
    sound_duration = _cue_numeric(cue_name, cue, payload, "sound_duration"),
    rot = _cue_value(cue, payload, "rot"),
    with_sound = _cue_value(cue, payload, "with_sound"),
    bind_to_player = cue.bind_to_player,
    bind_type = cue.bind_type,
    socket_name = cue.socket_name,
    bind_offset = _resolve_bind_offset(_cue_value(cue, payload, "bind_offset"), active_constants),
    allow_missing = cue.allow_missing_resource == true,
    followup_sounds = _followup_sounds(refs, cue_name, cue, payload),
  })
end

local function _add_error(errors, reason, message, fields)
  local entry = fields or {}
  entry.reason = reason
  entry.message = message
  errors[#errors + 1] = entry
end

local function _validate_startup_item_icons(errors, refs)
  for slot in ipairs(active_startup_item_ids) do
    local icon = runtime_assets.startup_item_slot_icon(slot, { refs = refs })
    if icon.ok ~= true then
      _add_error(errors, "missing_startup_item_icon", "missing startup item icon: " .. tostring(icon.lookup_key), {
        lookup_key = icon.lookup_key,
        slot_index = slot,
      })
    end
  end
end

local function _validate_skins(errors, refs)
  for _, skin in ipairs(active_skins or {}) do
    local product_id = skin and skin.product_id or nil
    local card = runtime_assets.image_for_skin_card(product_id, { refs = refs })
    if card.ok ~= true then
      _add_error(errors, "missing_skin_card_image", "missing skin card image: " .. tostring(product_id), {
        product_id = product_id,
      })
    end
    local model = runtime_assets.skin_model_for_product(product_id, { refs = refs })
    if model.ok ~= true then
      _add_error(errors, "missing_skin_model", "missing skin model: " .. tostring(product_id), {
        product_id = product_id,
      })
    end
  end
end

local function _validate_board_feedback(errors, refs)
  for cue_name, cue in pairs(refs.board_feedback or {}) do
    if cue.effect_id_ref ~= nil and _resolve_asset_ref(refs, "effect", cue.effect_id_ref) == nil then
      _add_error(
        errors,
        "missing_board_feedback_effect",
        "board feedback cue references unknown effect_id_ref: " .. tostring(cue.effect_id_ref) .. " (cue_name=" .. tostring(cue_name) .. ")",
        { cue_name = cue_name, ref = cue.effect_id_ref }
      )
    end
    if cue.sound_id_ref ~= nil and _resolve_asset_ref(refs, "sound", cue.sound_id_ref) == nil then
      _add_error(
        errors,
        "missing_board_feedback_sound",
        "board feedback cue references unknown sound_id_ref: " .. tostring(cue.sound_id_ref) .. " (cue_name=" .. tostring(cue_name) .. ")",
        { cue_name = cue_name, ref = cue.sound_id_ref }
      )
    end
    for _, entry in ipairs(cue.followup_sounds or {}) do
      local followup_ref = entry and entry.sound_id_ref or nil
      if followup_ref ~= nil and _resolve_asset_ref(refs, "sound", followup_ref) == nil then
        _add_error(
          errors,
          "missing_board_feedback_followup_sound",
          "board feedback followup references unknown sound_id_ref: " .. tostring(followup_ref) .. " (cue_name=" .. tostring(cue_name) .. ")",
          { cue_name = cue_name, ref = followup_ref }
        )
      end
    end
  end
end

function runtime_assets.validate_catalog(opts)
  local refs = _refs(opts)
  local errors = {}
  _validate_board_feedback(errors, refs)
  _validate_skins(errors, refs)
  _validate_startup_item_icons(errors, refs)
  return {
    ok = #errors == 0,
    errors = errors,
  }
end

function runtime_assets.compat_refs()
  return active_refs
end

function runtime_assets.configure_for_tests(opts)
  opts = opts or {}
  active_refs = opts.refs or default_refs
  active_skins = opts.skins or default_skins
  active_constants = opts.constants or default_constants
  active_startup_item_ids = opts.startup_item_ids or { 3001, 3002, 3003, 3004, 3005 }
end

function runtime_assets.reset_for_tests()
  active_refs = default_refs
  active_skins = default_skins
  active_constants = default_constants
  active_startup_item_ids = { 3001, 3002, 3003, 3004, 3005 }
end

return runtime_assets
