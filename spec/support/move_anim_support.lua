local runtime_ports = require("src.foundation.ports.runtime_ports")
local support = require("spec.support.shared_support")
local vec3 = require("spec.fixtures.vec3")

local M = {}

function M.new_scene_with_linear_tiles(count, opts)
  opts = opts or {}
  local length = opts.step_length or 10
  local scene = {
    tiles = {},
    units_by_player_id = opts.units_by_player_id or {},
  }
  local _vec3 = vec3.with_sub_length
  for index = 1, count do
    local tile_pos = _vec3((index - 1) * length, 0, 0)
    scene.tiles[index] = {
      get_position = function()
        return tile_pos
      end,
    }
  end
  return scene
end

function M.capture_scheduled_callbacks(fn)
  local scheduled = {}
  support.with_patches({
    {
      target = runtime_ports,
      key = "schedule",
      value = function(delay, cb)
        scheduled[#scheduled + 1] = { delay = delay, fn = cb }
      end,
    },
  }, function()
    fn(scheduled)
  end)
  return scheduled
end

local _SPY_METHODS = {
  "start_move_by_direction",
  "force_start_move",
  "force_stop_move",
  "stop_move",
  "stop_forced_move",
  "ai_command_stop_move",
  "stop_anim",
}

function M.new_unit_spy(overrides)
  overrides = overrides or {}
  local calls = {}
  local unit = {}
  for _, name in ipairs(_SPY_METHODS) do
    unit[name] = overrides[name] or function()
      calls[#calls + 1] = name
    end
  end
  for key, value in pairs(overrides) do
    unit[key] = value
  end
  return unit, calls
end

M.assert_eq = support.assert_eq
M.with_patches = support.with_patches

return M
