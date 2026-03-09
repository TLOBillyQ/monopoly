local profiles = {
  scenario_bankruptcy = {
    bootstrap = {
      players = {
        [1] = {
          cash = 3000,
          position_tile_id = 35,
          item_counts = {
            [2002] = 1,
          },
        },
        [2] = {
          cash = 120000,
          position_tile_id = 39,
        },
        [3] = {
          cash = 100000,
          position_tile_id = 44,
        },
        [4] = {
          cash = 100000,
          position_tile_id = 40,
        },
      },
      tiles = {
        [1] = {
          owner_player_index = 2,
          level = 3,
          render_called = true,
        },
      },
    },
  },
  scenario_upgrade_building_render = {
    bootstrap = {
      players = {
        [1] = {
          cash = 200000,
          position_tile_id = 35,
          item_counts = {
            [2002] = 1,
          },
        },
        [2] = {
          cash = 100000,
          position_tile_id = 39,
        },
        [3] = {
          cash = 100000,
          position_tile_id = 44,
        },
        [4] = {
          cash = 100000,
          position_tile_id = 40,
        },
      },
      tiles = {
        [1] = {
          owner_player_index = 1,
          level = 0,
          render_called = true,
        },
      },
    },
  },
  scenario_market_staging = {
    bootstrap = {
      players = {
        [1] = {
          position_tile_id = 27,
          item_counts = {
            [2002] = 1,
          },
        },
        [2] = {
          position_tile_id = 35,
        },
        [3] = {
          position_tile_id = 44,
        },
        [4] = {
          position_tile_id = 40,
        },
      },
    },
  },
  scenario_tax_survive = {
    bootstrap = {
      players = {
        [1] = {
          cash = 100000,
          position_tile_id = 18,
          item_counts = {
            [2010] = 1,
            [2002] = 1,
          },
        },
        [2] = {
          cash = 100000,
          position_tile_id = 35,
        },
        [3] = {
          cash = 100000,
          position_tile_id = 44,
        },
        [4] = {
          cash = 100000,
          position_tile_id = 40,
        },
      },
    },
  },
  scenario_hospital_staging = {
    bootstrap = {
      players = {
        [1] = {
          cash = 100000,
          position_tile_id = 6,
          item_counts = {
            [2002] = 1,
          },
        },
        [2] = {
          cash = 100000,
          position_tile_id = 35,
        },
        [3] = {
          cash = 100000,
          position_tile_id = 44,
        },
        [4] = {
          cash = 100000,
          position_tile_id = 40,
        },
      },
    },
  },
  scenario_mountain_staging = {
    bootstrap = {
      players = {
        [1] = {
          cash = 100000,
          position_tile_id = 12,
          item_counts = {
            [2002] = 1,
          },
        },
        [2] = {
          cash = 100000,
          position_tile_id = 35,
        },
        [3] = {
          cash = 100000,
          position_tile_id = 44,
        },
        [4] = {
          cash = 100000,
          position_tile_id = 40,
        },
      },
    },
  },
  scenario_monster_staging = {
    bootstrap = {
      players = {
        [1] = {
          cash = 120000,
          position_tile_id = 40,
          item_counts = {
            [2002] = 1,
            [2008] = 1,
          },
        },
        [2] = {
          cash = 120000,
          position_tile_id = 44,
        },
        [3] = {
          cash = 120000,
          position_tile_id = 38,
        },
        [4] = {
          cash = 120000,
          position_tile_id = 37,
        },
      },
      tiles = {
        [12] = {
          owner_player_index = 2,
          level = 2,
          render_called = true,
        },
      },
    },
  },
  scenario_missile_staging = {
    bootstrap = {
      players = {
        [1] = {
          cash = 120000,
          position_tile_id = 40,
          item_counts = {
            [2002] = 1,
            [2013] = 1,
          },
        },
        [2] = {
          cash = 120000,
          position_tile_id = 11,
        },
        [3] = {
          cash = 120000,
          position_tile_id = 44,
        },
        [4] = {
          cash = 120000,
          position_tile_id = 37,
        },
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
          {
            tile_id = 11,
            render_called = true,
          },
        },
        mines = {
          {
            tile_id = 11,
            render_called = true,
          },
        },
      },
    },
  },
}

return profiles
