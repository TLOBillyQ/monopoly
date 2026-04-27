local logger = require("src.core.utils.logger")
local number_utils = require("src.core.utils.number_utils")
local runtime_constants = require("src.config.gameplay.runtime_constants")

local sfx_runtime = {}
local default_sfx_duration = 1.0
local default_sfx_rate = 1.0
local default_with_sound = false
local default_sound_duration = 1.0
local default_sound_volume = 1.0

local function _warn_skip(...)
  logger.warn("board_feedback", ...)
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

local function _is_vector_like(value)
  if type(value) ~= "table" then
    return false
  end
  return value.x ~= nil or value.y ~= nil or value.z ~= nil or value[1] ~= nil or value[2] ~= nil or value[3] ~= nil
end

local function _resolve_rotation(rot)
  if rot ~= nil then
    return rot
  end
  return runtime_constants.q_zero
end

local function _resolve_pos(pos)
  if pos ~= nil then
    return pos
  end
  return runtime_constants.v3_zero or runtime_constants.v3_one
end

function sfx_runtime.play_sfx_by_key(sfx_key, pos, rot, scale, duration, rate, with_sound, opts)
  opts = opts or {}
  local cue_name = opts.cue_name
  local resolved_sfx_key = number_utils.to_integer(sfx_key)
  if resolved_sfx_key == nil or resolved_sfx_key <= 0 then
    _warn_skip("skip play_sfx_by_key: invalid sfx_key", "cue_name=" .. tostring(cue_name), "sfx_key=" .. tostring(sfx_key))
    return nil
  end
  local resolved_scale = _resolve_numeric(scale, 1.0)
  if resolved_scale == nil or _is_vector_like(scale) then
    _warn_skip(
      "skip play_sfx_by_key: invalid scale",
      "cue_name=" .. tostring(cue_name),
      "sfx_key=" .. tostring(resolved_sfx_key),
      "scale=" .. tostring(scale),
      "rate=" .. tostring(rate)
    )
    return nil
  end
  local resolved_duration = _resolve_numeric(duration, default_sfx_duration)
  local resolved_rate = _resolve_numeric(rate, default_sfx_rate)
  if resolved_rate == nil then
    _warn_skip(
      "skip play_sfx_by_key: invalid rate",
      "cue_name=" .. tostring(cue_name),
      "sfx_key=" .. tostring(resolved_sfx_key),
      "scale=" .. tostring(resolved_scale),
      "rate=" .. tostring(rate)
    )
    return nil
  end
  local resolved_pos = _resolve_pos(pos)
  local resolved_rot = _resolve_rotation(rot)
  local resolved_with_sound = with_sound == true or default_with_sound
  local game_api = GameAPI
  if not (game_api and type(game_api.play_sfx_by_key) == "function") then
    _warn_skip("skip play_sfx_by_key: missing GameAPI.play_sfx_by_key")
    return nil
  end
  local ok, sfx_id = pcall(
    game_api.play_sfx_by_key,
    resolved_sfx_key,
    resolved_pos,
    resolved_rot,
    resolved_scale,
    resolved_duration,
    resolved_rate,
    resolved_with_sound
  )
  if not ok then
    _warn_skip(
      "play_sfx_by_key failed:",
      "cue_name=" .. tostring(cue_name),
      "sfx_key=" .. tostring(resolved_sfx_key),
      "scale=" .. tostring(resolved_scale),
      "duration=" .. tostring(resolved_duration),
      "rate=" .. tostring(resolved_rate),
      "with_sound=" .. tostring(resolved_with_sound)
    )
    return nil
  end
  return sfx_id
end

function sfx_runtime.play_3d_sound(pos, sound_id, duration, volume)
  local resolved_sound_id = number_utils.to_integer(sound_id)
  if resolved_sound_id == nil or resolved_sound_id <= 0 then
    _warn_skip("skip play_3d_sound: invalid sound_id", tostring(sound_id))
    return nil
  end
  local game_api = GameAPI
  if not (game_api and type(game_api.play_3d_sound) == "function") then
    _warn_skip("skip play_3d_sound: missing GameAPI.play_3d_sound")
    return nil
  end
  local resolved_pos = _resolve_pos(pos)
  local resolved_duration = _resolve_numeric(duration, default_sound_duration)
  local resolved_volume = _resolve_numeric(volume, default_sound_volume)
  local ok, assigned_sound_id = pcall(game_api.play_3d_sound, resolved_pos, resolved_sound_id, resolved_duration, resolved_volume)
  if not ok then
    _warn_skip("play_3d_sound failed:", tostring(resolved_sound_id))
    return nil
  end
  return assigned_sound_id
end

function sfx_runtime.bind_sfx_to_unit(sfx_id, unit, socket_name, pos, bind_type)
  if sfx_id == nil or unit == nil then
    return false
  end
  local global_api = GlobalAPI
  if not (global_api and type(global_api.bind_sfx_to_unit) == "function") then
    return false
  end
  local ok = pcall(global_api.bind_sfx_to_unit, sfx_id, unit, socket_name, pos, bind_type)
  return ok
end

function sfx_runtime.destroy_sfx(sfx_id, fade_out)
  if sfx_id == nil then
    return false
  end
  local global_api = GlobalAPI
  if not (global_api and type(global_api.destroy_sfx) == "function") then
    return false
  end
  local ok = pcall(global_api.destroy_sfx, sfx_id, fade_out == true)
  return ok
end

function sfx_runtime.stop_sound(sound_id)
  if sound_id == nil then
    return false
  end
  local game_api = GameAPI
  if not (game_api and type(game_api.stop_sound) == "function") then
    return false
  end
  local ok = pcall(game_api.stop_sound, sound_id)
  return ok
end

return sfx_runtime
