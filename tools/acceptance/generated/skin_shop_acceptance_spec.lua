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
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["产品ID"] = 127,
      ["卡片渲染数"] = 276,
      ["容器数"] = 277,
      ["总页数"] = 65,
      ["按钮文本"] = 404,
      ["新槽位"] = 382,
      ["末页槽位数"] = 262,
      ["槽位"] = 78,
      ["槽位数"] = 64,
      ["皮肤ID"] = 311,
      ["皮肤数"] = 62,
      ["角色ID"] = 16,
      ["购买槽位"] = 479,
      ["赠礼名"] = 419,
      ["面板"] = 50,
      ["页码"] = 159,
      ["验证槽位"] = 81,
      ["验证角色ID"] = 274,
    },
    ["field_names"] = {
      ["产品ID"] = "产品ID",
      ["卡片渲染数"] = "卡片渲染数",
      ["容器数"] = "容器数",
      ["总页数"] = "总页数",
      ["按钮文本"] = "按钮文本",
      ["新槽位"] = "新槽位",
      ["末页槽位数"] = "末页槽位数",
      ["槽位"] = "槽位",
      ["槽位数"] = "槽位数",
      ["皮肤ID"] = "皮肤ID",
      ["皮肤数"] = "皮肤数",
      ["角色ID"] = "角色ID",
      ["购买槽位"] = "购买槽位",
      ["赠礼名"] = "赠礼名",
      ["面板"] = "面板",
      ["页码"] = "页码",
      ["验证槽位"] = "验证槽位",
      ["验证角色ID"] = "验证角色ID",
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
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["角色ID"] = 21,
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
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
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
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
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
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["角色ID"] = 43,
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
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
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
          ["角色ID"] = "1",
          ["面板"] = "皮肤商店",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["角色ID"] = 56,
          ["面板"] = 56,
        },
        ["source_line"] = 48,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "回合外打开皮肤商店后轮到玩家行动自动关闭并提示",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 49,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开<面板>",
            ["source_line"] = 50,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "玩家打开<面板>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "轮到玩家行动",
            ["source_line"] = 51,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "轮到玩家行动",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<面板>屏幕已关闭",
            ["source_line"] = 52,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "<面板>屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "提示\"轮到你行动了\"已显示",
            ["source_line"] = 53,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "提示\"轮到你行动了\"已显示",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
        },
        {
          ["总页数"] = "1",
          ["槽位数"] = "3",
          ["皮肤数"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 68,
          ["槽位数"] = 68,
          ["皮肤数"] = 68,
        },
        ["source_line"] = 61,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "皮肤商店每页展示6个槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 62,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 63,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 64,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 65,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "1",
          ["槽位数"] = "5",
          ["皮肤数"] = "5",
          ["角色ID"] = "1",
          ["验证槽位"] = "1",
        },
        {
          ["总页数"] = "1",
          ["槽位"] = "3",
          ["槽位数"] = "5",
          ["皮肤数"] = "5",
          ["角色ID"] = "1",
          ["验证槽位"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 86,
          ["槽位"] = 86,
          ["槽位数"] = 86,
          ["皮肤数"] = 86,
          ["角色ID"] = 86,
          ["验证槽位"] = 86,
        },
        ["source_line"] = 74,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买解锁皮肤槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 75,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 76,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
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
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤尚未解锁",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家购买槽位<槽位>的皮肤",
            ["source_line"] = 79,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家购买槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 80,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<验证槽位>的皮肤已归玩家持有",
            ["source_line"] = 81,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
          },
          ["text"] = "槽位<验证槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 82,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 83,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "2",
          ["皮肤数"] = "5",
          ["角色ID"] = "1",
          ["验证槽位"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 101,
          ["槽位"] = 101,
          ["皮肤数"] = 101,
          ["角色ID"] = 101,
          ["验证槽位"] = 101,
        },
        ["source_line"] = 90,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "赠礼解锁皮肤槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 91,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 92,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 93,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 94,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤尚未解锁",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家通过赠礼解锁槽位<槽位>的皮肤",
            ["source_line"] = 95,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家通过赠礼解锁槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 96,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<验证槽位>的皮肤已归玩家持有",
            ["source_line"] = 97,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
          },
          ["text"] = "槽位<验证槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 98,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "1",
          ["槽位数"] = "5",
          ["皮肤数"] = "5",
          ["角色ID"] = "1",
          ["验证槽位"] = "1",
        },
        {
          ["总页数"] = "1",
          ["槽位"] = "2",
          ["槽位数"] = "5",
          ["皮肤数"] = "5",
          ["角色ID"] = "2",
          ["验证槽位"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 119,
          ["槽位"] = 119,
          ["槽位数"] = 119,
          ["皮肤数"] = 119,
          ["角色ID"] = 119,
          ["验证槽位"] = 119,
        },
        ["source_line"] = 106,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "穿上已解锁的皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 107,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 108,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 109,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 110,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 111,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已装备成功",
            ["source_line"] = 112,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已装备成功",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<验证槽位>的皮肤已装备成功",
            ["source_line"] = 113,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
          },
          ["text"] = "槽位<验证槽位>的皮肤已装备成功",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 114,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 115,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 116,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["产品ID"] = "5001",
          ["槽位"] = "1",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["产品ID"] = 132,
          ["槽位"] = 132,
          ["角色ID"] = 132,
        },
        ["source_line"] = 123,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "穿上未解锁的皮肤失败",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 124,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
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
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 126,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤尚未解锁",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>对应皮肤产品ID为<产品ID>",
            ["source_line"] = 127,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "产品ID",
          },
          ["text"] = "槽位<槽位>对应皮肤产品ID为<产品ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 128,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤未成功装备",
            ["source_line"] = 129,
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
          ["总页数"] = "1",
          ["槽位"] = "5",
          ["槽位数"] = "3",
          ["皮肤数"] = "3",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 146,
          ["槽位"] = 146,
          ["槽位数"] = 146,
          ["皮肤数"] = 146,
          ["角色ID"] = 146,
        },
        ["source_line"] = 135,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "装备越界槽位不生效",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 136,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 137,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 138,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>在皮肤卡牌可见槽位范围内",
            ["source_line"] = 139,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>在皮肤卡牌可见槽位范围内",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 140,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤未成功装备",
            ["source_line"] = 141,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤未成功装备",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 142,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 143,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["槽位"] = "1",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
          ["页码"] = "2",
          ["验证槽位"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 163,
          ["槽位"] = 163,
          ["皮肤数"] = 163,
          ["角色ID"] = 163,
          ["页码"] = 163,
          ["验证槽位"] = 163,
        },
        ["source_line"] = 149,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻页后装备第二页的皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 150,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 151,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
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
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 153,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 154,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 155,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已装备成功",
            ["source_line"] = 156,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已装备成功",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<验证槽位>的皮肤已装备成功",
            ["source_line"] = 157,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
          },
          ["text"] = "槽位<验证槽位>的皮肤已装备成功",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 158,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 159,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前皮肤页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 160,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "1",
          ["皮肤数"] = "5",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 179,
          ["槽位"] = 179,
          ["皮肤数"] = 179,
          ["角色ID"] = 179,
        },
        ["source_line"] = 166,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "脱下已装备皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 167,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 168,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 169,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 170,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 171,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 172,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家脱下当前皮肤",
            ["source_line"] = 173,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家脱下当前皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "无皮肤装备中",
            ["source_line"] = 174,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "无皮肤装备中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已开启",
            ["source_line"] = 175,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已开启",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 176,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "1",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
        {
          ["总页数"] = "1",
          ["槽位"] = "3",
          ["皮肤数"] = "6",
          ["角色ID"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 199,
          ["槽位"] = 199,
          ["皮肤数"] = 199,
          ["角色ID"] = 199,
        },
        ["source_line"] = 184,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "脱下当前皮肤触发还原回调，参数为角色",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 185,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 186,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 187,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 188,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 189,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 190,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "脱下回调已注册",
            ["source_line"] = 191,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "脱下回调已注册",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家脱下当前皮肤",
            ["source_line"] = 192,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家脱下当前皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "脱下回调收到的角色ID为<角色ID>",
            ["source_line"] = 193,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "脱下回调收到的角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "无皮肤装备中",
            ["source_line"] = 194,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "无皮肤装备中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已开启",
            ["source_line"] = 195,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已开启",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 196,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["槽位数"] = "6",
          ["皮肤数"] = "12",
          ["页码"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 214,
          ["槽位数"] = 214,
          ["皮肤数"] = 214,
          ["页码"] = 214,
        },
        ["source_line"] = 205,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻到下一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 206,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 207,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 208,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 209,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前皮肤页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 210,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 211,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["槽位数"] = "6",
          ["皮肤数"] = "12",
          ["页码"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 227,
          ["槽位数"] = 227,
          ["皮肤数"] = 227,
          ["页码"] = 227,
        },
        ["source_line"] = 217,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻到上一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 218,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 219,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 220,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤上一页",
            ["source_line"] = 221,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 222,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前皮肤页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 223,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 224,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["槽位数"] = "2",
          ["皮肤数"] = "8",
          ["页码"] = "2",
        },
        {
          ["总页数"] = "2",
          ["槽位数"] = "6",
          ["皮肤数"] = "12",
          ["页码"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 239,
          ["槽位数"] = 239,
          ["皮肤数"] = 239,
          ["页码"] = 239,
        },
        ["source_line"] = 230,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "最后一页展示剩余皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 231,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 232,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 233,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 234,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前皮肤页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 235,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 236,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["页码"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 253,
          ["槽位数"] = 253,
          ["皮肤数"] = 253,
          ["页码"] = 253,
        },
        ["source_line"] = 243,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "下一页翻页不超出最大页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 244,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 245,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 246,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 247,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 248,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前皮肤页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 249,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 250,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "1",
          ["槽位数"] = "6",
          ["皮肤数"] = "7",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 266,
          ["末页槽位数"] = 266,
          ["槽位数"] = 266,
          ["皮肤数"] = 266,
        },
        ["source_line"] = 256,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "上一页翻页不低于第1页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 257,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 258,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤上一页",
            ["source_line"] = 259,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为1",
            ["source_line"] = 260,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前皮肤页码为1",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 261,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤目录末页展示<末页槽位数>个皮肤槽位",
            ["source_line"] = 262,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "末页槽位数",
          },
          ["text"] = "皮肤目录末页展示<末页槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 263,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["卡片渲染数"] = "6",
          ["容器数"] = "6",
          ["总页数"] = "1",
          ["末页槽位数"] = "6",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证角色ID"] = "1",
        },
        {
          ["卡片渲染数"] = "3",
          ["容器数"] = "3",
          ["总页数"] = "1",
          ["末页槽位数"] = "3",
          ["槽位数"] = "3",
          ["皮肤数"] = "3",
          ["角色ID"] = "1",
          ["验证角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["卡片渲染数"] = 284,
          ["容器数"] = 284,
          ["总页数"] = 284,
          ["末页槽位数"] = 284,
          ["槽位数"] = 284,
          ["皮肤数"] = 284,
          ["角色ID"] = 284,
          ["验证角色ID"] = 284,
        },
        ["source_line"] = 271,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开皮肤商店应渲染当前页全部卡片",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 272,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 273,
            ["source_path"] = "features/v102/skin_shop.feature",
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
            ["source_line"] = 274,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "当前角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 275,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 276,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "卡片渲染数",
          },
          ["text"] = "皮肤卡片渲染数为<卡片渲染数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位容器展示数为<容器数>个",
            ["source_line"] = 277,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "容器数",
          },
          ["text"] = "皮肤卡牌槽位容器展示数为<容器数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店打开角色ID为<验证角色ID>",
            ["source_line"] = 278,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "皮肤商店打开角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 279,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤目录末页展示<末页槽位数>个皮肤槽位",
            ["source_line"] = 280,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "末页槽位数",
          },
          ["text"] = "皮肤目录末页展示<末页槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 281,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["卡片渲染数"] = "6",
          ["容器数"] = "6",
          ["总页数"] = "2",
          ["槽位数"] = "6",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
          ["页码"] = "2",
        },
        {
          ["卡片渲染数"] = "2",
          ["容器数"] = "2",
          ["总页数"] = "2",
          ["槽位数"] = "2",
          ["皮肤数"] = "8",
          ["角色ID"] = "1",
          ["页码"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["卡片渲染数"] = 300,
          ["容器数"] = 300,
          ["总页数"] = 300,
          ["槽位数"] = 300,
          ["皮肤数"] = 300,
          ["角色ID"] = 300,
          ["页码"] = 300,
        },
        ["source_line"] = 288,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻页后渲染新页全部卡片",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 289,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 290,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 291,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 292,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 293,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "卡片渲染数",
          },
          ["text"] = "皮肤卡片渲染数为<卡片渲染数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位容器展示数为<容器数>个",
            ["source_line"] = 294,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "容器数",
          },
          ["text"] = "皮肤卡牌槽位容器展示数为<容器数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 295,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 296,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前皮肤页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 297,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["末页槽位数"] = "6",
          ["槽位"] = "1",
          ["皮肤ID"] = "skin_1",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证角色ID"] = "1",
        },
        {
          ["总页数"] = "1",
          ["末页槽位数"] = "6",
          ["槽位"] = "6",
          ["皮肤ID"] = "skin_6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证角色ID"] = "1",
        },
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "6",
          ["槽位"] = "1",
          ["皮肤ID"] = "skin_1",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
          ["验证角色ID"] = "1",
        },
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "6",
          ["槽位"] = "3",
          ["皮肤ID"] = "skin_3",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
          ["验证角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 316,
          ["末页槽位数"] = 316,
          ["槽位"] = 316,
          ["皮肤ID"] = 316,
          ["皮肤数"] = 316,
          ["角色ID"] = 316,
          ["验证角色ID"] = 316,
        },
        ["source_line"] = 306,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开皮肤商店后卡牌槽位贴对应皮肤的图",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 307,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 308,
            ["source_path"] = "features/v102/skin_shop.feature",
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
            ["source_line"] = 309,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "当前角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 310,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>当前贴图为皮肤<皮肤ID>的图",
            ["source_line"] = 311,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "皮肤ID",
          },
          ["text"] = "皮肤卡牌槽位<槽位>当前贴图为皮肤<皮肤ID>的图",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤目录末页展示<末页槽位数>个皮肤槽位",
            ["source_line"] = 312,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "末页槽位数",
          },
          ["text"] = "皮肤目录末页展示<末页槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 313,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["卡片渲染数"] = "6",
          ["总页数"] = "2",
          ["槽位"] = "1",
          ["皮肤ID"] = "skin_7",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
          ["页码"] = "2",
          ["验证角色ID"] = "1",
        },
        {
          ["卡片渲染数"] = "6",
          ["总页数"] = "2",
          ["槽位"] = "6",
          ["皮肤ID"] = "skin_12",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
          ["页码"] = "2",
          ["验证角色ID"] = "1",
        },
        {
          ["卡片渲染数"] = "2",
          ["总页数"] = "2",
          ["槽位"] = "1",
          ["皮肤ID"] = "skin_7",
          ["皮肤数"] = "8",
          ["角色ID"] = "1",
          ["页码"] = "2",
          ["验证角色ID"] = "1",
        },
        {
          ["卡片渲染数"] = "2",
          ["总页数"] = "2",
          ["槽位"] = "2",
          ["皮肤ID"] = "skin_8",
          ["皮肤数"] = "8",
          ["角色ID"] = "1",
          ["页码"] = "2",
          ["验证角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["卡片渲染数"] = 335,
          ["总页数"] = 335,
          ["槽位"] = 335,
          ["皮肤ID"] = 335,
          ["皮肤数"] = 335,
          ["角色ID"] = 335,
          ["页码"] = 335,
          ["验证角色ID"] = 335,
        },
        ["source_line"] = 322,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻到下一页后卡牌槽位贴图刷新为新页皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 323,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 324,
            ["source_path"] = "features/v102/skin_shop.feature",
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
            ["source_line"] = 325,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "当前角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 326,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 327,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>当前贴图为皮肤<皮肤ID>的图",
            ["source_line"] = 328,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "皮肤ID",
          },
          ["text"] = "皮肤卡牌槽位<槽位>当前贴图为皮肤<皮肤ID>的图",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店打开角色ID为<验证角色ID>",
            ["source_line"] = 329,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "皮肤商店打开角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 330,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "卡片渲染数",
          },
          ["text"] = "皮肤卡片渲染数为<卡片渲染数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 331,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前皮肤页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 332,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "6",
          ["槽位"] = "1",
          ["皮肤ID"] = "skin_1",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
          ["页码"] = "1",
        },
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "6",
          ["槽位"] = "6",
          ["皮肤ID"] = "skin_6",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
          ["页码"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 353,
          ["末页槽位数"] = 353,
          ["槽位"] = 353,
          ["皮肤ID"] = 353,
          ["皮肤数"] = 353,
          ["角色ID"] = 353,
          ["页码"] = 353,
        },
        ["source_line"] = 341,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻回上一页后卡牌槽位贴图恢复为前页皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 342,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 343,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 344,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 345,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤上一页",
            ["source_line"] = 346,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>当前贴图为皮肤<皮肤ID>的图",
            ["source_line"] = 347,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "皮肤ID",
          },
          ["text"] = "皮肤卡牌槽位<槽位>当前贴图为皮肤<皮肤ID>的图",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 348,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "页码",
          },
          ["text"] = "当前皮肤页码为<页码>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤目录末页展示<末页槽位数>个皮肤槽位",
            ["source_line"] = 349,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "末页槽位数",
          },
          ["text"] = "皮肤目录末页展示<末页槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 350,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["容器数"] = "6",
          ["总页数"] = "1",
          ["槽位"] = "1",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "1",
        },
        {
          ["容器数"] = "6",
          ["总页数"] = "1",
          ["槽位"] = "3",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "3",
        },
        {
          ["容器数"] = "6",
          ["总页数"] = "1",
          ["槽位"] = "6",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "6",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["容器数"] = 371,
          ["总页数"] = 371,
          ["槽位"] = 371,
          ["槽位数"] = 371,
          ["皮肤数"] = 371,
          ["角色ID"] = 371,
          ["验证槽位"] = 371,
        },
        ["source_line"] = 359,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "装备完成后槽位容器仍保持展示",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 360,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 361,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 362,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 363,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 364,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位容器展示数为<容器数>个",
            ["source_line"] = 365,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "容器数",
          },
          ["text"] = "皮肤卡牌槽位容器展示数为<容器数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<验证槽位>的皮肤已装备成功",
            ["source_line"] = 366,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
          },
          ["text"] = "槽位<验证槽位>的皮肤已装备成功",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 367,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 368,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["产品ID"] = "skin_1",
          ["容器数"] = "6",
          ["总页数"] = "1",
          ["新槽位"] = "2",
          ["槽位"] = "1",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "2",
        },
        {
          ["产品ID"] = "skin_3",
          ["容器数"] = "6",
          ["总页数"] = "1",
          ["新槽位"] = "5",
          ["槽位"] = "3",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["产品ID"] = 392,
          ["容器数"] = 392,
          ["总页数"] = 392,
          ["新槽位"] = 392,
          ["槽位"] = 392,
          ["皮肤数"] = 392,
          ["角色ID"] = 392,
          ["验证槽位"] = 392,
        },
        ["source_line"] = 376,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "切换装备后槽位容器仍保持展示",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 377,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 378,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 379,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>对应皮肤产品ID为<产品ID>",
            ["source_line"] = 380,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "产品ID",
          },
          ["text"] = "槽位<槽位>对应皮肤产品ID为<产品ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 381,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<新槽位>的皮肤已归玩家持有",
            ["source_line"] = 382,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "新槽位",
          },
          ["text"] = "槽位<新槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 383,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 384,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<新槽位>的皮肤",
            ["source_line"] = 385,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "新槽位",
          },
          ["text"] = "玩家穿上槽位<新槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位容器展示数为<容器数>个",
            ["source_line"] = 386,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "容器数",
          },
          ["text"] = "皮肤卡牌槽位容器展示数为<容器数>个",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<验证槽位>的皮肤已装备成功",
            ["source_line"] = 387,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
          },
          ["text"] = "槽位<验证槽位>的皮肤已装备成功",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 388,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 389,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["按钮文本"] = "100",
          ["槽位"] = "1",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "1",
        },
        {
          ["总页数"] = "1",
          ["按钮文本"] = "100",
          ["槽位"] = "6",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "6",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 412,
          ["按钮文本"] = 412,
          ["槽位"] = 412,
          ["槽位数"] = 412,
          ["皮肤数"] = 412,
          ["角色ID"] = 412,
          ["验证槽位"] = 412,
        },
        ["source_line"] = 398,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "未解锁的购买类槽位按钮显示价格并可点",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 399,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 400,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位3的皮肤改为赠礼解锁并设赠礼名为\"占位赠礼\"",
            ["source_line"] = 401,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "槽位3的皮肤改为赠礼解锁并设赠礼名为\"占位赠礼\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位4的皮肤改为赠礼解锁并设赠礼名为\"占位赠礼\"",
            ["source_line"] = 402,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "槽位4的皮肤改为赠礼解锁并设赠礼名为\"占位赠礼\"",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 403,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 404,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮可点",
            ["source_line"] = 405,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮可点",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<验证槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 406,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<验证槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<验证槽位>按钮可点",
            ["source_line"] = 407,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
          },
          ["text"] = "皮肤卡牌槽位<验证槽位>按钮可点",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 408,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 409,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["按钮文本"] = "谢礼",
          ["槽位"] = "5",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["赠礼名"] = "谢礼",
          ["验证槽位"] = "5",
        },
        {
          ["总页数"] = "1",
          ["按钮文本"] = "神秘礼",
          ["槽位"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["赠礼名"] = "神秘礼",
          ["验证槽位"] = "6",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 430,
          ["按钮文本"] = 430,
          ["槽位"] = 430,
          ["皮肤数"] = 430,
          ["角色ID"] = 430,
          ["赠礼名"] = 430,
          ["验证槽位"] = 430,
        },
        ["source_line"] = 416,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "未解锁的赠礼类槽位按钮显示赠礼名并不可点",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 417,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 418,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤改为赠礼解锁并设赠礼名为\"<赠礼名>\"",
            ["source_line"] = 419,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "赠礼名",
          },
          ["text"] = "槽位<槽位>的皮肤改为赠礼解锁并设赠礼名为\"<赠礼名>\"",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 420,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<赠礼名>\"",
            ["source_line"] = 421,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "赠礼名",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<赠礼名>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 422,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮不可点",
            ["source_line"] = 423,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮不可点",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<验证槽位>按钮文本为\"<赠礼名>\"",
            ["source_line"] = 424,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
            "赠礼名",
          },
          ["text"] = "皮肤卡牌槽位<验证槽位>按钮文本为\"<赠礼名>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<验证槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 425,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<验证槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<验证槽位>按钮不可点",
            ["source_line"] = 426,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
          },
          ["text"] = "皮肤卡牌槽位<验证槽位>按钮不可点",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 427,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["按钮文本"] = "脱下",
          ["槽位"] = "1",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "1",
        },
        {
          ["总页数"] = "1",
          ["按钮文本"] = "脱下",
          ["槽位"] = "3",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 449,
          ["按钮文本"] = 449,
          ["槽位"] = 449,
          ["槽位数"] = 449,
          ["皮肤数"] = 449,
          ["角色ID"] = 449,
          ["验证槽位"] = 449,
        },
        ["source_line"] = 434,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "装备完成后槽位按钮显示脱下并可点",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 435,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 436,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 437,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 438,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 439,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 440,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮可点",
            ["source_line"] = 441,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮可点",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<验证槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 442,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<验证槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<验证槽位>按钮可点",
            ["source_line"] = 443,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
          },
          ["text"] = "皮肤卡牌槽位<验证槽位>按钮可点",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 444,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 445,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 446,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["按钮文本"] = "穿上",
          ["槽位"] = "1",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "1",
        },
        {
          ["总页数"] = "1",
          ["按钮文本"] = "穿上",
          ["槽位"] = "3",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 468,
          ["按钮文本"] = 468,
          ["槽位"] = 468,
          ["槽位数"] = 468,
          ["皮肤数"] = 468,
          ["角色ID"] = 468,
          ["验证槽位"] = 468,
        },
        ["source_line"] = 453,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "脱下装备后槽位按钮恢复为穿上并可点",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 454,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 455,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 456,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 457,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 458,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 459,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家脱下当前皮肤",
            ["source_line"] = 460,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家脱下当前皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 461,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮可点",
            ["source_line"] = 462,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮可点",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<验证槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 463,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<验证槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 464,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 465,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["按钮文本"] = "谢礼",
          ["槽位"] = "5",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["购买槽位"] = "1",
          ["赠礼名"] = "谢礼",
        },
        {
          ["总页数"] = "1",
          ["按钮文本"] = "神秘礼",
          ["槽位"] = "6",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["购买槽位"] = "2",
          ["赠礼名"] = "神秘礼",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 486,
          ["按钮文本"] = 486,
          ["槽位"] = 486,
          ["槽位数"] = 486,
          ["皮肤数"] = 486,
          ["角色ID"] = 486,
          ["购买槽位"] = 486,
          ["赠礼名"] = 486,
        },
        ["source_line"] = 474,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买类槽位显示价格图标，赠礼类槽位隐藏价格图标",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 475,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 476,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤改为赠礼解锁并清空价格设赠礼名为\"<赠礼名>\"",
            ["source_line"] = 477,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "赠礼名",
          },
          ["text"] = "槽位<槽位>的皮肤改为赠礼解锁并清空价格设赠礼名为\"<赠礼名>\"",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 478,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<购买槽位>价格图标已展示",
            ["source_line"] = 479,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "购买槽位",
          },
          ["text"] = "皮肤卡牌槽位<购买槽位>价格图标已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
            ["source_line"] = 480,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 481,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 482,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 483,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["按钮文本"] = "穿上",
          ["槽位"] = "1",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["购买槽位"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 505,
          ["按钮文本"] = 505,
          ["槽位"] = 505,
          ["槽位数"] = 505,
          ["皮肤数"] = 505,
          ["角色ID"] = 505,
          ["购买槽位"] = 505,
        },
        ["source_line"] = 492,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "持有未装备的购买类皮肤价格图标隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 493,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 494,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 495,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 496,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 497,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
            ["source_line"] = 498,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 499,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<购买槽位>价格图标已展示",
            ["source_line"] = 500,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "购买槽位",
          },
          ["text"] = "皮肤卡牌槽位<购买槽位>价格图标已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 501,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 502,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["按钮文本"] = "脱下",
          ["槽位"] = "1",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["购买槽位"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 522,
          ["按钮文本"] = 522,
          ["槽位"] = 522,
          ["槽位数"] = 522,
          ["皮肤数"] = 522,
          ["角色ID"] = 522,
          ["购买槽位"] = 522,
        },
        ["source_line"] = 508,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "已装备的购买类皮肤价格图标隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 509,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 510,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 511,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 512,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 513,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 514,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
            ["source_line"] = 515,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 516,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<购买槽位>价格图标已展示",
            ["source_line"] = 517,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "购买槽位",
          },
          ["text"] = "皮肤卡牌槽位<购买槽位>价格图标已展示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 518,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 519,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["按钮文本"] = "加更",
          ["槽位"] = "3",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["赠礼名"] = "加更",
          ["验证槽位"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 538,
          ["按钮文本"] = 538,
          ["槽位"] = 538,
          ["皮肤数"] = 538,
          ["角色ID"] = 538,
          ["赠礼名"] = 538,
          ["验证槽位"] = 538,
        },
        ["source_line"] = 527,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "赠礼解锁但保留价格的槽位价格图标仍隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 528,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 529,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤改为赠礼解锁但保留价格设赠礼名为\"<赠礼名>\"",
            ["source_line"] = 530,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "赠礼名",
          },
          ["text"] = "槽位<槽位>的皮肤改为赠礼解锁但保留价格设赠礼名为\"<赠礼名>\"",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 531,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
            ["source_line"] = 532,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<验证槽位>价格图标已隐藏",
            ["source_line"] = 533,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
          },
          ["text"] = "皮肤卡牌槽位<验证槽位>价格图标已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 534,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 535,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["产品ID"] = "skin_4",
          ["总页数"] = "1",
          ["槽位"] = "4",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["产品ID"] = 551,
          ["总页数"] = 551,
          ["槽位"] = 551,
          ["皮肤数"] = 551,
          ["角色ID"] = 551,
        },
        ["source_line"] = 541,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买类槽位但价格字段缺失时价格图标隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 542,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 543,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤保持购买解锁但清空价格字段",
            ["source_line"] = 544,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤保持购买解锁但清空价格字段",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 545,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>对应皮肤产品ID为<产品ID>",
            ["source_line"] = 546,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "产品ID",
          },
          ["text"] = "槽位<槽位>对应皮肤产品ID为<产品ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
            ["source_line"] = 547,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 548,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "5",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 564,
          ["槽位"] = 564,
          ["皮肤数"] = 564,
          ["角色ID"] = 564,
          ["验证槽位"] = 564,
        },
        ["source_line"] = 554,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买类槽位但货币字段缺失时价格图标隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 555,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 556,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤保持购买解锁但清空货币字段",
            ["source_line"] = 557,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤保持购买解锁但清空货币字段",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 558,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
            ["source_line"] = 559,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<验证槽位>价格图标已隐藏",
            ["source_line"] = 560,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证槽位",
          },
          ["text"] = "皮肤卡牌槽位<验证槽位>价格图标已隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 561,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["产品ID"] = "skin_1",
          ["总页数"] = "1",
          ["槽位"] = "1",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
        {
          ["产品ID"] = "skin_3",
          ["总页数"] = "1",
          ["槽位"] = "3",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["产品ID"] = 582,
          ["总页数"] = 582,
          ["槽位"] = 582,
          ["槽位数"] = 582,
          ["皮肤数"] = 582,
          ["角色ID"] = 582,
        },
        ["source_line"] = 569,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "装备未解锁的购买类皮肤触发购买回调，参数为角色与皮肤产品",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 570,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 571,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 572,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 573,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤尚未解锁",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "购买回调已注册",
            ["source_line"] = 574,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "购买回调已注册",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 575,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "购买回调收到的角色ID为<角色ID>",
            ["source_line"] = 576,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "购买回调收到的角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "购买回调收到的皮肤产品ID为<产品ID>",
            ["source_line"] = 577,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "产品ID",
          },
          ["text"] = "购买回调收到的皮肤产品ID为<产品ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 578,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位数",
          },
          ["text"] = "当前页面展示<槽位数>个皮肤槽位",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 579,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "1",
          ["槽位"] = "1",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
        {
          ["总页数"] = "1",
          ["槽位"] = "5",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 599,
          ["槽位"] = 599,
          ["皮肤数"] = 599,
          ["角色ID"] = 599,
        },
        ["source_line"] = 586,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买回调成功后槽位解锁并自动装备",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 587,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 588,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 589,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 590,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤尚未解锁",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "购买回调注册为成功回调",
            ["source_line"] = 591,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "购买回调注册为成功回调",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 592,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 593,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已装备成功",
            ["source_line"] = 594,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已装备成功",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 595,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 596,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["产品ID"] = "skin_1",
          ["总页数"] = "1",
          ["槽位"] = "1",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
        {
          ["产品ID"] = "skin_4",
          ["总页数"] = "1",
          ["槽位"] = "4",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["产品ID"] = 615,
          ["总页数"] = 615,
          ["槽位"] = 615,
          ["皮肤数"] = 615,
          ["角色ID"] = 615,
        },
        ["source_line"] = 603,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "未注册购买回调时装备未解锁皮肤失败且不改变面板",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 604,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 605,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 606,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 607,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤尚未解锁",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>对应皮肤产品ID为<产品ID>",
            ["source_line"] = 608,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
            "产品ID",
          },
          ["text"] = "槽位<槽位>对应皮肤产品ID为<产品ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 609,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 610,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤尚未解锁",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤未成功装备",
            ["source_line"] = 611,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤未成功装备",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 612,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["总页数"] = "2",
          ["槽位"] = "1",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
          ["验证角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 635,
          ["槽位"] = 635,
          ["皮肤数"] = 635,
          ["角色ID"] = 635,
          ["验证角色ID"] = 635,
        },
        ["source_line"] = 621,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开/翻页/购买/装备/关闭都不改写皮肤静态文本",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 622,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 623,
            ["source_path"] = "features/v102/skin_shop.feature",
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
            ["source_line"] = 624,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "当前角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 625,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 626,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>在皮肤卡牌可见槽位范围内",
            ["source_line"] = 627,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>在皮肤卡牌可见槽位范围内",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家购买槽位<槽位>的皮肤",
            ["source_line"] = 628,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家购买槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 629,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家穿上槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家关闭皮肤商店",
            ["source_line"] = 630,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤静态文本未被改写",
            ["source_line"] = 631,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤静态文本未被改写",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 632,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
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
