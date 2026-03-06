local logger = require("src.core.Logger")
local number_utils = require("src.core.NumberUtils")

local sfx_runtime = {}

local function _warn_skip(...)
  logger.warn("board_feedback", ...)
end

function sfx_runtime.play_sfx_by_key(sfx_key, pos, rot, scale, duration, rate, with_sound)
  local resolved_sfx_key = number_utils.to_integer(sfx_key)
  if resolved_sfx_key == nil or resolved_sfx_key <= 0 then
    _warn_skip("skip play_sfx_by_key: invalid sfx_key", tostring(sfx_key))
    return nil
  end
  local game_api = GameAPI
  if not (game_api and type(game_api.play_sfx_by_key) == "function") then
    _warn_skip("skip play_sfx_by_key: missing GameAPI.play_sfx_by_key")
    return nil
  end
  local ok, sfx_id = pcall(game_api.play_sfx_by_key, resolved_sfx_key, pos, rot, scale, duration, rate, with_sound)
  if not ok then
    _warn_skip("play_sfx_by_key failed:", tostring(resolved_sfx_key))
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
  local ok, assigned_sound_id = pcall(game_api.play_3d_sound, pos, resolved_sound_id, duration, volume)
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
