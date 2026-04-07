local support = require("support.domain_support")
local vehicle_helper = require("src.host.vehicle_helper")
local vehicle_feature = require("src.rules.vehicle")
local monopoly_events = require("src.core.events")
local runtime_ports = require("src.core.ports.runtime_ports")

local _assert_eq = support.assert_eq

local _mock_vehicle = { id = "v1" }
local _mock_position = { x = 1, y = 0, z = 2 }
local _mock_direction = { x = 0, y = 0, z = 1 }
local _mock_life_entity = {
  try_enter_vehicle = function() end,
  try_exit_vehicle = function() end,
}
local _mock_character = { id = "char1" }

local function _with_feature_enabled(fn)
  local prev = vehicle_feature.is_enabled()
  vehicle_feature.set_enabled(true)
  local ok, err = pcall(fn)
  vehicle_feature.set_enabled(prev)
  if not ok then
    error(err, 0)
  end
end

local function _capture_events()
  local captured = {}
  return captured, {
    target = runtime_ports,
    key = "emit_event",
    value = function(kind, payload)
      captured[#captured + 1] = { kind = kind, payload = payload }
    end,
  }
end

local function _stub_game_api(overrides)
  overrides = overrides or {}
  return {
    target = _G,
    key = "GameAPI",
    value = {
      create_vehicle = overrides.create_vehicle or function(vehicle_key, pos, dir, role)
        return { id = "created_" .. tostring(vehicle_key) }
      end,
      copy_vehicle = overrides.copy_vehicle or function(vehicle, pos, dir, role)
        return { id = "copied" }
      end,
      delay_destroy_vehicle = overrides.delay_destroy_vehicle or function() end,
      get_driving_vehicle = overrides.get_driving_vehicle or function()
        return _mock_vehicle
      end,
    },
  }
end

local function _test_create_with_valid_opts_returns_result_and_emits_event()
  local captured, event_patch = _capture_events()
  support.with_patches({
    event_patch,
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local result, err = vehicle_helper.create({
        vehicle_key = "car_01",
        position = _mock_position,
        direction = _mock_direction,
      })
      assert(result ~= nil, "create should return result")
      assert(err == nil, "create should not return error")
      _assert_eq(result.vehicle_key, "car_01", "result should carry vehicle_key")
      assert(result.vehicle ~= nil, "result should carry vehicle")
      _assert_eq(#captured, 1, "create should emit one event")
      _assert_eq(captured[1].kind, monopoly_events.vehicle.created, "event kind should be vh.created")
    end)
  end, { skip_runtime_context_refresh = true })
end

local function _test_create_with_missing_param_returns_error()
  support.with_patches({
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local result, err = vehicle_helper.create({ position = _mock_position, direction = _mock_direction })
      assert(result == nil, "create with missing vehicle_key should return nil")
      assert(type(err) == "string" and err:find("vehicle_key", 1, true), "error should mention vehicle_key")
    end)
  end)
end

local function _test_create_when_disabled_returns_error()
  vehicle_feature.set_enabled(false)
  local result, err = vehicle_helper.create({
    vehicle_key = "car_01",
    position = _mock_position,
    direction = _mock_direction,
  })
  assert(result == nil, "create when disabled should return nil")
  assert(type(err) == "string" and err:find("disabled", 1, true), "error should mention disabled")
end

local function _test_create_when_host_api_fails_returns_error()
  support.with_patches({
    _stub_game_api({
      create_vehicle = function() error("host crash") end,
    }),
  }, function()
    _with_feature_enabled(function()
      local result, err = vehicle_helper.create({
        vehicle_key = "car_01",
        position = _mock_position,
        direction = _mock_direction,
      })
      assert(result == nil, "create should return nil on host failure")
      assert(type(err) == "string" and err:find("failed", 1, true), "error should mention failure")
    end)
  end)
end

local function _test_copy_with_valid_opts_returns_result_and_emits_event()
  local captured, event_patch = _capture_events()
  support.with_patches({
    event_patch,
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local result, err = vehicle_helper.copy({
        vehicle = _mock_vehicle,
        position = _mock_position,
        direction = _mock_direction,
      })
      assert(result ~= nil, "copy should return result")
      assert(err == nil, "copy should not return error")
      assert(result.vehicle ~= nil, "copy result should carry vehicle")
      _assert_eq(#captured, 1, "copy should emit one event")
      _assert_eq(captured[1].kind, monopoly_events.vehicle.copied, "event kind should be vh.copied")
    end)
  end, { skip_runtime_context_refresh = true })
end

local function _test_copy_with_missing_param_returns_error()
  support.with_patches({
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local result, err = vehicle_helper.copy({ position = _mock_position, direction = _mock_direction })
      assert(result == nil, "copy with missing vehicle should return nil")
      assert(type(err) == "string" and err:find("vehicle", 1, true), "error should mention vehicle")
    end)
  end)
end

local function _test_destroy_returns_true_and_emits_event()
  local captured, event_patch = _capture_events()
  support.with_patches({
    event_patch,
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local ok, err = vehicle_helper.destroy(_mock_vehicle)
      _assert_eq(ok, true, "destroy should return true")
      assert(err == nil, "destroy should not return error")
      _assert_eq(#captured, 1, "destroy should emit one event")
      _assert_eq(captured[1].kind, monopoly_events.vehicle.destroyed, "event kind should be vh.destroyed")
    end)
  end, { skip_runtime_context_refresh = true })
end

local function _test_destroy_with_missing_param_returns_error()
  support.with_patches({
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local ok, err = vehicle_helper.destroy(nil)
      _assert_eq(ok, false, "destroy with nil should return false")
      assert(type(err) == "string" and err:find("vehicle", 1, true), "error should mention vehicle")
    end)
  end)
end

local function _test_get_driving_vehicle_returns_vehicle_without_feature_guard()
  support.with_patches({
    _stub_game_api(),
  }, function()
    vehicle_feature.set_enabled(false)
    local vehicle, err = vehicle_helper.get_driving_vehicle(_mock_character)
    assert(vehicle ~= nil, "get_driving_vehicle should return vehicle even when feature disabled")
    assert(err == nil, "get_driving_vehicle should not return error")
    vehicle_feature.set_enabled(false)
  end)
end

local function _test_get_driving_vehicle_with_missing_param_returns_error()
  local result, err = vehicle_helper.get_driving_vehicle(nil)
  assert(result == nil, "get_driving_vehicle with nil should return nil")
  assert(type(err) == "string" and err:find("character", 1, true), "error should mention character")
end

local function _test_enter_returns_true_and_emits_event()
  local captured, event_patch = _capture_events()
  support.with_patches({
    event_patch,
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local ok, err = vehicle_helper.enter(_mock_life_entity, _mock_vehicle)
      _assert_eq(ok, true, "enter should return true")
      assert(err == nil, "enter should not return error")
      _assert_eq(#captured, 1, "enter should emit one event")
      _assert_eq(captured[1].kind, monopoly_events.vehicle.entered, "event kind should be vh.entered")
    end)
  end, { skip_runtime_context_refresh = true })
end

local function _test_enter_when_disabled_returns_error()
  vehicle_feature.set_enabled(false)
  local ok, err = vehicle_helper.enter(_mock_life_entity, _mock_vehicle)
  _assert_eq(ok, false, "enter when disabled should return false")
  assert(type(err) == "string" and err:find("disabled", 1, true), "error should mention disabled")
end

local function _test_enter_with_missing_life_entity_returns_error()
  support.with_patches({
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local ok, err = vehicle_helper.enter(nil, _mock_vehicle)
      _assert_eq(ok, false, "enter with nil life_entity should return false")
      assert(type(err) == "string" and err:find("life_entity", 1, true), "error should mention life_entity")
    end)
  end)
end

local function _test_exit_returns_true_and_emits_event()
  local captured, event_patch = _capture_events()
  support.with_patches({
    event_patch,
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local ok, err = vehicle_helper.exit(_mock_life_entity)
      _assert_eq(ok, true, "exit should return true")
      assert(err == nil, "exit should not return error")
      _assert_eq(#captured, 1, "exit should emit one event")
      _assert_eq(captured[1].kind, monopoly_events.vehicle.exited, "event kind should be vh.exited")
    end)
  end, { skip_runtime_context_refresh = true })
end

local function _test_exit_when_disabled_returns_error()
  vehicle_feature.set_enabled(false)
  local ok, err = vehicle_helper.exit(_mock_life_entity)
  _assert_eq(ok, false, "exit when disabled should return false")
  assert(type(err) == "string" and err:find("disabled", 1, true), "error should mention disabled")
end

local function _test_move_returns_true_and_emits_event()
  local mock_vehicle_with_move = {
    id = "v1",
    start_move_by_direction = function() end,
  }
  local captured, event_patch = _capture_events()
  support.with_patches({
    event_patch,
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local ok, err = vehicle_helper.move(mock_vehicle_with_move, _mock_direction, 2.0)
      _assert_eq(ok, true, "move should return true")
      assert(err == nil, "move should not return error")
      _assert_eq(#captured, 1, "move should emit one event")
      _assert_eq(captured[1].kind, monopoly_events.vehicle.moved, "event kind should be vh.moved")
    end)
  end, { skip_runtime_context_refresh = true })
end

local function _test_move_with_missing_direction_returns_error()
  support.with_patches({
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local ok, err = vehicle_helper.move(_mock_vehicle, nil, 2.0)
      _assert_eq(ok, false, "move with nil direction should return false")
      assert(type(err) == "string" and err:find("direction", 1, true), "error should mention direction")
    end)
  end)
end

local function _test_stop_returns_true_and_emits_event()
  local mock_vehicle_with_stop = {
    id = "v1",
    stop_move = function() end,
  }
  local captured, event_patch = _capture_events()
  support.with_patches({
    event_patch,
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local ok, err = vehicle_helper.stop(mock_vehicle_with_stop)
      _assert_eq(ok, true, "stop should return true")
      assert(err == nil, "stop should not return error")
      _assert_eq(#captured, 1, "stop should emit one event")
      _assert_eq(captured[1].kind, monopoly_events.vehicle.stopped, "event kind should be vh.stopped")
    end)
  end, { skip_runtime_context_refresh = true })
end

local function _test_stop_with_missing_vehicle_returns_error()
  support.with_patches({
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local ok, err = vehicle_helper.stop(nil)
      _assert_eq(ok, false, "stop with nil vehicle should return false")
      assert(type(err) == "string" and err:find("vehicle", 1, true), "error should mention vehicle")
    end)
  end)
end

local function _test_reset_returns_true_and_emits_event()
  local mock_vehicle_with_reset = {
    id = "v1",
    reset = function() end,
  }
  local captured, event_patch = _capture_events()
  support.with_patches({
    event_patch,
    _stub_game_api(),
  }, function()
    _with_feature_enabled(function()
      local ok, err = vehicle_helper.reset(mock_vehicle_with_reset)
      _assert_eq(ok, true, "reset should return true")
      assert(err == nil, "reset should not return error")
      _assert_eq(#captured, 1, "reset should emit one event")
      _assert_eq(captured[1].kind, monopoly_events.vehicle.reset, "event kind should be vh.reset")
    end)
  end, { skip_runtime_context_refresh = true })
end

local function _test_reset_when_disabled_returns_error()
  vehicle_feature.set_enabled(false)
  local ok, err = vehicle_helper.reset(_mock_vehicle)
  _assert_eq(ok, false, "reset when disabled should return false")
  assert(type(err) == "string" and err:find("disabled", 1, true), "error should mention disabled")
end

return {
  name = "vehicle_helper",
  tests = {
    { name = "create_with_valid_opts_returns_result_and_emits_event", run = _test_create_with_valid_opts_returns_result_and_emits_event },
    { name = "create_with_missing_param_returns_error", run = _test_create_with_missing_param_returns_error },
    { name = "create_when_disabled_returns_error", run = _test_create_when_disabled_returns_error },
    { name = "create_when_host_api_fails_returns_error", run = _test_create_when_host_api_fails_returns_error },
    { name = "copy_with_valid_opts_returns_result_and_emits_event", run = _test_copy_with_valid_opts_returns_result_and_emits_event },
    { name = "copy_with_missing_param_returns_error", run = _test_copy_with_missing_param_returns_error },
    { name = "destroy_returns_true_and_emits_event", run = _test_destroy_returns_true_and_emits_event },
    { name = "destroy_with_missing_param_returns_error", run = _test_destroy_with_missing_param_returns_error },
    { name = "get_driving_vehicle_returns_vehicle_without_feature_guard", run = _test_get_driving_vehicle_returns_vehicle_without_feature_guard },
    { name = "get_driving_vehicle_with_missing_param_returns_error", run = _test_get_driving_vehicle_with_missing_param_returns_error },
    { name = "enter_returns_true_and_emits_event", run = _test_enter_returns_true_and_emits_event },
    { name = "enter_when_disabled_returns_error", run = _test_enter_when_disabled_returns_error },
    { name = "enter_with_missing_life_entity_returns_error", run = _test_enter_with_missing_life_entity_returns_error },
    { name = "exit_returns_true_and_emits_event", run = _test_exit_returns_true_and_emits_event },
    { name = "exit_when_disabled_returns_error", run = _test_exit_when_disabled_returns_error },
    { name = "move_returns_true_and_emits_event", run = _test_move_returns_true_and_emits_event },
    { name = "move_with_missing_direction_returns_error", run = _test_move_with_missing_direction_returns_error },
    { name = "stop_returns_true_and_emits_event", run = _test_stop_returns_true_and_emits_event },
    { name = "stop_with_missing_vehicle_returns_error", run = _test_stop_with_missing_vehicle_returns_error },
    { name = "reset_returns_true_and_emits_event", run = _test_reset_returns_true_and_emits_event },
    { name = "reset_when_disabled_returns_error", run = _test_reset_when_disabled_returns_error },
  },
}
