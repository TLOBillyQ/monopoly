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

--[[ mutate4lua-manifest
version=2
projectHash=1a44d454e44c1863
scope.0.id=chunk:src/config/gameplay/config_sanity.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=67
scope.0.semanticHash=b8910ce5c54ccfe0
scope.1.id=function:_assert_ref_exists:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=16
scope.1.semanticHash=d95ef37805d092f8
scope.2.id=function:_validate_cue_ref:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=23
scope.2.semanticHash=6076047b37814919
scope.3.id=function:_validate_board_feedback_audio_refs:46
scope.3.kind=function
scope.3.startLine=46
scope.3.endLine=51
scope.3.semanticHash=ea7a44b9b96982e1
scope.4.id=function:config_sanity.validate:53
scope.4.kind=function
scope.4.startLine=53
scope.4.endLine=60
scope.4.semanticHash=31c31a04901a254b
scope.5.id=function:config_sanity.reset_for_tests:62
scope.5.kind=function
scope.5.startLine=62
scope.5.endLine=64
scope.5.semanticHash=105c5f919a1e81e3
]]
