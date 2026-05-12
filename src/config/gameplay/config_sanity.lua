local runtime_refs = require("src.config.content.runtime_refs")

local config_sanity = {}

local validated = false

local function _assert_ref_exists(refs, ref_value, ref_field, cue_name, suffix)
  assert(
    refs[ref_value] ~= nil,
    "board feedback " .. (suffix or "cue") .. " references unknown " .. ref_field .. ": "
      .. tostring(ref_value)
      .. " (cue_name="
      .. tostring(cue_name)
      .. ")"
  )
end

local function _validate_cue_ref(refs, cue_name, cue, ref_field)
  local ref_value = cue and cue[ref_field] or nil
  if ref_value ~= nil then
    _assert_ref_exists(refs, ref_value, ref_field, cue_name)
  end
end

local function _validate_board_feedback_cue(effect_refs, audio_refs, cue_name, cue)
  _validate_cue_ref(effect_refs, cue_name, cue, "effect_id_ref")
  _validate_cue_ref(audio_refs, cue_name, cue, "sound_id_ref")
  local followup_sounds = cue and cue.followup_sounds or nil
  if type(followup_sounds) ~= "table" then
    return
  end
  for _, entry in ipairs(followup_sounds) do
    local followup_ref = entry and entry.sound_id_ref or nil
    if followup_ref ~= nil then
      _assert_ref_exists(audio_refs, followup_ref, "sound_id_ref", cue_name, "followup")
    end
  end
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
  _validate_board_feedback_audio_refs()
  validated = true
  return true
end

function config_sanity.reset_for_tests()
  validated = false
end

return config_sanity
