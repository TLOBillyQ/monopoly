local function _profile(meta, bootstrap)
  local out = {}
  for key, value in pairs(meta or {}) do
    out[key] = value
  end
  out.bootstrap = bootstrap or {}
  return out
end

local profiles = {
  bankruptcy = _profile({
    group = "economy_core",
    goal = "bankruptcy_rent_resolution",
    value = "core",
    covers = { "bankruptcy", "rent", "tile_owner" },
    rotation = true,
    rotation_rank = 50,
    owner_tests = { "runtime.test_profiles", "gameplay.timeout_and_auto_runner" },
  }, {
    players = {
      [1] = {
        cash = 3000,
        position_tile_id = 35,
        item_counts = { [2002] = 1 },
      },
      [2] = { cash = 120000, position_tile_id = 39 },
      [3] = { cash = 100000, position_tile_id = 44 },
      [4] = { cash = 100000, position_tile_id = 40 },
    },
    tiles = {
      [1] = {
        owner_player_index = 2,
        level = 3,
        render_called = true,
      },
    },
  }),
  circle = _profile({
    group = "interrupt_resume",
    goal = "market_resume_and_second_remote_roll",
    value = "core",
    covers = { "market_resume", "remote_dice", "chance_reentry" },
    rotation = true,
    rotation_rank = 32,
    owner_tests = { "gameplay.gameplay_items_startup", "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 100000,
        position_tile_id = 15,
        item_counts = { [2002] = 2 },
      },
      [2] = { cash = 100000, position_tile_id = 35 },
      [3] = { cash = 100000, position_tile_id = 44 },
      [4] = { cash = 100000, position_tile_id = 40 },
    },
  }),
  clear_obstacles = _profile({
    group = "combat_obstacle",
    goal = "clear_obstacles_overlay_scan",
    value = "edge",
    covers = { "clear_obstacles", "overlay_cleanup" },
    rotation = false,
    rotation_rank = 0,
    owner_tests = { "domain.chance", "gameplay.intent_dispatch" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 7,
        item_counts = { [2006] = 1 },
      },
      [2] = { cash = 120000, position_tile_id = 35 },
      [3] = { cash = 120000, position_tile_id = 44 },
      [4] = { cash = 120000, position_tile_id = 40 },
    },
    overlays = {
      roadblocks = {
        { tile_id = 8, render_called = true },
        { tile_id = 9, render_called = true },
      },
      mines = {
        { tile_id = 9, render_called = true },
      },
    },
  }),
  exile = _profile({
    group = "relocation_status",
    goal = "targeted_exile_to_mountain",
    value = "core",
    covers = { "exile", "mountain_followup", "teleport" },
    rotation = true,
    rotation_rank = 22,
    owner_tests = { "domain.item" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 7,
        item_counts = { [2012] = 1 },
      },
      [2] = { cash = 120000, position_tile_id = 8 },
      [3] = { cash = 120000, position_tile_id = 44 },
      [4] = { cash = 120000, position_tile_id = 37 },
    },
  }),
  forced_move_hospital = _profile({
    group = "relocation_status",
    goal = "chance_forced_move_to_hospital",
    value = "core",
    covers = { "forced_move", "hospital_followup", "teleport" },
    rotation = true,
    rotation_rank = 20,
    owner_tests = { "domain.chance" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 44,
        item_counts = { [2002] = 1 },
      },
      [2] = { cash = 120000, position_tile_id = 35 },
      [3] = { cash = 120000, position_tile_id = 40 },
      [4] = { cash = 120000, position_tile_id = 37 },
    },
  }),
  forced_move_market = _profile({
    group = "relocation_status",
    goal = "chance_forced_move_to_market",
    value = "edge",
    covers = { "forced_move", "market_landing", "teleport" },
    rotation = false,
    rotation_rank = 0,
    owner_tests = { "domain.chance" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 44,
        item_counts = { [2002] = 1 },
      },
      [2] = { cash = 120000, position_tile_id = 35 },
      [3] = { cash = 120000, position_tile_id = 40 },
      [4] = { cash = 120000, position_tile_id = 37 },
    },
  }),
  hospital = _profile({
    group = "relocation_status",
    goal = "landing_before_hospital",
    value = "edge",
    covers = { "hospital_landing", "remote_dice" },
    rotation = false,
    rotation_rank = 0,
    owner_tests = { "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 100000,
        position_tile_id = 6,
        item_counts = { [2002] = 1 },
      },
      [2] = { cash = 100000, position_tile_id = 35 },
      [3] = { cash = 100000, position_tile_id = 44 },
      [4] = { cash = 100000, position_tile_id = 40 },
    },
  }),
  market = _profile({
    group = "economy_core",
    goal = "market_entry_and_preload",
    value = "core",
    covers = { "market_entry", "remote_dice" },
    rotation = false,
    rotation_rank = 0,
    owner_tests = { "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        position_tile_id = 27,
        item_counts = { [2002] = 1 },
      },
      [2] = { position_tile_id = 35 },
      [3] = { position_tile_id = 44 },
      [4] = { position_tile_id = 40 },
    },
  }),
  mine = _profile({
    group = "combat_obstacle",
    goal = "mine_arm_and_trigger_followup",
    value = "core",
    covers = { "mine", "hospital_followup", "obstacle" },
    rotation = true,
    rotation_rank = 12,
    owner_tests = { "gameplay.gameplay_items_startup", "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 7,
        item_counts = { [2005] = 1 },
      },
      [2] = {
        cash = 120000,
        position_tile_id = 6,
        item_counts = { [2002] = 1 },
      },
      [3] = { cash = 120000, position_tile_id = 44 },
      [4] = { cash = 120000, position_tile_id = 37 },
    },
  }),
  missile = _profile({
    group = "combat_obstacle",
    goal = "missile_multi_effect_followup",
    value = "core",
    covers = { "missile", "hospital_followup", "overlay_cleanup", "building_destroy" },
    rotation = true,
    rotation_rank = 11,
    owner_tests = { "gameplay.gameplay_items_startup", "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 40,
        item_counts = {
          [2002] = 1,
          [2013] = 1,
        },
      },
      [2] = { cash = 120000, position_tile_id = 11 },
      [3] = { cash = 120000, position_tile_id = 44 },
      [4] = { cash = 120000, position_tile_id = 37 },
    },
    tiles = {
      [11] = {
        owner_player_index = 2,
        level = 2,
        render_called = true,
      },
    },
    overlays = {
      roadblocks = {
        { tile_id = 11, render_called = true },
      },
      mines = {
        { tile_id = 11, render_called = true },
      },
    },
  }),
  monster = _profile({
    group = "combat_obstacle",
    goal = "monster_building_destroy",
    value = "core",
    covers = { "monster", "building_destroy" },
    rotation = true,
    rotation_rank = 10,
    owner_tests = { "gameplay.gameplay_items_startup", "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 40,
        item_counts = {
          [2002] = 1,
          [2008] = 1,
        },
      },
      [2] = { cash = 120000, position_tile_id = 44 },
      [3] = { cash = 120000, position_tile_id = 38 },
      [4] = { cash = 120000, position_tile_id = 37 },
    },
    tiles = {
      [12] = {
        owner_player_index = 2,
        level = 2,
        render_called = true,
      },
    },
  }),
  mountain = _profile({
    group = "relocation_status",
    goal = "landing_before_mountain",
    value = "edge",
    covers = { "mountain_landing", "remote_dice" },
    rotation = false,
    rotation_rank = 0,
    owner_tests = { "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 100000,
        position_tile_id = 12,
        item_counts = { [2002] = 1 },
      },
      [2] = { cash = 100000, position_tile_id = 35 },
      [3] = { cash = 100000, position_tile_id = 44 },
      [4] = { cash = 100000, position_tile_id = 40 },
    },
  }),
  roadblock_hit = _profile({
    group = "combat_obstacle",
    goal = "roadblock_trigger_and_clear",
    value = "edge",
    covers = { "roadblock_hit", "obstacle" },
    rotation = false,
    rotation_rank = 0,
    owner_tests = { "domain.movement" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 7,
        item_counts = { [2002] = 1 },
      },
      [2] = { cash = 120000, position_tile_id = 35 },
      [3] = { cash = 120000, position_tile_id = 44 },
      [4] = { cash = 120000, position_tile_id = 40 },
    },
    overlays = {
      roadblocks = {
        { tile_id = 8, render_called = true },
      },
    },
  }),
  steal = _profile({
    group = "interrupt_resume",
    goal = "steal_multi_item_choice",
    value = "core",
    covers = { "steal", "choice_resume" },
    rotation = true,
    rotation_rank = 30,
    owner_tests = { "gameplay.gameplay_items_startup", "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 7,
        item_counts = { [2007] = 1 },
      },
      [2] = {
        cash = 120000,
        position_tile_id = 8,
        item_counts = {
          [2001] = 1,
          [2010] = 1,
        },
      },
      [3] = { cash = 120000, position_tile_id = 44 },
      [4] = { cash = 120000, position_tile_id = 37 },
    },
  }),
  steal_one = _profile({
    group = "interrupt_resume",
    goal = "steal_single_item_auto_resolve",
    value = "edge",
    covers = { "steal", "auto_resume" },
    rotation = false,
    rotation_rank = 0,
    owner_tests = { "gameplay.gameplay_items_startup", "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 7,
        item_counts = { [2007] = 1 },
      },
      [2] = {
        cash = 120000,
        position_tile_id = 8,
        item_counts = { [2001] = 1 },
      },
      [3] = { cash = 120000, position_tile_id = 44 },
      [4] = { cash = 120000, position_tile_id = 37 },
    },
  }),
  steal_queue = _profile({
    group = "interrupt_resume",
    goal = "steal_queue_skip_and_resume",
    value = "edge",
    covers = { "steal", "queue_resume" },
    rotation = false,
    rotation_rank = 0,
    owner_tests = { "gameplay.gameplay_items_startup", "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 7,
        item_counts = { [2007] = 1 },
      },
      [2] = {
        cash = 120000,
        position_tile_id = 8,
        item_counts = { [2001] = 1 },
      },
      [3] = {
        cash = 120000,
        position_tile_id = 9,
        item_counts = { [2010] = 1 },
      },
      [4] = { cash = 120000, position_tile_id = 44 },
    },
  }),
  strong_card = _profile({
    group = "property_control",
    goal = "strong_card_rent_branching",
    value = "core",
    covers = { "strong_card", "rent_choice", "free_rent_fallback" },
    rotation = true,
    rotation_rank = 40,
    owner_tests = { "gameplay.gameplay_items_startup", "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 120000,
        position_tile_id = 11,
        item_counts = {
          [2001] = 1,
          [2002] = 1,
          [2009] = 1,
        },
      },
      [2] = { cash = 120000, position_tile_id = 44 },
      [3] = { cash = 120000, position_tile_id = 38 },
      [4] = { cash = 120000, position_tile_id = 37 },
    },
    tiles = {
      [12] = {
        owner_player_index = 2,
        level = 2,
        render_called = true,
      },
    },
  }),
  tax = _profile({
    group = "economy_core",
    goal = "tax_choice_and_tax_free",
    value = "core",
    covers = { "tax", "tax_free" },
    rotation = true,
    rotation_rank = 60,
    owner_tests = { "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 100000,
        position_tile_id = 18,
        item_counts = {
          [2010] = 1,
          [2002] = 1,
        },
      },
      [2] = { cash = 100000, position_tile_id = 35 },
      [3] = { cash = 100000, position_tile_id = 44 },
      [4] = { cash = 100000, position_tile_id = 40 },
    },
  }),
  upgrade_build = _profile({
    group = "property_control",
    goal = "upgrade_build_render_and_state",
    value = "core",
    covers = { "upgrade_build", "building_render" },
    rotation = true,
    rotation_rank = 41,
    owner_tests = { "runtime.test_profiles" },
  }, {
    players = {
      [1] = {
        cash = 200000,
        position_tile_id = 35,
        item_counts = { [2002] = 1 },
      },
      [2] = { cash = 100000, position_tile_id = 39 },
      [3] = { cash = 100000, position_tile_id = 44 },
      [4] = { cash = 100000, position_tile_id = 40 },
    },
    tiles = {
      [1] = {
        owner_player_index = 1,
        level = 0,
        render_called = true,
      },
    },
  }),
}

return profiles
