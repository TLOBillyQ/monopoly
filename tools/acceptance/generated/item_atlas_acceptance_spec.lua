-- luacheck: globals describe it
local runtime = require("acceptance4lua.runtime")
local steps = require("acceptance.steps")
local json = require("acceptance4lua.json")

local embedded_ir = {
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
      ["卡片渲染数"] = 246,
      ["总页数"] = 53,
      ["末页槽位数"] = 204,
      ["槽位"] = 66,
      ["槽位数"] = 52,
      ["角色ID"] = 16,
      ["选中道具"] = 68,
      ["道具ID"] = 377,
      ["道具数"] = 49,
      ["页码"] = 244,
      ["验证角色ID"] = 241,
    },
    ["field_names"] = {
      ["卡片渲染数"] = "卡片渲染数",
      ["总页数"] = "总页数",
      ["末页槽位数"] = "末页槽位数",
      ["槽位"] = "槽位",
      ["槽位数"] = "槽位数",
      ["角色ID"] = "角色ID",
      ["选中道具"] = "选中道具",
      ["道具ID"] = "道具ID",
      ["道具数"] = "道具数",
      ["页码"] = "页码",
      ["验证角色ID"] = "验证角色ID",
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
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["角色ID"] = 21,
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
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
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
          ["角色ID"] = "1",
        },
        {
          ["角色ID"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["角色ID"] = 32,
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
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
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
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["角色ID"] = 43,
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
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
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
          ["总页数"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "8",
        },
        {
          ["总页数"] = "1",
          ["槽位数"] = "5",
          ["角色ID"] = "1",
          ["道具数"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 56,
          ["槽位数"] = 56,
          ["角色ID"] = 56,
          ["道具数"] = 56,
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
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 50,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
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
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 53,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["选中道具"] = "item_1",
          ["道具数"] = "8",
        },
        {
          ["总页数"] = "1",
          ["槽位"] = "5",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["选中道具"] = "item_5",
          ["道具数"] = "8",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 74,
          ["槽位"] = 74,
          ["槽位数"] = 74,
          ["角色ID"] = 74,
          ["选中道具"] = 74,
          ["道具数"] = 74,
        },
        ["source_line"] = 62,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "选中道具槽位展示放大卡牌",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 63,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 64,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 65,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 66,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家选中第<槽位>格道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前选中道具为第<槽位>格对应道具",
            ["source_line"] = 67,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "当前选中道具为第<槽位>格对应道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 68,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "选中道具",
          },
          ["text"] = "当前选中道具ID为<选中道具>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已展示",
            ["source_line"] = 69,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 70,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 71,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "3",
          ["角色ID"] = "1",
          ["选中道具"] = "item_3",
          ["道具数"] = "8",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 89,
          ["槽位"] = 89,
          ["角色ID"] = 89,
          ["选中道具"] = 89,
          ["道具数"] = 89,
        },
        ["source_line"] = 78,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "放大卡牌展示道具名称与描述",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 79,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 80,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 81,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 82,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家选中第<槽位>格道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌显示第<槽位>格道具的名称",
            ["source_line"] = 83,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "放大卡牌显示第<槽位>格道具的名称",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌显示第<槽位>格道具的描述",
            ["source_line"] = 84,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "放大卡牌显示第<槽位>格道具的描述",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 85,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "选中道具",
          },
          ["text"] = "当前选中道具ID为<选中道具>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 86,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "3",
          ["角色ID"] = "1",
          ["选中道具"] = "item_3",
          ["道具数"] = "8",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 104,
          ["槽位"] = 104,
          ["角色ID"] = 104,
          ["选中道具"] = 104,
          ["道具数"] = 104,
        },
        ["source_line"] = 92,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "再次点击同一道具取消选中",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 93,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 94,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 95,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 96,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家选中第<槽位>格道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 97,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "选中道具",
          },
          ["text"] = "当前选中道具ID为<选中道具>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 98,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家选中第<槽位>格道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "无道具被选中",
            ["source_line"] = 99,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "无道具被选中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 100,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 101,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["槽位"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["选中道具"] = "item_1",
          ["道具数"] = "8",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["槽位"] = 119,
          ["槽位数"] = 119,
          ["角色ID"] = 119,
          ["选中道具"] = 119,
          ["道具数"] = 119,
        },
        ["source_line"] = 107,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击空白关闭放大卡牌",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 108,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 109,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 110,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 111,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家选中第<槽位>格道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 112,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "选中道具",
          },
          ["text"] = "当前选中道具ID为<选中道具>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 113,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家点击空白区域关闭放大卡牌",
            ["source_line"] = 114,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击空白区域关闭放大卡牌",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 115,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已开启",
            ["source_line"] = 116,
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
          ["总页数"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "8",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 133,
          ["槽位数"] = 133,
          ["角色ID"] = 133,
          ["道具数"] = 133,
        },
        ["source_line"] = 122,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "打开图鉴时未选中道具放大卡牌组件保持隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 123,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 124,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 125,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 126,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴关闭提示已隐藏",
            ["source_line"] = 127,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴关闭提示已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴空白关闭层已隐藏",
            ["source_line"] = 128,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴空白关闭层已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 129,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 130,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "1",
          ["角色ID"] = "1",
          ["选中道具"] = "item_1",
          ["道具数"] = "8",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 148,
          ["槽位"] = 148,
          ["角色ID"] = 148,
          ["选中道具"] = 148,
          ["道具数"] = 148,
        },
        ["source_line"] = 136,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "选中道具时同步展示放大卡牌组件",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 137,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 138,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 139,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 140,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家选中第<槽位>格道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已展示",
            ["source_line"] = 141,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴关闭提示已展示",
            ["source_line"] = 142,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴关闭提示已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴空白关闭层已展示",
            ["source_line"] = 143,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴空白关闭层已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 144,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "选中道具",
          },
          ["text"] = "当前选中道具ID为<选中道具>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 145,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["选中道具"] = "item_1",
          ["道具数"] = "8",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 165,
          ["槽位"] = 165,
          ["槽位数"] = 165,
          ["角色ID"] = 165,
          ["选中道具"] = 165,
          ["道具数"] = 165,
        },
        ["source_line"] = 151,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击空白关闭时同步隐藏放大卡牌组件",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 152,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 153,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
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
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 155,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家选中第<槽位>格道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 156,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "选中道具",
          },
          ["text"] = "当前选中道具ID为<选中道具>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 157,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家点击空白区域关闭放大卡牌",
            ["source_line"] = 158,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击空白区域关闭放大卡牌",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 159,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴关闭提示已隐藏",
            ["source_line"] = 160,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴关闭提示已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴空白关闭层已隐藏",
            ["source_line"] = 161,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴空白关闭层已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 162,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "7",
          ["槽位数"] = "6",
          ["角色ID"] = "1",
          ["道具数"] = "6",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 179,
          ["槽位"] = 179,
          ["槽位数"] = 179,
          ["角色ID"] = 179,
          ["道具数"] = 179,
        },
        ["source_line"] = 168,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "点击空槽位无反应",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 169,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 170,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 171,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 172,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家选中第<槽位>格道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "无道具被选中",
            ["source_line"] = 173,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "无道具被选中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 174,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 175,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 176,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "8",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 194,
          ["槽位数"] = 194,
          ["角色ID"] = 194,
          ["道具数"] = 194,
        },
        ["source_line"] = 184,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "单页图鉴上下一页箭头均隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 185,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 186,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 187,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴上一页箭头已隐藏",
            ["source_line"] = 188,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴上一页箭头已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴下一页箭头已隐藏",
            ["source_line"] = 189,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴下一页箭头已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 190,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 191,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "9",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 208,
          ["末页槽位数"] = 208,
          ["槽位数"] = 208,
          ["角色ID"] = 208,
          ["道具数"] = 208,
        },
        ["source_line"] = 197,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "多页图鉴首页只显示下一页箭头",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 198,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 199,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 200,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴上一页箭头已隐藏",
            ["source_line"] = 201,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴上一页箭头已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴下一页箭头已展示",
            ["source_line"] = 202,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴下一页箭头已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 203,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具目录末页展示<末页槽位数>个道具槽位",
            ["source_line"] = 204,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "末页槽位数",
          },
          ["text"] = "道具目录末页展示<末页槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 205,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "3",
          ["角色ID"] = "1",
          ["道具数"] = "17",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 221,
          ["角色ID"] = 221,
          ["道具数"] = 221,
        },
        ["source_line"] = 211,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "多页图鉴中间页两侧箭头都显示",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 212,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 213,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 214,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 215,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴上一页箭头已展示",
            ["source_line"] = 216,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴上一页箭头已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴下一页箭头已展示",
            ["source_line"] = 217,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴下一页箭头已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 218,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "16",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 235,
          ["槽位数"] = 235,
          ["角色ID"] = 235,
          ["道具数"] = 235,
        },
        ["source_line"] = 224,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "多页图鉴末页只显示上一页箭头",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 225,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 226,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 227,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 228,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴上一页箭头已展示",
            ["source_line"] = 229,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴上一页箭头已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴下一页箭头已隐藏",
            ["source_line"] = 230,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴下一页箭头已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 231,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 232,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["卡片渲染数"] = "8",
          ["总页数"] = "2",
          ["角色ID"] = "1",
          ["道具数"] = "16",
          ["页码"] = "2",
          ["验证角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["卡片渲染数"] = 250,
          ["总页数"] = 250,
          ["角色ID"] = 250,
          ["道具数"] = 250,
          ["页码"] = 250,
          ["验证角色ID"] = 250,
        },
        ["source_line"] = 238,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻到下一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 239,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 240,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前角色ID为<验证角色ID>",
            ["source_line"] = 241,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "当前角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 242,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 243,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 244,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前图鉴页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴打开角色ID为<验证角色ID>",
            ["source_line"] = 245,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "图鉴打开角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 246,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "卡片渲染数",
          },
          ["text"] = "图鉴卡片渲染数为<卡片渲染数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 247,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "16",
          ["页码"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 264,
          ["末页槽位数"] = 264,
          ["角色ID"] = 264,
          ["道具数"] = 264,
          ["页码"] = 264,
        },
        ["source_line"] = 253,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻到上一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 254,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 255,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 256,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 257,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具目录末页展示<末页槽位数>个道具槽位",
            ["source_line"] = 258,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "末页槽位数",
          },
          ["text"] = "道具目录末页展示<末页槽位数>个道具槽位",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴上一页",
            ["source_line"] = 259,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 260,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前图鉴页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 261,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["槽位数"] = "2",
          ["角色ID"] = "1",
          ["道具数"] = "10",
          ["页码"] = "2",
        },
        {
          ["总页数"] = "2",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "16",
          ["页码"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 277,
          ["槽位数"] = 277,
          ["角色ID"] = 277,
          ["道具数"] = 277,
          ["页码"] = 277,
        },
        ["source_line"] = 267,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "最后一页展示剩余道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 268,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 269,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 270,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 271,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 272,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前图鉴页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 273,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 274,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "8",
          ["页码"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 292,
          ["槽位数"] = 292,
          ["角色ID"] = 292,
          ["道具数"] = 292,
          ["页码"] = 292,
        },
        ["source_line"] = 281,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "下一页翻页不超出最大页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 282,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 283,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 284,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 285,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 286,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 287,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前图鉴页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 288,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 289,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "9",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 306,
          ["末页槽位数"] = 306,
          ["槽位数"] = 306,
          ["角色ID"] = 306,
          ["道具数"] = 306,
        },
        ["source_line"] = 295,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "上一页翻页不低于第1页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 296,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 297,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 298,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴上一页",
            ["source_line"] = 299,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为1",
            ["source_line"] = 300,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前图鉴页码为1",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 301,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具目录末页展示<末页槽位数>个道具槽位",
            ["source_line"] = 302,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "末页槽位数",
          },
          ["text"] = "道具目录末页展示<末页槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 303,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["槽位"] = "1",
          ["槽位数"] = "1",
          ["角色ID"] = "1",
          ["选中道具"] = "item_1",
          ["道具数"] = "9",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["槽位"] = 321,
          ["槽位数"] = 321,
          ["角色ID"] = 321,
          ["选中道具"] = 321,
          ["道具数"] = 321,
        },
        ["source_line"] = 309,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻页后清除选中状态",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 310,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 311,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 312,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 313,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家选中第<槽位>格道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 314,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "选中道具",
          },
          ["text"] = "当前选中道具ID为<选中道具>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 315,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "无道具被选中",
            ["source_line"] = 316,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "无道具被选中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "放大卡牌已隐藏",
            ["source_line"] = 317,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "放大卡牌已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 318,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["卡片渲染数"] = "8",
          ["总页数"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "8",
        },
        {
          ["卡片渲染数"] = "5",
          ["总页数"] = "1",
          ["槽位数"] = "5",
          ["角色ID"] = "1",
          ["道具数"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["卡片渲染数"] = 335,
          ["总页数"] = 335,
          ["槽位数"] = 335,
          ["角色ID"] = 335,
          ["道具数"] = 335,
        },
        ["source_line"] = 326,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "打开图鉴渲染当前页全部道具卡片",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 327,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 328,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 329,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 330,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "卡片渲染数",
          },
          ["text"] = "图鉴卡片渲染数为<卡片渲染数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 331,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 332,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["卡片渲染数"] = "8",
          ["总页数"] = "2",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "16",
          ["页码"] = "2",
        },
        {
          ["卡片渲染数"] = "2",
          ["总页数"] = "2",
          ["槽位数"] = "2",
          ["角色ID"] = "1",
          ["道具数"] = "10",
          ["页码"] = "2",
        },
        {
          ["卡片渲染数"] = "1",
          ["总页数"] = "2",
          ["槽位数"] = "1",
          ["角色ID"] = "1",
          ["道具数"] = "9",
          ["页码"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["卡片渲染数"] = 350,
          ["总页数"] = 350,
          ["槽位数"] = 350,
          ["角色ID"] = 350,
          ["道具数"] = 350,
          ["页码"] = 350,
        },
        ["source_line"] = 339,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "下一页箭头刷新到新页卡片",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 340,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 341,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 342,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 343,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 344,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "卡片渲染数",
          },
          ["text"] = "图鉴卡片渲染数为<卡片渲染数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 345,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 346,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前图鉴页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 347,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["卡片渲染数"] = "8",
          ["总页数"] = "2",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "16",
          ["页码"] = "1",
        },
        {
          ["卡片渲染数"] = "8",
          ["总页数"] = "2",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具数"] = "9",
          ["页码"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["卡片渲染数"] = 367,
          ["总页数"] = 367,
          ["槽位数"] = 367,
          ["角色ID"] = 367,
          ["道具数"] = 367,
          ["页码"] = 367,
        },
        ["source_line"] = 355,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "上一页箭头刷新到上一页卡片",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 356,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 357,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 358,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 359,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴上一页",
            ["source_line"] = 360,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 361,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "卡片渲染数",
          },
          ["text"] = "图鉴卡片渲染数为<卡片渲染数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 362,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 363,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前图鉴页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 364,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["末页槽位数"] = "8",
          ["槽位"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具ID"] = "item_1",
          ["道具数"] = "8",
        },
        {
          ["总页数"] = "1",
          ["末页槽位数"] = "8",
          ["槽位"] = "8",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具ID"] = "item_8",
          ["道具数"] = "8",
        },
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "8",
          ["槽位"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具ID"] = "item_1",
          ["道具数"] = "16",
        },
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "8",
          ["槽位"] = "4",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["道具ID"] = "item_4",
          ["道具数"] = "16",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 383,
          ["末页槽位数"] = 383,
          ["槽位"] = 383,
          ["槽位数"] = 383,
          ["角色ID"] = 383,
          ["道具ID"] = 383,
          ["道具数"] = 383,
        },
        ["source_line"] = 373,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "打开图鉴后卡牌槽位贴对应道具的图",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 374,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 375,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 376,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴卡牌槽位<槽位>当前贴图为道具<道具ID>的图",
            ["source_line"] = 377,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
            "道具ID",
          },
          ["text"] = "图鉴卡牌槽位<槽位>当前贴图为道具<道具ID>的图",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 378,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具目录末页展示<末页槽位数>个道具槽位",
            ["source_line"] = 379,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "末页槽位数",
          },
          ["text"] = "道具目录末页展示<末页槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 380,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["卡片渲染数"] = "8",
          ["总页数"] = "2",
          ["槽位"] = "1",
          ["角色ID"] = "1",
          ["道具ID"] = "item_9",
          ["道具数"] = "16",
          ["页码"] = "2",
          ["验证角色ID"] = "1",
        },
        {
          ["卡片渲染数"] = "8",
          ["总页数"] = "2",
          ["槽位"] = "4",
          ["角色ID"] = "1",
          ["道具ID"] = "item_12",
          ["道具数"] = "16",
          ["页码"] = "2",
          ["验证角色ID"] = "1",
        },
        {
          ["卡片渲染数"] = "8",
          ["总页数"] = "2",
          ["槽位"] = "8",
          ["角色ID"] = "1",
          ["道具ID"] = "item_16",
          ["道具数"] = "16",
          ["页码"] = "2",
          ["验证角色ID"] = "1",
        },
        {
          ["卡片渲染数"] = "2",
          ["总页数"] = "2",
          ["槽位"] = "1",
          ["角色ID"] = "1",
          ["道具ID"] = "item_9",
          ["道具数"] = "10",
          ["页码"] = "2",
          ["验证角色ID"] = "1",
        },
        {
          ["卡片渲染数"] = "2",
          ["总页数"] = "2",
          ["槽位"] = "2",
          ["角色ID"] = "1",
          ["道具ID"] = "item_10",
          ["道具数"] = "10",
          ["页码"] = "2",
          ["验证角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["卡片渲染数"] = 402,
          ["总页数"] = 402,
          ["槽位"] = 402,
          ["角色ID"] = 402,
          ["道具ID"] = 402,
          ["道具数"] = 402,
          ["页码"] = 402,
          ["验证角色ID"] = 402,
        },
        ["source_line"] = 389,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻到下一页后卡牌槽位贴图刷新为新页对应道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 390,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 391,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前角色ID为<验证角色ID>",
            ["source_line"] = 392,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "当前角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 393,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 394,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴卡牌槽位<槽位>当前贴图为道具<道具ID>的图",
            ["source_line"] = 395,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
            "道具ID",
          },
          ["text"] = "图鉴卡牌槽位<槽位>当前贴图为道具<道具ID>的图",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴打开角色ID为<验证角色ID>",
            ["source_line"] = 396,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "图鉴打开角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 397,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "卡片渲染数",
          },
          ["text"] = "图鉴卡片渲染数为<卡片渲染数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 398,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前图鉴页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 399,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "8",
          ["槽位"] = "1",
          ["角色ID"] = "1",
          ["道具ID"] = "item_1",
          ["道具数"] = "16",
          ["页码"] = "1",
          ["验证角色ID"] = "1",
        },
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "8",
          ["槽位"] = "8",
          ["角色ID"] = "1",
          ["道具ID"] = "item_8",
          ["道具数"] = "16",
          ["页码"] = "1",
          ["验证角色ID"] = "1",
        },
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "2",
          ["槽位"] = "1",
          ["角色ID"] = "1",
          ["道具ID"] = "item_1",
          ["道具数"] = "10",
          ["页码"] = "1",
          ["验证角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 423,
          ["末页槽位数"] = 423,
          ["槽位"] = 423,
          ["角色ID"] = 423,
          ["道具ID"] = 423,
          ["道具数"] = 423,
          ["页码"] = 423,
          ["验证角色ID"] = 423,
        },
        ["source_line"] = 409,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻回上一页后卡牌槽位贴图恢复为前页对应道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 410,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 411,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前角色ID为<验证角色ID>",
            ["source_line"] = 412,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "当前角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 413,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 414,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具目录末页展示<末页槽位数>个道具槽位",
            ["source_line"] = 415,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "末页槽位数",
          },
          ["text"] = "道具目录末页展示<末页槽位数>个道具槽位",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴上一页",
            ["source_line"] = 416,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴卡牌槽位<槽位>当前贴图为道具<道具ID>的图",
            ["source_line"] = 417,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
            "道具ID",
          },
          ["text"] = "图鉴卡牌槽位<槽位>当前贴图为道具<道具ID>的图",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴打开角色ID为<验证角色ID>",
            ["source_line"] = 418,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "图鉴打开角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 419,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前图鉴页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 420,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["槽位"] = "1",
          ["槽位数"] = "8",
          ["角色ID"] = "1",
          ["选中道具"] = "item_9",
          ["道具数"] = "16",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 443,
          ["槽位"] = 443,
          ["槽位数"] = 443,
          ["角色ID"] = 443,
          ["选中道具"] = 443,
          ["道具数"] = 443,
        },
        ["source_line"] = 430,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "打开/翻页/选中/关闭都不改写图鉴静态文本",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 431,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "道具数",
          },
          ["text"] = "道具目录共有<道具数>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 432,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 433,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 434,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 435,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家选中第<槽位>格道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中道具ID为<选中道具>",
            ["source_line"] = 436,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "选中道具",
          },
          ["text"] = "当前选中道具ID为<选中道具>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家点击空白区域关闭放大卡牌",
            ["source_line"] = 437,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击空白区域关闭放大卡牌",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "图鉴静态文本未被改写",
            ["source_line"] = 438,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "图鉴静态文本未被改写",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 439,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个道具槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "图鉴总页数为<总页数>",
            ["source_line"] = 440,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "图鉴总页数为<总页数>",
        },
      },
    },
  },
}

local function load_ir()
  local override_path = os.getenv("ACCEPTANCE_FEATURE_JSON")
  if override_path ~= nil and override_path ~= "" then
    local file = assert(io.open(override_path, "rb"))
    local content = file:read("*a")
    file:close()
    return json.decode(content)
  end
  return embedded_ir
end

local ir = load_ir()

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
