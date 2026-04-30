local number_utils = require("src.foundation.lang.number")
local logger = require("src.foundation.log.logger")
local runtime_refs = require("src.config.content.runtime_refs")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local catalog = require("src.ui.render.board_feedback.catalog")
local effect_timeline = require("src.ui.render.support.effect_timeline")
local effect_track = require("src.ui.render.support.effect_track")
local unit_position = require("src.ui.render.unit_position")
local host_runtime_bridge = require("src.ui.host_bridge")
local service = {}
local active_host_runtime = nil
local warned_missing_refs = {
  effect = {},
  sound = {},
}
local default_sfx_scale = 1.0
local default_sfx_rate = 1.0
local default_sfx_duration = 1.0
local default_sound_duration = 1.0
local default_sound_volume = 1.0
local default_with_sound = false

local function _resolve_host_runtime(state, deps)
  local resolved_deps = deps or (state and state.presentation_runtime) or nil
  if resolved_deps and resolved_deps.host_runtime then
    return resolved_deps.host_runtime
  end
  return host_runtime_bridge
end
local function _warn(...)
  logger.warn("board_feedback", ...)
end
local function _warn_missing_ref_once(kind, cue_name, ref_value, reason)
  local warned = warned_missing_refs[kind]
  local key = tostring(cue_name) .. "|" .. tostring(ref_value) .. "|" .. tostring(reason)
  if warned[key] then
    return
  end
  warned[key] = true
  _warn(
    kind == "effect" and "skip play_sfx_by_key:" or "skip play_3d_sound:",
    "cue_name=" .. tostring(cue_name),
    (kind == "effect" and "effect_id_ref=" or "sound_id_ref=") .. tostring(ref_value),
    "reason=" .. tostring(reason)
  )
end
local function _resolve_numeric(value, fallback)
  if number_utils.is_numeric(value) then
    return value + 0
  end
  if number_utils.is_numeric(fallback) then
    return fallback + 0
  end
  return nil
end
local function _warn_invalid_cue_field(cue_name, field, value, fallback)
  _warn(
    "invalid cue field:",
    "cue_name=" .. tostring(cue_name),
    "field=" .. tostring(field),
    "value=" .. tostring(value),
    "fallback=" .. tostring(fallback)
  )
end
local function _resolve_sfx_scale(cue_name, value, fallback)
  local resolved = _resolve_numeric(value, fallback)
  if resolved ~= nil then
    return resolved
  end
  _warn_invalid_cue_field(cue_name, "scale", value, default_sfx_scale)
  return default_sfx_scale
end
local function _resolve_cue_ref_id(cue_name, cue, payload, kind, refs)
  local resolved_id = number_utils.to_integer(payload and payload[kind .. "_id"] or nil)
  if resolved_id ~= nil then
    return resolved_id
  end
  local ref_name = payload and payload[kind .. "_id_ref"] or cue[kind .. "_id_ref"]
  if type(ref_name) ~= "string" or ref_name == "" then
    if cue.allow_missing_resource ~= true then
      _warn("skip cue " .. kind .. " with missing " .. kind .. "_id_ref:", tostring(cue_name))
    end
    return nil
  end
  resolved_id = number_utils.to_integer((refs or {})[ref_name])
  if resolved_id == nil or resolved_id <= 0 then
    _warn_missing_ref_once(kind, cue_name, ref_name, "missing_or_unconfigured")
    return nil
  end
  return resolved_id
end
local function _resolve_tile_position(state, tile_index)
  return unit_position.read_scene_tile_position(state and state.board_scene or nil, tile_index)
end
local function _resolve_building_tile_position(state, tile_index)
  return unit_position.read_scene_building_position(state and state.board_scene or nil, tile_index)
end
local function _resolve_tile_cue_position(state, tile_index, payload)
  if payload and payload.use_building_tile_position == true then
    local building_pos = _resolve_building_tile_position(state, tile_index)
    if building_pos ~= nil then
      return building_pos
    end
  end
  return _resolve_tile_position(state, tile_index)
end
local function _resolve_player_unit(state, player_id)
  local units_by_player_id = state and state.board_scene and state.board_scene.units_by_player_id or nil
  if type(units_by_player_id) == "table" and units_by_player_id[player_id] ~= nil then
    return units_by_player_id[player_id]
  end
  local player_units = state and state.player_units or nil
  if type(player_units) == "table" then
    return player_units[player_id]
  end
  return nil
end
local function _resolve_player_position(state, player_id)
  local unit = _resolve_player_unit(state, player_id)
  local unit_pos = unit_position.read_unit_position(unit)
  if unit_pos ~= nil then
    return unit_pos
  end
  local player = state and state.game and state.game.find_player_by_id and state.game:find_player_by_id(player_id) or nil
  return _resolve_tile_position(state, player and player.position or nil)
end
local function _schedule_followup_sound(cue_name, pos, entry)
  if type(entry) ~= "table" then
    return false
  end
  local host_runtime = active_host_runtime
  if not (host_runtime and type(host_runtime.play_3d_sound) == "function" and type(host_runtime.schedule) == "function") then
    return false
  end
  local delay = _resolve_numeric(entry.delay, 0) or 0
  effect_timeline.run_step(delay, function()
    local sound_id_ref = entry.sound_id_ref
    local audio_refs = runtime_refs.audio or {}
    local sound_id = number_utils.to_integer(audio_refs[sound_id_ref])
    if sound_id == nil or sound_id <= 0 then
      _warn_missing_ref_once("sound", cue_name, sound_id_ref, "missing_or_unconfigured")
      return
    end
    host_runtime.play_3d_sound(pos, sound_id, _resolve_numeric(entry.duration, default_sound_duration), _resolve_numeric(entry.volume, default_sound_volume))
  end, {
    schedule = host_runtime.schedule,
  })
  return true
end
local function _resolve_with_sound(cue, payload)
  local with_sound = payload and payload.with_sound
  if with_sound == nil then
    with_sound = cue.with_sound
  end
  if with_sound == nil then
    with_sound = default_with_sound
  end
  return with_sound
end

local function _play_effect(cue_name, cue, pos, unit, payload)
  local effect_id = _resolve_cue_ref_id(cue_name, cue, payload, "effect", runtime_refs.effects)
  if effect_id == nil then
    return false
  end
  local raw_duration = _resolve_numeric(payload and payload.duration or cue.duration, default_sfx_duration)
  local duration = effect_track.scaled_duration(raw_duration)
  local scale = _resolve_sfx_scale(cue_name, payload and payload.scale or cue.scale, default_sfx_scale)
  local rot = payload and payload.rot or cue.rot or runtime_constants.q_zero
  local rate = _resolve_numeric(payload and payload.rate or cue.rate, default_sfx_rate)
  local with_sound = _resolve_with_sound(cue, payload)
  local host_runtime = active_host_runtime
  if not (host_runtime and type(host_runtime.play_sfx_by_key) == "function") then
    return false
  end
  local sfx_id = host_runtime.play_sfx_by_key(effect_id, pos, rot, scale, duration, rate, with_sound, {
    cue_name = cue_name,
  })
  if sfx_id == nil then
    return false
  end
  effect_track.spawn(cue_name, "effect", duration)
  if cue.bind_to_player == true and unit ~= nil then
    if type(host_runtime.bind_sfx_to_unit) ~= "function" then
      return true
    end
    host_runtime.bind_sfx_to_unit(
      sfx_id,
      unit,
      cue.socket_name,
      cue.bind_offset or runtime_constants.v3_one,
      cue.bind_type
    )
  end
  return true
end
local function _play_sound(cue_name, cue, pos, payload)
  local sound_id = _resolve_cue_ref_id(cue_name, cue, payload, "sound", runtime_refs.audio)
  if sound_id == nil then
    return false
  end
  local duration = _resolve_numeric(payload and payload.sound_duration or cue.sound_duration or cue.duration, default_sound_duration)
  local volume = _resolve_numeric(payload and payload.volume or cue.volume, default_sound_volume)
  local host_runtime = active_host_runtime
  if not (host_runtime and type(host_runtime.play_3d_sound) == "function") then
    return false
  end
  local sound_handle = host_runtime.play_3d_sound(pos, sound_id, duration, volume)
  return sound_handle ~= nil
end

local function _play_followup_sounds(cue_name, pos, followup_sounds)
  local played = false
  if type(followup_sounds) ~= "table" then
    return played
  end
  for _, entry in ipairs(followup_sounds) do
    if _schedule_followup_sound(cue_name, pos, entry) then
      played = true
    end
  end
  return played
end

local function _play_cue(state, cue_name, pos, unit, payload)
  local cue = type(cue_name) == "string" and cue_name ~= "" and catalog.get(cue_name) or nil
  if cue == nil then
    return false
  end
  if pos == nil then
    pos = runtime_constants.v3_zero or runtime_constants.v3_one
  end
  local played = false
  if _play_effect(cue_name, cue, pos, unit, payload) then
    played = true
  end
  if _play_sound(cue_name, cue, pos, payload) then
    played = true
  end
  local followup_sounds = payload and payload.followup_sounds or cue.followup_sounds
  if _play_followup_sounds(cue_name, pos, followup_sounds) then
    played = true
  end
  return played
end
function service.play_tile_cue(state, cue_name, tile_index, payload, deps)
  active_host_runtime = _resolve_host_runtime(state, deps)
  local pos = _resolve_tile_cue_position(state, tile_index, payload)
  if pos == nil then
    return false
  end
  local player_id = payload and payload.player_id or nil
  local unit = player_id and _resolve_player_unit(state, player_id) or nil
  return _play_cue(state, cue_name, pos, unit, payload)
end
function service.play_player_cue(state, cue_name, player_id, payload, deps)
  active_host_runtime = _resolve_host_runtime(state, deps)
  local pos = payload and payload.pos or _resolve_player_position(state, player_id)
  if pos == nil then
    return false
  end
  local unit = _resolve_player_unit(state, player_id)
  return _play_cue(state, cue_name, pos, unit, payload)
end
function service.play_sound_only(state, cue_name, payload, deps)
  active_host_runtime = _resolve_host_runtime(state, deps)
  return _play_cue(
    state,
    cue_name,
    payload and (payload.pos or (payload.player_id ~= nil and _resolve_player_position(state, payload.player_id)) or (payload.tile_index ~= nil and _resolve_tile_position(state, payload.tile_index))) or nil,
    nil,
    payload
  )
end
function service.play_step_tile_sound(state, player_id, tile_index, deps)
  return service.play_sound_only(state, "move_step_pounce", {
    player_id = player_id,
    tile_index = tile_index,
  }, deps)
end
return service
