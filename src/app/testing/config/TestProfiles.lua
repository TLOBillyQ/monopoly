local profiles = {
  default = {
    map_module = "Config.Maps.DefaultMap",
  },
  ui_quick_all = {
    map_module = "Config.Maps.UIQuickAll",
    bootstrap = {
      players = {
        [1] = {
          cash = 60000,
          balances = {
            ["金豆"] = 200,
            ["乐园币"] = 300,
          },
          items = { 2002, 2004, 2007, 2008, 2003 },
        },
        [2] = {
          cash = 80000,
        },
      },
    },
  },
  ui_quick_choice = {
    map_module = "Config.Maps.UIQuickChoice",
    bootstrap = {
      players = {
        [1] = {
          cash = 50000,
          balances = {
            ["金豆"] = 150,
            ["乐园币"] = 200,
          },
          items = { 2002, 2004, 2007, 2008 },
        },
      },
    },
  },
  ui_quick_bankruptcy = {
    map_module = "Config.Maps.UIQuickBankruptcy",
    bootstrap = {
      players = {
        [1] = {
          cash = 3000,
          items = { 2002 },
        },
        [2] = {
          cash = 120000,
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
  ui_quick_status3d = {
    map_module = "Config.Maps.UIQuickAll",
    bootstrap = {
      players = {
        [1] = {
          cash = 60000,
          items = { 2004, 2015, 2017, 2018, 2019 },
        },
        [2] = {
          cash = 60000,
          items = { 2004, 2015, 2017, 2018, 2019 },
        },
      },
    },
  },
  ui_quick_all_items = {
    map_module = "Config.Maps.UIQuickAll",
    bootstrap = {
      players = {
        [1] = {
          cash = 200000,
          balances = {
            ["金豆"] = 500,
            ["乐园币"] = 500,
          },
          inventory_slots = 19,
          items = {
            2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010,
            2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019,
          },
        },
        [2] = {
          cash = 200000,
          balances = {
            ["金豆"] = 500,
            ["乐园币"] = 500,
          },
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
