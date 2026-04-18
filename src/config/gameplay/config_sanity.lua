local chance_cfg = require("src.config.content.chance_cards")
local market_catalog = require("src.config.content.market_catalog")
local market_cfg = require("src.config.content.market")
local runtime_refs = require("src.config.content.runtime_refs")

local config_sanity = {}

local validated = false

local function _validate_chance_card(card)
  assert(
    card.effect ~= "set_vehicle",
    "config must not include chance set_vehicle cards (card_id=" .. tostring(card.id) .. ")"
  )
end

local function _validate_market_entry(entry)
  assert(
    entry.kind ~= "vehicle",
    "config must not include vehicle market entries (product_id=" .. tostring(entry.product_id) .. ")"
  )
end

local function _validate_rows(rows, validator)
  for _, row in ipairs(rows) do
    validator(row)
  end
end

local function _validate_data_has_no_vehicle_content()
  _validate_rows(chance_cfg, _validate_chance_card)
  _validate_rows(market_cfg, _validate_market_entry)
  market_catalog.assert_valid()
end

local function _validate_board_feedback_effect_ref(effect_refs, cue_name, cue)
  local effect_id_ref = cue and cue.effect_id_ref or nil
  if effect_id_ref == nil then
    return
  end
  assert(
    effect_refs[effect_id_ref] ~= nil,
    "board feedback cue references unknown effect_id_ref: "
      .. tostring(effect_id_ref)
      .. " (cue_name="
      .. tostring(cue_name)
      .. ")"
  )
end

local function _validate_board_feedback_sound_ref(audio_refs, cue_name, cue)
  local sound_id_ref = cue and cue.sound_id_ref or nil
  if sound_id_ref == nil then
    return
  end
  assert(
    audio_refs[sound_id_ref] ~= nil,
    "board feedback cue references unknown sound_id_ref: "
      .. tostring(sound_id_ref)
      .. " (cue_name="
      .. tostring(cue_name)
      .. ")"
  )
end

local function _validate_board_feedback_followup_sound_refs(audio_refs, cue_name, cue)
  local followup_sounds = cue and cue.followup_sounds or nil
  if type(followup_sounds) ~= "table" then
    return
  end
  for index, entry in ipairs(followup_sounds) do
    local followup_ref = entry and entry.sound_id_ref or nil
    if followup_ref ~= nil then
      assert(
        audio_refs[followup_ref] ~= nil,
        "board feedback followup references unknown sound_id_ref: "
          .. tostring(followup_ref)
          .. " (cue_name="
          .. tostring(cue_name)
          .. ", index="
          .. tostring(index)
          .. ")"
      )
    end
  end
end

local function _validate_board_feedback_cue(effect_refs, audio_refs, cue_name, cue)
  _validate_board_feedback_effect_ref(effect_refs, cue_name, cue)
  _validate_board_feedback_sound_ref(audio_refs, cue_name, cue)
  _validate_board_feedback_followup_sound_refs(audio_refs, cue_name, cue)
end

local function _validate_board_feedback_cues(cues, effect_refs, audio_refs)
  for cue_name, cue in pairs(cues) do
    _validate_board_feedback_cue(effect_refs, audio_refs, cue_name, cue)
  end
end

local function _validate_board_feedback_audio_refs()
  local cues = runtime_refs.board_feedback or {}
  local audio_refs = runtime_refs.audio or {}
  local effect_refs = runtime_refs.effects or {}
  _validate_board_feedback_cues(cues, effect_refs, audio_refs)
end

function config_sanity.validate()
  if validated then
    return true
  end
  _validate_data_has_no_vehicle_content()
  _validate_board_feedback_audio_refs()
  validated = true
  return true
end

function config_sanity.reset_for_tests()
  validated = false
end

return config_sanity
