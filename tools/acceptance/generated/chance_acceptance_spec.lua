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
        ["source_path"] = "features/game/chance.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
    {
      ["keyword"] = "And",
      ["metadata"] = {
        ["original_text"] = "玩家落在机会格",
        ["source_line"] = 7,
        ["source_path"] = "features/game/chance.feature",
      },
      ["parameters"] = {},
      ["text"] = "玩家落在机会格",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["余额"] = 76,
      ["其他玩家数"] = 126,
      ["卡号"] = 10,
      ["参数"] = 13,
      ["变化量"] = 241,
      ["基础金额"] = 106,
      ["实际丢弃"] = 188,
      ["实际金额"] = 108,
      ["对手余额"] = 145,
      ["扣除额"] = 97,
      ["持有数"] = 185,
      ["效果"] = 11,
      ["效果类型"] = 238,
      ["数量"] = 183,
      ["步数"] = 158,
      ["百分比"] = 94,
      ["目标"] = 12,
      ["神灵"] = 236,
      ["移动方向"] = 158,
      ["负面"] = 14,
      ["金额"] = 64,
      ["验证余额"] = 77,
      ["验证其他玩家数"] = 127,
      ["验证对手余额"] = 146,
      ["验证持有数"] = 186,
      ["验证收取额"] = 150,
      ["验证数量"] = 184,
      ["验证步数"] = 162,
      ["验证神灵"] = 237,
      ["验证移动方向"] = 161,
      ["验证金额"] = 67,
    },
    ["field_names"] = {
      ["余额"] = "余额",
      ["其他玩家数"] = "其他玩家数",
      ["卡号"] = "卡号",
      ["参数"] = "参数",
      ["变化量"] = "变化量",
      ["基础金额"] = "基础金额",
      ["实际丢弃"] = "实际丢弃",
      ["实际金额"] = "实际金额",
      ["对手余额"] = "对手余额",
      ["扣除额"] = "扣除额",
      ["持有数"] = "持有数",
      ["效果"] = "效果",
      ["效果类型"] = "效果类型",
      ["数量"] = "数量",
      ["步数"] = "步数",
      ["百分比"] = "百分比",
      ["目标"] = "目标",
      ["神灵"] = "神灵",
      ["移动方向"] = "移动方向",
      ["负面"] = "负面",
      ["金额"] = "金额",
      ["验证余额"] = "验证余额",
      ["验证其他玩家数"] = "验证其他玩家数",
      ["验证对手余额"] = "验证对手余额",
      ["验证持有数"] = "验证持有数",
      ["验证收取额"] = "验证收取额",
      ["验证数量"] = "验证数量",
      ["验证步数"] = "验证步数",
      ["验证神灵"] = "验证神灵",
      ["验证移动方向"] = "验证移动方向",
      ["验证金额"] = "验证金额",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/chance.feature",
  },
  ["name"] = "机会卡",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["卡号"] = "3001",
          ["参数"] = "10000",
          ["效果"] = "add_cash",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3002",
          ["参数"] = "1000",
          ["效果"] = "add_cash",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3003",
          ["参数"] = "2000",
          ["效果"] = "add_cash",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3004",
          ["参数"] = "5000",
          ["效果"] = "add_cash",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3005",
          ["参数"] = "10000",
          ["效果"] = "pay_cash",
          ["目标"] = "self",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3006",
          ["参数"] = "1000",
          ["效果"] = "pay_cash",
          ["目标"] = "self",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3007",
          ["参数"] = "2000",
          ["效果"] = "pay_cash",
          ["目标"] = "self",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3008",
          ["参数"] = "5000",
          ["效果"] = "pay_cash",
          ["目标"] = "self",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3009",
          ["参数"] = "3000",
          ["效果"] = "add_cash",
          ["目标"] = "all",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3010",
          ["参数"] = "3000",
          ["效果"] = "pay_cash",
          ["目标"] = "all",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3011",
          ["参数"] = "20",
          ["效果"] = "percent_pay_cash",
          ["目标"] = "all",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3012",
          ["参数"] = "3000",
          ["效果"] = "pay_others",
          ["目标"] = "self",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3013",
          ["参数"] = "3000",
          ["效果"] = "collect_from_others",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3017",
          ["参数"] = "-",
          ["效果"] = "destroy_buildings_on_path",
          ["目标"] = "path",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3018",
          ["参数"] = "-",
          ["效果"] = "reset_tiles_on_path",
          ["目标"] = "path",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3019",
          ["参数"] = "1",
          ["效果"] = "move_backward",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3020",
          ["参数"] = "2",
          ["效果"] = "move_backward",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3021",
          ["参数"] = "3",
          ["效果"] = "move_backward",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3022",
          ["参数"] = "1",
          ["效果"] = "move_forward",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3023",
          ["参数"] = "2",
          ["效果"] = "move_forward",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3024",
          ["参数"] = "3",
          ["效果"] = "move_forward",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3025",
          ["参数"] = "2017",
          ["效果"] = "grant_item",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3026",
          ["参数"] = "2018",
          ["效果"] = "grant_item",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3027",
          ["参数"] = "2019",
          ["效果"] = "grant_item",
          ["目标"] = "self",
          ["负面"] = "false",
        },
        {
          ["卡号"] = "3028",
          ["参数"] = "1",
          ["效果"] = "discard_items",
          ["目标"] = "self",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3029",
          ["参数"] = "0",
          ["效果"] = "discard_items",
          ["目标"] = "self",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3030",
          ["参数"] = "1",
          ["效果"] = "discard_properties",
          ["目标"] = "self",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3031",
          ["参数"] = "36",
          ["效果"] = "forced_move",
          ["目标"] = "self",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3032",
          ["参数"] = "37",
          ["效果"] = "forced_move",
          ["目标"] = "self",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3033",
          ["参数"] = "38",
          ["效果"] = "forced_move",
          ["目标"] = "self",
          ["负面"] = "true",
        },
        {
          ["卡号"] = "3034",
          ["参数"] = "39",
          ["效果"] = "forced_move",
          ["目标"] = "self",
          ["负面"] = "false",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["卡号"] = 17,
          ["参数"] = 17,
          ["效果"] = 17,
          ["目标"] = 17,
          ["负面"] = 17,
        },
        ["source_line"] = 9,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "策划案机会卡目录完整",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "策划案机会卡目录包含<卡号>",
            ["source_line"] = 10,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "卡号",
          },
          ["text"] = "策划案机会卡目录包含<卡号>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "机会卡<卡号>的效果为<效果>",
            ["source_line"] = 11,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "卡号",
            "效果",
          },
          ["text"] = "机会卡<卡号>的效果为<效果>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "机会卡<卡号>的目标为<目标>",
            ["source_line"] = 12,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "卡号",
            "目标",
          },
          ["text"] = "机会卡<卡号>的目标为<目标>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "机会卡<卡号>的参数为<参数>",
            ["source_line"] = 13,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "卡号",
            "参数",
          },
          ["text"] = "机会卡<卡号>的参数为<参数>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "机会卡<卡号>的负面标记为<负面>",
            ["source_line"] = 14,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "卡号",
            "负面",
          },
          ["text"] = "机会卡<卡号>的负面标记为<负面>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 50,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "抽取机会卡按权重随机",
      ["steps"] = {
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 51,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "从机会卡池中按权重随机抽取一张",
            ["source_line"] = 52,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "从机会卡池中按权重随机抽取一张",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "弹出机会卡展示弹窗",
            ["source_line"] = 53,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "弹出机会卡展示弹窗",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "事件日志记录抽到的卡片",
            ["source_line"] = 54,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "事件日志记录抽到的卡片",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 56,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "天使守护免疫负面机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家拥有天使守护",
            ["source_line"] = 57,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家拥有天使守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡标记为负面",
            ["source_line"] = 58,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡标记为负面",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 59,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "负面效果无效",
            ["source_line"] = 60,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "负面效果无效",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "提示天使保护",
            ["source_line"] = 61,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "提示天使保护",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["金额"] = "1000",
          ["验证金额"] = "1000",
        },
        {
          ["金额"] = "5000",
          ["验证金额"] = "5000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["金额"] = 70,
          ["验证金额"] = 70,
        },
        ["source_line"] = 63,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "获得金币类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为获得<金额>金币",
            ["source_line"] = 64,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "金额",
          },
          ["text"] = "抽到的机会卡效果为获得<金额>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 65,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家获得<金额>金币",
            ["source_line"] = 66,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "金额",
          },
          ["text"] = "玩家获得<金额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "获得金额记为<验证金额>金币",
            ["source_line"] = 67,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证金额",
          },
          ["text"] = "获得金额记为<验证金额>金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["余额"] = "5000",
          ["金额"] = "1000",
          ["验证余额"] = "5000",
          ["验证金额"] = "1000",
        },
        {
          ["余额"] = "10000",
          ["金额"] = "3000",
          ["验证余额"] = "10000",
          ["验证金额"] = "3000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["余额"] = 83,
          ["金额"] = 83,
          ["验证余额"] = 83,
          ["验证金额"] = 83,
        },
        ["source_line"] = 74,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "支付金币类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为支付<金额>金币",
            ["source_line"] = 75,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "金额",
          },
          ["text"] = "抽到的机会卡效果为支付<金额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 76,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "余额",
          },
          ["text"] = "玩家持有<余额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家初始余额为<验证余额>金币",
            ["source_line"] = 77,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证余额",
          },
          ["text"] = "玩家初始余额为<验证余额>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 78,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家扣除<金额>金币",
            ["source_line"] = 79,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "金额",
          },
          ["text"] = "玩家扣除<金额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "实际扣除金额为<验证金额>金币",
            ["source_line"] = 80,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证金额",
          },
          ["text"] = "实际扣除金额为<验证金额>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 87,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "支付金币后余额归零触发破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为支付5000金币",
            ["source_line"] = 88,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡效果为支付5000金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有3000金币",
            ["source_line"] = 89,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有3000金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 90,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家破产淘汰",
            ["source_line"] = 91,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家破产淘汰",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["余额"] = "10000",
          ["扣除额"] = "5000",
          ["百分比"] = "50",
        },
        {
          ["余额"] = "5000",
          ["扣除额"] = "1500",
          ["百分比"] = "30",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["余额"] = 100,
          ["扣除额"] = 100,
          ["百分比"] = 100,
        },
        ["source_line"] = 93,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "按比例支付金币类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为按<百分比>%支付金币",
            ["source_line"] = 94,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "百分比",
          },
          ["text"] = "抽到的机会卡效果为按<百分比>%支付金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 95,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "余额",
          },
          ["text"] = "玩家持有<余额>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 96,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家扣除<扣除额>金币",
            ["source_line"] = 97,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "扣除额",
          },
          ["text"] = "玩家扣除<扣除额>金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["基础金额"] = "1000",
          ["实际金额"] = "2000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["基础金额"] = 111,
          ["实际金额"] = 111,
        },
        ["source_line"] = 104,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "财神倍增获得金币效果",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有财神守护",
            ["source_line"] = 105,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有财神守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "抽到获得<基础金额>金币的机会卡",
            ["source_line"] = 106,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "基础金额",
          },
          ["text"] = "抽到获得<基础金额>金币的机会卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 107,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "实际获得<实际金额>金币",
            ["source_line"] = 108,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "实际金额",
          },
          ["text"] = "实际获得<实际金额>金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["基础金额"] = "1000",
          ["实际金额"] = "2000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["基础金额"] = 121,
          ["实际金额"] = 121,
        },
        ["source_line"] = 114,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "穷神倍增支付金币效果",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有穷神",
            ["source_line"] = 115,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有穷神",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "抽到支付<基础金额>金币的机会卡",
            ["source_line"] = 116,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "基础金额",
          },
          ["text"] = "抽到支付<基础金额>金币的机会卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 117,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "实际扣除<实际金额>金币",
            ["source_line"] = 118,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "实际金额",
          },
          ["text"] = "实际扣除<实际金额>金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["其他玩家数"] = "3",
          ["金额"] = "500",
          ["验证其他玩家数"] = "3",
          ["验证金额"] = "500",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["其他玩家数"] = 133,
          ["金额"] = 133,
          ["验证其他玩家数"] = 133,
          ["验证金额"] = 133,
        },
        ["source_line"] = 124,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "向他人支付金币类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为向每位玩家支付<金额>金币",
            ["source_line"] = 125,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "金额",
          },
          ["text"] = "抽到的机会卡效果为向每位玩家支付<金额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏中有<其他玩家数>名未淘汰对手",
            ["source_line"] = 126,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "其他玩家数",
          },
          ["text"] = "游戏中有<其他玩家数>名未淘汰对手",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前对手数量为<验证其他玩家数>名",
            ["source_line"] = 127,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证其他玩家数",
          },
          ["text"] = "当前对手数量为<验证其他玩家数>名",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 128,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家向每位对手各支付<金额>金币",
            ["source_line"] = 129,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "金额",
          },
          ["text"] = "玩家向每位对手各支付<金额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "实际每对手支付为<验证金额>金币",
            ["source_line"] = 130,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证金额",
          },
          ["text"] = "实际每对手支付为<验证金额>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 136,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "向他人支付时深山中的对手不收钱",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到向每位玩家支付500金币的机会卡",
            ["source_line"] = 137,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到向每位玩家支付500金币的机会卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手A在深山状态",
            ["source_line"] = 138,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手A在深山状态",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 139,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "对手A不收到任何金币",
            ["source_line"] = 140,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手A不收到任何金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["对手余额"] = "5000",
          ["金额"] = "1000",
          ["验证对手余额"] = "5000",
          ["验证收取额"] = "1000",
          ["验证金额"] = "1000",
        },
        {
          ["对手余额"] = "500",
          ["金额"] = "1000",
          ["验证对手余额"] = "500",
          ["验证收取额"] = "500",
          ["验证金额"] = "1000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["对手余额"] = 153,
          ["金额"] = 153,
          ["验证对手余额"] = 153,
          ["验证收取额"] = 153,
          ["验证金额"] = 153,
        },
        ["source_line"] = 142,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "从他人收取金币类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为向每位玩家收取<金额>金币",
            ["source_line"] = 143,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "金额",
          },
          ["text"] = "抽到的机会卡效果为向每位玩家收取<金额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前收取上限为<验证金额>金币",
            ["source_line"] = 144,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证金额",
          },
          ["text"] = "当前收取上限为<验证金额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手持有<对手余额>金币",
            ["source_line"] = 145,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "对手余额",
          },
          ["text"] = "对手持有<对手余额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手起始余额为<验证对手余额>金币",
            ["source_line"] = 146,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证对手余额",
          },
          ["text"] = "对手起始余额为<验证对手余额>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 147,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家从每位对手收取最多<金额>金币",
            ["source_line"] = 148,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "金额",
          },
          ["text"] = "玩家从每位对手收取最多<金额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手余额不足时只收取其全部余额",
            ["source_line"] = 149,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手余额不足时只收取其全部余额",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "实际收取总额为<验证收取额>金币",
            ["source_line"] = 150,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证收取额",
          },
          ["text"] = "实际收取总额为<验证收取额>金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["步数"] = "3",
          ["移动方向"] = "前进",
          ["验证步数"] = "3",
          ["验证移动方向"] = "前进",
        },
        {
          ["步数"] = "2",
          ["移动方向"] = "后退",
          ["验证步数"] = "2",
          ["验证移动方向"] = "后退",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["步数"] = 166,
          ["移动方向"] = 166,
          ["验证步数"] = 166,
          ["验证移动方向"] = 166,
        },
        ["source_line"] = 157,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "前进或后退步数类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为<移动方向><步数>步",
            ["source_line"] = 158,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "移动方向",
            "步数",
          },
          ["text"] = "抽到的机会卡效果为<移动方向><步数>步",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 159,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家<移动方向><步数>步",
            ["source_line"] = 160,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "移动方向",
            "步数",
          },
          ["text"] = "玩家<移动方向><步数>步",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "实际移动方向为<验证移动方向>",
            ["source_line"] = 161,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证移动方向",
          },
          ["text"] = "实际移动方向为<验证移动方向>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "实际移动步数为<验证步数>步",
            ["source_line"] = 162,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证步数",
          },
          ["text"] = "实际移动步数为<验证步数>步",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "到达后触发落地结算",
            ["source_line"] = 163,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "到达后触发落地结算",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 170,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "强制传送类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为传送到指定格",
            ["source_line"] = 171,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡效果为传送到指定格",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 172,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家被传送到目标格",
            ["source_line"] = 173,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家被传送到目标格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "到达后触发落地结算",
            ["source_line"] = 174,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "到达后触发落地结算",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 176,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "获得道具类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为获得指定道具",
            ["source_line"] = 177,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡效果为获得指定道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家背包未满",
            ["source_line"] = 178,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家背包未满",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 179,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "指定道具加入玩家背包",
            ["source_line"] = 180,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "指定道具加入玩家背包",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["实际丢弃"] = "2",
          ["持有数"] = "5",
          ["数量"] = "2",
          ["验证持有数"] = "5",
          ["验证数量"] = "2",
        },
        {
          ["实际丢弃"] = "1",
          ["持有数"] = "1",
          ["数量"] = "3",
          ["验证持有数"] = "1",
          ["验证数量"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["实际丢弃"] = 191,
          ["持有数"] = 191,
          ["数量"] = 191,
          ["验证持有数"] = 191,
          ["验证数量"] = 191,
        },
        ["source_line"] = 182,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "丢弃道具类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为随机丢弃<数量>张道具",
            ["source_line"] = 183,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "数量",
          },
          ["text"] = "抽到的机会卡效果为随机丢弃<数量>张道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "指定丢弃数为<验证数量>张",
            ["source_line"] = 184,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证数量",
          },
          ["text"] = "指定丢弃数为<验证数量>张",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有<持有数>张道具",
            ["source_line"] = 185,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "持有数",
          },
          ["text"] = "玩家持有<持有数>张道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "背包道具数为<验证持有数>张",
            ["source_line"] = 186,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证持有数",
          },
          ["text"] = "背包道具数为<验证持有数>张",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 187,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家随机失去<实际丢弃>张道具",
            ["source_line"] = 188,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "实际丢弃",
          },
          ["text"] = "玩家随机失去<实际丢弃>张道具",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["实际丢弃"] = "1",
          ["持有数"] = "3",
          ["数量"] = "1",
          ["验证数量"] = "1",
        },
        {
          ["实际丢弃"] = "1",
          ["持有数"] = "1",
          ["数量"] = "2",
          ["验证数量"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["实际丢弃"] = 204,
          ["持有数"] = 204,
          ["数量"] = 204,
          ["验证数量"] = 204,
        },
        ["source_line"] = 195,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "丢弃地块类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为随机丢弃<数量>块地块",
            ["source_line"] = 196,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "数量",
          },
          ["text"] = "抽到的机会卡效果为随机丢弃<数量>块地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "指定丢弃地块数为<验证数量>块",
            ["source_line"] = 197,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证数量",
          },
          ["text"] = "指定丢弃地块数为<验证数量>块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家拥有<持有数>块地块",
            ["source_line"] = 198,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "持有数",
          },
          ["text"] = "玩家拥有<持有数>块地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 199,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家随机失去<实际丢弃>块地块",
            ["source_line"] = 200,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "实际丢弃",
          },
          ["text"] = "玩家随机失去<实际丢弃>块地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "被丢弃的地块重置为无主状态",
            ["source_line"] = 201,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "被丢弃的地块重置为无主状态",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 208,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "台风摧毁沿途建筑",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到台风类机会卡",
            ["source_line"] = 209,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到台风类机会卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家本次移动经过的路径上有等级大于0的地块",
            ["source_line"] = 210,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本次移动经过的路径上有等级大于0的地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 211,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "路径上所有地块等级重置为0",
            ["source_line"] = 212,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "路径上所有地块等级重置为0",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 214,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "强制征地重置沿途地块",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到强制征地类机会卡",
            ["source_line"] = 215,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到强制征地类机会卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家本次移动经过的路径上有已购地块",
            ["source_line"] = 216,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本次移动经过的路径上有已购地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 217,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "路径上所有地块恢复初始状态",
            ["source_line"] = 218,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "路径上所有地块恢复初始状态",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 220,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "全体支付类机会卡影响所有未淘汰玩家",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡目标为全体",
            ["source_line"] = 221,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡目标为全体",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "效果为支付1000金币",
            ["source_line"] = 222,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果为支付1000金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 223,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "所有未淘汰玩家各扣除1000金币",
            ["source_line"] = 224,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "所有未淘汰玩家各扣除1000金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 226,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "全体负面支付机会卡跳过拥有天使守护的对手",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家抽到负面全体支付1000金币的机会卡",
            ["source_line"] = 227,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家抽到负面全体支付1000金币的机会卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏中有2名对手",
            ["source_line"] = 228,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏中有2名对手",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手B拥有天使守护",
            ["source_line"] = 229,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手B拥有天使守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "各对手初始持有5000金币",
            ["source_line"] = 230,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "各对手初始持有5000金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 231,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "拥有天使守护的对手金币不变",
            ["source_line"] = 232,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "拥有天使守护的对手金币不变",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "无天使守护的对手被扣除1000金币",
            ["source_line"] = 233,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "无天使守护的对手被扣除1000金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["变化量"] = "+6000",
          ["效果类型"] = "向每位对手支付",
          ["神灵"] = "穷神",
          ["验证神灵"] = "穷神",
        },
        {
          ["变化量"] = "-6000",
          ["效果类型"] = "从每位对手收取",
          ["神灵"] = "财神",
          ["验证神灵"] = "财神",
        },
        {
          ["变化量"] = "-3000",
          ["效果类型"] = "从每位对手收取",
          ["神灵"] = "穷神",
          ["验证神灵"] = "穷神",
        },
        {
          ["变化量"] = "+3000",
          ["效果类型"] = "向每位对手支付",
          ["神灵"] = "财神",
          ["验证神灵"] = "财神",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["变化量"] = 244,
          ["效果类型"] = 244,
          ["神灵"] = 244,
          ["验证神灵"] = 244,
        },
        ["source_line"] = 235,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "穷神和财神影响向他人支付和从他人收取效果",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家附有<神灵>",
            ["source_line"] = 236,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "神灵",
          },
          ["text"] = "玩家附有<神灵>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家神灵状态为<验证神灵>",
            ["source_line"] = 237,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "验证神灵",
          },
          ["text"] = "玩家神灵状态为<验证神灵>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "抽到<效果类型>3000金币的多人机会卡",
            ["source_line"] = 238,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "效果类型",
          },
          ["text"] = "抽到<效果类型>3000金币的多人机会卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏中有1名持有10000金币的对手",
            ["source_line"] = 239,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏中有1名持有10000金币的对手",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 240,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "对手的金币变化量为<变化量>",
            ["source_line"] = 241,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "变化量",
          },
          ["text"] = "对手的金币变化量为<变化量>",
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
