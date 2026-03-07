local number_utils = require("src.core.utils.number_utils")
local logger = require("src.core.utils.logger")
local runtime_refs = require("Config.runtime_refs")
local runtime_constants = require("src.core.config.runtime_constants")
local host_runtime = require("src.presentation.adapter.host_runtime_port")
local catalog = require("src.presentation.render.board_feedback_catalog")

local service = {}
local warned_missing_effect_refs = {}
local warned_missing_sound_refs = {}
local default_sfx_scale = 1.0
local default_sfx_rate = 1.0
local default_sfx_duration = 1.0
local default_sound_duration = 1.0
local default_sound_volume = 1.0
local default_with_sound = false

local function _warn(...)
  logger.warn("board_feedback", ...)
end

local function _warn_missing_effect_ref_once(cue_name, effect_id_ref, reason)
  local key = tostring(cue_name) .. "|" .. tostring(effect_id_ref) .. "|" .. tostring(reason)
  if warned_missing_effect_refs[key] then
    return
  end
  warned_missing_effect_refs[key] = true
  _warn(
    "skip play_sfx_by_key:",
    "cue_name=" .. tostring(cue_name),
    "effect_id_ref=" .. tostring(effect_id_ref),
    "reason=" .. tostring(reason)
  )
end

local function _warn_missing_sound_ref_once(cue_name, sound_id_ref, reason)
  local key = tostring(cue_name) .. "|" .. tostring(sound_id_ref) .. "|" .. tostring(reason)
  if warned_missing_sound_refs[key] then
    return
  end
  warned_missing_sound_refs[key] = true
  _warn(
    "skip play_3d_sound:",
    "cue_name=" .. tostring(cue_name),
    "sound_id_ref=" .. tostring(sound_id_ref),
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

local function _resolve_cue(cue_name)
  if type(cue_name) ~= "string" or cue_name == "" then
    return nil
  end
  return catalog.get(cue_name)
end

local function _resolve_scene(state)
  return state and state.board_scene or nil
end

local function _resolve_tile_position(state, tile_index)
  local scene = _resolve_scene(state)
  local tiles = scene and scene.tiles or nil
  local tile = tiles and tiles[tile_index] or nil
  if tile and type(tile.get_position) == "function" then
    return tile.get_position()
  end
  return nil
end

local function _resolve_player_unit(state, player_id)
  local scene = _resolve_scene(state)
  local units_by_player_id = scene and scene.units_by_player_id or nil
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
  if unit and type(unit.get_position) == "function" then
    return unit.get_position()
  end
  local player = state and state.game and state.game.find_player_by_id and state.game:find_player_by_id(player_id) or nil
  local tile_index = player and player.position or nil
  return _resolve_tile_position(state, tile_index)
end

local function _schedule_followup_sound(cue_name, pos, entry)
  if type(entry) ~= "table" then
    return false
  end
  local delay = _resolve_numeric(entry.delay, 0) or 0
  host_runtime.schedule(delay, function()
    local sound_id_ref = entry.sound_id_ref
    local audio_refs = runtime_refs.audio or {}
    local sound_id = number_utils.to_integer(audio_refs[sound_id_ref])
    if sound_id == nil or sound_id <= 0 then
      _warn_missing_sound_ref_once(cue_name, sound_id_ref, "missing_or_unconfigured")
      return
    end
    host_runtime.play_3d_sound(pos, sound_id, _resolve_numeric(entry.duration, default_sound_duration), _resolve_numeric(entry.volume, default_sound_volume))
  end)
  return true
end

local function _play_effect(state, cue_name, cue, pos, unit, payload)
  local effect_id = number_utils.to_integer(payload and payload.effect_id or nil)
  if effect_id == nil then
    local effect_id_ref = payload and payload.effect_id_ref or cue.effect_id_ref
    if type(effect_id_ref) ~= "string" or effect_id_ref == "" then
      if cue.allow_missing_resource ~= true then
        _warn("skip cue effect with missing effect_id_ref:", tostring(cue_name))
      end
      return false
    end
    local effect_refs = runtime_refs.effects or {}
    effect_id = number_utils.to_integer(effect_refs[effect_id_ref])
    if effect_id == nil or effect_id <= 0 then
      _warn_missing_effect_ref_once(cue_name, effect_id_ref, "missing_or_unconfigured")
      return false
    end
  end

  local duration = _resolve_numeric(payload and payload.duration or cue.duration, default_sfx_duration)
  local scale = _resolve_sfx_scale(cue_name, payload and payload.scale or cue.scale, default_sfx_scale)
  local rot = payload and payload.rot or cue.rot or runtime_constants.q_zero
  local rate = _resolve_numeric(payload and payload.rate or cue.rate, default_sfx_rate)
  local with_sound = payload and payload.with_sound
  if with_sound == nil then
    with_sound = cue.with_sound
  end
  if with_sound == nil then
    with_sound = default_with_sound
  end
  local sfx_id = host_runtime.play_sfx_by_key(effect_id, pos, rot, scale, duration, rate, with_sound, {
    cue_name = cue_name,
  })
  if sfx_id == nil then
    return false
  end
  if cue.bind_to_player == true and unit ~= nil then
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

local function _resolve_sound_id(cue_name, cue, payload)
  local sound_id = number_utils.to_integer(payload and payload.sound_id or nil)
  if sound_id ~= nil then
    return sound_id
  end

  local sound_id_ref = payload and payload.sound_id_ref or cue.sound_id_ref
  if type(sound_id_ref) ~= "string" or sound_id_ref == "" then
    if cue.allow_missing_resource ~= true then
      _warn("skip cue sound with missing sound_id_ref:", tostring(cue_name))
    end
    return nil
  end

  local audio_refs = runtime_refs.audio or {}
  sound_id = number_utils.to_integer(audio_refs[sound_id_ref])
  if sound_id == nil or sound_id <= 0 then
    _warn_missing_sound_ref_once(cue_name, sound_id_ref, "missing_or_unconfigured")
    return nil
  end
  return sound_id
end

local function _play_sound(cue_name, cue, pos, payload)
  local sound_id = _resolve_sound_id(cue_name, cue, payload)
  if sound_id == nil then
    return false
  end
  local duration = _resolve_numeric(payload and payload.sound_duration or cue.sound_duration or cue.duration, default_sound_duration)
  local volume = _resolve_numeric(payload and payload.volume or cue.volume, default_sound_volume)
  local sound_handle = host_runtime.play_3d_sound(pos, sound_id, duration, volume)
  return sound_handle ~= nil
end

local function _play_cue(state, cue_name, pos, unit, payload)
  local cue = _resolve_cue(cue_name)
  if cue == nil then
    return false
  end
  if pos == nil then
    pos = runtime_constants.v3_zero or runtime_constants.v3_one
  end

  local played = false
  if _play_effect(state, cue_name, cue, pos, unit, payload) then
    played = true
  end
  if _play_sound(cue_name, cue, pos, payload) then
    played = true
  end
  local followup_sounds = payload and payload.followup_sounds or cue.followup_sounds
  if type(followup_sounds) == "table" then
    for _, entry in ipairs(followup_sounds) do
      if _schedule_followup_sound(cue_name, pos, entry) then
        played = true
      end
    end
  end
  return played
end

function service.play_tile_cue(state, cue_name, tile_index, payload)
  local pos = _resolve_tile_position(state, tile_index)
  if pos == nil then
    return false
  end
  local player_id = payload and payload.player_id or nil
  local unit = player_id and _resolve_player_unit(state, player_id) or nil
  return _play_cue(state, cue_name, pos, unit, payload)
end

function service.play_player_cue(state, cue_name, player_id, payload)
  local pos = _resolve_player_position(state, player_id)
  if pos == nil then
    return false
  end
  local unit = _resolve_player_unit(state, player_id)
  return _play_cue(state, cue_name, pos, unit, payload)
end

function service.play_sound_only(state, cue_name, payload)
  local pos = payload and payload.pos or nil
  if pos == nil and payload and payload.player_id ~= nil then
    pos = _resolve_player_position(state, payload.player_id)
  end
  if pos == nil and payload and payload.tile_index ~= nil then
    pos = _resolve_tile_position(state, payload.tile_index)
  end
  return _play_cue(state, cue_name, pos, nil, payload)
end

function service.play_step_tile_sound(state, player_id, tile_index)
  return service.play_sound_only(state, "move_step_pounce", {
    player_id = player_id,
    tile_index = tile_index,
  })
end

return service
