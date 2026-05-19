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
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 11,
      ["p2"] = 33,
      ["p3"] = 36,
      ["p4"] = 49,
      ["p5"] = 102,
    },
    ["field_names"] = {
      ["p1"] = "角色ID",
      ["p2"] = "道具数",
      ["p3"] = "槽位数",
      ["p4"] = "槽位",
      ["p5"] = "页码",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/v102/item_atlas.feature",
  },
  ["name"] = "道具图鉴",
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
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "打开道具图鉴后图鉴开启",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 11,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 12,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已开启",
            ["source_line"] = 13,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具图鉴屏幕已开启",
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
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "关闭道具图鉴",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 21,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 22,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家关闭道具图鉴",
            ["source_line"] = 23,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已关闭",
            ["source_line"] = 24,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具图鉴屏幕已关闭",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p3"] = "8",
        },
        {
          ["p1"] = "1",
          ["p2"] = "5",
          ["p3"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 39,
          ["p2"] = 39,
          ["p3"] = 39,
        },
        ["source_line"] = 32,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "道具图鉴每页展示8个道具槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 33,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 34,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 35,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 36,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个道具槽位",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p4"] = "1",
        },
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p4"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 54,
          ["p2"] = 54,
          ["p4"] = 54,
        },
        ["source_line"] = 45,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "选中道具槽位展示放大卡牌",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 46,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 47,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 48,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 49,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家选中第<p4>格道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前选中道具为第<槽位>格对应道具",
            ["source_line"] = 50,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "当前选中道具为第<p4>格对应道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已展示",
            ["source_line"] = 51,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已展示",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p4"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 67,
          ["p2"] = 67,
          ["p4"] = 67,
        },
        ["source_line"] = 58,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "放大卡牌展示道具名称与描述",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 59,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 60,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 61,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 62,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家选中第<p4>格道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌显示第<槽位>格道具的名称",
            ["source_line"] = 63,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "放大卡牌显示第<p4>格道具的名称",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌显示第<槽位>格道具的描述",
            ["source_line"] = 64,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "放大卡牌显示第<p4>格道具的描述",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p4"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 80,
          ["p2"] = 80,
          ["p4"] = 80,
        },
        ["source_line"] = 70,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击空白关闭放大卡牌",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 71,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 72,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 73,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 74,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家选中第<p4>格道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家点击空白区域关闭放大卡牌",
            ["source_line"] = 75,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击空白区域关闭放大卡牌",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 76,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已开启",
            ["source_line"] = 77,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具图鉴屏幕已开启",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "5",
          ["p4"] = "7",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 92,
          ["p2"] = 92,
          ["p4"] = 92,
        },
        ["source_line"] = 83,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击空槽位无反应",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 84,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 85,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 86,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 87,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家选中第<p4>格道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "无道具被选中",
            ["source_line"] = 88,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "无道具被选中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 89,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "16",
          ["p5"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 105,
          ["p2"] = 105,
          ["p5"] = 105,
        },
        ["source_line"] = 97,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻到下一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 98,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 99,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 100,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 101,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 102,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前图鉴页码为<p5>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "16",
          ["p5"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 117,
          ["p2"] = 117,
          ["p5"] = 117,
        },
        ["source_line"] = 108,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻到上一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 109,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 110,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 111,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 112,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴上一页",
            ["source_line"] = 113,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 114,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前图鉴页码为<p5>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "10",
          ["p3"] = "2",
          ["p5"] = "2",
        },
        {
          ["p1"] = "1",
          ["p2"] = "16",
          ["p3"] = "8",
          ["p5"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 129,
          ["p2"] = 129,
          ["p3"] = 129,
          ["p5"] = 129,
        },
        ["source_line"] = 120,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "最后一页展示剩余道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 121,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 122,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 123,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 124,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 125,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前图鉴页码为<p5>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 126,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个道具槽位",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p5"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 142,
          ["p2"] = 142,
          ["p5"] = 142,
        },
        ["source_line"] = 133,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "下一页翻页不超出最大页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 134,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 135,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 136,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 137,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 138,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 139,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前图鉴页码为<p5>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "16",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 153,
          ["p2"] = 153,
        },
        ["source_line"] = 145,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "上一页翻页不低于第1页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 146,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 147,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 148,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴上一页",
            ["source_line"] = 149,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为1",
            ["source_line"] = 150,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前图鉴页码为1",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "16",
          ["p4"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 166,
          ["p2"] = 166,
          ["p4"] = 166,
        },
        ["source_line"] = 156,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻页后清除选中状态",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 157,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 158,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 159,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 160,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家选中第<p4>格道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 161,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "无道具被选中",
            ["source_line"] = 162,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "无道具被选中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 163,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
