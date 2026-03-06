local number_utils = require("src.core.NumberUtils")
local logger = require("src.core.Logger")
local runtime_refs = require("Config.RuntimeRefs")
local runtime_constants = require("src.core.config.RuntimeConstants")
local host_runtime = require("src.presentation.api.HostRuntimePort")
local catalog = require("src.presentation.render.BoardFeedbackCatalog")

local service = {}
local warned_missing_sound_refs = {}

local function _vec3(x, y, z)
  if math and math.Vector3 then
    return math.Vector3(x, y, z)
  end
  return { x = x, y = y, z = z }
end

local function _warn(...)
  logger.warn("board_feedback", ...)
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

local function _resolve_scale(value, fallback)
  if type(value) == "table" then
    return value
  end
  if number_utils.is_numeric(value) then
    return _vec3(value, value, value)
  end
  return fallback or runtime_constants.v3_one
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
  local delay = entry.delay or 0
  host_runtime.schedule(delay, function()
    local sound_id_ref = entry.sound_id_ref
    local audio_refs = runtime_refs.audio or {}
    local sound_id = number_utils.to_integer(audio_refs[sound_id_ref])
    if sound_id == nil or sound_id <= 0 then
      _warn_missing_sound_ref_once(cue_name, sound_id_ref, "missing_or_unconfigured")
      return
    end
    host_runtime.play_3d_sound(pos, sound_id, entry.duration, entry.volume)
  end)
  return true
end

local function _play_effect(state, cue_name, cue, pos, unit, payload)
  local effect_key = payload and payload.effect_key or cue.effect_key
  if type(effect_key) ~= "string" or effect_key == "" then
    if cue.allow_missing_resource ~= true then
      _warn("skip cue effect with missing effect_key:", tostring(cue_name))
    end
    return false
  end

  local duration = payload and payload.duration or cue.duration
  local scale = _resolve_scale(payload and payload.scale or cue.scale, runtime_constants.v3_one)
  local rot = payload and payload.rot or cue.rot or runtime_constants.q_zero
  local rate = payload and payload.rate or cue.rate
  local with_sound = payload and payload.with_sound or cue.with_sound
  local sfx_id = host_runtime.play_sfx_by_key(effect_key, pos, rot, scale, duration, rate, with_sound)
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
  local duration = payload and payload.sound_duration or cue.sound_duration or cue.duration
  local volume = payload and payload.volume or cue.volume
  local sound_handle = host_runtime.play_3d_sound(pos, sound_id, duration, volume)
  return sound_handle ~= nil
end

local function _play_cue(state, cue_name, pos, unit, payload)
  local cue = _resolve_cue(cue_name)
  if cue == nil then
    return false
  end
  if pos == nil then
    pos = _vec3(0.0, 0.0, 0.0)
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
