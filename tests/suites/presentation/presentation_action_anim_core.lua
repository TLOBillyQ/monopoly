local action_anim = require("src.presentation.view.render.action_anim")
local runtime_port = require("src.presentation.runtime.ui")
local handlers = require("src.presentation.view.render.anim_handlers")
local host_runtime = require("src.presentation.runtime.host")
local board_feedback = require("src.presentation.view.render.board_feedback_service")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local logger = require("src.core.utils.logger")
local support = require("support.presentation_support")

local _with_patches = support.with_patches

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
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

local function _test_action_anim_overlay_handler_returns_duration()
  local state = _build_state()
  local duration = action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 })
  assert(duration == 0.2, "roadblock duration should be used")
end

local function _test_action_anim_roadblock_overlay_uses_4x_scale()
  local state = _build_state()
  local unit_calls = 0
  local group_calls = 0
  local captured_scale = nil

  _with_patches({
    {
      target = host_runtime,
      key = "create_unit_with_scale",
      value = function(_, _, _, scale)
        unit_calls = unit_calls + 1
        captured_scale = scale
        return { _unit_id = 1 }
      end,
    },
    {
      target = host_runtime,
      key = "create_unit_group",
      value = function()
        group_calls = group_calls + 1
        return { _group_id = 1 }
      end,
    },
  }, function()
    action_anim.play(state, { kind = "roadblock", tile_index = 1, duration = 0.2 })
  end)

  assert(unit_calls == 1, "roadblock should spawn via unit path")
  assert(group_calls == 0, "roadblock should not spawn via group path")
  assert(captured_scale ~= nil, "roadblock should pass explicit scale")
  assert(captured_scale.x == 4.0 and captured_scale.y == 4.0 and captured_scale.z == 4.0, "roadblock should use 4x scale")
end

local function _test_action_anim_roll_screen_two_stage_timeline()
  local state = _build_state()
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

  local timers = {}

  local function run_timers_until(limit)
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

    assert(total_duration == 2.0, "roll action duration should use 1.0s spin + 1.0s hold")
    assert(nodes["骰子屏"].visible == true, "dice screen should be visible at start")
    assert(nodes["骰子_旋转中"].visible == true, "spin node should be visible at start")
    for i = 1, 6 do
      assert(nodes["骰子_点数" .. i].visible == false, "face should be hidden while spinning")
    end

    run_timers_until(1.0)
    assert(nodes["骰子_旋转中"].visible == false, "spin node should hide at 1.0s")
    assert(nodes["骰子_点数1"].visible == true, "first roll face should be shown")
    for i = 2, 6 do
      assert(nodes["骰子_点数" .. i].visible == false, "other faces should remain hidden")
    end

    run_timers_until(1.6)
    assert(nodes["骰子屏"].visible == true, "dice screen should stay visible during hold")
    assert(nodes["骰子_点数1"].visible == true, "face should remain visible during hold")

    run_timers_until(2.0)
    assert(nodes["骰子屏"].visible == false, "dice screen should hide after hold")
    for i = 1, 6 do
      assert(nodes["骰子_点数" .. i].visible == false, "all faces should hide after hold")
    end
  end)
end

local function _test_action_anim_roll_screen_fallback_face_when_invalid()
  local state = _build_state()
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

  local timers = {}

  local function run_timers_until(limit)
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

    run_timers_until(1.0)
    assert(nodes["骰子_旋转中"].visible == false, "spin node should hide at 1.0s")
    assert(nodes["骰子_点数1"].visible == true, "fallback face should show 1 when parsed face is invalid")
    for i = 2, 6 do
      assert(nodes["骰子_点数" .. i].visible == false, "other faces should remain hidden on fallback")
    end
  end)
end

local function _test_action_anim_upgrade_land_does_not_call_overlay_handler()
  local state = _build_state()
  local called = 0

  _with_patches({
    {
      target = handlers,
      key = "play_overlay",
      value = function()
        called = called + 1
      end,
    },
  }, function()
    local out_duration = action_anim.play(state, {
      kind = "upgrade_land",
      tile_index = 1,
      level = 1,
      duration = 0.6,
    })
    assert(out_duration == 0.6, "upgrade_land should keep configured duration")
    assert(called == 0, "upgrade_land should not call overlay handler")
  end)
end

local function _test_action_anim_is_silent_by_default()
  local state = _build_state()
  local tip_calls = 0

  _with_patches({
    {
      target = host_runtime,
      key = "show_tips",
      value = function()
        tip_calls = tip_calls + 1
        return true
      end,
    },
  }, function()
    local duration = action_anim.play(state, {
      kind = "item_use",
      player_id = 1,
      item_id = 2001,
      duration = 0.6,
    })
    assert(duration == 0.6, "silent action anim should still return duration")
  end)

  assert(tip_calls == 0, "action anim should not emit user tips by default")
end

local function _test_action_anim_user_tip_policy_forces_tip()
  local state = _build_state()
  local tips = {}

  _with_patches({
    {
      target = host_runtime,
      key = "show_tips",
      value = function(text, duration)
        tips[#tips + 1] = { text = text, duration = duration }
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

  assert(#tips == 1, "tip_policy=user should force exactly one tip")
  assert(tips[1].text ~= nil and tips[1].text ~= "", "forced tip should contain text")
end

local function _test_action_anim_debug_log_uses_info_without_tip()
  local state = _build_state()
  local tip_calls = 0
  local info_calls = {}

  _with_patches({
    {
      target = gameplay_rules,
      key = "action_anim_debug_log_enabled",
      value = false,
    },
    {
      target = logger,
      key = "anim_debug_enabled_provider",
      value = function()
        return true
      end,
    },
    {
      target = host_runtime,
      key = "show_tips",
      value = function()
        tip_calls = tip_calls + 1
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
  }, function()
    action_anim.play(state, {
      kind = "move_effect",
      player_id = 1,
      from_index = 1,
      to_index = 1,
      duration = 0.6,
    })
  end)

  assert(tip_calls == 0, "debug action anim log should not consume tip channel")
  assert(#info_calls == 1, "debug action anim log should emit one info log")
end

local function _test_host_runtime_sfx_port_skips_missing_keys_and_routes_valid_calls()
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

    assert(sfx_id == 101, "valid sfx call should return engine id")
    assert(missing_id == nil, "missing sfx key should skip safely")
    assert(zero_sfx_id == nil, "zero sfx key should skip safely")
    assert(string_sfx_id == nil, "string sfx key should skip safely")
    assert(vector_scale_id == nil, "vector scale should skip safely")
    assert(sound_id == 202, "valid sound call should return engine id")
    assert(missing_sound_id == nil, "missing sound id should skip safely")
    assert(zero_sound_id == nil, "zero sound id should skip safely")
    assert(string_sound_id == nil, "string sound id should skip safely")
  end)

  assert(#sfx_calls == 1, "invalid sfx keys should not call engine")
  assert(sfx_calls[1].sfx_key == 4286, "sfx key should route unchanged as integer")
  assert(sfx_calls[1].scale == 1.0, "direct sfx port should pass caller-provided scalar scale")
  assert(sfx_calls[1].rate == 1.0, "direct sfx port should default missing rate to 1.0")
  assert(sfx_calls[1].with_sound == false, "direct sfx port should default with_sound to false")
  assert(sfx_calls[1].rot ~= nil, "direct sfx port should default missing rot")
  assert(#sound_calls == 1, "sound call should route once")
  assert(sound_calls[1].sound_id == 301, "sound id should route unchanged")
end

local function _test_action_anim_upgrade_land_routes_board_feedback()
  local state = _build_state()
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
          duration = payload and payload.duration or nil,
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
    assert(out_duration == 0.6, "upgrade_land should keep configured duration")
  end)

  assert(#calls == 1, "upgrade_land should route exactly one board feedback cue")
  assert(calls[1].cue_name == "upgrade_land_smoke", "upgrade cue name mismatch")
  assert(calls[1].tile_index == 1, "upgrade cue should target tile index")
  assert(calls[1].player_id == 1, "upgrade cue should preserve player id")
  assert(calls[1].use_building_tile_position == true, "upgrade cue should request building tile position")
end

local function _test_action_anim_cash_receive_routes_board_feedback()
  local state = _build_state()
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
    assert(out_duration == 0.7, "cash_receive should keep configured duration")
  end)

  assert(#calls == 1, "cash_receive should route exactly one board feedback cue")
  assert(calls[1].cue_name == "cash_burst", "cash cue name mismatch")
  assert(calls[1].player_id == 1, "cash cue should preserve player id")
  assert(calls[1].amount == 500, "cash cue should preserve amount")
end

local function _test_anim_tip_text_builds_named_player_and_clear_obstacles_copy()
  local tip_text = require("src.presentation.view.render.anim_tip_text")
  local state = _build_state()

  local target_copy = tip_text.build(state, {
    kind = "item_target_player",
    item_name = "导弹卡",
    target_player_id = 1,
  })
  local clear_copy = tip_text.build(state, {
    kind = "clear_obstacles",
    cleared_indices = { 3, 4, 5 },
  })

  assert(target_copy == "目标道具：导弹卡 -> 玩家 测试玩家",
    "item_target_player tip should resolve runtime player name")
  assert(clear_copy == "清障动画：清除数量 3",
    "clear_obstacles tip should count removed indices")
end

local function _test_anim_tip_text_falls_back_for_unknown_player_and_change_skin()
  local tip_text = require("src.presentation.view.render.anim_tip_text")
  local state = _build_state()
  state.game.find_player_by_id = function()
    return nil
  end

  local target_copy = tip_text.build(state, {
    kind = "item_target_player",
    item_id = 2009,
    target_player_id = 99,
  })
  local change_skin_copy = tip_text.build(state, {
    kind = "change_skin",
    player_id = 99,
    skin_name = "海绵宝宝",
  })

  assert(target_copy == "目标道具：2009 -> 玩家 99",
    "item_target_player tip should fall back to raw player id when lookup is missing")
  assert(change_skin_copy == "换肤动画：99 -> 海绵宝宝",
    "change_skin tip should fall back to raw player id when lookup is missing")
end

local function _test_anim_tip_text_covers_roll_tile_and_cash_variants()
  local tip_text = require("src.presentation.view.render.anim_tip_text")
  local state = _build_state()

  local focus_copy = tip_text.build(state, {
    kind = "move_effect",
    focus_text = "直接使用焦点文案",
    from_index = 1,
    to_index = 2,
  })
  local roll_copy = tip_text.build(state, {
    kind = "roll",
    rolls = { 2, 6 },
    total = 8,
  })
  local roadblock_copy = tip_text.build(state, {
    kind = "roadblock",
    tile_index = 1,
  })
  local move_copy = tip_text.build(state, {
    kind = "move_effect",
    from_index = 1,
    to_index = 2,
  })
  local cash_copy = tip_text.build(state, {
    kind = "cash_receive",
    player_id = 1,
    amount = 500,
  })

  assert(focus_copy == "直接使用焦点文案", "focus_text should override kind-specific copy")
  assert(roll_copy == "投骰动画：2,6 => 8", "roll tip should join rolls and total")
  assert(roadblock_copy == "路障动画：放置在 测试地块", "roadblock tip should resolve tile name")
  assert(move_copy == "位移动画：从 测试地块 到 测试地块", "move_effect tip should resolve both tile names")
  assert(cash_copy == "收钱动画：测试玩家 +500", "cash_receive tip should resolve player name and amount")
end

local function _test_anim_tip_text_covers_chance_item_and_unknown_tile_variants()
  local tip_text = require("src.presentation.view.render.anim_tip_text")
  local state = _build_state()

  state.game.board.get_tile = function(_, tile_index)
    if tile_index == 999 then
      return nil
    end
    return { name = "测试地块" }
  end

  local chance_copy = tip_text.build(state, {
    kind = "chance",
    card_desc = "全员发钱",
  })
  local item_use_copy = tip_text.build(state, {
    kind = "item_use",
    item_id = "freeze_card",
  })
  local mine_copy = tip_text.build(state, {
    kind = "mine",
    tile_index = 999,
  })
  local missile_copy = tip_text.build(state, {
    kind = "missile",
    tile_index = 999,
  })
  local monster_copy = tip_text.build(state, {
    kind = "monster",
    tile_index = 999,
  })
  local upgrade_copy = tip_text.build(state, {
    kind = "upgrade_land",
    tile_index = 999,
  })
  local missing_copy = tip_text.build(state, {
    kind = "unknown_kind",
  })

  assert(chance_copy == "机会卡展示：全员发钱", "chance tip should prefer card_desc")
  assert(item_use_copy == "道具生效：freeze_card", "item_use tip should fall back to item_id")
  assert(mine_copy == "地雷动画：埋设在 未知地块", "mine tip should fall back to unknown tile name")
  assert(missile_copy == "导弹动画：轰炸 未知地块", "missile tip should fall back to unknown tile name")
  assert(monster_copy == "怪兽动画：破坏 未知地块", "monster tip should fall back to unknown tile name")
  assert(upgrade_copy == "加盖动画：未知地块", "upgrade_land tip should fall back to unknown tile name")
  assert(missing_copy == nil, "unknown kind should not generate tip copy")
end

local function _test_anim_unit_overlay_clear_obstacles_clears_each_overlay_and_spawns_robot()
  local overlay = require("src.presentation.view.render.anim_unit_overlay")
  local state = _build_state()
  local cleared_calls = {}
  local transient_calls = {}

  _with_patches({
    {
      target = host_runtime,
      key = "create_unit_group",
      value = function(group_id, pos)
        transient_calls[#transient_calls + 1] = {
          group_id = group_id,
          pos = pos,
        }
        return { _group_id = group_id }
      end,
    },
    {
      target = host_runtime,
      key = "create_unit",
      value = function(unit_id, pos)
        transient_calls[#transient_calls + 1] = {
          unit_id = unit_id,
          pos = pos,
        }
        return { _unit_id = unit_id }
      end,
    },
  }, function()
    overlay.play_clear_obstacles(state, {
      cleared_indices = { 2, 4 },
      player_id = 1,
    }, 0.75, {
      clear_overlay = function(_, kind, tile_index)
        cleared_calls[#cleared_calls + 1] = kind .. ":" .. tostring(tile_index)
      end,
    })
  end)

  assert(#cleared_calls == 4, "clear_obstacles should clear roadblock and mine for each cleared tile")
  assert(cleared_calls[1] == "roadblock:2", "clear_obstacles should clear roadblock first")
  assert(cleared_calls[2] == "mine:2", "clear_obstacles should clear mine second")
  assert(cleared_calls[3] == "roadblock:4", "clear_obstacles should repeat for each cleared tile")
  assert(cleared_calls[4] == "mine:4", "clear_obstacles should clear mine for each cleared tile")
  assert(#transient_calls == 1, "clear_obstacles should spawn one robot transient")
  assert(transient_calls[1].pos.x == 0.0 and transient_calls[1].pos.y == 1.0 and transient_calls[1].pos.z == 0.0,
    "clear_obstacles robot should spawn above the acting player tile")
end

local function _test_anim_unit_overlay_play_missile_clears_overlays_and_spawns_transient()
  local overlay = require("src.presentation.view.render.anim_unit_overlay")
  local prefab = require("Data.Prefab")
  local state = _build_state()
  local cleared_calls = {}
  local transient_calls = {}

  state.presentation_runtime = {
    host_runtime = {
      create_unit_group = function(group_id, pos)
        transient_calls[#transient_calls + 1] = {
          group_id = group_id,
          pos = pos,
        }
        return { _group_id = group_id }
      end,
      create_unit = function(unit_id, pos)
        transient_calls[#transient_calls + 1] = {
          unit_id = unit_id,
          pos = pos,
        }
        return { _unit_id = unit_id }
      end,
      schedule = function() end,
    },
  }

  local original_group = prefab.group["导弹"]
  prefab.group["导弹"] = 9999

  _with_patches({
    {
      target = host_runtime,
      key = "create_unit_group",
      value = function(group_id, pos)
        transient_calls[#transient_calls + 1] = {
          group_id = group_id,
          pos = pos,
        }
        return { _group_id = group_id }
      end,
    },
    {
      target = host_runtime,
      key = "create_unit",
      value = function(unit_id, pos)
        transient_calls[#transient_calls + 1] = {
          unit_id = unit_id,
          pos = pos,
        }
        return { _unit_id = unit_id }
      end,
    },
  }, function()
    overlay.play_missile(state, {
      tile_index = 1,
    }, 0.5, {
      clear_overlay = function(_, kind, tile_index)
        cleared_calls[#cleared_calls + 1] = kind .. ":" .. tostring(tile_index)
      end,
    })
  end)

  prefab.group["导弹"] = original_group

  assert(#cleared_calls == 2, "play_missile should clear roadblock and mine")
  assert(cleared_calls[1] == "roadblock:1", "play_missile should clear roadblock first")
  assert(cleared_calls[2] == "mine:1", "play_missile should clear mine second")
  assert(#transient_calls >= 1, "play_missile should spawn at least one transient")
end

return {
  name = "presentation.action_anim_core",
  tests = {
    { name = "action_anim_overlay_handler_returns_duration", run = _test_action_anim_overlay_handler_returns_duration },
    { name = "action_anim_roadblock_overlay_uses_4x_scale", run = _test_action_anim_roadblock_overlay_uses_4x_scale },
    { name = "action_anim_upgrade_land_does_not_call_overlay_handler", run = _test_action_anim_upgrade_land_does_not_call_overlay_handler },
    { name = "action_anim_is_silent_by_default", run = _test_action_anim_is_silent_by_default },
    { name = "action_anim_user_tip_policy_forces_tip", run = _test_action_anim_user_tip_policy_forces_tip },
    { name = "action_anim_debug_log_uses_info_without_tip", run = _test_action_anim_debug_log_uses_info_without_tip },
    { name = "host_runtime_sfx_port_skips_missing_keys_and_routes_valid_calls", run = _test_host_runtime_sfx_port_skips_missing_keys_and_routes_valid_calls },
    { name = "action_anim_upgrade_land_routes_board_feedback", run = _test_action_anim_upgrade_land_routes_board_feedback },
    { name = "action_anim_cash_receive_routes_board_feedback", run = _test_action_anim_cash_receive_routes_board_feedback },
    { name = "anim_tip_text_builds_named_player_and_clear_obstacles_copy", run = _test_anim_tip_text_builds_named_player_and_clear_obstacles_copy },
    { name = "anim_tip_text_falls_back_for_unknown_player_and_change_skin", run = _test_anim_tip_text_falls_back_for_unknown_player_and_change_skin },
    { name = "anim_tip_text_covers_roll_tile_and_cash_variants", run = _test_anim_tip_text_covers_roll_tile_and_cash_variants },
    { name = "anim_tip_text_covers_chance_item_and_unknown_tile_variants", run = _test_anim_tip_text_covers_chance_item_and_unknown_tile_variants },
    { name = "anim_unit_overlay_clear_obstacles_clears_each_overlay_and_spawns_robot", run = _test_anim_unit_overlay_clear_obstacles_clears_each_overlay_and_spawns_robot },
    { name = "anim_unit_overlay_play_missile_clears_overlays_and_spawns_transient", run = _test_anim_unit_overlay_play_missile_clears_overlays_and_spawns_transient },
    { name = "action_anim_roll_screen_two_stage_timeline", run = _test_action_anim_roll_screen_two_stage_timeline },
    { name = "action_anim_roll_screen_fallback_face_when_invalid", run = _test_action_anim_roll_screen_fallback_face_when_invalid },
  },
}
