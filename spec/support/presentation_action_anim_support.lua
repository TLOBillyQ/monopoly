local handlers = require("src.ui.render.anim.handlers")
local host_runtime = require("src.host")
local support = require("spec.support.presentation_support")

local M = {}

function M.build_min_state(opts)
  opts = opts or {}
  local state = {
    ui = {},
    board_scene = {
      tiles = {
        [1] = {
          get_position = function()
            return math.Vector3(0.0, 0.0, 0.0)
          end,
        },
      },
      buildings = {
        [1] = {
          get_position = function()
            return math.Vector3(10.0, 0.0, 0.0)
          end,
        },
      },
      units_by_player_id = {},
    },
    game = {
      board = {
        get_tile = function(_, _tile_index)
          return { name = "测试地块" }
        end,
      },
      find_player_by_id = function()
        return { position = 1, name = "测试玩家" }
      end,
    },
  }

  if type(opts.tile_getter) == "function" then
    state.game.board.get_tile = opts.tile_getter
  end
  if type(opts.find_player_by_id) == "function" then
    state.game.find_player_by_id = opts.find_player_by_id
  end
  if type(opts.mutate) == "function" then
    opts.mutate(state)
  end
  return state
end

function M.capture_handler_duration(handler_key, payload)
  local captured_anim = nil
  local duration = nil
  return {
    patches = {
      {
        target = handlers,
        key = handler_key,
        value = function(_, anim)
          captured_anim = anim
          return duration or 0
        end,
      },
    },
    set_duration = function(value)
      duration = value
    end,
    captured_anim = function()
      return captured_anim
    end,
    payload = payload,
  }
end

function M.stub_host_runtime(overrides)
  overrides = overrides or {}
  local unit_calls = {}
  local group_calls = {}

  return {
    unit_calls = unit_calls,
    group_calls = group_calls,
    patches = {
      {
        target = host_runtime,
        key = "create_unit_with_scale",
        value = overrides.create_unit_with_scale or function(_, _, _, scale)
          unit_calls[#unit_calls + 1] = { scale = scale }
          return { _unit_id = 1 }
        end,
      },
      {
        target = host_runtime,
        key = "create_unit_group",
        value = overrides.create_unit_group or function(group_id, pos)
          group_calls[#group_calls + 1] = { group_id = group_id, pos = pos }
          return { _group_id = group_id }
        end,
      },
      {
        target = host_runtime,
        key = "create_unit",
        value = overrides.create_unit or function(unit_id, pos)
          unit_calls[#unit_calls + 1] = { unit_id = unit_id, pos = pos }
          return { _unit_id = unit_id }
        end,
      },
    },
  }
end

M.with_patches = support.with_patches

return M
