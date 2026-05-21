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
      ["p1"] = 16,
      ["p2"] = 49,
      ["p3"] = 52,
      ["p4"] = 65,
      ["p5"] = 67,
      ["p6"] = 70,
      ["p7"] = 223,
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
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 10,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "游戏初始化后图鉴默认关闭",
      ["steps"] = {
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已关闭",
            ["source_line"] = 11,
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
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 21,
        },
        ["source_line"] = 15,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击基础屏图鉴图标打开道具图鉴",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 16,
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
            ["original_text"] = "触发基础屏图鉴按钮",
            ["source_line"] = 17,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "触发基础屏图鉴按钮",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已开启",
            ["source_line"] = 18,
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
        {
          ["p1"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 32,
        },
        ["source_line"] = 26,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "打开道具图鉴后图鉴开启",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 27,
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
            ["source_line"] = 28,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已开启",
            ["source_line"] = 29,
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
          ["p1"] = 43,
        },
        ["source_line"] = 36,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "关闭道具图鉴",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 37,
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
            ["source_line"] = 38,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家关闭道具图鉴",
            ["source_line"] = 39,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已关闭",
            ["source_line"] = 40,
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
          ["p1"] = 55,
          ["p2"] = 55,
          ["p3"] = 55,
        },
        ["source_line"] = 48,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "道具图鉴每页展示8个道具槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 49,
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
            ["source_line"] = 50,
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
            ["source_line"] = 51,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 52,
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
          ["p1"] = 73,
          ["p2"] = 73,
          ["p3"] = 73,
          ["p4"] = 73,
          ["p5"] = 73,
          ["p6"] = 73,
        },
        ["source_line"] = 61,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "选中道具槽位展示放大卡牌",
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
            ["original_text"] = "当前选中道具为第<槽位>格对应道具",
            ["source_line"] = 66,
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
            ["source_line"] = 67,
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
            ["source_line"] = 68,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 69,
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
            ["source_line"] = 70,
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
          ["p1"] = 88,
          ["p2"] = 88,
          ["p4"] = 88,
          ["p5"] = 88,
          ["p6"] = 88,
        },
        ["source_line"] = 77,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "放大卡牌展示道具名称与描述",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 78,
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
            ["source_line"] = 79,
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
            ["source_line"] = 80,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 81,
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
            ["source_line"] = 82,
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
            ["source_line"] = 83,
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
            ["source_line"] = 84,
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
            ["source_line"] = 85,
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
          ["p1"] = 103,
          ["p2"] = 103,
          ["p3"] = 103,
          ["p4"] = 103,
          ["p5"] = 103,
        },
        ["source_line"] = 91,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击空白关闭放大卡牌",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 92,
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
            ["source_line"] = 93,
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
            ["source_line"] = 94,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 95,
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
            ["source_line"] = 96,
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
            ["source_line"] = 97,
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
            ["source_line"] = 98,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击空白区域关闭放大卡牌",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 99,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已开启",
            ["source_line"] = 100,
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
          ["p1"] = 117,
          ["p2"] = 117,
          ["p3"] = 117,
          ["p6"] = 117,
        },
        ["source_line"] = 106,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "打开图鉴时未选中道具放大卡牌组件保持隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 107,
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
            ["source_line"] = 108,
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
            ["source_line"] = 109,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 110,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴关闭提示已隐藏",
            ["source_line"] = 111,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴关闭提示已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴空白关闭层已隐藏",
            ["source_line"] = 112,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴空白关闭层已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 113,
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
            ["source_line"] = 114,
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
          ["p1"] = 132,
          ["p2"] = 132,
          ["p4"] = 132,
          ["p5"] = 132,
          ["p6"] = 132,
        },
        ["source_line"] = 120,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "选中道具时同步展示放大卡牌组件",
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
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 124,
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
            ["source_line"] = 125,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴关闭提示已展示",
            ["source_line"] = 126,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴关闭提示已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴空白关闭层已展示",
            ["source_line"] = 127,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴空白关闭层已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 128,
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
            ["source_line"] = 129,
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
          ["p1"] = 148,
          ["p2"] = 148,
          ["p3"] = 148,
          ["p4"] = 148,
          ["p5"] = 148,
        },
        ["source_line"] = 135,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击空白关闭时同步隐藏放大卡牌组件",
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
          ["keyword"] = "And",
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
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 140,
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
            ["source_line"] = 141,
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
            ["source_line"] = 142,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击空白区域关闭放大卡牌",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 143,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴关闭提示已隐藏",
            ["source_line"] = 144,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴关闭提示已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴空白关闭层已隐藏",
            ["source_line"] = 145,
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
          ["p2"] = "6",
          ["p3"] = "6",
          ["p4"] = "7",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 161,
          ["p2"] = 161,
          ["p3"] = 161,
          ["p4"] = 161,
        },
        ["source_line"] = 151,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击空槽位无反应",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 152,
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
            ["source_line"] = 153,
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
            ["source_line"] = 154,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 155,
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
            ["source_line"] = 156,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "无道具被选中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 157,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 158,
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
          ["p6"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 176,
          ["p2"] = 176,
          ["p3"] = 176,
          ["p6"] = 176,
        },
        ["source_line"] = 166,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "单页图鉴上下一页箭头均隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 167,
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
            ["source_line"] = 168,
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
            ["source_line"] = 169,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴上一页箭头已隐藏",
            ["source_line"] = 170,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴上一页箭头已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴下一页箭头已隐藏",
            ["source_line"] = 171,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴下一页箭头已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 172,
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
            ["source_line"] = 173,
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
          ["p6"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 188,
          ["p2"] = 188,
          ["p6"] = 188,
        },
        ["source_line"] = 179,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "多页图鉴首页只显示下一页箭头",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 180,
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
            ["source_line"] = 181,
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
            ["source_line"] = 182,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴上一页箭头已隐藏",
            ["source_line"] = 183,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴上一页箭头已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴下一页箭头已展示",
            ["source_line"] = 184,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴下一页箭头已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 185,
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
          ["p2"] = "17",
          ["p6"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 201,
          ["p2"] = 201,
          ["p6"] = 201,
        },
        ["source_line"] = 191,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "多页图鉴中间页两侧箭头都显示",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 192,
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
            ["source_line"] = 193,
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
            ["source_line"] = 194,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 195,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴上一页箭头已展示",
            ["source_line"] = 196,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴上一页箭头已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴下一页箭头已展示",
            ["source_line"] = 197,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴下一页箭头已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 198,
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
          ["p3"] = "8",
          ["p6"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 215,
          ["p2"] = 215,
          ["p3"] = 215,
          ["p6"] = 215,
        },
        ["source_line"] = 204,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "多页图鉴末页只显示上一页箭头",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 205,
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
            ["source_line"] = 206,
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
            ["source_line"] = 207,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 208,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴上一页箭头已展示",
            ["source_line"] = 209,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴上一页箭头已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴下一页箭头已隐藏",
            ["source_line"] = 210,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴下一页箭头已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 211,
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
            ["source_line"] = 212,
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
          ["p7"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 227,
          ["p2"] = 227,
          ["p6"] = 227,
          ["p7"] = 227,
        },
        ["source_line"] = 218,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻到下一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 219,
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
            ["source_line"] = 220,
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
            ["source_line"] = 221,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 222,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 223,
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
            ["source_line"] = 224,
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
          ["p1"] = 240,
          ["p2"] = 240,
          ["p6"] = 240,
          ["p7"] = 240,
        },
        ["source_line"] = 230,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻到上一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 231,
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
            ["source_line"] = 232,
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
            ["source_line"] = 233,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 234,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴上一页",
            ["source_line"] = 235,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 236,
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
            ["source_line"] = 237,
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
          ["p1"] = 253,
          ["p2"] = 253,
          ["p3"] = 253,
          ["p6"] = 253,
          ["p7"] = 253,
        },
        ["source_line"] = 243,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "最后一页展示剩余道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 244,
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
            ["source_line"] = 245,
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
            ["source_line"] = 246,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 247,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 248,
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
            ["source_line"] = 249,
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
            ["source_line"] = 250,
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
          ["p6"] = "1",
          ["p7"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 268,
          ["p2"] = 268,
          ["p3"] = 268,
          ["p6"] = 268,
          ["p7"] = 268,
        },
        ["source_line"] = 257,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "下一页翻页不超出最大页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 258,
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
            ["source_line"] = 259,
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
            ["source_line"] = 260,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 261,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 262,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 263,
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
            ["source_line"] = 264,
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
            ["source_line"] = 265,
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
          ["p3"] = "8",
          ["p6"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 281,
          ["p2"] = 281,
          ["p3"] = 281,
          ["p6"] = 281,
        },
        ["source_line"] = 271,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "上一页翻页不低于第1页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 272,
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
            ["source_line"] = 273,
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
            ["source_line"] = 274,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴上一页",
            ["source_line"] = 275,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为1",
            ["source_line"] = 276,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前图鉴页码为1",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 277,
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
            ["source_line"] = 278,
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
          ["p1"] = 296,
          ["p2"] = 296,
          ["p3"] = 296,
          ["p4"] = 296,
          ["p5"] = 296,
        },
        ["source_line"] = 284,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻页后清除选中状态",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 285,
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
            ["source_line"] = 286,
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
            ["source_line"] = 287,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 288,
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
            ["source_line"] = 289,
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
            ["source_line"] = 290,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "无道具被选中",
            ["source_line"] = 291,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "无道具被选中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 292,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 293,
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
          ["p3"] = "8",
          ["p4"] = "1",
          ["p5"] = "item_9",
          ["p6"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 314,
          ["p2"] = 314,
          ["p3"] = 314,
          ["p4"] = 314,
          ["p5"] = 314,
          ["p6"] = 314,
        },
        ["source_line"] = 301,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "打开/翻页/选中/关闭都不改写图鉴静态文本",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 302,
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
            ["source_line"] = 303,
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
            ["source_line"] = 304,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 305,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 306,
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
            ["source_line"] = 307,
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
            ["original_text"] = "玩家点击空白区域关闭放大卡牌",
            ["source_line"] = 308,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击空白区域关闭放大卡牌",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴静态文本未被改写",
            ["source_line"] = 309,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴静态文本未被改写",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 310,
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
            ["source_line"] = 311,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "图鉴总页数为<p6>",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
