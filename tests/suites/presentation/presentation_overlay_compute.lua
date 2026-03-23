local overlay_compute = require("src.ui.render.anim_overlay_compute")
local visual_sync = require("src.ui.render.board.visual_sync")
local overlay_runtime = require("src.ui.render.anim_overlay_runtime")
local host_runtime = require("src.host.eggy")
local logger = require("src.core.utils.logger")
local tip_queue = require("src.core.utils.tip_queue")
local runtime_context = require("src.host.eggy.context")

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

local function _with_patches(patches, fn)
  local function _refresh_runtime_ctx()
    local lua_api = {}
    if type(LuaAPI) == "table" then
      for key, value in pairs(LuaAPI) do
        lua_api[key] = value
      end
    end
    if type(SetTimeOut) == "function" then
      lua_api.call_delay_time = function(delay, cb)
        return SetTimeOut(delay, cb)
      end
    elseif type(lua_api.call_delay_time) ~= "function" then
      lua_api.call_delay_time = function(_, cb)
        if cb then
          cb()
          return true
        end
        return false
      end
    end
    runtime_context.set_current(runtime_context.new({
      GameAPI = GameAPI,
      LuaAPI = lua_api,
    }))
    tip_queue.configure_runtime({
      presenter = function(text, duration)
        if GlobalAPI and type(GlobalAPI.show_tips) == "function" then
          return GlobalAPI.show_tips(text, duration)
        end
        return false
      end,
      scheduler = function(delay, cb)
        return lua_api.call_delay_time(delay, cb)
      end,
      test_mode = logger.is_test_mode(),
    })
  end

  local originals = {}
  for i, patch in ipairs(patches) do
    local target = patch.target or _G
    originals[i] = { target = target, key = patch.key, value = target[patch.key] }
    target[patch.key] = patch.value
  end
  _refresh_runtime_ctx()
  local ok, err = xpcall(fn, debug.traceback)
  for i = #originals, 1, -1 do
    local patch = originals[i]
    patch.target[patch.key] = patch.value
  end
  _refresh_runtime_ctx()
  if not ok then
    error(err)
  end
end

local function _build_state()
  return {
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
    },
    game = {
      board = {
        get_tile = function()
          return { name = "测试地块" }
        end,
      },
      find_player_by_id = function()
        return { position = 1, name = "测试玩家" }
      end,
    },
  }
end

local function _make_host_unit(x, y, z)
  if type(newproxy) == "function" then
    local unit = newproxy(true)
    getmetatable(unit).__index = {
      get_position = function()
        return math.Vector3(x, y, z)
      end,
    }
    return unit
  end
  return {
    get_position = function()
      return math.Vector3(x, y, z)
    end,
  }
end

local function _test_overlay_compute_reads_host_unit_position_without_table_guard()
  local state = _build_state()
  state.board_scene.tiles[1] = _make_host_unit(5.0, 6.0, 7.0)

  local pos = overlay_compute.overlay_pos_for_tile(state, 1)
  assert(pos.x == 5.0, "overlay compute should preserve host unit x")
  assert(pos.y == 7.0, "overlay compute should add y offset on host unit position")
  assert(pos.z == 7.0, "overlay compute should preserve host unit z")
end

local function _test_visual_sync_overlay_uses_host_unit_position()
  local state = _build_state()
  state.board_scene.tiles[1] = _make_host_unit(12.0, 3.0, 4.0)
  state.game.board = {
    has_roadblock = function()
      return false
    end,
    has_mine = function()
      return true
    end,
  }
  local spawn_calls = {}

  _with_patches({
    {
      target = overlay_runtime,
      key = "spawn_overlay",
      value = function(scene, kind, tile_index, group_id, unit_id, pos)
        spawn_calls[#spawn_calls + 1] = {
          kind = kind,
          tile_index = tile_index,
          pos = pos,
        }
        return true
      end,
    },
  }, function()
    local handled = visual_sync.sync_overlay_visual(state, 1)
    assert(handled == true, "visual sync should handle mine overlay")
  end)

  assert(#spawn_calls == 1, "visual sync should spawn one mine overlay")
  assert(spawn_calls[1].kind == "mine", "visual sync should spawn mine overlay")
  assert(spawn_calls[1].pos.x == 12.0, "visual sync should pass host unit x")
  assert(spawn_calls[1].pos.y == 4.0, "visual sync should add overlay y offset")
  assert(spawn_calls[1].pos.z == 4.0, "visual sync should pass host unit z")
end

local function _test_overlay_runtime_spawn_transient_schedules_destroy_for_groups()
  local calls = {
    create_group = 0,
    destroy = 0,
    scheduled = 0,
  }

  _with_patches({
    {
      target = host_runtime,
      key = "create_unit_group",
      value = function(group_id, pos)
        calls.create_group = calls.create_group + 1
        return { id = group_id, pos = pos }
      end,
    },
    {
      target = host_runtime,
      key = "destroy_unit_with_children",
      value = function()
        calls.destroy = calls.destroy + 1
      end,
    },
    {
      target = host_runtime,
      key = "schedule",
      value = function(delay, fn)
        calls.scheduled = delay
        fn()
      end,
    },
  }, function()
    overlay_runtime.spawn_transient(2001, nil, math.Vector3(1, 2, 3), 0.5, {
      host_runtime = host_runtime,
    })
  end)

  assert(calls.create_group == 1, "spawn_transient should create one transient group")
  assert(calls.scheduled == 0.5, "spawn_transient should schedule delayed cleanup")
  assert(calls.destroy == 1, "spawn_transient should destroy transient group after delay")
end

return {
  name = "presentation.overlay_compute",
  tests = {
    { name = "overlay_compute_reads_host_unit_position_without_table_guard", run = _test_overlay_compute_reads_host_unit_position_without_table_guard },
    { name = "visual_sync_overlay_uses_host_unit_position", run = _test_visual_sync_overlay_uses_host_unit_position },
    { name = "overlay_runtime_spawn_transient_schedules_destroy_for_groups", run = _test_overlay_runtime_spawn_transient_schedules_destroy_for_groups },
  },
}
