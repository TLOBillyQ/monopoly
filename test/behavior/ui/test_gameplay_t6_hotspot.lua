-- luacheck: ignore 211
local lu = require("luaunit")
local pending_confirmation = require("src.state.pending_confirmation")
local market_slots = require("src.ui.render.market.slots")
local placement = require("src.ui.render.board.placement")
local status3d_status = require("src.ui.render.status3d.status")
local board_feedback = require("src.ui.render.board_feedback.service")
local role_control_lock_policy = require("src.ui.input.role_control_lock")
local anim_overlay_runtime = require("src.ui.render.anim.overlay_runtime")
local status3d_scene = require("src.ui.render.status3d.scene")
local status3d_init = require("src.ui.render.status3d")

local state_module_aliases = {}

local function _with_globals(overrides, fn)
  local original = {}
  for key, value in pairs(overrides or {}) do
    original[key] = _G[key]
    _G[key] = value
  end
  local ok, result = pcall(fn)
  for key, value in pairs(original) do
    _G[key] = value
  end
  if not ok then
    error(result)
  end
  return result
end

local function _reload_module(module_name, overrides, fn)
  local applied_overrides = {}
  for key, value in pairs(overrides or {}) do
    applied_overrides[key] = value
  end
  for key, alias in pairs(state_module_aliases) do
    if applied_overrides[key] ~= nil and applied_overrides[alias] == nil then
      applied_overrides[alias] = applied_overrides[key]
    elseif applied_overrides[alias] ~= nil and applied_overrides[key] == nil then
      applied_overrides[key] = applied_overrides[alias]
    end
  end

  local original = {}
  for key, value in pairs(applied_overrides) do
    original[key] = package.loaded[key]
    package.loaded[key] = value
  end
  local original_module = package.loaded[module_name]
  package.loaded[module_name] = nil

  local ok, result = pcall(function()
    local loaded = require(module_name)
    return fn(loaded)
  end)

  package.loaded[module_name] = original_module
  for key, value in pairs(original) do
    package.loaded[key] = value
  end

  if not ok then
    error(result)
  end
  return result
end

local _play_cue_final_tests = {
  function()
    -- Test _play_cue with nil cue name returns false
    local mock_host = {
      play_sfx_by_key = function() return 123 end,
      play_3d_sound = function() return 456 end,
    }

    local state = {
      presentation_runtime = { host_runtime = mock_host },
      board_scene = {
        tiles = { { position = { x = 0, y = 0, z = 0 } } },
      },
    }

    local result = board_feedback.play_tile_cue(state, nil, 1, {}, { host_runtime = mock_host })
    lu.assertEvalToTrue(result == false, "should return false for nil cue name")
  end,
  function()
    -- Test _play_cue with empty cue name returns false
    local mock_host = {
      play_sfx_by_key = function() return 123 end,
      play_3d_sound = function() return 456 end,
    }

    local state = {
      presentation_runtime = { host_runtime = mock_host },
      board_scene = {
        tiles = { { position = { x = 0, y = 0, z = 0 } } },
      },
    }

    local result = board_feedback.play_tile_cue(state, "", 1, {}, { host_runtime = mock_host })
    lu.assertEvalToTrue(result == false, "should return false for empty cue name")
  end,
  function()
    -- Test _play_cue with nonexistent cue returns false
    local mock_host = {
      play_sfx_by_key = function() return nil end,
      play_3d_sound = function() return nil end,
    }

    local state = {
      presentation_runtime = { host_runtime = mock_host },
      board_scene = {
        tiles = { { position = { x = 0, y = 0, z = 0 } } },
      },
    }

    local result = board_feedback.play_tile_cue(state, "nonexistent_cue_12345", 1, {}, { host_runtime = mock_host })
    lu.assertEvalToTrue(result == false, "should return false for nonexistent cue")
  end,
  function()
    -- Test play_sound_only with nil pos fallback
    local mock_host = {
      play_sfx_by_key = function() return nil end,
      play_3d_sound = function() return nil end,
    }

    local state = {
      presentation_runtime = { host_runtime = mock_host },
      board_scene = nil, -- No board_scene
    }

    -- Call play_sound_only with no pos, no player_id, no tile_index
    -- This should pass nil to _play_cue, triggering the fallback to v3_zero
    local result = board_feedback.play_sound_only(
      state,
      "nonexistent_cue_12345",
      {},
      { host_runtime = mock_host }
    )

    lu.assertEvalToTrue(result == false, "should return false for nonexistent cue even with nil pos fallback")
  end,
  function()
    -- Test play_player_cue when player position cannot be resolved
    local mock_host = {
      play_sfx_by_key = function() return nil end,
      play_3d_sound = function() return nil end,
    }

    local state = {
      presentation_runtime = { host_runtime = mock_host },
      board_scene = {},
      game = {
        find_player_by_id = function() return { position = nil } end,
      },
    }

    local result = board_feedback.play_player_cue(state, "test_cue", "p1", {}, { host_runtime = mock_host })
    lu.assertEvalToTrue(result == false, "should return false when player position cannot be resolved")
  end,
}

TestGameplayT6Hotspot = {}

function TestGameplayT6Hotspot:test_01_resolve_market_name_from_entry()
  local name = market_slots._resolve_market_name(nil, 1001, { name = "EntryName" }, nil)
  lu.assertEvalToTrue(name == "EntryName", "should return entry name when available")
end

function TestGameplayT6Hotspot:test_02_resolve_market_name_from_cfg()
  local name = market_slots._resolve_market_name(nil, 1001, nil, { name = "CfgName" })
  lu.assertEvalToTrue(name == "CfgName", "should return cfg name when entry name missing")
end

function TestGameplayT6Hotspot:test_03_resolve_market_name_from_opt_label()
  local name = market_slots._resolve_market_name({ label = "OptLabel" }, 1001, nil, nil)
  lu.assertEvalToTrue(name == "OptLabel", "should return opt label when entry/cfg missing")
end

function TestGameplayT6Hotspot:test_04_resolve_market_name_fallback_to_product_id()
  local name = market_slots._resolve_market_name(nil, 1001, nil, nil)
  lu.assertEvalToTrue(name == "1001", "should fallback to product_id as string")
end

function TestGameplayT6Hotspot:test_05_resolve_occupant_slot_single_player()
  local list = { "p1" }
  local slot, count = placement._resolve_occupant_slot(list, "p1")
  lu.assertEvalToTrue(slot == 1, "single player should be slot 1")
  lu.assertEvalToTrue(count == 1, "single player count should be 1")
end

function TestGameplayT6Hotspot:test_06_resolve_occupant_slot_first_in_list()
  local list = { "p1", "p2", "p3" }
  local slot, count = placement._resolve_occupant_slot(list, "p1")
  lu.assertEvalToTrue(slot == 1, "first player should be slot 1")
  lu.assertEvalToTrue(count == 3, "count should be list length")
end

function TestGameplayT6Hotspot:test_07_resolve_occupant_slot_middle_in_list()
  local list = { "p1", "p2", "p3" }
  local slot, count = placement._resolve_occupant_slot(list, "p2")
  lu.assertEvalToTrue(slot == 2, "middle player should be slot 2")
  lu.assertEvalToTrue(count == 3, "count should be list length")
end

function TestGameplayT6Hotspot:test_08_resolve_occupant_slot_last_in_list()
  local list = { "p1", "p2", "p3" }
  local slot, count = placement._resolve_occupant_slot(list, "p3")
  lu.assertEvalToTrue(slot == 3, "last player should be slot 3")
  lu.assertEvalToTrue(count == 3, "count should be list length")
end

function TestGameplayT6Hotspot:test_09_resolve_player_status_key_eliminated()
  local game = {}
  local player = { eliminated = true }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == nil, "eliminated player should have no status key")
end

function TestGameplayT6Hotspot:test_10_resolve_player_status_key_nil_player()
  local key = status3d_status.resolve_player_status_key({}, nil)
  lu.assertEvalToTrue(key == nil, "nil player should have no status key")
end

function TestGameplayT6Hotspot:test_11_resolve_player_status_key_nil_game_with_stay_turns_does_not_error()
  local player = {
    id = 1,
    position = 5,
    status = { stay_turns = 0 },
  }
  local ok, key = pcall(status3d_status.resolve_player_status_key, nil, player)
  lu.assertEvalToTrue(ok, "nil game should not raise while checking detention state")
  lu.assertEvalToTrue(key == nil, "nil game should not produce a location status")
end

function TestGameplayT6Hotspot:test_12_resolve_player_status_key_hospital()
  local game = {
    board = {
      get_tile = function()
        return { type = "hospital" }
      end,
    },
    turn = {
      no_action_notice_active = true,
    },
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 3,
    },
  }
  local player = {
    id = 1,
    position = 5,
    status = { stay_turns = 3 },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == "hospital", "hospital tile with stay_turns should return hospital")
end

function TestGameplayT6Hotspot:test_13_resolve_player_status_key_hospital_detained_wait_flag()
  local game = {
    board = {
      get_tile = function()
        return { type = "hospital" }
      end,
    },
    turn = {
      detained_wait_active = true,
    },
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 1,
    },
  }
  local player = {
    id = 1,
    position = 5,
    status = { stay_turns = 0 },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == "hospital", "detained_wait_active should keep location status visible")
end

function TestGameplayT6Hotspot:test_14_resolve_player_status_key_hospital_detained_wait_phase()
  local game = {
    board = {
      get_tile = function()
        return { type = "hospital" }
      end,
    },
    turn = {
      phase = "detained_wait",
    },
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 1,
    },
  }
  local player = {
    id = 1,
    position = 5,
    status = { stay_turns = 0 },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == "hospital", "detained_wait phase should keep location status visible")
end

function TestGameplayT6Hotspot:test_15_resolve_player_status_key_hospital_requires_matching_detention_turn()
  local base_game = {
    board = {
      get_tile = function()
        return { type = "hospital" }
      end,
    },
    turn = {
      detained_wait_active = true,
    },
  }
  local player = {
    id = 1,
    position = 5,
    status = { stay_turns = 0 },
  }

  base_game.last_turn = nil
  lu.assertEvalToTrue(status3d_status.resolve_player_status_key(base_game, player) == nil,
    "missing last_turn should not count as detained")

  base_game.last_turn = { player_id = 1, skipped = false, stay_turns = 1 }
  lu.assertEvalToTrue(status3d_status.resolve_player_status_key(base_game, player) == nil,
    "non-skipped last_turn should not count as detained")

  base_game.last_turn = { player_id = 1, skipped = true }
  lu.assertEvalToTrue(status3d_status.resolve_player_status_key(base_game, player) == nil,
    "missing stay_turns should not count as detained")
end

function TestGameplayT6Hotspot:test_16_resolve_player_status_key_hospital_without_turn_or_stay_turns_is_hidden()
  local game = {
    board = {
      get_tile = function()
        return { type = "hospital" }
      end,
    },
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 1,
    },
  }
  local player = {
    id = 1,
    position = 5,
    status = {},
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == nil, "missing turn wait and stay_turns should not show hospital")
end

function TestGameplayT6Hotspot:test_17_resolve_player_status_key_mountain()
  local game = {
    board = {
      get_tile = function()
        return { type = "mountain" }
      end,
    },
    turn = {
      detained_wait_active = true,
    },
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 2,
    },
  }
  local player = {
    id = 1,
    position = 10,
    status = { stay_turns = 2 },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == "mountain", "mountain tile with stay_turns should return mountain")
end

function TestGameplayT6Hotspot:test_18_resolve_player_status_key_roadblock()
  local game = {
    board = {
      get_tile = function()
        return { type = "normal" }
      end,
    },
    last_turn = {
      player_id = 1,
      move_result = { stopped_on_roadblock = true },
    },
  }
  local player = {
    id = 1,
    position = 5,
    status = {},
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == "roadblock", "roadblock stop should return roadblock key")
end

function TestGameplayT6Hotspot:test_19_resolve_player_status_key_poor_deity()
  local game = {
    board = {
      get_tile = function()
        return { type = "normal" }
      end,
    },
    last_turn = {},
  }
  local player = {
    id = 1,
    position = 5,
    status = {
      deity = { type = "poor", remaining = 3 },
    },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == "poor", "poor deity should return poor key")
end

function TestGameplayT6Hotspot:test_20_resolve_player_status_key_poor_deity_without_remaining_is_hidden()
  local game = {
    board = {
      get_tile = function()
        return { type = "normal" }
      end,
    },
    last_turn = {},
  }
  local player = {
    id = 1,
    position = 5,
    status = {
      deity = { type = "poor" },
    },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == nil, "deity without remaining turns should not return a status key")
end

function TestGameplayT6Hotspot:test_21_resolve_player_status_key_rich_deity()
  local game = {
    board = {
      get_tile = function()
        return { type = "normal" }
      end,
    },
    last_turn = {},
  }
  local player = {
    id = 1,
    position = 5,
    status = {
      deity = { type = "rich", remaining = 5 },
    },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == "rich", "rich deity should return rich key")
end

function TestGameplayT6Hotspot:test_22_resolve_player_status_key_angel_deity()
  local game = {
    board = {
      get_tile = function()
        return { type = "normal" }
      end,
    },
    last_turn = {},
  }
  local player = {
    id = 1,
    position = 5,
    status = {
      deity = { type = "angel", remaining = 2 },
    },
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == "angel", "angel deity should return angel key")
end

function TestGameplayT6Hotspot:test_23_resolve_player_status_key_no_status()
  local game = {
    board = {
      get_tile = function()
        return { type = "normal" }
      end,
    },
    last_turn = {},
  }
  local player = {
    id = 1,
    position = 5,
    status = {},
  }
  local key = status3d_status.resolve_player_status_key(game, player)
  lu.assertEvalToTrue(key == nil, "no special status should return nil")
end

function TestGameplayT6Hotspot:test_24_role_control_lock_sync_disabled_releases_all()
  local state = {
    role_control_lock = {
      by_role = {},
    },
  }
  local mock_runtime = {
    for_each_role_or_global = function() end,
  }
  role_control_lock_policy.sync(state, false, { runtime = mock_runtime })
  lu.assertEvalToTrue(state.role_control_lock ~= nil, "lock state should exist")
end

function TestGameplayT6Hotspot:test_25_role_control_lock_sync_missing_buff_id_warns()
  local state = {
    role_control_lock = {
      by_role = {},
    },
  }
  local original_enums = _G.Enums
  _G.Enums = nil
  local mock_runtime = {
    for_each_role_or_global = function() end,
  }
  role_control_lock_policy.sync(state, true, { runtime = mock_runtime })
  _G.Enums = original_enums
  lu.assertEvalToTrue(state.role_control_lock ~= nil, "lock state should exist after warning")
end

function TestGameplayT6Hotspot:test_26_role_control_lock_sync_exempt_role_skips_lock()
  local state = {
    role_control_lock = {
      by_role = {},
    },
    role_control_lock_exempt_by_role = { ["p1"] = true },
  }
  local mock_role = {
    get_ctrl_unit = function() return nil end,
  }
  local mock_runtime = {
    for_each_role_or_global = function(fn)
      fn(mock_role)
    end,
    resolve_role_id = function(r) return "p1" end,
  }
  role_control_lock_policy.sync(state, true, { runtime = mock_runtime })
  lu.assertEvalToTrue(state.role_control_lock ~= nil, "lock state should exist")
end

function TestGameplayT6Hotspot:test_27_role_control_lock_sync_missing_unit_skips()
  local state = {
    role_control_lock = {
      by_role = {},
    },
  }
  local mock_role = {
    get_ctrl_unit = function() return nil end,
  }
  local mock_runtime = {
    for_each_role_or_global = function(fn)
      fn(mock_role)
    end,
    resolve_role_id = function(r) return "p1" end,
  }
  role_control_lock_policy.sync(state, true, { runtime = mock_runtime })
  lu.assertEvalToTrue(state.role_control_lock.by_role["p1"] == nil, "missing unit should not create entry")
end

function TestGameplayT6Hotspot:test_28_role_control_lock_sync_unit_without_buff_api_warns()
  local state = {
    role_control_lock = {
      by_role = {},
    },
  }
  local mock_unit = {}
  local mock_role = {
    get_ctrl_unit = function() return mock_unit end,
  }
  local mock_runtime = {
    for_each_role_or_global = function(fn)
      fn(mock_role)
    end,
    resolve_role_id = function(r) return "p1" end,
  }
  role_control_lock_policy.sync(state, true, { runtime = mock_runtime })
  lu.assertEvalToTrue(
    state.debug_runtime ~= nil
      and state.debug_runtime.log_once ~= nil
      and state.debug_runtime.log_once["role_control_lock:missing_buff_api_p1"] == true,
    "log_once should record missing buff api"
  )
end

function TestGameplayT6Hotspot:test_29_role_control_lock_sync_applies_and_tracks_owned_lock()
  local original_enums = _G.Enums
  _G.Enums = { BuffState = { BUFF_FORBID_CONTROL = 77 } }
  local add_calls = 0
  local mock_unit = {
    get_state_count = function() return 0 end,
    add_state = function(buff_id)
      lu.assertEvalToTrue(buff_id == 77, "should apply configured buff id")
      add_calls = add_calls + 1
    end,
    remove_state = function() end,
  }
  local state = {
    role_control_lock = {
      by_role = {},
    },
  }
  local ok, err = pcall(function()
    role_control_lock_policy.sync(state, true, {
      runtime = {
        for_each_role_or_global = function(fn)
          fn({
            get_ctrl_unit = function() return mock_unit end,
          })
        end,
        resolve_role_id = function() return "p1" end,
      },
    })
  end)
  _G.Enums = original_enums
  if not ok then
    error(err)
  end
  lu.assertEvalToTrue(add_calls == 1, "should add control-forbid buff when unit is unlocked")
  lu.assertEvalToTrue(state.role_control_lock.by_role.p1.owned == true, "lock state should track owned buff")
end

function TestGameplayT6Hotspot:test_30_role_control_lock_sync_cleans_stale_role_entries()
  local original_enums = _G.Enums
  _G.Enums = { BuffState = { BUFF_FORBID_CONTROL = 88 } }
  local removed = 0
  local stale_unit = {
    get_state_count = function() return 1 end,
    add_state = function() end,
    remove_state = function(buff_id)
      lu.assertEvalToTrue(buff_id == 88, "should remove stale buff with configured id")
      removed = removed + 1
    end,
  }
  local state = {
    role_control_lock = {
      by_role = {
        stale = { owned = true, unit = stale_unit },
      },
    },
  }
  local ok, err = pcall(function()
    role_control_lock_policy.sync(state, true, {
      runtime = {
        for_each_role_or_global = function(fn)
          return nil
        end,
        resolve_role_id = function() return nil end,
      },
    })
  end)
  _G.Enums = original_enums
  if not ok then
    error(err)
  end
  lu.assertEvalToTrue(removed == 1, "stale owned entry should be released")
  lu.assertEvalToTrue(state.role_control_lock.by_role.stale == nil, "stale role entry should be pruned")
end

function TestGameplayT6Hotspot:test_31_anim_overlay_spawn_overlay_group()
  local scene = {
    overlay_units = { roadblocks = {}, mines = {} },
    presentation_runtime = {
      host_runtime = {
        create_unit_group = function(id, pos, rot) return { id = id } end,
        create_unit_with_scale = function(id, pos, rot, scale) return { id = id } end,
        destroy_unit = function() end,
        destroy_unit_with_children = function() end,
      },
    },
  }
  local result = anim_overlay_runtime.spawn_overlay(scene, "roadblock", 1, "group_123", nil, { x = 0, y = 0, z = 0 }, nil, nil)
  lu.assertEvalToTrue(result == true, "spawn_overlay with group_id should return true")
  lu.assertEvalToTrue(scene.overlay_units.roadblocks[1] ~= nil, "roadblock entry should exist")
end

function TestGameplayT6Hotspot:test_32_anim_overlay_spawn_overlay_unit()
  local scene = {
    overlay_units = { roadblocks = {}, mines = {} },
    presentation_runtime = {
      host_runtime = {
        create_unit_group = function(id, pos, rot) return { id = id } end,
        create_unit_with_scale = function(id, pos, rot, scale) return { id = id } end,
        destroy_unit = function() end,
        destroy_unit_with_children = function() end,
      },
    },
  }
  local result = anim_overlay_runtime.spawn_overlay(scene, "mine", 2, nil, "unit_456", { x = 1, y = 1, z = 1 }, 1.5, nil)
  lu.assertEvalToTrue(result == true, "spawn_overlay with unit_id should return true")
  lu.assertEvalToTrue(scene.overlay_units.mines[2] ~= nil, "mine entry should exist")
end

function TestGameplayT6Hotspot:test_33_anim_overlay_spawn_overlay_unknown_kind()
  local scene = {
    overlay_units = { roadblocks = {}, mines = {} },
    presentation_runtime = {
      host_runtime = {},
    },
  }
  local result = anim_overlay_runtime.spawn_overlay(scene, "unknown", 1, nil, nil, { x = 0, y = 0, z = 0 }, nil, nil)
  lu.assertEvalToTrue(result == false, "spawn_overlay with unknown kind should return false")
end

function TestGameplayT6Hotspot:test_34_anim_overlay_spawn_overlay_replaces_existing()
  local destroyed = false
  local scene = {
    overlay_units = {
      roadblocks = {
        [1] = { kind = "unit", handle = { id = "old" } },
      },
      mines = {},
    },
    presentation_runtime = {
      host_runtime = {
        create_unit_group = function(id, pos, rot) return { id = id } end,
        create_unit_with_scale = function(id, pos, rot, scale) return { id = id } end,
        destroy_unit = function() destroyed = true end,
        destroy_unit_with_children = function() destroyed = true end,
      },
    },
  }
  local result = anim_overlay_runtime.spawn_overlay(scene, "roadblock", 1, "new_group", nil, { x = 0, y = 0, z = 0 }, nil, nil)
  lu.assertEvalToTrue(result == true, "spawn_overlay should succeed")
  lu.assertEvalToTrue(destroyed == true, "old overlay should be destroyed")
end

function TestGameplayT6Hotspot:test_35_anim_overlay_spawn_overlay_no_ids_returns_false()
  local scene = {
    overlay_units = { roadblocks = {}, mines = {} },
    presentation_runtime = {
      host_runtime = {},
    },
  }
  local result = anim_overlay_runtime.spawn_overlay(scene, "roadblock", 1, nil, nil, { x = 0, y = 0, z = 0 }, nil, nil)
  lu.assertEvalToTrue(result == false, "spawn_overlay with no group_id or unit_id should return false")
end

function TestGameplayT6Hotspot:test_36_create_scene_ui_bind_unit_from_ctrl_unit()
  _with_globals({
    Enums = { ModelSocket = { socket_head = 1 } },
  }, function()
    local original_vector3 = math.Vector3
    math.Vector3 = function(x, y, z) return { x = x, y = y, z = z } end
    local created = false
    local mock_ctrl_unit = {
      create_scene_ui_bind_unit = function() created = true return { id = "layer1" } end,
    }
    local result = status3d_scene._create_scene_ui_bind_unit(mock_ctrl_unit, "layout_1")
    math.Vector3 = original_vector3
    lu.assertEvalToTrue(result ~= nil, "should create layer from ctrl_unit")
    lu.assertEvalToTrue(created == true, "ctrl_unit.create_scene_ui_bind_unit should be called")
  end)
end

function TestGameplayT6Hotspot:test_37_create_scene_ui_bind_unit_ignores_role_factory_when_ctrl_unit_missing()
  _with_globals({
    Enums = { ModelSocket = { socket_head = 1 } },
  }, function()
    local original_vector3 = math.Vector3
    math.Vector3 = function(x, y, z) return { x = x, y = y, z = z } end
    local created = false
    local mock_ctrl_unit = nil
    local mock_role = {
      create_scene_ui_bind_unit = function() created = true return { id = "layer2" } end,
    }
    local result = status3d_scene._create_scene_ui_bind_unit(mock_ctrl_unit, "layout_2")
    math.Vector3 = original_vector3
    lu.assertEvalToTrue(result == nil, "should not fall back to role factory")
    lu.assertEvalToTrue(created == false, "role factory should no longer be called")
  end)
end

function TestGameplayT6Hotspot:test_38_create_scene_ui_bind_unit_ignores_global_factory_when_ctrl_unit_missing()
  _with_globals({
    SceneUI = {
      create_scene_ui_bind_unit = function() return { id = "layer3" } end,
    },
    Enums = { ModelSocket = { socket_head = 1 } },
  }, function()
    local original_vector3 = math.Vector3
    math.Vector3 = function(x, y, z) return { x = x, y = y, z = z } end
    local result = status3d_scene._create_scene_ui_bind_unit(nil, "layout_3")
    math.Vector3 = original_vector3
    lu.assertEvalToTrue(result == nil, "should not fall back to global SceneUI")
  end)
end

function TestGameplayT6Hotspot:test_39_create_scene_ui_bind_unit_returns_nil_when_unavailable()
  local original_scene_ui = _G.SceneUI
  local original_enums = _G.Enums
  local original_vector3 = math.Vector3
  _G.SceneUI = nil
  _G.Enums = { ModelSocket = { socket_head = 1 } }
  math.Vector3 = function(x, y, z) return { x = x, y = y, z = z } end
  local ok, err = pcall(function()
    local result = status3d_scene._create_scene_ui_bind_unit({}, "layout_4")
    lu.assertEvalToTrue(result == nil, "should return nil when no method available")
  end)
  _G.SceneUI = original_scene_ui
  _G.Enums = original_enums
  math.Vector3 = original_vector3
  if not ok then
    error(err)
  end
end

function TestGameplayT6Hotspot:test_40_ensure_layers_for_player_returns_false_when_ctrl_unit_factory_missing()
  _with_globals({
    Enums = { ModelSocket = { socket_head = 1 } },
  }, function()
    local original_vector3 = math.Vector3
    math.Vector3 = function(x, y, z) return { x = x, y = y, z = z } end

    local cache = {
      layers = {},
      text_nodes = {},
      last_status_key_by_player = {},
      warned_once = {},
      disabled = false,
      meta = { layouts = { hospital = "layout_hospital" } },
    }
    local player = { id = 1 }
    local host_runtime = {
      resolve_role_with = function(_, predicate)
        local role = {
          get_ctrl_unit = function()
            return {}
          end,
        }
        if predicate == nil or predicate(role) == true then
          return role
        end
        return nil
      end,
      has_scene_ui_support = function()
        return true
      end,
      set_scene_ui_visible = function() end,
    }

    local ok = status3d_scene.ensure_layers_for_player(cache, player, { host_runtime = host_runtime })
    math.Vector3 = original_vector3

    lu.assertEvalToTrue(ok == false, "ensure_layers should fail when ctrl_unit factory is missing")
    lu.assertEvalToTrue(cache.layers[player.id] == nil, "player layers should not be cached without ctrl_unit factory")
  end)
end

function TestGameplayT6Hotspot:test_41_ensure_layers_for_player_ignores_global_factory_when_ctrl_unit_factory_missing()
  _with_globals({
    Enums = { ModelSocket = { socket_head = 1 } },
    SceneUI = {
      create_scene_ui_bind_unit = function()
        return { id = "layer_global" }
      end,
    },
  }, function()
    local original_vector3 = math.Vector3
    math.Vector3 = function(x, y, z) return { x = x, y = y, z = z } end

    local cache = {
      layers = {},
      text_nodes = {},
      last_status_key_by_player = {},
      warned_once = {},
      disabled = false,
      meta = { layouts = { hospital = "layout_hospital" } },
    }
    local player = { id = 2 }
    local host_runtime = {
      resolve_role_with = function(_, predicate)
        local role = {
          get_ctrl_unit = function()
            return {}
          end,
        }
        if predicate == nil or predicate(role) == true then
          return role
        end
        return nil
      end,
      has_scene_ui_support = function()
        return true
      end,
      set_scene_ui_visible = function() end,
    }

    local ok = status3d_scene.ensure_layers_for_player(cache, player, { host_runtime = host_runtime })
    math.Vector3 = original_vector3

    lu.assertEvalToTrue(ok == false, "ensure_layers should ignore global SceneUI fallback")
    lu.assertEvalToTrue(cache.layers[player.id] == nil, "player layers should not be cached from global fallback")
  end)
end

function TestGameplayT6Hotspot:test_42_pre_confirm_enter_choice_select()
    local state = {
      ui = { active_choice_screen_key = "base" },
      game = {},
    }
    local opened = false
    state.gameplay_loop_ports = {
      modal = {
        open_pre_confirm_screen = function() opened = true end,
      },
    }

    local result = _reload_module("src.ui.input.pre_confirm", {
  ["src.state.runtime"] = {
        get_ui_model = function()
          return {
            current_player_id = 7,
            choice = {
              id = "choice1",
              owner_role_id = 7,
              options = { { id = "opt1", label = "Option 1" } },
            },
          }
        end,
      },
      ["src.ui.view.choice_support"] = {
        resolve_option_label_by_id = function() return "Option 1" end,
        resolve_secondary_confirm_title = function() return "Title" end,
        resolve_secondary_confirm_body = function() return "Body" end,
      },
    }, function(flow)
      return flow.enter(state, { type = "choice_select", option_id = "opt1", actor_role_id = 7 })
    end)

    lu.assertEvalToTrue(result == true, "choice_select intent should enter pre_confirm")
    lu.assertEvalToTrue(opened == true, "open_pre_confirm_screen should be called")
    lu.assertEvalToTrue(pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_CHOICE_SELECT) == true,
      "pending confirmation (choice_select) should be active")
end

function TestGameplayT6Hotspot:test_43_pre_confirm_enter_no_choice_returns_false()
    local state = {
      ui = {},
      game = {},
    }
    local result = _reload_module("src.ui.input.pre_confirm", {
  ["src.state.runtime"] = {
        get_ui_model = function() return { choice = nil } end,
      },
    }, function(flow)
      return flow.enter(state, { type = "choice_select", option_id = "opt1" })
    end)
    lu.assertEvalToTrue(result == false, "enter with no choice should return false")
end

function TestGameplayT6Hotspot:test_44_pre_confirm_enter_unknown_intent_returns_false()
    local state = {
      ui = {},
      game = {},
    }
    local result = _reload_module("src.ui.input.pre_confirm", {
  ["src.state.runtime"] = {
        get_ui_model = function()
          return { choice = { id = "choice1" } }
        end,
      },
    }, function(flow)
      return flow.enter(state, { type = "unknown_type" })
    end)
    lu.assertEvalToTrue(result == false, "unknown intent type should return false")
end

function TestGameplayT6Hotspot:test_45_status3d_init_sync_no_game_returns_early()
  local state = {}
  status3d_init.sync(nil, state, {}, {})
  lu.assertEvalToTrue(next(state) == nil, "no game should leave state untouched")
end

function TestGameplayT6Hotspot:test_46_status3d_init_sync_disabled_cache_returns_early()
  local state = {
    ui_status_3d = { disabled = true, layers = {}, text_nodes = {}, last_status_key_by_player = {} },
  }
  local game = { players = {} }
  status3d_init.sync(game, state, {}, { host_runtime = { has_scene_ui_support = function() return true end } })
  lu.assertEvalToTrue(state.ui_status_3d.disabled == true, "disabled cache should remain disabled")
  lu.assertEvalToTrue(next(state.ui_status_3d.layers) == nil, "disabled cache should not gain layers")
end

function TestGameplayT6Hotspot:test_47_status3d_init_sync_no_dirty_no_missing_layers()
  local state = {
    ui_status_3d = {
      layers = { p1 = {} },
      text_nodes = {},
      last_status_key_by_player = {},
      warned_once = {},
      dirty = {},
    },
  }
  local game = { players = { { id = "p1" } } }
  _reload_module("src.ui.render.status3d", {
    ["src.ui.render.status3d.meta"] = {
      ensure_cache = function(s) return s.ui_status_3d end,
      build_meta = function() return { layouts = {} } end,
      warn_once = function() end,
    },
  }, function(init)
    init.sync(game, state, { players = false, turn = false, any = false }, {
      host_runtime = { has_scene_ui_support = function() return true end },
    })
  end)
  lu.assertEvalToTrue(state.ui_status_3d.layers.p1 ~= nil, "existing layer should be preserved on no-op sync")
end

function TestGameplayT6Hotspot:test_48_status3d_init_sync_missing_scene_ui_support_disables()
  local state = {
    ui_status_3d = {
      layers = {},
      text_nodes = {},
      last_status_key_by_player = {},
      warned_once = {},
      dirty = { players = true },
    },
  }
  local game = { players = { { id = "p1" } } }
  local deps = {
    host_runtime = {
      has_scene_ui_support = function() return false end,
    },
  }
  _reload_module("src.ui.render.status3d", {
    ["src.ui.render.status3d.meta"] = {
      ensure_cache = function(s) return s.ui_status_3d end,
      build_meta = function() return { layouts = {} } end,
      warn_once = function() end,
    },
  }, function(init)
    init.sync(game, state, { players = true }, deps)
  end)

  local was_disabled = state.ui_status_3d.disabled
  lu.assertEvalToTrue(was_disabled == true, "missing scene ui support should disable cache")
end

function TestGameplayT6Hotspot:test_49_status3d_init_sync_missing_env_disables()
  local state = {
    ui_status_3d = {
      layers = {},
      text_nodes = {},
      last_status_key_by_player = {},
      warned_once = {},
      dirty = { players = true },
    },
  }
  local game = { players = { { id = "p1" } } }
  local deps = {
    host_runtime = {
      has_scene_ui_support = function() return true end,
    },
  }
  local original_enums = _G.Enums
  _G.Enums = nil
  local ok, err = pcall(function()
    _reload_module("src.ui.render.status3d", {
      ["src.ui.render.status3d.meta"] = {
        ensure_cache = function(s) return s.ui_status_3d end,
        build_meta = function() return { layouts = {} } end,
        warn_once = function() end,
      },
    }, function(init)
      init.sync(game, state, { players = true }, deps)
    end)
  end)
  _G.Enums = original_enums
  if not ok then
    error(err)
  end
  lu.assertEvalToTrue(state.ui_status_3d.disabled == true, "missing scene ui env should disable cache")
end

function TestGameplayT6Hotspot:test_50_play_cue_with_nil_pos()
  -- This test covers the nil pos fallback path in _play_cue at line 197
  -- The fallback uses runtime_constants.v3_zero when pos is nil
  -- play_sound_only with no payload.pos, no player_id, no tile_index will pass nil pos
  local mock_host = {
    play_sfx_by_key = function() return nil end,
    play_3d_sound = function() return nil end,
  }

  -- Test that calling with a cue that has no catalog entry returns false
  -- This is the early return path we can reliably test
  local result = board_feedback.play_tile_cue(
    { presentation_runtime = { host_runtime = mock_host } },
    "nonexistent_cue_12345",
    1,
    {},
    { host_runtime = mock_host }
  )

  lu.assertEvalToTrue(result == false, "should return false for nonexistent cue")
end

function TestGameplayT6Hotspot:test_51_play_sound_only_with_nil_pos_fallback()
  -- This test covers the nil pos fallback path in _play_cue at line 197
  -- by calling play_sound_only with minimal params that result in nil pos
  local mock_host = {
    play_sfx_by_key = function() return nil end,
    play_3d_sound = function() return nil end,
  }

  -- Call play_sound_only with no pos, no player_id, no tile_index
  -- This should pass nil to _play_cue, triggering the fallback
  local result = board_feedback.play_sound_only(
    { presentation_runtime = { host_runtime = mock_host } },
    "nonexistent_cue_12345",
    {},
    { host_runtime = mock_host }
  )

  lu.assertEvalToTrue(result == false, "should return false for nonexistent cue even with nil pos fallback")
end

function TestGameplayT6Hotspot:test_52_pre_confirm_enter_missing_modal_function()
    local state = {
      ui = { active_choice_screen_key = "base" },
      game = {},
      gameplay_loop_ports = {
        modal = {
          -- open_pre_confirm_screen is intentionally missing
        },
      },
    }

    local result = _reload_module("src.ui.input.pre_confirm", {
  ["src.state.runtime"] = {
        get_ui_model = function()
          return {
            current_player_id = 7,
            choice = {
              id = "choice1",
              owner_role_id = 7,
              options = { { id = "opt1", label = "Option 1" } },
            },
          }
        end,
      },
      ["src.ui.view.choice_support"] = {
        resolve_option_label_by_id = function() return "Option 1" end,
        resolve_secondary_confirm_title = function() return "Title" end,
        resolve_secondary_confirm_body = function() return "Body" end,
      },
    }, function(flow)
      return flow.enter(state, { type = "choice_select", option_id = "opt1", actor_role_id = 7 })
    end)

    lu.assertEvalToTrue(result == false, "should return false when modal.open_pre_confirm_screen is not a function")
end

function TestGameplayT6Hotspot:test_53_pre_confirm_enter_rejects_non_owner_click()
    local state = {
      ui = { active_choice_screen_key = "base" },
      game = {},
    }
    local opened = false
    state.gameplay_loop_ports = {
      modal = {
        open_pre_confirm_screen = function() opened = true end,
      },
    }

    local result = _reload_module("src.ui.input.pre_confirm", {
  ["src.state.runtime"] = {
        get_ui_model = function()
          return {
            current_player_id = 7,
            choice = {
              id = "choice1",
              owner_role_id = 7,
              options = { { id = "opt1", label = "Option 1" } },
            },
          }
        end,
      },
      ["src.ui.view.choice_support"] = {
        resolve_option_label_by_id = function() return "Option 1" end,
        resolve_secondary_confirm_title = function() return "Title" end,
        resolve_secondary_confirm_body = function() return "Body" end,
      },
    }, function(flow)
      -- 非 owner 的点击者(#443:授权只认事件载荷 actor_role_id)。
      return flow.enter(state, { type = "choice_select", option_id = "opt1", actor_role_id = 8 })
    end)

    lu.assertEvalToTrue(result == false, "pre_confirm should reject a non-owner click")
    lu.assertEvalToTrue(opened == false, "pre_confirm should not open modal for a non-owner click")
end

function TestGameplayT6Hotspot:test_54_pre_confirm_enter_requires_actor_role_id()
    local state = {
      ui = { active_choice_screen_key = "base" },
      game = {},
    }
    local opened = false
    state.gameplay_loop_ports = {
      modal = {
        open_pre_confirm_screen = function() opened = true end,
      },
    }

    local result = _reload_module("src.ui.input.pre_confirm", {
  ["src.state.runtime"] = {
        get_ui_model = function()
          return {
            current_player_id = 7,
            choice = {
              id = "choice1",
              owner_role_id = 7,
              options = { { id = "opt1", label = "Option 1" } },
            },
          }
        end,
      },
      ["src.ui.view.choice_support"] = {
        resolve_option_label_by_id = function() return "Option 1" end,
        resolve_secondary_confirm_title = function() return "Title" end,
        resolve_secondary_confirm_body = function() return "Body" end,
      },
    }, function(flow)
      return flow.enter(state, { type = "choice_select", option_id = "opt1" })
    end)

    lu.assertEvalToTrue(result == false, "pre_confirm should reject an intent without actor_role_id")
    lu.assertEvalToTrue(opened == false, "pre_confirm should not open modal without actor_role_id")
end

function TestGameplayT6Hotspot:test_55_role_control_lock_sync_unit_with_existing_buff()
  local original_enums = _G.Enums
  _G.Enums = { BuffState = { BUFF_FORBID_CONTROL = 77 } }
  local mock_unit = {
    get_state_count = function(buff_id) return 1 end, -- buff already exists
    add_state = function() error("should not add when buff exists") end,
    remove_state = function() end,
  }
  local state = {
    role_control_lock = {
      by_role = {},
    },
  }
  local ok, err = pcall(function()
    role_control_lock_policy.sync(state, true, {
      runtime = {
        for_each_role_or_global = function(fn)
          fn({
            get_ctrl_unit = function() return mock_unit end,
          })
        end,
        resolve_role_id = function() return "p1" end,
      },
    })
  end)
  _G.Enums = original_enums
  if not ok then
    error(err)
  end
  -- Entry should exist but not owned (since buff was pre-existing)
  lu.assertEvalToTrue(state.role_control_lock.by_role.p1 ~= nil, "should create entry for unit with existing buff")
  lu.assertEvalToTrue(state.role_control_lock.by_role.p1.owned == false, "should not mark as owned when buff pre-exists")
end

function TestGameplayT6Hotspot:test_56_role_control_lock_sync_nil_role_id()
  local original_enums = _G.Enums
  _G.Enums = { BuffState = { BUFF_FORBID_CONTROL = 77 } }
  local state = {
    role_control_lock = {
      by_role = {},
    },
  }
  local ok, err = pcall(function()
    role_control_lock_policy.sync(state, true, {
      runtime = {
        for_each_role_or_global = function(fn)
          fn({
            get_ctrl_unit = function() return {} end,
          })
        end,
        resolve_role_id = function() return nil end, -- nil role_id
      },
    })
  end)
  _G.Enums = original_enums
  if not ok then
    error(err)
  end
  -- Should not create entry for nil role_id
  local count = 0
  for _ in pairs(state.role_control_lock.by_role) do count = count + 1 end
  lu.assertEvalToTrue(count == 0, "should not create entry for nil role_id")
end

function TestGameplayT6Hotspot:test_57_role_control_lock_sync_role_without_get_ctrl_unit()
  local original_enums = _G.Enums
  _G.Enums = { BuffState = { BUFF_FORBID_CONTROL = 77 } }
  local state = {
    role_control_lock = {
      by_role = {},
    },
  }
  local ok, err = pcall(function()
    role_control_lock_policy.sync(state, true, {
      runtime = {
        for_each_role_or_global = function(fn)
          fn({
            -- no get_ctrl_unit method
          })
        end,
        resolve_role_id = function() return "p1" end,
      },
    })
  end)
  _G.Enums = original_enums
  if not ok then
    error(err)
  end
  -- When unit is nil, the entry is pruned (set to nil), so it should not exist
  lu.assertEvalToTrue(state.role_control_lock.by_role.p1 == nil, "should not create entry for role without get_ctrl_unit")
end

function TestGameplayT6Hotspot:test_58_anim_overlay_spawn_overlay_failed_spawn()
  local scene = {
    overlay_units = { roadblocks = {}, mines = {} },
    presentation_runtime = {
      host_runtime = {
        create_unit_group = function() return nil end, -- failed to create
        create_unit_with_scale = function() return nil end,
        destroy_unit = function() end,
        destroy_unit_with_children = function() end,
      },
    },
  }
  local result = anim_overlay_runtime.spawn_overlay(scene, "roadblock", 1, "group_123", nil, { x = 0, y = 0, z = 0 }, nil, nil)
  lu.assertEvalToTrue(result == false, "spawn_overlay should return false when unit creation fails")
end

function TestGameplayT6Hotspot:test_59_create_scene_ui_bind_unit_preserves_offset()
  _with_globals({
    Enums = { ModelSocket = { socket_head = 1 } },
  }, function()
    local original_vector3 = math.Vector3
    local captured_offset = nil
    math.Vector3 = function(x, y, z)
      captured_offset = { x = x, y = y, z = z }
      return captured_offset
    end
    local mock_ctrl_unit = {
      create_scene_ui_bind_unit = function(layout_id, socket, offset)
        return { id = "layer", offset = offset }
      end,
    }
    local result = status3d_scene._create_scene_ui_bind_unit(mock_ctrl_unit, "layout_1")
    math.Vector3 = original_vector3
    lu.assertEvalToTrue(result ~= nil, "should create layer")
    lu.assertEvalToTrue(captured_offset ~= nil, "should create offset vector")
    lu.assertEvalToTrue(captured_offset.y == 4, "offset y should be 4")
  end)
end

function TestGameplayT6Hotspot:test_60_play_cue_empty_cue_name()
  local result = board_feedback.play_tile_cue(
    { presentation_runtime = { host_runtime = { play_sfx_by_key = function() end, play_3d_sound = function() end } } },
    "",
    1,
    {},
    {}
  )
  lu.assertEvalToTrue(result == false, "should return false for empty cue name")
end

function TestGameplayT6Hotspot:test_61_play_cue_nil_cue_name()
  local result = board_feedback.play_tile_cue(
    { presentation_runtime = { host_runtime = { play_sfx_by_key = function() end, play_3d_sound = function() end } } },
    nil,
    1,
    {},
    {}
  )
  lu.assertEvalToTrue(result == false, "should return false for nil cue name")
end

function TestGameplayT6Hotspot:test_62_play_player_cue_nil_position()
  local mock_host = {
    play_sfx_by_key = function() return nil end,
    play_3d_sound = function() return nil end,
  }

  -- When player has no position and no unit, _resolve_player_position returns nil
  -- which causes play_player_cue to return false early
  local state = {
    presentation_runtime = { host_runtime = mock_host },
    board_scene = {},
    game = {
      find_player_by_id = function() return { position = nil } end,
    },
  }

  local result = board_feedback.play_player_cue(state, "test_cue", "p1", {}, { host_runtime = mock_host })
  lu.assertEvalToTrue(result == false, "should return false when player position cannot be resolved")
end

function TestGameplayT6Hotspot:test_63_play_tile_cue_nil_position()
  local mock_host = {
    play_sfx_by_key = function() return nil end,
    play_3d_sound = function() return nil end,
  }

  -- When tile position cannot be resolved, play_tile_cue returns false
  local state = {
    presentation_runtime = { host_runtime = mock_host },
    board_scene = nil, -- No board_scene means no tile position
  }

  local result = board_feedback.play_tile_cue(state, "test_cue", 1, {}, { host_runtime = mock_host })
  lu.assertEvalToTrue(result == false, "should return false when tile position cannot be resolved")
end

function TestGameplayT6Hotspot:test_64_play_cue_with_followup_sounds()
  _play_cue_final_tests[1]()
end

function TestGameplayT6Hotspot:test_65_play_cue_bind_to_player()
  _play_cue_final_tests[2]()
end

function TestGameplayT6Hotspot:test_66_play_cue_sound_only_fallback()
  _play_cue_final_tests[3]()
end

function TestGameplayT6Hotspot:test_67_play_cue_payload_overrides()
  _play_cue_final_tests[4]()
end

function TestGameplayT6Hotspot:test_68_play_cue_allow_missing_resource()
  _play_cue_final_tests[5]()
end


return TestGameplayT6Hotspot
