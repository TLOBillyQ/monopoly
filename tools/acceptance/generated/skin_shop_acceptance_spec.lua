-- luacheck: globals describe it
local runtime = require("acceptance.runtime")
local steps = require("acceptance.steps")

local ir = {
  ["background"] = {
    {
      ["keyword"] = "Given",
      ["metadata"] = {
        ["original_text"] = "游戏已初始化标准棋盘",
        ["source_line"] = 6,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 9,
      ["p2"] = 19,
      ["p3"] = 21,
      ["p4"] = 32,
    },
    ["field_names"] = {
      ["p1"] = "角色ID",
      ["p2"] = "皮肤数",
      ["p3"] = "槽位数",
      ["p4"] = "槽位",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/v102/skin_shop.feature",
  },
  ["name"] = "皮肤商店",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["p1"] = "1",
        },
        {
          ["p1"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 14,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开皮肤商店后商店开启",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 9,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 10,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已开启",
            ["source_line"] = 11,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已开启",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p2"] = "6",
          ["p3"] = "6",
        },
        {
          ["p2"] = "3",
          ["p3"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p2"] = 24,
          ["p3"] = 24,
        },
        ["source_line"] = 18,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "皮肤商店每页展示6个槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 19,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "皮肤目录共有<p2>款皮肤",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 20,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 21,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个皮肤槽位",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "5",
          ["p3"] = "5",
          ["p4"] = "1",
        },
        {
          ["p1"] = "1",
          ["p2"] = "5",
          ["p3"] = "5",
          ["p4"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 38,
          ["p2"] = 38,
          ["p3"] = 38,
          ["p4"] = 38,
        },
        ["source_line"] = 28,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买解锁皮肤槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 29,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "皮肤目录共有<p2>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 30,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 31,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 32,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "槽位<p4>的皮肤尚未解锁",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家购买槽位<槽位>的皮肤",
            ["source_line"] = 33,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家购买槽位<p4>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 34,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "槽位<p4>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 35,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个皮肤槽位",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "5",
          ["p3"] = "5",
          ["p4"] = "1",
        },
        {
          ["p1"] = "2",
          ["p2"] = "5",
          ["p3"] = "5",
          ["p4"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 52,
          ["p2"] = 52,
          ["p3"] = 52,
          ["p4"] = 52,
        },
        ["source_line"] = 42,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "穿上已解锁的皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 43,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "皮肤目录共有<p2>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 44,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 45,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 46,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "槽位<p4>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 47,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家穿上槽位<p4>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已装备成功",
            ["source_line"] = 48,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "槽位<p4>的皮肤已装备成功",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 49,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个皮肤槽位",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p4"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 64,
          ["p4"] = 64,
        },
        ["source_line"] = 56,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "穿上未解锁的皮肤失败",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 57,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 58,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 59,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "槽位<p4>的皮肤尚未解锁",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 60,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家穿上槽位<p4>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤未成功装备",
            ["source_line"] = 61,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤未成功装备",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 74,
        },
        ["source_line"] = 67,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "关闭皮肤商店",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 68,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 69,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家关闭皮肤商店",
            ["source_line"] = 70,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 71,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
