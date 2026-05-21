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
      ["p1"] = 11,
      ["p2"] = 33,
      ["p3"] = 35,
      ["p4"] = 48,
      ["p5"] = 117,
      ["p6"] = 173,
    },
    ["field_names"] = {
      ["p1"] = "角色ID",
      ["p2"] = "皮肤数",
      ["p3"] = "槽位数",
      ["p4"] = "槽位",
      ["p5"] = "页码",
      ["p6"] = "卡片渲染数",
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
          ["p1"] = 16,
        },
        ["source_line"] = 10,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开皮肤商店后商店开启",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 11,
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
            ["source_line"] = 12,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已开启",
            ["source_line"] = 13,
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
          ["p1"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 27,
        },
        ["source_line"] = 20,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "关闭皮肤商店",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 21,
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
            ["source_line"] = 22,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家关闭皮肤商店",
            ["source_line"] = 23,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 24,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
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
          ["p2"] = 38,
          ["p3"] = 38,
        },
        ["source_line"] = 32,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "皮肤商店每页展示6个槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 33,
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
            ["source_line"] = 34,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
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
          ["p1"] = "1",
          ["p2"] = "5",
          ["p3"] = "5",
          ["p4"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 54,
          ["p2"] = 54,
          ["p3"] = 54,
          ["p4"] = 54,
        },
        ["source_line"] = 44,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买解锁皮肤槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 45,
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
            ["source_line"] = 46,
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
            ["source_line"] = 47,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 48,
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
            ["source_line"] = 49,
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
            ["source_line"] = 50,
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
            ["source_line"] = 51,
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
          ["p4"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 67,
          ["p2"] = 67,
          ["p4"] = 67,
        },
        ["source_line"] = 58,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "赠礼解锁皮肤槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 59,
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
            ["source_line"] = 60,
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
            ["source_line"] = 61,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 62,
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
            ["original_text"] = "玩家通过赠礼解锁槽位<槽位>的皮肤",
            ["source_line"] = 63,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家通过赠礼解锁槽位<p4>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 64,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "槽位<p4>的皮肤已归玩家持有",
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
          ["p1"] = 82,
          ["p2"] = 82,
          ["p3"] = 82,
          ["p4"] = 82,
        },
        ["source_line"] = 72,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "穿上已解锁的皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 73,
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
            ["source_line"] = 74,
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
            ["source_line"] = 75,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 76,
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
            ["source_line"] = 77,
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
            ["source_line"] = 78,
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
            ["source_line"] = 79,
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
          ["p1"] = 94,
          ["p4"] = 94,
        },
        ["source_line"] = 86,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "穿上未解锁的皮肤失败",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 87,
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
            ["source_line"] = 88,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 89,
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
            ["source_line"] = 90,
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
            ["source_line"] = 91,
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
          ["p2"] = "5",
          ["p4"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 108,
          ["p2"] = 108,
          ["p4"] = 108,
        },
        ["source_line"] = 97,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "脱下已装备皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 98,
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
            ["source_line"] = 99,
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
            ["source_line"] = 100,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 101,
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
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 102,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家穿上槽位<p4>的皮肤",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家脱下当前皮肤",
            ["source_line"] = 103,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家脱下当前皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "无皮肤装备中",
            ["source_line"] = 104,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "无皮肤装备中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已开启",
            ["source_line"] = 105,
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
          ["p2"] = "12",
          ["p5"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p2"] = 120,
          ["p5"] = 120,
        },
        ["source_line"] = 113,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻到下一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 114,
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
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 115,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 116,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 117,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前皮肤页码为<p5>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p2"] = "12",
          ["p5"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p2"] = 131,
          ["p5"] = 131,
        },
        ["source_line"] = 123,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻到上一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 124,
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
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 125,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 126,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤上一页",
            ["source_line"] = 127,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 128,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前皮肤页码为<p5>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p2"] = "8",
          ["p3"] = "2",
          ["p5"] = "2",
        },
        {
          ["p2"] = "12",
          ["p3"] = "6",
          ["p5"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p2"] = 142,
          ["p3"] = 142,
          ["p5"] = 142,
        },
        ["source_line"] = 134,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "最后一页展示剩余皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 135,
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
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 136,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 137,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 138,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前皮肤页码为<p5>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 139,
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
          ["p2"] = "6",
          ["p5"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p2"] = 154,
          ["p5"] = 154,
        },
        ["source_line"] = 146,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "下一页翻页不超出最大页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 147,
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
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 148,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 149,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 150,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 151,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前皮肤页码为<p5>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p2"] = "12",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p2"] = 164,
        },
        ["source_line"] = 157,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "上一页翻页不低于第1页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 158,
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
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 159,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤上一页",
            ["source_line"] = 160,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为1",
            ["source_line"] = 161,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前皮肤页码为1",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "6",
          ["p3"] = "6",
          ["p6"] = "6",
        },
        {
          ["p1"] = "1",
          ["p2"] = "3",
          ["p3"] = "3",
          ["p6"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 177,
          ["p2"] = 177,
          ["p3"] = 177,
          ["p6"] = 177,
        },
        ["source_line"] = 169,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开皮肤商店应渲染当前页全部卡片",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 170,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "皮肤目录共有<p2>款皮肤",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 171,
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
            ["source_line"] = 172,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 173,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "皮肤卡片渲染数为<p6>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 174,
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
          ["p2"] = "12",
          ["p3"] = "6",
          ["p5"] = "2",
          ["p6"] = "6",
        },
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p3"] = "2",
          ["p5"] = "2",
          ["p6"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 191,
          ["p2"] = 191,
          ["p3"] = 191,
          ["p5"] = 191,
          ["p6"] = 191,
        },
        ["source_line"] = 181,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻页后渲染新页全部卡片",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 182,
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
            ["source_line"] = 183,
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
            ["source_line"] = 184,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 185,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 186,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "皮肤卡片渲染数为<p6>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 187,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 188,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前皮肤页码为<p5>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "12",
          ["p4"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 208,
          ["p2"] = 208,
          ["p4"] = 208,
        },
        ["source_line"] = 197,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开/翻页/购买/装备/关闭都不改写皮肤静态文本",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 198,
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
            ["source_line"] = 199,
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
            ["source_line"] = 200,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 201,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家购买槽位<槽位>的皮肤",
            ["source_line"] = 202,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家购买槽位<p4>的皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 203,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家穿上槽位<p4>的皮肤",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家关闭皮肤商店",
            ["source_line"] = 204,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤静态文本未被改写",
            ["source_line"] = 205,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤静态文本未被改写",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
