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
        ["source_line"] = 486,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["产品ID"] = 992,
      ["卡片渲染数"] = 733,
      ["容器数"] = 734,
      ["总页数"] = 545,
      ["按钮文本"] = 858,
      ["新槽位"] = 836,
      ["旧槽位"] = 835,
      ["末页槽位数"] = 737,
      ["槽位"] = 558,
      ["槽位数"] = 544,
      ["皮肤ID"] = 767,
      ["皮肤数"] = 542,
      ["角色ID"] = 496,
      ["购买槽位"] = 930,
      ["赠礼名"] = 873,
      ["面板"] = 530,
      ["页码"] = 638,
      ["验证槽位"] = 561,
      ["验证角色ID"] = 731,
    },
    ["field_names"] = {
      ["产品ID"] = "产品ID",
      ["卡片渲染数"] = "卡片渲染数",
      ["容器数"] = "容器数",
      ["总页数"] = "总页数",
      ["按钮文本"] = "按钮文本",
      ["新槽位"] = "新槽位",
      ["旧槽位"] = "旧槽位",
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
        ["source_line"] = 490,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "游戏初始化后皮肤商店默认关闭",
      ["steps"] = {
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 491,
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
          ["角色ID"] = 501,
        },
        ["source_line"] = 495,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "点击基础屏皮肤图标打开皮肤商店",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 496,
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
            ["source_line"] = 497,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "触发基础屏皮肤按钮",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已开启",
            ["source_line"] = 498,
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
          ["角色ID"] = 512,
        },
        ["source_line"] = 506,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开皮肤商店后商店开启",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 507,
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
            ["source_line"] = 508,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已开启",
            ["source_line"] = 509,
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
          ["角色ID"] = 523,
        },
        ["source_line"] = 516,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "关闭皮肤商店",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 517,
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
            ["source_line"] = 518,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家关闭皮肤商店",
            ["source_line"] = 519,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 520,
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
          ["角色ID"] = 536,
          ["面板"] = 536,
        },
        ["source_line"] = 528,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "回合外打开皮肤商店后轮到玩家行动自动关闭并提示",
      ["steps"] = {
        {
          ["keyword"] = "Given",
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
            ["original_text"] = "玩家打开<面板>",
            ["source_line"] = 530,
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
            ["source_line"] = 531,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "轮到玩家行动",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<面板>屏幕已关闭",
            ["source_line"] = 532,
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
            ["source_line"] = 533,
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
          ["总页数"] = 548,
          ["槽位数"] = 548,
          ["皮肤数"] = 548,
        },
        ["source_line"] = 541,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "皮肤商店每页展示6个槽位",
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
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 543,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 544,
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
            ["source_line"] = 545,
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
          ["总页数"] = 566,
          ["槽位"] = 566,
          ["槽位数"] = 566,
          ["皮肤数"] = 566,
          ["角色ID"] = 566,
          ["验证槽位"] = 566,
        },
        ["source_line"] = 554,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买解锁皮肤槽位",
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
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 557,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 558,
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
            ["source_line"] = 559,
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
            ["source_line"] = 560,
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
            ["source_line"] = 561,
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
            ["source_line"] = 562,
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
            ["source_line"] = 563,
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
          ["总页数"] = 581,
          ["槽位"] = 581,
          ["皮肤数"] = 581,
          ["角色ID"] = 581,
          ["验证槽位"] = 581,
        },
        ["source_line"] = 570,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "赠礼解锁皮肤槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 571,
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
            ["source_line"] = 572,
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
            ["source_line"] = 573,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 574,
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
            ["source_line"] = 575,
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
            ["source_line"] = 576,
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
            ["source_line"] = 577,
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
            ["source_line"] = 578,
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
          ["总页数"] = 599,
          ["槽位"] = 599,
          ["槽位数"] = 599,
          ["皮肤数"] = 599,
          ["角色ID"] = 599,
          ["验证槽位"] = 599,
        },
        ["source_line"] = 586,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "穿上已解锁的皮肤",
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
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 590,
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
            ["source_line"] = 591,
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
            ["source_line"] = 592,
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
            ["source_line"] = 593,
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
            ["source_line"] = 594,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 595,
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
          ["槽位"] = "1",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["槽位"] = 611,
          ["角色ID"] = 611,
        },
        ["source_line"] = 603,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "穿上未解锁的皮肤失败",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 604,
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
            ["source_line"] = 605,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 606,
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
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 607,
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
            ["source_line"] = 608,
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
          ["总页数"] = 625,
          ["槽位"] = 625,
          ["槽位数"] = 625,
          ["皮肤数"] = 625,
          ["角色ID"] = 625,
        },
        ["source_line"] = 614,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "装备越界槽位不生效",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 615,
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
            ["source_line"] = 616,
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
            ["source_line"] = 617,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>在皮肤卡牌可见槽位范围内",
            ["source_line"] = 618,
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
            ["source_line"] = 619,
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
            ["source_line"] = 620,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤未成功装备",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 621,
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
            ["source_line"] = 622,
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
          ["总页数"] = 642,
          ["槽位"] = 642,
          ["皮肤数"] = 642,
          ["角色ID"] = 642,
          ["页码"] = 642,
          ["验证槽位"] = 642,
        },
        ["source_line"] = 628,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻页后装备第二页的皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 629,
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
            ["source_line"] = 630,
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
            ["source_line"] = 631,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 632,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 633,
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
            ["source_line"] = 634,
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
            ["source_line"] = 635,
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
            ["source_line"] = 636,
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
            ["source_line"] = 637,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 638,
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
            ["source_line"] = 639,
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
          ["总页数"] = 658,
          ["槽位"] = 658,
          ["皮肤数"] = 658,
          ["角色ID"] = 658,
        },
        ["source_line"] = 645,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "脱下已装备皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 646,
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
            ["source_line"] = 647,
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
            ["source_line"] = 648,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 649,
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
            ["source_line"] = 650,
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
            ["source_line"] = 651,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家脱下当前皮肤",
            ["source_line"] = 652,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家脱下当前皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "无皮肤装备中",
            ["source_line"] = 653,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "无皮肤装备中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤商店屏幕已开启",
            ["source_line"] = 654,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已开启",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 655,
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
          ["总页数"] = 672,
          ["槽位数"] = 672,
          ["皮肤数"] = 672,
          ["页码"] = 672,
        },
        ["source_line"] = 663,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻到下一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 664,
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
            ["source_line"] = 665,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 666,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 667,
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
            ["source_line"] = 668,
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
            ["source_line"] = 669,
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
          ["总页数"] = 685,
          ["槽位数"] = 685,
          ["皮肤数"] = 685,
          ["页码"] = 685,
        },
        ["source_line"] = 675,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻到上一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 676,
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
            ["source_line"] = 677,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 678,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤上一页",
            ["source_line"] = 679,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 680,
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
            ["source_line"] = 681,
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
            ["source_line"] = 682,
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
          ["总页数"] = 697,
          ["槽位数"] = 697,
          ["皮肤数"] = 697,
          ["页码"] = 697,
        },
        ["source_line"] = 688,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "最后一页展示剩余皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 689,
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
            ["source_line"] = 690,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 691,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 692,
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
            ["source_line"] = 693,
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
            ["source_line"] = 694,
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
          ["总页数"] = 711,
          ["槽位数"] = 711,
          ["皮肤数"] = 711,
          ["页码"] = 711,
        },
        ["source_line"] = 701,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "下一页翻页不超出最大页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 702,
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
            ["source_line"] = 703,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 704,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 705,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为<页码>",
            ["source_line"] = 706,
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
            ["source_line"] = 707,
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
            ["source_line"] = 708,
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
          ["皮肤数"] = "7",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 723,
          ["槽位数"] = 723,
          ["皮肤数"] = 723,
        },
        ["source_line"] = 714,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "上一页翻页不低于第1页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 715,
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
            ["source_line"] = 716,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤上一页",
            ["source_line"] = 717,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前皮肤页码为1",
            ["source_line"] = 718,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前皮肤页码为1",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 719,
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
            ["source_line"] = 720,
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
          ["卡片渲染数"] = 741,
          ["容器数"] = 741,
          ["总页数"] = 741,
          ["末页槽位数"] = 741,
          ["槽位数"] = 741,
          ["皮肤数"] = 741,
          ["角色ID"] = 741,
          ["验证角色ID"] = 741,
        },
        ["source_line"] = 728,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开皮肤商店应渲染当前页全部卡片",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 729,
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
            ["source_line"] = 730,
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
            ["source_line"] = 731,
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
            ["source_line"] = 732,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 733,
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
            ["source_line"] = 734,
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
            ["source_line"] = 735,
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
            ["source_line"] = 736,
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
            ["source_line"] = 737,
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
            ["source_line"] = 738,
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
          ["卡片渲染数"] = 757,
          ["容器数"] = 757,
          ["总页数"] = 757,
          ["槽位数"] = 757,
          ["皮肤数"] = 757,
          ["角色ID"] = 757,
          ["页码"] = 757,
        },
        ["source_line"] = 745,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻页后渲染新页全部卡片",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 746,
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
            ["source_line"] = 747,
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
            ["source_line"] = 748,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 749,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡片渲染数为<卡片渲染数>个",
            ["source_line"] = 750,
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
            ["source_line"] = 751,
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
            ["source_line"] = 752,
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
            ["source_line"] = 753,
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
            ["source_line"] = 754,
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
        },
        {
          ["总页数"] = "1",
          ["末页槽位数"] = "6",
          ["槽位"] = "6",
          ["皮肤ID"] = "skin_6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "6",
          ["槽位"] = "1",
          ["皮肤ID"] = "skin_1",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
        },
        {
          ["总页数"] = "2",
          ["末页槽位数"] = "6",
          ["槽位"] = "3",
          ["皮肤ID"] = "skin_3",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 772,
          ["末页槽位数"] = 772,
          ["槽位"] = 772,
          ["皮肤ID"] = 772,
          ["皮肤数"] = 772,
          ["角色ID"] = 772,
        },
        ["source_line"] = 763,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开皮肤商店后卡牌槽位贴对应皮肤的图",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 764,
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
            ["source_line"] = 765,
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
            ["source_line"] = 766,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>当前贴图为皮肤<皮肤ID>的图",
            ["source_line"] = 767,
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
            ["source_line"] = 768,
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
            ["source_line"] = 769,
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
          ["卡片渲染数"] = 791,
          ["总页数"] = 791,
          ["槽位"] = 791,
          ["皮肤ID"] = 791,
          ["皮肤数"] = 791,
          ["角色ID"] = 791,
          ["页码"] = 791,
          ["验证角色ID"] = 791,
        },
        ["source_line"] = 778,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻到下一页后卡牌槽位贴图刷新为新页皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 779,
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
            ["source_line"] = 780,
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
            ["source_line"] = 781,
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
            ["source_line"] = 782,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 783,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>当前贴图为皮肤<皮肤ID>的图",
            ["source_line"] = 784,
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
            ["source_line"] = 785,
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
            ["source_line"] = 786,
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
            ["source_line"] = 787,
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
            ["source_line"] = 788,
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
          ["皮肤ID"] = "skin_1",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
          ["页码"] = "1",
        },
        {
          ["总页数"] = "2",
          ["槽位"] = "6",
          ["皮肤ID"] = "skin_6",
          ["皮肤数"] = "12",
          ["角色ID"] = "1",
          ["页码"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 808,
          ["槽位"] = 808,
          ["皮肤ID"] = 808,
          ["皮肤数"] = 808,
          ["角色ID"] = 808,
          ["页码"] = 808,
        },
        ["source_line"] = 797,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "翻回上一页后卡牌槽位贴图恢复为前页皮肤",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 798,
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
            ["source_line"] = 799,
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
            ["source_line"] = 800,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 801,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤上一页",
            ["source_line"] = 802,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤上一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>当前贴图为皮肤<皮肤ID>的图",
            ["source_line"] = 803,
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
            ["source_line"] = 804,
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
            ["source_line"] = 805,
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
          ["容器数"] = 826,
          ["总页数"] = 826,
          ["槽位"] = 826,
          ["槽位数"] = 826,
          ["皮肤数"] = 826,
          ["角色ID"] = 826,
          ["验证槽位"] = 826,
        },
        ["source_line"] = 814,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "装备完成后槽位容器仍保持展示",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 815,
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
            ["source_line"] = 816,
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
            ["source_line"] = 817,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 818,
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
            ["source_line"] = 819,
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
            ["source_line"] = 820,
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
            ["source_line"] = 821,
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
            ["source_line"] = 822,
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
            ["source_line"] = 823,
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
          ["新槽位"] = "2",
          ["旧槽位"] = "1",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "2",
        },
        {
          ["容器数"] = "6",
          ["总页数"] = "1",
          ["新槽位"] = "5",
          ["旧槽位"] = "3",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["容器数"] = 846,
          ["总页数"] = 846,
          ["新槽位"] = 846,
          ["旧槽位"] = 846,
          ["皮肤数"] = 846,
          ["角色ID"] = 846,
          ["验证槽位"] = 846,
        },
        ["source_line"] = 831,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "切换装备后槽位容器仍保持展示",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 832,
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
            ["source_line"] = 833,
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
            ["source_line"] = 834,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<旧槽位>的皮肤已归玩家持有",
            ["source_line"] = 835,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "旧槽位",
          },
          ["text"] = "槽位<旧槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<新槽位>的皮肤已归玩家持有",
            ["source_line"] = 836,
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
            ["original_text"] = "玩家穿上槽位<旧槽位>的皮肤",
            ["source_line"] = 837,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {
            "旧槽位",
          },
          ["text"] = "玩家穿上槽位<旧槽位>的皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 838,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<新槽位>的皮肤",
            ["source_line"] = 839,
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
            ["source_line"] = 840,
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
            ["source_line"] = 841,
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
            ["source_line"] = 842,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 843,
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
          ["总页数"] = 866,
          ["按钮文本"] = 866,
          ["槽位"] = 866,
          ["槽位数"] = 866,
          ["皮肤数"] = 866,
          ["角色ID"] = 866,
          ["验证槽位"] = 866,
        },
        ["source_line"] = 852,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "未解锁的购买类槽位按钮显示价格并可点",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 853,
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
            ["source_line"] = 854,
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
            ["source_line"] = 855,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "槽位3的皮肤改为赠礼解锁并设赠礼名为\"占位赠礼\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位4的皮肤改为赠礼解锁并设赠礼名为\"占位赠礼\"",
            ["source_line"] = 856,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "槽位4的皮肤改为赠礼解锁并设赠礼名为\"占位赠礼\"",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 857,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 858,
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
            ["source_line"] = 859,
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
            ["source_line"] = 860,
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
            ["source_line"] = 861,
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
            ["source_line"] = 862,
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
            ["source_line"] = 863,
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
          ["总页数"] = 884,
          ["按钮文本"] = 884,
          ["槽位"] = 884,
          ["皮肤数"] = 884,
          ["角色ID"] = 884,
          ["赠礼名"] = 884,
          ["验证槽位"] = 884,
        },
        ["source_line"] = 870,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "未解锁的赠礼类槽位按钮显示赠礼名并不可点",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 871,
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
            ["source_line"] = 872,
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
            ["source_line"] = 873,
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
            ["source_line"] = 874,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<赠礼名>\"",
            ["source_line"] = 875,
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
            ["source_line"] = 876,
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
            ["source_line"] = 877,
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
            ["source_line"] = 878,
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
            ["source_line"] = 879,
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
            ["source_line"] = 880,
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
            ["source_line"] = 881,
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
        },
        {
          ["总页数"] = "1",
          ["按钮文本"] = "脱下",
          ["槽位"] = "3",
          ["槽位数"] = "6",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 901,
          ["按钮文本"] = 901,
          ["槽位"] = 901,
          ["槽位数"] = 901,
          ["皮肤数"] = 901,
          ["角色ID"] = 901,
        },
        ["source_line"] = 888,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "装备完成后槽位按钮显示脱下并可点",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 889,
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
            ["source_line"] = 890,
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
            ["source_line"] = 891,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 892,
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
            ["source_line"] = 893,
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
            ["source_line"] = 894,
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
            ["source_line"] = 895,
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
            ["original_text"] = "皮肤商店屏幕已关闭",
            ["source_line"] = 896,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个皮肤槽位",
            ["source_line"] = 897,
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
            ["source_line"] = 898,
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
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "1",
        },
        {
          ["总页数"] = "1",
          ["按钮文本"] = "穿上",
          ["槽位"] = "3",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
          ["验证槽位"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 919,
          ["按钮文本"] = 919,
          ["槽位"] = 919,
          ["皮肤数"] = 919,
          ["角色ID"] = 919,
          ["验证槽位"] = 919,
        },
        ["source_line"] = 905,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "脱下装备后槽位按钮恢复为穿上并可点",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 906,
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
            ["source_line"] = 907,
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
            ["source_line"] = 908,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 909,
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
            ["source_line"] = 910,
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
            ["source_line"] = 911,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家脱下当前皮肤",
            ["source_line"] = 912,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家脱下当前皮肤",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 913,
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
            ["source_line"] = 914,
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
            ["source_line"] = 915,
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
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 916,
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
          ["总页数"] = 937,
          ["按钮文本"] = 937,
          ["槽位"] = 937,
          ["槽位数"] = 937,
          ["皮肤数"] = 937,
          ["角色ID"] = 937,
          ["购买槽位"] = 937,
          ["赠礼名"] = 937,
        },
        ["source_line"] = 925,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买类槽位显示价格图标，赠礼类槽位隐藏价格图标",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 926,
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
            ["source_line"] = 927,
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
            ["source_line"] = 928,
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
            ["source_line"] = 929,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<购买槽位>价格图标已展示",
            ["source_line"] = 930,
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
            ["source_line"] = 931,
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
            ["source_line"] = 932,
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
            ["source_line"] = 933,
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
            ["source_line"] = 934,
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
          ["总页数"] = 954,
          ["按钮文本"] = 954,
          ["槽位"] = 954,
          ["皮肤数"] = 954,
          ["角色ID"] = 954,
          ["赠礼名"] = 954,
          ["验证槽位"] = 954,
        },
        ["source_line"] = 943,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "赠礼解锁但保留价格的槽位价格图标仍隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 944,
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
            ["source_line"] = 945,
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
            ["source_line"] = 946,
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
            ["source_line"] = 947,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
            ["source_line"] = 948,
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
            ["source_line"] = 949,
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
            ["source_line"] = 950,
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
            ["source_line"] = 951,
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
          ["槽位"] = "4",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 966,
          ["槽位"] = 966,
          ["皮肤数"] = 966,
          ["角色ID"] = 966,
        },
        ["source_line"] = 957,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买类槽位但价格字段缺失时价格图标隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 958,
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
            ["source_line"] = 959,
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
            ["source_line"] = 960,
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
            ["source_line"] = 961,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
            ["source_line"] = 962,
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
            ["source_line"] = 963,
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
          ["总页数"] = 979,
          ["槽位"] = 979,
          ["皮肤数"] = 979,
          ["角色ID"] = 979,
          ["验证槽位"] = 979,
        },
        ["source_line"] = 969,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买类槽位但货币字段缺失时价格图标隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 970,
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
            ["source_line"] = 971,
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
            ["source_line"] = 972,
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
            ["source_line"] = 973,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>价格图标已隐藏",
            ["source_line"] = 974,
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
            ["source_line"] = 975,
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
            ["source_line"] = 976,
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
          ["产品ID"] = "skin_3",
          ["总页数"] = "1",
          ["槽位"] = "3",
          ["皮肤数"] = "6",
          ["角色ID"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["产品ID"] = 996,
          ["总页数"] = 996,
          ["槽位"] = 996,
          ["皮肤数"] = 996,
          ["角色ID"] = 996,
        },
        ["source_line"] = 984,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "装备未解锁的购买类皮肤触发购买回调，参数为角色与皮肤产品",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 985,
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
            ["source_line"] = 986,
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
            ["source_line"] = 987,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 988,
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
            ["source_line"] = 989,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "购买回调已注册",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 990,
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
            ["source_line"] = 991,
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
            ["source_line"] = 992,
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
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 993,
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
          ["总页数"] = 1013,
          ["槽位"] = 1013,
          ["皮肤数"] = 1013,
          ["角色ID"] = 1013,
        },
        ["source_line"] = 1000,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "购买回调成功后槽位解锁并自动装备",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 1001,
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
            ["source_line"] = 1002,
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
            ["source_line"] = 1003,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 1004,
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
            ["source_line"] = 1005,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "购买回调注册为成功回调",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家穿上槽位<槽位>的皮肤",
            ["source_line"] = 1006,
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
            ["source_line"] = 1007,
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
            ["source_line"] = 1008,
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
            ["source_line"] = 1009,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤商店屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 1010,
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
          ["产品ID"] = 1029,
          ["总页数"] = 1029,
          ["槽位"] = 1029,
          ["皮肤数"] = 1029,
          ["角色ID"] = 1029,
        },
        ["source_line"] = 1017,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "未注册购买回调时装备未解锁皮肤失败且不改变面板",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 1018,
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
            ["source_line"] = 1019,
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
            ["source_line"] = 1020,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤尚未解锁",
            ["source_line"] = 1021,
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
            ["source_line"] = 1022,
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
            ["source_line"] = 1023,
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
            ["source_line"] = 1024,
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
            ["source_line"] = 1025,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤未成功装备",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 1026,
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
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总页数"] = 1048,
          ["槽位"] = 1048,
          ["皮肤数"] = 1048,
          ["角色ID"] = 1048,
        },
        ["source_line"] = 1035,
        ["source_path"] = "features/v102/skin_shop.feature",
      },
      ["name"] = "打开/翻页/购买/装备/关闭都不改写皮肤静态文本",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 1036,
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
            ["source_line"] = 1037,
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
            ["source_line"] = 1038,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到皮肤下一页",
            ["source_line"] = 1039,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到皮肤下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>在皮肤卡牌可见槽位范围内",
            ["source_line"] = 1040,
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
            ["source_line"] = 1041,
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
            ["source_line"] = 1042,
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
            ["source_line"] = 1043,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "皮肤静态文本未被改写",
            ["source_line"] = 1044,
            ["source_path"] = "features/v102/skin_shop.feature",
          },
          ["parameters"] = {},
          ["text"] = "皮肤静态文本未被改写",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 1045,
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
