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
      ["p5"] = 51,
      ["p6"] = 54,
      ["p7"] = 155,
    },
    ["field_names"] = {
      ["p1"] = "角色ID",
      ["p2"] = "道具数",
      ["p3"] = "槽位数",
      ["p4"] = "槽位",
      ["p5"] = "选中道具",
      ["p6"] = "总页数",
      ["p7"] = "页码",
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
          ["p3"] = "8",
          ["p4"] = "1",
          ["p5"] = "item_1",
          ["p6"] = "1",
        },
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p3"] = "8",
          ["p4"] = "5",
          ["p5"] = "item_5",
          ["p6"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 57,
          ["p2"] = 57,
          ["p3"] = 57,
          ["p4"] = 57,
          ["p5"] = 57,
          ["p6"] = 57,
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
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 51,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前选中道具ID为<p5>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已展示",
            ["source_line"] = 52,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 53,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 54,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "图鉴总页数为<p6>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p4"] = "3",
          ["p5"] = "item_3",
          ["p6"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 72,
          ["p2"] = 72,
          ["p4"] = 72,
          ["p5"] = 72,
          ["p6"] = 72,
        },
        ["source_line"] = 61,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "放大卡牌展示道具名称与描述",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 62,
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
            ["source_line"] = 63,
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
            ["source_line"] = 64,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 65,
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
            ["source_line"] = 66,
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
            ["source_line"] = 67,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "放大卡牌显示第<p4>格道具的描述",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 68,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前选中道具ID为<p5>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 69,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "图鉴总页数为<p6>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p3"] = "8",
          ["p4"] = "1",
          ["p5"] = "item_1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 87,
          ["p2"] = 87,
          ["p3"] = 87,
          ["p4"] = 87,
          ["p5"] = 87,
        },
        ["source_line"] = 75,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击空白关闭放大卡牌",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 76,
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
            ["source_line"] = 77,
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
            ["source_line"] = 78,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 79,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家选中第<p4>格道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 80,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前选中道具ID为<p5>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 81,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个道具槽位",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家点击空白区域关闭放大卡牌",
            ["source_line"] = 82,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击空白区域关闭放大卡牌",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 83,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已开启",
            ["source_line"] = 84,
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
          ["p2"] = "8",
          ["p3"] = "8",
          ["p6"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 101,
          ["p2"] = 101,
          ["p3"] = 101,
          ["p6"] = 101,
        },
        ["source_line"] = 90,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "打开图鉴时未选中道具放大卡牌组件保持隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 91,
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
            ["source_line"] = 92,
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
            ["source_line"] = 93,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 94,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴关闭提示已隐藏",
            ["source_line"] = 95,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴关闭提示已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴空白关闭层已隐藏",
            ["source_line"] = 96,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴空白关闭层已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 97,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 98,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "图鉴总页数为<p6>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p4"] = "1",
          ["p5"] = "item_1",
          ["p6"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 116,
          ["p2"] = 116,
          ["p4"] = 116,
          ["p5"] = 116,
          ["p6"] = 116,
        },
        ["source_line"] = 104,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "选中道具时同步展示放大卡牌组件",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 105,
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
            ["source_line"] = 106,
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
            ["source_line"] = 107,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 108,
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
            ["original_text"] = "放大卡牌已展示",
            ["source_line"] = 109,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴关闭提示已展示",
            ["source_line"] = 110,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴关闭提示已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴空白关闭层已展示",
            ["source_line"] = 111,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴空白关闭层已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 112,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前选中道具ID为<p5>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 113,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "图鉴总页数为<p6>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p3"] = "8",
          ["p4"] = "1",
          ["p5"] = "item_1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 132,
          ["p2"] = 132,
          ["p3"] = 132,
          ["p4"] = 132,
          ["p5"] = 132,
        },
        ["source_line"] = 119,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击空白关闭时同步隐藏放大卡牌组件",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 120,
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
            ["source_line"] = 121,
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
            ["source_line"] = 122,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 123,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家选中第<p4>格道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 124,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前选中道具ID为<p5>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 125,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个道具槽位",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家点击空白区域关闭放大卡牌",
            ["source_line"] = 126,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击空白区域关闭放大卡牌",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 127,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴关闭提示已隐藏",
            ["source_line"] = 128,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴关闭提示已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴空白关闭层已隐藏",
            ["source_line"] = 129,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴空白关闭层已隐藏",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "5",
          ["p3"] = "5",
          ["p4"] = "7",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 145,
          ["p2"] = 145,
          ["p3"] = 145,
          ["p4"] = 145,
        },
        ["source_line"] = 135,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击空槽位无反应",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 136,
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
            ["source_line"] = 137,
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
            ["source_line"] = 138,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 139,
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
            ["source_line"] = 140,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "无道具被选中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 141,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 142,
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
          ["p2"] = "16",
          ["p6"] = "2",
          ["p7"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 159,
          ["p2"] = 159,
          ["p6"] = 159,
          ["p7"] = 159,
        },
        ["source_line"] = 150,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻到下一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 151,
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
            ["source_line"] = 152,
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
            ["source_line"] = 153,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 154,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 155,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p7",
          },
          ["text"] = "当前图鉴页码为<p7>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 156,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "图鉴总页数为<p6>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "16",
          ["p6"] = "2",
          ["p7"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 172,
          ["p2"] = 172,
          ["p6"] = 172,
          ["p7"] = 172,
        },
        ["source_line"] = 162,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻到上一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 163,
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
            ["source_line"] = 164,
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
            ["source_line"] = 165,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 166,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴上一页",
            ["source_line"] = 167,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 168,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p7",
          },
          ["text"] = "当前图鉴页码为<p7>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 169,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "图鉴总页数为<p6>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "10",
          ["p3"] = "2",
          ["p6"] = "2",
          ["p7"] = "2",
        },
        {
          ["p1"] = "1",
          ["p2"] = "16",
          ["p3"] = "8",
          ["p6"] = "2",
          ["p7"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 185,
          ["p2"] = 185,
          ["p3"] = 185,
          ["p6"] = 185,
          ["p7"] = 185,
        },
        ["source_line"] = 175,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "最后一页展示剩余道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 176,
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
            ["source_line"] = 177,
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
            ["source_line"] = 178,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 179,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 180,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p7",
          },
          ["text"] = "当前图鉴页码为<p7>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 181,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 182,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "图鉴总页数为<p6>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p7"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 198,
          ["p2"] = 198,
          ["p7"] = 198,
        },
        ["source_line"] = 189,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "下一页翻页不超出最大页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 190,
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
            ["source_line"] = 191,
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
            ["source_line"] = 192,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 193,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 194,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 195,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p7",
          },
          ["text"] = "当前图鉴页码为<p7>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "16",
          ["p6"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 210,
          ["p2"] = 210,
          ["p6"] = 210,
        },
        ["source_line"] = 201,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "上一页翻页不低于第1页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 202,
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
            ["source_line"] = 203,
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
            ["source_line"] = 204,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴上一页",
            ["source_line"] = 205,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为1",
            ["source_line"] = 206,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前图鉴页码为1",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 207,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "图鉴总页数为<p6>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "9",
          ["p3"] = "1",
          ["p4"] = "1",
          ["p5"] = "item_1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 225,
          ["p2"] = 225,
          ["p3"] = 225,
          ["p4"] = 225,
          ["p5"] = 225,
        },
        ["source_line"] = 213,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻页后清除选中状态",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 214,
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
            ["source_line"] = 215,
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
            ["source_line"] = 216,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 217,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家选中第<p4>格道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 218,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前选中道具ID为<p5>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 219,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "无道具被选中",
            ["source_line"] = 220,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "无道具被选中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 221,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 222,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个道具槽位",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
