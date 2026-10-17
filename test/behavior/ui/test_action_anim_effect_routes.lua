-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
---@diagnostic disable: need-check-nil, different-requires, undefined-field

local action_anim = require("src.ui.render.anim")
local handlers = require("src.ui.render.anim.handlers")
local anim_units = require("src.ui.render.anim.units")
local board_feedback = require("src.ui.render.board_feedback.service")
local timing = require("src.config.gameplay.timing")
local logger = require("src.foundation.log")
local host_runtime = require("src.host")
local host_sfx = require("src.ui.seams.host_sfx")
local tip_queue = require("src.foundation.tips")
local runtime_ports_mod = require("src.foundation.ports.runtime_ports")
local move_anim = require("src.ui.render.move_anim")
local unit_position = require("src.ui.render.support.unit_position")
local runtime_port = require("src.ui.render.support.runtime_ui")
local shared_support = require("test.support.shared_support")
local support = require("test.support.ui_action_anim_support")

local _with_patches = support.with_patches

local function _with_tip_presenter(presented, fn)
  tip_queue.clear()
  tip_queue.configure_runtime({
    presenter = function(text, duration, tip)
      presented[#presented + 1] = tip or { text = text, duration = duration }
    end,
    scheduler = function()
      return true
    end,
    test_mode = false,
  })
  local ok, err = xpcall(fn, debug.traceback)
  tip_queue.clear()
  shared_support.restore_runtime_services()
  if not ok then
    error(err, 0)
  end
end

local function _new_roll_nodes()
  local nodes = {}
  local node_names = {
    "骰子屏",
    "骰子_旋转中",
    "骰子_点数1",
    "骰子_点数2",
    "骰子_点数3",
    "骰子_点数4",
    "骰子_点数5",
    "骰子_点数6",
  }
  for _, name in ipairs(node_names) do
    nodes[name] = { visible = false, name = name }
  end
  return nodes
end

local function _run_timers_until(timers, limit)
  table.sort(timers, function(left, right)
    return left.delay < right.delay
  end)
  for _, entry in ipairs(timers) do
    if not entry.done and entry.delay <= limit then
      entry.done = true
      entry.cb()
    end
  end
end

local function _with_roll_runtime(nodes, fn)
  local timers = {}
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
      value = function(cb)
        cb(nil)
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
    fn(timers)
  end)
end

describe("TestActionAnimEffectRoutes", function()

  it("test_action_anim_overlay_handler_returns_duration", function()
    local state = support.build_min_state()
    local duration = action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 })
    luassert.truthy(duration == 0.2, "roadblock duration should be used")
  end)

  it("test_action_anim_play_uses_the_state_presentation_runtime_bundle", function()
    local state = support.build_min_state()
    state.presentation_runtime = {
      host_runtime = nil,
      ui_events = {
        show = {},
        hide = {},
        send_to_all = function() end,
      },
    }

    local duration = action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 })

    luassert.truthy(duration == 0.2, "presentation_runtime bundle should still resolve the duration")
  end)

  it("test_action_anim_move_effect_uses_real_handler_duration", function()
    local state = support.build_min_state()
    local probe = support.capture_handler_duration("play_move_effect")
    probe.set_duration(0.75)

    _with_patches(probe.patches, function()
      local duration = action_anim.play(state, {
        kind = "move_effect",
        player_id = 1,
        from_index = 1,
        to_index = 1,
        duration = 2.0,
      })
      luassert.truthy(duration == 0.75, "move_effect should use handler duration instead of default wait")
    end)

    local captured_anim = probe.captured_anim()
    luassert.truthy(captured_anim ~= nil, "move_effect handler should receive animation payload")
    luassert.truthy(captured_anim.direction ~= nil, "move_effect handler should receive a fallback direction")
  end)

  it("test_action_anim_teleport_effect_uses_real_handler_duration_without_direction_patch", function()
    local state = support.build_min_state()
    local probe = support.capture_handler_duration("play_teleport_effect")
    probe.set_duration(0)

    _with_patches(probe.patches, function()
      local duration = action_anim.play(state, {
        kind = "teleport_effect",
        player_id = 1,
        from_index = 1,
        to_index = 1,
        duration = 2.0,
      })
      luassert.truthy(duration == 0, "teleport_effect should use handler duration instead of default wait")
    end)

    local captured_anim = probe.captured_anim()
    luassert.truthy(captured_anim ~= nil, "teleport_effect handler should receive animation payload")
    luassert.truthy(captured_anim.direction == nil, "teleport_effect should not receive move direction fallback")
  end)

  it("test_action_anim_forced_relocation_uses_real_handler_duration_without_direction_patch", function()
    local state = support.build_min_state()
    local probe = support.capture_handler_duration("play_forced_relocation")
    probe.set_duration(0)

    _with_patches(probe.patches, function()
      local duration = action_anim.play(state, {
        kind = "forced_relocation",
        player_id = 1,
        from_index = 1,
        to_index = 1,
        duration = 2.0,
      })
      luassert.truthy(duration == 0, "forced_relocation should use handler duration instead of default wait")
    end)

    local captured_anim = probe.captured_anim()
    luassert.truthy(captured_anim ~= nil, "forced_relocation handler should receive animation payload")
    luassert.truthy(captured_anim.direction == nil, "forced_relocation should not receive move direction fallback")
  end)

  it("test_action_anim_mine_trigger_uses_real_handler_duration_without_direction_patch", function()
    local state = support.build_min_state()
    local probe = support.capture_handler_duration("play_mine_trigger")
    probe.set_duration(0)

    _with_patches(probe.patches, function()
      local duration = action_anim.play(state, {
        kind = "mine_trigger",
        player_id = 1,
        tile_index = 1,
        from_index = 1,
        to_index = 1,
        cue_name = "mine_blast",
        duration = 2.0,
      })
      luassert.truthy(duration == 0, "mine_trigger should use handler duration instead of default wait")
    end)

    local captured_anim = probe.captured_anim()
    luassert.truthy(captured_anim ~= nil, "mine_trigger handler should receive animation payload")
    luassert.truthy(captured_anim.direction == nil, "mine_trigger should not receive move direction fallback")
  end)

  it("test_action_anim_missile_waits_before_starting_handler", function()
    local state = support.build_min_state()
    local scheduled_delay = nil
    local scheduled_fn = nil
    local sfx_calls = {}
    local expected_delay = timing.demolish_effect_start_delay_seconds or 0.2

    _with_patches({
      {
        target = host_sfx,
        key = "play_sfx_by_key",
        value = function(sfx_key, pos)
          sfx_calls[#sfx_calls + 1] = { sfx_key = sfx_key, pos = pos }
          return nil
        end,
      },
      {
        target = runtime_ports_mod,
        key = "schedule",
        value = function(delay, fn)
          scheduled_delay = delay
          scheduled_fn = fn
        end,
      },
    }, function()
      local duration = action_anim.play(state, {
        kind = "missile",
        tile_index = 1,
        duration = 0.6,
      })
      luassert.truthy(duration == 0.6 + expected_delay, "missile should add startup delay to total duration")
      luassert.truthy(scheduled_delay == expected_delay, "missile should schedule handler after startup delay")
      luassert.truthy(#sfx_calls == 0, "missile should not emit host effects before ui closes")
      luassert.truthy(type(scheduled_fn) == "function", "missile should enqueue delayed handler callback")
      scheduled_fn()
      luassert.truthy(#sfx_calls == 1, "missile should emit its host effect after delayed callback")
      luassert.truthy(sfx_calls[1].sfx_key == 1288, "missile delayed callback should emit mine_blast")
    end)
  end)

  it("test_action_anim_monster_waits_before_starting_handler", function()
    local state = support.build_min_state()
    local scheduled_delay = nil
    local scheduled_fn = nil
    local sfx_calls = {}
    local expected_delay = timing.demolish_effect_start_delay_seconds or 0.2

    _with_patches({
      {
        target = host_sfx,
        key = "play_sfx_by_key",
        value = function(sfx_key, pos)
          sfx_calls[#sfx_calls + 1] = { sfx_key = sfx_key, pos = pos }
          return nil
        end,
      },
      {
        target = runtime_ports_mod,
        key = "schedule",
        value = function(delay, fn)
          scheduled_delay = delay
          scheduled_fn = fn
        end,
      },
    }, function()
      local duration = action_anim.play(state, {
        kind = "monster",
        tile_index = 1,
        duration = 0.6,
      })
      luassert.truthy(duration == 0.6 + expected_delay, "monster should add startup delay to total duration")
      luassert.truthy(scheduled_delay == expected_delay, "monster should schedule handler after startup delay")
      luassert.truthy(#sfx_calls == 0, "monster should not emit host effects before ui closes")
      luassert.truthy(type(scheduled_fn) == "function", "monster should enqueue delayed handler callback")
      scheduled_fn()
      luassert.truthy(#sfx_calls == 1, "monster should emit its host effect after delayed callback")
      luassert.truthy(sfx_calls[1].sfx_key == 1288, "monster delayed callback should emit mine_blast")
    end)
  end)

  it("test_action_anim_roadblock_trigger_routes_clear_overlay", function()
    local state = support.build_min_state()
    local cleared = {}
    local scheduled_delay = nil
    local scheduled_fn = nil
    local expected_delay = timing.roadblock_destroy_hold_seconds

    _with_patches({
      {
        target = action_anim,
        key = "clear_overlay",
        value = function(_, kind, tile_index)
          cleared[#cleared + 1] = kind .. ":" .. tostring(tile_index)
        end,
      },
      {
        target = runtime_ports_mod,
        key = "schedule",
        value = function(delay, fn)
          scheduled_delay = delay
          scheduled_fn = fn
        end,
      },
    }, function()
      action_anim.play(state, { kind = "roadblock_trigger", tile_index = 1, duration = 0.2 })
      luassert.truthy(scheduled_delay == expected_delay, "roadblock_trigger should hold destroy by config delay")
      luassert.truthy(type(scheduled_fn) == "function", "roadblock_trigger should enqueue destroy callback")
      luassert.truthy(#cleared == 0, "roadblock overlay should not clear before scheduled callback fires")
      scheduled_fn()
      luassert.truthy(cleared[1] == "roadblock:1", "scheduled callback should clear the roadblock overlay")
    end)
  end)

  it("test_action_anim_upgrade_land_routes_sfx_without_overlay_units", function()
    local state = support.build_min_state()
    state.board_scene.overlay_units = {
      roadblocks = {},
      mines = {},
    }
    local sfx_calls = {}

    _with_patches({
      {
        target = host_sfx,
        key = "play_sfx_by_key",
        value = function(sfx_key)
          sfx_calls[#sfx_calls + 1] = sfx_key
          return nil
        end,
      },
    }, function()
      local out_duration = action_anim.play(state, {
        kind = "upgrade_land",
        tile_index = 1,
        level = 1,
        duration = 0.6,
      })
      luassert.truthy(out_duration == 0.6, "upgrade_land should keep configured duration")
    end)

    luassert.truthy(#sfx_calls == 1, "upgrade_land should emit its configured host effect")
    luassert.truthy(sfx_calls[1] == 4286, "upgrade_land should emit upgrade_land_smoke")
    luassert.truthy(next(state.board_scene.overlay_units.roadblocks) == nil, "upgrade_land should not create roadblock overlays")
    luassert.truthy(next(state.board_scene.overlay_units.mines) == nil, "upgrade_land should not create mine overlays")
  end)

  it("test_action_anim_is_silent_by_default", function()
    local state = support.build_min_state()
    local presented = {}

    _with_tip_presenter(presented, function()
      local duration = action_anim.play(state, {
        kind = "item_use",
        player_id = 1,
        item_id = 2001,
        duration = 0.6,
      })
      luassert.truthy(duration == 0.6, "silent action anim should still return duration")
    end)

    luassert.truthy(#presented == 0, "action anim should not present user tips by default")
  end)

  it("test_action_anim_user_tip_policy_forces_tip", function()
    local state = support.build_min_state()
    local tips = {}

    _with_patches({
      {
        target = tip_queue,
        key = "enqueue",
        value = function(intent)
          tips[#tips + 1] = intent
          return true
        end,
      },
    }, function()
      action_anim.play(state, {
        kind = "item_use",
        player_id = 1,
        item_id = 2001,
        item_name = "免费卡",
        duration = 0.6,
        tip_policy = "user",
      })
    end)

    luassert.truthy(#tips == 1, "tip_policy=user should force exactly one tip")
    luassert.truthy(tips[1].text ~= nil and tips[1].text ~= "", "forced tip should contain text")
  end)

  it("test_action_anim_debug_log_uses_info_without_tip", function()
    local state = support.build_min_state()
    local presented = {}
    local info_calls = {}

    _with_patches({
      {
        target = logger,
        key = "anim_debug_enabled_provider",
        value = function()
          return true
        end,
      },
      {
        target = logger,
        key = "info_unlimited",
        value = function(...)
          info_calls[#info_calls + 1] = table.concat({ ... }, " ")
        end,
      },
      {
        target = handlers,
        key = "play_move_effect",
        value = function()
          return 0.6
        end,
      },
    }, function()
      _with_tip_presenter(presented, function()
        action_anim.play(state, {
          kind = "move_effect",
          player_id = 1,
          from_index = 1,
          to_index = 1,
          duration = 0.6,
        })
      end)
    end)

    luassert.truthy(#presented == 0, "debug action anim log should not present a tip")
    luassert.truthy(#info_calls == 1, "debug action anim log should emit one info log")
  end)

  it("test_host_runtime_sfx_port_skips_missing_keys_and_routes_valid_calls", function()
    local sfx_calls = {}
    local sound_calls = {}

    _with_patches({
      {
        key = "GameAPI",
        value = {
          play_sfx_by_key = function(sfx_key, pos, rot, scale, duration, rate, with_sound)
            sfx_calls[#sfx_calls + 1] = {
              sfx_key = sfx_key,
              pos = pos,
              rot = rot,
              scale = scale,
              duration = duration,
              rate = rate,
              with_sound = with_sound,
            }
            return 101
          end,
          play_3d_sound = function(pos, sound_id, duration, volume)
            sound_calls[#sound_calls + 1] = {
              pos = pos,
              sound_id = sound_id,
              duration = duration,
              volume = volume,
            }
            return 202
          end,
        },
      },
    }, function()
      local pos = math.Vector3(1.0, 2.0, 3.0)
      local sfx_id = host_runtime.play_sfx_by_key(4286, pos, nil, 1.0, 1.0, nil, false)
      local missing_id = host_runtime.play_sfx_by_key(nil, pos, nil, nil, 1.0, nil, false)
      local zero_sfx_id = host_runtime.play_sfx_by_key(0, pos, nil, nil, 1.0, nil, false)
      local string_sfx_id = host_runtime.play_sfx_by_key("fx.valid", pos, nil, nil, 1.0, nil, false)
      local vector_scale_id = host_runtime.play_sfx_by_key(4286, pos, nil, math.Vector3(1.0, 1.0, 1.0), 1.0, nil, false)
      local sound_id = host_runtime.play_3d_sound(pos, 301, 0.8, 1.0)
      local missing_sound_id = host_runtime.play_3d_sound(pos, nil, 0.8, 1.0)
      local zero_sound_id = host_runtime.play_3d_sound(pos, 0, 0.8, 1.0)
      local string_sound_id = host_runtime.play_3d_sound(pos, "snd.valid", 0.8, 1.0)

      luassert.truthy(sfx_id == 101, "valid sfx call should return engine id")
      luassert.truthy(missing_id == nil, "missing sfx key should skip safely")
      luassert.truthy(zero_sfx_id == nil, "zero sfx key should skip safely")
      luassert.truthy(string_sfx_id == nil, "string sfx key should skip safely")
      luassert.truthy(vector_scale_id == nil, "vector scale should skip safely")
      luassert.truthy(sound_id == 202, "valid sound call should return engine id")
      luassert.truthy(missing_sound_id == nil, "missing sound id should skip safely")
      luassert.truthy(zero_sound_id == nil, "zero sound id should skip safely")
      luassert.truthy(string_sound_id == nil, "string sound id should skip safely")
    end)

    luassert.truthy(#sfx_calls == 1, "invalid sfx keys should not call engine")
    luassert.truthy(sfx_calls[1].sfx_key == 4286, "sfx key should route unchanged as integer")
    luassert.truthy(sfx_calls[1].scale == 1.0, "direct sfx port should pass caller-provided scalar scale")
    luassert.truthy(sfx_calls[1].rate == 1.0, "direct sfx port should default missing rate to 1.0")
    luassert.truthy(sfx_calls[1].with_sound == false, "direct sfx port should default with_sound to false")
    luassert.truthy(sfx_calls[1].rot ~= nil, "direct sfx port should default missing rot")
    luassert.truthy(#sound_calls == 1, "sound call should route once")
    luassert.truthy(sound_calls[1].sound_id == 301, "sound id should route unchanged")
  end)

  it("test_action_anim_upgrade_land_routes_board_feedback", function()
    local state = support.build_min_state()
    local calls = {}

    _with_patches({
      {
        target = board_feedback,
        key = "play_tile_cue",
        value = function(_, cue_name, tile_index, payload)
          calls[#calls + 1] = {
            cue_name = cue_name,
            tile_index = tile_index,
            player_id = payload and payload.player_id or nil,
            use_building_tile_position = payload and payload.use_building_tile_position or nil,
          }
          return true
        end,
      },
    }, function()
      local out_duration = action_anim.play(state, {
        kind = "upgrade_land",
        player_id = 1,
        tile_index = 1,
        level = 2,
        duration = 0.6,
      })
      luassert.truthy(out_duration == 0.6, "upgrade_land should keep configured duration")
    end)

    luassert.truthy(#calls == 1, "upgrade_land should route exactly one board feedback cue")
    luassert.truthy(calls[1].cue_name == "upgrade_land_smoke", "upgrade cue name mismatch")
    luassert.truthy(calls[1].tile_index == 1, "upgrade cue should target tile index")
    luassert.truthy(calls[1].player_id == 1, "upgrade cue should preserve player id")
    luassert.truthy(calls[1].use_building_tile_position == true, "upgrade cue should request building tile position")
  end)

  it("test_action_anim_cash_receive_routes_board_feedback", function()
    local state = support.build_min_state()
    local calls = {}

    _with_patches({
      {
        target = board_feedback,
        key = "play_player_cue",
        value = function(_, cue_name, player_id, payload)
          calls[#calls + 1] = {
            cue_name = cue_name,
            player_id = player_id,
            amount = payload and payload.amount or nil,
          }
          return true
        end,
      },
    }, function()
      local out_duration = action_anim.play(state, {
        kind = "cash_receive",
        player_id = 1,
        amount = 500,
        duration = 0.7,
      })
      luassert.truthy(out_duration == 0.7, "cash_receive should keep configured duration")
    end)

    luassert.truthy(#calls == 1, "cash_receive should route exactly one board feedback cue")
    luassert.truthy(calls[1].cue_name == "cash_burst", "cash cue name mismatch")
    luassert.truthy(calls[1].player_id == 1, "cash cue should preserve player id")
    luassert.truthy(calls[1].amount == 500, "cash cue should preserve amount")
  end)

  it("test_play_mine_trigger_prefers_player_cue_with_unit_position", function()
    local state = support.build_min_state()
    local expected_pos = { x = 1, y = 2, z = 3 }
    local tile_pos = { x = 9, y = 9, z = 9 }
    state.board_scene.units_by_player_id[1] = {
      get_position = function()
        return expected_pos
      end,
    }
    state.board_scene.tiles[1].get_position = function()
      return tile_pos
    end
    state.board_scene.overlay_units = {
      roadblocks = {},
      mines = {
        [1] = { kind = "unit", handle = {}, pooled = false },
      },
    }
    local sfx_calls = {}

    _with_patches({
      {
        target = host_sfx,
        key = "play_sfx_by_key",
        value = function(sfx_key, pos)
          sfx_calls[#sfx_calls + 1] = { sfx_key = sfx_key, pos = pos }
          return nil
        end,
      },
      {
        target = move_anim,
        key = "prepare_player_for_snap",
        value = function() end,
      },
      {
        target = move_anim,
        key = "snap_player_to_index",
        value = function()
          return 0.4
        end,
      },
    }, function()
      local duration = anim_units.play_mine_trigger(state, {
        player_id = 1,
        tile_index = 1,
        to_index = 2,
        cue_name = "mine_blast",
      }, 0.1, {
        clear_overlay = anim_units.clear_overlay,
      })

      luassert.truthy(duration == 0.4, "play_mine_trigger should keep positive snap delay when above minimum duration")
    end)

    luassert.truthy(#sfx_calls == 1, "play_mine_trigger should emit exactly one host cue")
    luassert.truthy(sfx_calls[1].sfx_key == 1288, "play_mine_trigger should emit mine_blast")
    luassert.truthy(sfx_calls[1].pos == expected_pos, "play_mine_trigger should prefer unit position over tile position")
    luassert.truthy(state.board_scene.overlay_units.mines[1] == nil, "play_mine_trigger should remove the mine from the public overlay runtime")
  end)

  it("test_play_mine_trigger_falls_back_to_tile_position_for_player_cue", function()
    local state = support.build_min_state()
    local expected_pos = { x = 4, y = 5, z = 6 }
    local tile_cue_pos = { x = 9, y = 9, z = 9 }
    local current_tile_pos = expected_pos
    state.board_scene.tiles[1].get_position = function()
      local resolved = current_tile_pos
      current_tile_pos = tile_cue_pos
      return resolved
    end
    local sfx_calls = {}

    _with_patches({
      {
        target = host_sfx,
        key = "play_sfx_by_key",
        value = function(sfx_key, pos)
          sfx_calls[#sfx_calls + 1] = { sfx_key = sfx_key, pos = pos }
          return nil
        end,
      },
      {
        target = move_anim,
        key = "prepare_player_for_snap",
        value = function() end,
      },
      {
        target = move_anim,
        key = "snap_player_to_index",
        value = function()
          return 0
        end,
      },
    }, function()
      anim_units.play_mine_trigger(state, {
        player_id = 1,
        tile_index = 1,
        to_index = 2,
      }, 0, {
        clear_overlay = function() end,
      })
    end)

    luassert.truthy(#sfx_calls == 1, "play_mine_trigger should emit exactly one host cue")
    luassert.truthy(sfx_calls[1].sfx_key == 1288, "play_mine_trigger should emit mine_blast")
    luassert.truthy(sfx_calls[1].pos == expected_pos, "player cue should reuse the hit position instead of resolving a tile cue position")
  end)

  it("test_play_mine_trigger_uses_tile_cue_after_hit_position_miss_and_normalizes_minimum_delay", function()
    local state = support.build_min_state()
    local expected_pos = { x = 4, y = 5, z = 6 }
    local current_tile_pos = nil
    state.board_scene.tiles[3] = {
      get_position = function()
        local resolved = current_tile_pos
        current_tile_pos = expected_pos
        return resolved
      end,
    }
    local sfx_calls = {}

    _with_patches({
      {
        target = host_sfx,
        key = "play_sfx_by_key",
        value = function(sfx_key, pos)
          sfx_calls[#sfx_calls + 1] = { sfx_key = sfx_key, pos = pos }
          return nil
        end,
      },
      {
        target = move_anim,
        key = "prepare_player_for_snap",
        value = function() end,
      },
      {
        target = move_anim,
        key = "snap_player_to_index",
        value = function()
          return -1
        end,
      },
    }, function()
      local duration = anim_units.play_mine_trigger(state, {
        player_id = 1,
        tile_index = 3,
        to_index = 2,
      }, 0.2, {
        clear_overlay = function() end,
      })

      luassert.truthy(duration == 0.2, "play_mine_trigger should clamp negative snap delay to minimum duration")
    end)

    luassert.truthy(#sfx_calls == 1, "tile fallback should emit exactly one host cue")
    luassert.truthy(sfx_calls[1].sfx_key == 1288, "tile fallback should emit mine_blast")
    luassert.truthy(sfx_calls[1].pos == expected_pos, "tile fallback should resolve its own public tile position")
  end)

  it("test_play_mine_trigger_clears_mine_before_snap_without_scheduler", function()
    local state = support.build_min_state()
    local steps = {}

    _with_patches({
      {
        target = unit_position,
        key = "read_unit_position",
        value = function()
          return nil
        end,
      },
      {
        target = unit_position,
        key = "read_scene_tile_position",
        value = function()
          return nil
        end,
      },
      {
        target = board_feedback,
        key = "play_player_cue",
        value = function()
          steps[#steps + 1] = "player_cue"
        end,
      },
      {
        target = board_feedback,
        key = "play_tile_cue",
        value = function(_, cue_name, tile_index)
          steps[#steps + 1] = cue_name .. ":" .. tostring(tile_index)
        end,
      },
      {
        target = move_anim,
        key = "prepare_player_for_snap",
        value = function()
          steps[#steps + 1] = "prepare"
        end,
      },
      {
        target = move_anim,
        key = "snap_player_to_index",
        value = function()
          steps[#steps + 1] = "snap"
          return -1
        end,
      },
    }, function()
      local duration = anim_units.play_mine_trigger(state, {
        player_id = 1,
        tile_index = 3,
        to_index = 2,
        cue_name = "mine_blast",
      }, -0.5, {
        clear_overlay = function(_, kind, tile_index)
          steps[#steps + 1] = kind .. ":" .. tostring(tile_index)
        end,
      })

      luassert.truthy(duration == 0, "play_mine_trigger should normalize negative fallback duration to zero")
    end)

    luassert.truthy(steps[1] == "mine_blast:3", "play_mine_trigger should emit tile cue immediately when no hit position exists")
    luassert.truthy(steps[2] == "mine:3", "play_mine_trigger should clear the mine overlay before snapping")
    luassert.truthy(steps[3] == "prepare", "play_mine_trigger should prepare the player after clearing the mine")
    luassert.truthy(steps[4] == "snap", "play_mine_trigger should snap after clearing the mine")
  end)

  it("test_play_missile_plays_blast_and_delays_upgrade_smoke", function()
    local state = support.build_min_state()
    local cue_calls = {}
    local scheduled_delay = nil
    local scheduled_fn = nil
    local expected_delay = timing.demolish_effect_followup_delay_seconds or 0.35

    _with_patches({
      {
        target = board_feedback,
        key = "play_tile_cue",
        value = function(_, cue_name, tile_index, payload)
          cue_calls[#cue_calls + 1] = {
            cue_name = cue_name,
            tile_index = tile_index,
            use_building_tile_position = payload and payload.use_building_tile_position,
          }
          return true
        end,
      },
      {
        target = move_anim,
        key = "prepare_player_for_snap",
        value = function() end,
      },
      {
        target = move_anim,
        key = "snap_player_to_index",
        value = function()
          return 0
        end,
      },
      {
        target = require("src.ui.render.anim.unit_overlay"),
        key = "play_missile",
        value = function() end,
      },
    }, function()
      anim_units.play_missile(state, {
        tile_index = 3,
        target_player_ids = { 2 },
        to_index = 4,
      }, 0.5, {
        schedule = function(delay, fn)
          scheduled_delay = delay
          scheduled_fn = fn
        end,
        clear_overlay = function() end,
      })

      luassert.truthy(#cue_calls == 1, "play_missile should emit mine blast immediately")
      luassert.truthy(cue_calls[1].cue_name == "mine_blast", "play_missile should reuse mine blast cue")
      luassert.truthy(cue_calls[1].tile_index == 3, "play_missile should target the demolished tile")
      luassert.truthy(cue_calls[1].use_building_tile_position == false, "play_missile blast should use tile position")
      luassert.truthy(scheduled_delay == expected_delay, "play_missile should delay upgrade smoke cue")
      luassert.truthy(type(scheduled_fn) == "function", "play_missile should schedule followup upgrade smoke cue")

      scheduled_fn()

      luassert.truthy(#cue_calls == 2, "play_missile should emit delayed upgrade smoke cue")
      luassert.truthy(cue_calls[2].cue_name == "upgrade_land_smoke", "play_missile should reuse upgrade smoke cue")
      luassert.truthy(cue_calls[2].tile_index == 3, "play_missile delayed smoke should target the demolished tile")
      luassert.truthy(cue_calls[2].use_building_tile_position == false, "play_missile delayed smoke should use tile position")
    end)
  end)

  it("test_play_monster_plays_blast_and_delays_upgrade_smoke", function()
    local state = support.build_min_state()
    local cue_calls = {}
    local scheduled_delay = nil
    local scheduled_fn = nil
    local expected_delay = timing.demolish_effect_followup_delay_seconds or 0.35

    _with_patches({
      {
        target = board_feedback,
        key = "play_tile_cue",
        value = function(_, cue_name, tile_index, payload)
          cue_calls[#cue_calls + 1] = {
            cue_name = cue_name,
            tile_index = tile_index,
            use_building_tile_position = payload and payload.use_building_tile_position,
          }
          return true
        end,
      },
      {
        target = require("src.ui.render.anim.unit_overlay"),
        key = "play_monster",
        value = function() end,
      },
    }, function()
      anim_units.play_monster(state, {
        tile_index = 5,
      }, 0.5, {
        schedule = function(delay, fn)
          scheduled_delay = delay
          scheduled_fn = fn
        end,
      })

      luassert.truthy(#cue_calls == 1, "play_monster should emit mine blast immediately")
      luassert.truthy(cue_calls[1].cue_name == "mine_blast", "play_monster should reuse mine blast cue")
      luassert.truthy(cue_calls[1].tile_index == 5, "play_monster should target the demolished tile")
      luassert.truthy(cue_calls[1].use_building_tile_position == true, "play_monster blast should use building position")
      luassert.truthy(scheduled_delay == expected_delay, "play_monster should delay upgrade smoke cue")
      luassert.truthy(type(scheduled_fn) == "function", "play_monster should schedule followup upgrade smoke cue")

      scheduled_fn()

      luassert.truthy(#cue_calls == 2, "play_monster should emit delayed upgrade smoke cue")
      luassert.truthy(cue_calls[2].cue_name == "upgrade_land_smoke", "play_monster should reuse upgrade smoke cue")
      luassert.truthy(cue_calls[2].tile_index == 5, "play_monster delayed smoke should target the demolished tile")
      luassert.truthy(cue_calls[2].use_building_tile_position == true, "play_monster delayed smoke should use building position")
    end)
  end)

  it("test_play_mine_trigger_delays_snap_when_schedule_available", function()
    local state = support.build_min_state()
    local scheduled_delay = nil
    local scheduled_fn = nil
    local steps = {}

    _with_patches({
      {
        target = unit_position,
        key = "read_unit_position",
        value = function()
          return { x = 1, y = 2, z = 3 }
        end,
      },
      {
        target = board_feedback,
        key = "play_player_cue",
        value = function()
          steps[#steps + 1] = "cue"
        end,
      },
      {
        target = move_anim,
        key = "prepare_player_for_snap",
        value = function()
          steps[#steps + 1] = "prepare"
        end,
      },
      {
        target = move_anim,
        key = "snap_player_to_index",
        value = function()
          steps[#steps + 1] = "snap"
          return 0
        end,
      },
    }, function()
      local duration = anim_units.play_mine_trigger(state, {
        player_id = 1,
        tile_index = 1,
        to_index = 2,
      }, 0, {
        clear_overlay = function()
          steps[#steps + 1] = "clear"
        end,
        schedule = function(delay, fn)
          scheduled_delay = delay
          scheduled_fn = fn
        end,
      })

      -- #550:瞬移延时改由 anim duration 承担(此处传 0),销毁雷挪进回调
      luassert.truthy(duration == 0, "play_mine_trigger should return the anim duration as the snap delay")
      luassert.truthy(scheduled_delay == 0, "play_mine_trigger should schedule the snap at the anim duration")
      luassert.truthy(type(scheduled_fn) == "function", "play_mine_trigger should enqueue delayed snap callback")
      luassert.truthy(steps[1] == "cue", "mine feedback cue should emit immediately")
      luassert.truthy(steps[2] == nil, "mine overlay should zero-destroy at handler start; clear defers into the callback")

      scheduled_fn()
      luassert.truthy(steps[2] == "clear", "scheduled callback should clear the mine overlay first")
      luassert.truthy(steps[3] == "prepare", "scheduled callback should prepare player for snap")
      luassert.truthy(steps[4] == "snap", "scheduled callback should snap player to hospital")
    end)
  end)

  it("test_action_anim_roll_screen_two_stage_timeline", function()
    local state = support.build_min_state()
    local nodes = _new_roll_nodes()

    _with_roll_runtime(nodes, function(timers)
      local total_duration = action_anim.play(state, {
        kind = "roll",
        duration = 3.0,
        rolls = { 1, 5 },
        total = 6,
      })

      luassert.truthy(total_duration == 2.0, "roll action duration should use 1.0s spin + 1.0s hold")
      luassert.truthy(nodes["骰子屏"].visible == true, "dice screen should be visible at start")
      luassert.truthy(nodes["骰子_旋转中"].visible == true, "spin node should be visible at start")
      for i = 1, 6 do
        luassert.truthy(nodes["骰子_点数" .. i].visible == false, "face should be hidden while spinning")
      end

      _run_timers_until(timers, 1.0)
      luassert.truthy(nodes["骰子_旋转中"].visible == false, "spin node should hide at 1.0s")
      luassert.truthy(nodes["骰子_点数1"].visible == true, "first roll face should be shown")

      _run_timers_until(timers, 1.6)
      luassert.truthy(nodes["骰子屏"].visible == true, "dice screen should stay visible during hold")
      luassert.truthy(nodes["骰子_点数1"].visible == true, "face should remain visible during hold")

      _run_timers_until(timers, 2.0)
      luassert.truthy(nodes["骰子屏"].visible == false, "dice screen should hide after hold")
      for i = 1, 6 do
        luassert.truthy(nodes["骰子_点数" .. i].visible == false, "all faces should hide after hold")
      end
    end)
  end)

  it("test_action_anim_roll_screen_fallback_face_when_invalid", function()
    local state = support.build_min_state()
    local nodes = _new_roll_nodes()

    _with_roll_runtime(nodes, function(timers)
      action_anim.play(state, {
        kind = "roll",
        duration = 3.0,
        rolls = {
          setmetatable({}, {
            __tostring = function()
              return "bad"
            end,
          }),
        },
        total = "bad",
      })

      _run_timers_until(timers, 1.0)
      luassert.truthy(nodes["骰子_旋转中"].visible == false, "spin node should hide at 1.0s")
      luassert.truthy(nodes["骰子_点数1"].visible == true, "fallback face should show 1 when parsed face is invalid")
      for i = 2, 6 do
        luassert.truthy(nodes["骰子_点数" .. i].visible == false, "other faces should remain hidden on fallback")
      end
    end)
  end)


end)
