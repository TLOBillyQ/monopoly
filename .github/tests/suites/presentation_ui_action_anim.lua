local action_anim = require("src.presentation.render.ActionAnim")
local runtime_port = require("src.presentation.api.UIRuntimePort")

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

local function _with_patches(patches, fn)
  local originals = {}
  for i, patch in ipairs(patches) do
    local target = patch.target or _G
    originals[i] = { target = target, key = patch.key, value = target[patch.key] }
    target[patch.key] = patch.value
  end
  local ok, err = xpcall(fn, debug.traceback)
  for i = #originals, 1, -1 do
    local patch = originals[i]
    patch.target[patch.key] = patch.value
  end
  if not ok then
    error(err)
  end
end

local function _build_state()
  local state = {
    ui = {},
    board_scene = {
      tiles = {
        [1] = {
          get_position = function()
            if math and math.Vector3 then
              return math.Vector3(0.0, 0.0, 0.0)
            end
            return { x = 0.0, y = 0.0, z = 0.0 }
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
  return state
end

local function _test_action_anim_overlay_handler_returns_duration()
  local state = _build_state()
  local duration = action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 })
  assert(duration == 0.2, "roadblock duration should be used")
end

local function _test_action_anim_roll_screen_two_stage_timeline()
  local state = _build_state()
  local nodes = {}
  local node_names = {
    "骰子屏",
    "骰子-旋转骰子底图",
    "骰子-摇骰子结束特效1",
    "骰子-摇骰子结束特效2",
    "骰子-骰子点数1",
    "骰子-骰子点数2",
    "骰子-骰子点数3",
    "骰子-骰子点数4",
    "骰子-骰子点数5",
    "骰子-骰子点数6",
  }
  for _, name in ipairs(node_names) do
    nodes[name] = { visible = false, name = name }
  end

  local timers = {}
  local function run_timers_until(limit)
    table.sort(timers, function(a, b)
      return a.delay < b.delay
    end)
    for _, entry in ipairs(timers) do
      if not entry.done and entry.delay <= limit then
        entry.done = true
        entry.cb()
      end
    end
  end

  _with_patches({
    {
      key = "SetTimeOut",
      value = function(delay, cb)
        timers[#timers + 1] = {
          delay = delay,
          cb = cb,
          done = false,
        }
      end,
    },
    {
      target = runtime_port,
      key = "for_each_role_or_global",
      value = function(fn)
        fn(nil)
      end,
    },
    {
      target = runtime_port,
      key = "query_node",
      value = function(name)
        return assert(nodes[name], "missing test node: " .. tostring(name))
      end,
    },
  }, function()
    local total_duration = action_anim.play(state, {
      kind = "roll",
      duration = 3.0,
      rolls = { 1, 5 },
      total = 6,
    })

    assert(total_duration == 1.5, "roll action duration should use 1s spin + hold")
    assert(nodes["骰子屏"].visible == true, "dice screen should be visible at start")
    assert(nodes["骰子-旋转骰子底图"].visible == true, "spin node should be visible at start")
    assert(nodes["骰子-摇骰子结束特效1"].visible == false, "fx1 should be hidden at start")
    assert(nodes["骰子-摇骰子结束特效2"].visible == false, "fx2 should be hidden at start")
    for i = 1, 6 do
      assert(nodes["骰子-骰子点数" .. i].visible == false, "face should be hidden while spinning")
    end

    run_timers_until(1.0)
    assert(nodes["骰子-旋转骰子底图"].visible == false, "spin node should hide at 1s")
    assert(nodes["骰子-摇骰子结束特效1"].visible == true, "fx1 should show at 1s")
    assert(nodes["骰子-摇骰子结束特效2"].visible == true, "fx2 should show at 1s")
    assert(nodes["骰子-骰子点数1"].visible == true, "first roll face should be shown")
    for i = 2, 6 do
      assert(nodes["骰子-骰子点数" .. i].visible == false, "other faces should remain hidden")
    end

    run_timers_until(1.5)
    assert(nodes["骰子屏"].visible == false, "dice screen should hide after hold")
    assert(nodes["骰子-摇骰子结束特效1"].visible == false, "fx1 should hide after hold")
    assert(nodes["骰子-摇骰子结束特效2"].visible == false, "fx2 should hide after hold")
    for i = 1, 6 do
      assert(nodes["骰子-骰子点数" .. i].visible == false, "all faces should hide after hold")
    end
  end)
end

return {
  _test_action_anim_overlay_handler_returns_duration,
  _test_action_anim_roll_screen_two_stage_timeline,
}
