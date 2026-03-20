local source = {}

local function _is_non_empty_string(value)
  return type(value) == "string" and value ~= ""
end

local function _safe_get_role(get_game_api, role_id)
  if role_id == nil then
    return nil
  end
  local game_api = get_game_api and get_game_api() or nil
  if not (game_api and game_api.get_role) then
    return nil
  end
  local ok, role = pcall(game_api.get_role, role_id)
  if not ok then
    return nil
  end
  return role
end

local function _first_role_from_list(roles)
  if type(roles) ~= "table" then
    return nil
  end
  for _, role in ipairs(roles) do
    if role ~= nil then
      return role
    end
  end
  return nil
end

local function _build_none_helper(get_roles, get_game_api)
  local function _resolve_any_role()
    if type(get_roles) == "function" then
      local role = _first_role_from_list(get_roles())
      if role ~= nil then
        return role
      end
    end
    local game_api = get_game_api and get_game_api() or nil
    if game_api and game_api.get_all_valid_roles then
      local ok, roles = pcall(game_api.get_all_valid_roles)
      if ok then
        local role = _first_role_from_list(roles)
        if role ~= nil then
          return role
        end
      end
    end
    for role_id = 1, 8 do
      local role = _safe_get_role(get_game_api, role_id)
      if role ~= nil then
        return role
      end
    end
    return nil
  end

  return {
    player_id = nil,
    vehicle_id = nil,
    move_direction = nil,
    move_time = nil,
    set_position = nil,
    active_vehicle_by_player = {},
    needs_enter_wait_by_player = {},
    resolve_role = function(role_id)
      return _safe_get_role(get_game_api, role_id)
    end,
    resolve_any_role = _resolve_any_role,
    emit_vehicle_enter = function() return false end,
    emit_vehicle_exit = function() return false end,
    emit_vehicle_move = function() return false end,
    emit_vehicle_stop = function() return false end,
    emit_vehicle_set_position = function() return false end,
    consume_enter_delay = function() return 0 end,
  }
end

local function _resolve_mode(globals)
  local mode = globals and globals.VEHICLE_RUNTIME_MODE or nil
  if _is_non_empty_string(mode) then
    return tostring(mode)
  end
  return "none"
end

local function _resolve_module(globals)
  local module_name = globals and globals.VEHICLE_RUNTIME_MODULE or nil
  if _is_non_empty_string(module_name) then
    return tostring(module_name)
  end
  return "src.host.eggy.vehicle_runtime_legacy"
end

local function _load_runtime(globals)
  if _resolve_mode(globals) == "none" then
    return {
      build_helper = function(get_roles, get_game_api)
        return _build_none_helper(get_roles, get_game_api)
      end,
      install_editor_exports = function()
        return false
      end,
    }
  end

  local module_name = _resolve_module(globals)
  local ok, module_or_err = pcall(require, module_name)
  assert(ok, "failed to require vehicle runtime module: " .. tostring(module_or_err))
  return module_or_err
end

function source.resolve(globals)
  return _load_runtime(globals or _G)
end

function source.build_helper(get_roles, get_game_api, deps, globals)
  local runtime = _load_runtime(globals or _G)
  return runtime.build_helper(get_roles, get_game_api, deps or {})
end

function source.install_editor_exports(ctx, deps, globals)
  local runtime = _load_runtime(globals or _G)
  if type(runtime.install_editor_exports) ~= "function" then
    return false
  end
  return runtime.install_editor_exports(ctx, deps or {})
end

return source
