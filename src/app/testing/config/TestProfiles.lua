local profiles = {
  default = {
    bootstrap = {},
  },
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
        },
      },
    },
  },
  scenario_market_staging = {
    bootstrap = {
      players = {
        [1] = {
          position_tile_id = 27,
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
  ["机会卡测试"] = {
    bootstrap = {
      players = {
        [1] = {
          position_tile_id = 9,
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
  items_move_control = {
    bootstrap = {
      players = {
        [1] = {
          cash = 60000,
          balances = {
            ["金豆"] = 200,
            ["乐园币"] = 300,
          },
          position_tile_id = 35,
          item_counts = {
            [2002] = 1,
            [2003] = 1,
            [2004] = 1,
            [2005] = 1,
            [2006] = 1,
          },
        },
        [2] = {
          cash = 60000,
          position_tile_id = 39,
        },
        [3] = {
          cash = 60000,
          position_tile_id = 44,
        },
        [4] = {
          cash = 60000,
          position_tile_id = 40,
        },
      },
    },
  },
  items_economy_tax = {
    bootstrap = {
      players = {
        [1] = {
          cash = 200000,
          balances = {
            ["金豆"] = 100,
            ["乐园币"] = 100,
          },
          position_tile_id = 44,
          item_counts = {
            [2001] = 1,
            [2009] = 1,
            [2010] = 1,
            [2011] = 1,
            [2014] = 1,
          },
        },
        [2] = {
          cash = 80000,
          position_tile_id = 40,
        },
        [3] = {
          cash = 80000,
          position_tile_id = 38,
        },
        [4] = {
          cash = 80000,
          position_tile_id = 37,
        },
      },
    },
  },
  items_target_disrupt = {
    bootstrap = {
      players = {
        [1] = {
          cash = 120000,
          position_tile_id = 40,
          item_counts = {
            [2007] = 1,
            [2008] = 1,
            [2012] = 1,
            [2013] = 1,
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
    },
  },
  items_deity_status = {
    bootstrap = {
      players = {
        [1] = {
          cash = 100000,
          position_tile_id = 38,
          item_counts = {
            [2015] = 1,
            [2016] = 1,
            [2017] = 1,
            [2018] = 1,
            [2019] = 1,
          },
        },
        [2] = {
          cash = 100000,
          position_tile_id = 37,
        },
        [3] = {
          cash = 100000,
          position_tile_id = 35,
        },
        [4] = {
          cash = 100000,
          position_tile_id = 39,
        },
      },
    },
  },
}

local M = {}

local function _deep_copy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = _deep_copy(v)
  end
  return out
end

function M.resolve(profile_name)
  if type(profile_name) ~= "string" or profile_name == "" then
    return _deep_copy(profiles.default)
  end
  return _deep_copy(profiles[profile_name] or profiles.default)
end

function M.has(profile_name)
  return type(profile_name) == "string" and profiles[profile_name] ~= nil
end

function M.get(profile_name)
  if not M.has(profile_name) then
    return nil
  end
  return _deep_copy(profiles[profile_name])
end

function M.names()
  local out = {}
  for name in pairs(profiles) do
    out[#out + 1] = name
  end
  table.sort(out)
  return out
end

return M
