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
          items = { 2004, 2015, 2016, 2017, 2018, 2019 },
        },
        [2] = {
          cash = 60000,
          items = { 2004, 2015, 2016, 2017, 2018, 2019 },
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

return M
