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
      ["p1"] = 16,
      ["p2"] = 49,
      ["p3"] = 51,
      ["p4"] = 64,
      ["p5"] = 133,
      ["p6"] = 189,
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
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 10,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "游戏初始化后皮肤商店默认关闭",
      ["steps"] = {
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 11,
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
          ["p1"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 21,
        },
        ["source_line"] = 15,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "点击基础屏皮肤图标打开皮肤商店",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 16,
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
            ["original_text"] = "触发基础屏皮肤按钮",
            ["source_line"] = 17,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "触发基础屏皮肤按钮",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已开启",
            ["source_line"] = 18,
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
        {
          ["p1"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 32,
        },
        ["source_line"] = 26,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开皮肤商店后商店开启",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 27,
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
            ["source_line"] = 28,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已开启",
            ["source_line"] = 29,
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
          ["p1"] = 43,
        },
        ["source_line"] = 36,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "关闭皮肤商店",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 37,
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
            ["source_line"] = 38,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家关闭皮肤商店",
            ["source_line"] = 39,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 40,
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
          ["p2"] = 54,
          ["p3"] = 54,
        },
        ["source_line"] = 48,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "皮肤商店每页展示6个槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 49,
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
            ["source_line"] = 50,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
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
          ["p1"] = 70,
          ["p2"] = 70,
          ["p3"] = 70,
          ["p4"] = 70,
        },
        ["source_line"] = 60,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买解锁皮肤槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 61,
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
            ["source_line"] = 62,
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
            ["source_line"] = 63,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 64,
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
            ["source_line"] = 65,
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
            ["source_line"] = 66,
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
            ["source_line"] = 67,
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
          ["p1"] = 83,
          ["p2"] = 83,
          ["p4"] = 83,
        },
        ["source_line"] = 74,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "赠礼解锁皮肤槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 75,
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
            ["source_line"] = 76,
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
            ["source_line"] = 77,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 78,
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
            ["source_line"] = 79,
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
            ["source_line"] = 80,
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
          ["p1"] = 98,
          ["p2"] = 98,
          ["p3"] = 98,
          ["p4"] = 98,
        },
        ["source_line"] = 88,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "穿上已解锁的皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 89,
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
            ["source_line"] = 90,
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
            ["source_line"] = 91,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 92,
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
            ["source_line"] = 93,
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
            ["source_line"] = 94,
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
            ["source_line"] = 95,
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
          ["p1"] = 110,
          ["p4"] = 110,
        },
        ["source_line"] = 102,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "穿上未解锁的皮肤失败",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 103,
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
            ["source_line"] = 104,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 105,
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
            ["source_line"] = 106,
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
            ["source_line"] = 107,
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
          ["p1"] = 124,
          ["p2"] = 124,
          ["p4"] = 124,
        },
        ["source_line"] = 113,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "脱下已装备皮肤",
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
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 115,
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
            ["source_line"] = 116,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 117,
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
            ["source_line"] = 118,
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
            ["source_line"] = 119,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家脱下当前皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "无皮肤装备中",
            ["source_line"] = 120,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "无皮肤装备中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已开启",
            ["source_line"] = 121,
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
          ["p2"] = 136,
          ["p5"] = 136,
        },
        ["source_line"] = 129,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻到下一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 130,
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
            ["source_line"] = 131,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 132,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 133,
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
          ["p2"] = 147,
          ["p5"] = 147,
        },
        ["source_line"] = 139,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻到上一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 140,
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
            ["source_line"] = 141,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 142,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤上一页",
            ["source_line"] = 143,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 144,
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
          ["p2"] = 158,
          ["p3"] = 158,
          ["p5"] = 158,
        },
        ["source_line"] = 150,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "最后一页展示剩余皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 151,
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
            ["source_line"] = 152,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 153,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 154,
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
            ["source_line"] = 155,
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
          ["p2"] = 170,
          ["p5"] = 170,
        },
        ["source_line"] = 162,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "下一页翻页不超出最大页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 163,
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
            ["source_line"] = 164,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 165,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 166,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 167,
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
          ["p2"] = 180,
        },
        ["source_line"] = 173,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "上一页翻页不低于第1页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 174,
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
            ["source_line"] = 175,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤上一页",
            ["source_line"] = 176,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为1",
            ["source_line"] = 177,
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
          ["p1"] = 193,
          ["p2"] = 193,
          ["p3"] = 193,
          ["p6"] = 193,
        },
        ["source_line"] = 185,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开皮肤商店应渲染当前页全部卡片",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 186,
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
            ["source_line"] = 187,
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
            ["source_line"] = 188,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 189,
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
            ["source_line"] = 190,
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
          ["p1"] = 207,
          ["p2"] = 207,
          ["p3"] = 207,
          ["p5"] = 207,
          ["p6"] = 207,
        },
        ["source_line"] = 197,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻页后渲染新页全部卡片",
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
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 201,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 202,
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
            ["source_line"] = 203,
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
            ["source_line"] = 204,
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
          ["p1"] = 224,
          ["p2"] = 224,
          ["p4"] = 224,
        },
        ["source_line"] = 213,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开/翻页/购买/装备/关闭都不改写皮肤静态文本",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 214,
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
            ["source_line"] = 215,
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
            ["source_line"] = 216,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 217,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家购买槽位<槽位>的皮肤",
            ["source_line"] = 218,
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
            ["source_line"] = 219,
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
            ["source_line"] = 220,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤静态文本未被改写",
            ["source_line"] = 221,
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
