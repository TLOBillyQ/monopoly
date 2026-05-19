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
      ["p1"] = 23,
      ["p10"] = 109,
      ["p11"] = 132,
      ["p12"] = 133,
      ["p13"] = 135,
      ["p14"] = 176,
      ["p15"] = 177,
      ["p16"] = 180,
      ["p2"] = 34,
      ["p3"] = 50,
      ["p4"] = 53,
      ["p5"] = 62,
      ["p6"] = 64,
      ["p7"] = 82,
      ["p8"] = 98,
      ["p9"] = 109,
    },
    ["field_names"] = {
      ["p1"] = "金额",
      ["p10"] = "步数",
      ["p11"] = "数量",
      ["p12"] = "持有数",
      ["p13"] = "实际丢弃",
      ["p14"] = "神灵",
      ["p15"] = "效果类型",
      ["p16"] = "变化量",
      ["p2"] = "余额",
      ["p3"] = "百分比",
      ["p4"] = "扣除额",
      ["p5"] = "基础金额",
      ["p6"] = "实际金额",
      ["p7"] = "其他玩家数",
      ["p8"] = "对手余额",
      ["p9"] = "移动方向",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/chance.feature",
  },
  ["name"] = "机会卡",
  ["scenarios"] = {
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 9,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "抽取机会卡按权重随机",
      ["steps"] = {
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 10,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "从机会卡池中按权重随机抽取一张",
            ["source_line"] = 11,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "从机会卡池中按权重随机抽取一张",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "弹出机会卡展示弹窗",
            ["source_line"] = 12,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "弹出机会卡展示弹窗",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "事件日志记录抽到的卡片",
            ["source_line"] = 13,
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
        ["source_line"] = 15,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "天使守护免疫负面机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家拥有天使守护",
            ["source_line"] = 16,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家拥有天使守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡标记为负面",
            ["source_line"] = 17,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡标记为负面",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 18,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "负面效果无效",
            ["source_line"] = 19,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "负面效果无效",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "提示天使保护",
            ["source_line"] = 20,
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
          ["p1"] = "1000",
        },
        {
          ["p1"] = "5000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 28,
        },
        ["source_line"] = 22,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "获得金币类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为获得<金额>金币",
            ["source_line"] = 23,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "抽到的机会卡效果为获得<p1>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 24,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家获得<金额>金币",
            ["source_line"] = 25,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家获得<p1>金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1000",
          ["p2"] = "5000",
        },
        {
          ["p1"] = "3000",
          ["p2"] = "10000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 39,
          ["p2"] = 39,
        },
        ["source_line"] = 32,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "支付金币类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为支付<金额>金币",
            ["source_line"] = 33,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "抽到的机会卡效果为支付<p1>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 34,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家持有<p2>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 35,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家扣除<金额>金币",
            ["source_line"] = 36,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家扣除<p1>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 43,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "支付金币后余额归零触发破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为支付5000金币",
            ["source_line"] = 44,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡效果为支付5000金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有3000金币",
            ["source_line"] = 45,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有3000金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 46,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家破产淘汰",
            ["source_line"] = 47,
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
          ["p2"] = "10000",
          ["p3"] = "50",
          ["p4"] = "5000",
        },
        {
          ["p2"] = "5000",
          ["p3"] = "30",
          ["p4"] = "1500",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p2"] = 56,
          ["p3"] = 56,
          ["p4"] = 56,
        },
        ["source_line"] = 49,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "按比例支付金币类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为按<百分比>%支付金币",
            ["source_line"] = 50,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "抽到的机会卡效果为按<p3>%支付金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 51,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家持有<p2>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 52,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家扣除<扣除额>金币",
            ["source_line"] = 53,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家扣除<p4>金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p5"] = "1000",
          ["p6"] = "2000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p5"] = 67,
          ["p6"] = 67,
        },
        ["source_line"] = 60,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "财神倍增获得金币效果",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有财神守护",
            ["source_line"] = 61,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有财神守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "抽到获得<基础金额>金币的机会卡",
            ["source_line"] = 62,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "抽到获得<p5>金币的机会卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 63,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "实际获得<实际金额>金币",
            ["source_line"] = 64,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "实际获得<p6>金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p5"] = "1000",
          ["p6"] = "2000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p5"] = 77,
          ["p6"] = 77,
        },
        ["source_line"] = 70,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "穷神倍增支付金币效果",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有穷神",
            ["source_line"] = 71,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有穷神",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "抽到支付<基础金额>金币的机会卡",
            ["source_line"] = 72,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "抽到支付<p5>金币的机会卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 73,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "实际扣除<实际金额>金币",
            ["source_line"] = 74,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "实际扣除<p6>金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "500",
          ["p7"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 87,
          ["p7"] = 87,
        },
        ["source_line"] = 80,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "向他人支付金币类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为向每位玩家支付<金额>金币",
            ["source_line"] = 81,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "抽到的机会卡效果为向每位玩家支付<p1>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏中有<其他玩家数>名未淘汰对手",
            ["source_line"] = 82,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p7",
          },
          ["text"] = "游戏中有<p7>名未淘汰对手",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 83,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家向每位对手各支付<金额>金币",
            ["source_line"] = 84,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家向每位对手各支付<p1>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 90,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "向他人支付时深山中的对手不收钱",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到向每位玩家支付500金币的机会卡",
            ["source_line"] = 91,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到向每位玩家支付500金币的机会卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手A在深山状态",
            ["source_line"] = 92,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手A在深山状态",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 93,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "对手A不收到任何金币",
            ["source_line"] = 94,
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
          ["p1"] = "1000",
          ["p8"] = "5000",
        },
        {
          ["p1"] = "1000",
          ["p8"] = "500",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 104,
          ["p8"] = 104,
        },
        ["source_line"] = 96,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "从他人收取金币类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为向每位玩家收取<金额>金币",
            ["source_line"] = 97,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "抽到的机会卡效果为向每位玩家收取<p1>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手持有<对手余额>金币",
            ["source_line"] = 98,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p8",
          },
          ["text"] = "对手持有<p8>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 99,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家从每位对手收取最多<金额>金币",
            ["source_line"] = 100,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家从每位对手收取最多<p1>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手余额不足时只收取其全部余额",
            ["source_line"] = 101,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手余额不足时只收取其全部余额",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p10"] = "3",
          ["p9"] = "前进",
        },
        {
          ["p10"] = "2",
          ["p9"] = "后退",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p10"] = 115,
          ["p9"] = 115,
        },
        ["source_line"] = 108,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "前进或后退步数类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为<移动方向><步数>步",
            ["source_line"] = 109,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p9",
            "p10",
          },
          ["text"] = "抽到的机会卡效果为<p9><p10>步",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 110,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家<移动方向><步数>步",
            ["source_line"] = 111,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p9",
            "p10",
          },
          ["text"] = "玩家<p9><p10>步",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "到达后触发落地结算",
            ["source_line"] = 112,
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
        ["source_line"] = 119,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "强制传送类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为传送到指定格",
            ["source_line"] = 120,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡效果为传送到指定格",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 121,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家被传送到目标格",
            ["source_line"] = 122,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家被传送到目标格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "到达后触发落地结算",
            ["source_line"] = 123,
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
        ["source_line"] = 125,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "获得道具类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为获得指定道具",
            ["source_line"] = 126,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡效果为获得指定道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家背包未满",
            ["source_line"] = 127,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家背包未满",
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
            ["original_text"] = "指定道具加入玩家背包",
            ["source_line"] = 129,
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
          ["p11"] = "2",
          ["p12"] = "5",
          ["p13"] = "2",
        },
        {
          ["p11"] = "3",
          ["p12"] = "1",
          ["p13"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p11"] = 138,
          ["p12"] = 138,
          ["p13"] = 138,
        },
        ["source_line"] = 131,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "丢弃道具类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为随机丢弃<数量>张道具",
            ["source_line"] = 132,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p11",
          },
          ["text"] = "抽到的机会卡效果为随机丢弃<p11>张道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有<持有数>张道具",
            ["source_line"] = 133,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p12",
          },
          ["text"] = "玩家持有<p12>张道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 134,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家随机失去<实际丢弃>张道具",
            ["source_line"] = 135,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p13",
          },
          ["text"] = "玩家随机失去<p13>张道具",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p11"] = "1",
          ["p12"] = "3",
          ["p13"] = "1",
        },
        {
          ["p11"] = "2",
          ["p12"] = "1",
          ["p13"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p11"] = 150,
          ["p12"] = 150,
          ["p13"] = 150,
        },
        ["source_line"] = 142,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "丢弃地块类机会卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为随机丢弃<数量>块地块",
            ["source_line"] = 143,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p11",
          },
          ["text"] = "抽到的机会卡效果为随机丢弃<p11>块地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家拥有<持有数>块地块",
            ["source_line"] = 144,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p12",
          },
          ["text"] = "玩家拥有<p12>块地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 145,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家随机失去<实际丢弃>块地块",
            ["source_line"] = 146,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p13",
          },
          ["text"] = "玩家随机失去<p13>块地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "被丢弃的地块重置为无主状态",
            ["source_line"] = 147,
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
        ["source_line"] = 154,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "台风摧毁沿途建筑",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到台风类机会卡",
            ["source_line"] = 155,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到台风类机会卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家本次移动经过的路径上有等级大于0的地块",
            ["source_line"] = 156,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本次移动经过的路径上有等级大于0的地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 157,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "路径上所有地块等级重置为0",
            ["source_line"] = 158,
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
        ["source_line"] = 160,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "全体支付类机会卡影响所有未淘汰玩家",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡目标为全体",
            ["source_line"] = 161,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡目标为全体",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "效果为支付1000金币",
            ["source_line"] = 162,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果为支付1000金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 163,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "所有未淘汰玩家各扣除1000金币",
            ["source_line"] = 164,
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
        ["source_line"] = 166,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "全体负面支付机会卡跳过拥有天使守护的对手",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家抽到负面全体支付1000金币的机会卡",
            ["source_line"] = 167,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家抽到负面全体支付1000金币的机会卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏中有2名对手",
            ["source_line"] = 168,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏中有2名对手",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手B拥有天使守护",
            ["source_line"] = 169,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手B拥有天使守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "各对手初始持有5000金币",
            ["source_line"] = 170,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "各对手初始持有5000金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 171,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "拥有天使守护的对手金币不变",
            ["source_line"] = 172,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "拥有天使守护的对手金币不变",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "无天使守护的对手被扣除1000金币",
            ["source_line"] = 173,
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
          ["p14"] = "穷神",
          ["p15"] = "向每位对手支付",
          ["p16"] = "+6000",
        },
        {
          ["p14"] = "财神",
          ["p15"] = "从每位对手收取",
          ["p16"] = "-6000",
        },
        {
          ["p14"] = "穷神",
          ["p15"] = "从每位对手收取",
          ["p16"] = "-3000",
        },
        {
          ["p14"] = "财神",
          ["p15"] = "向每位对手支付",
          ["p16"] = "+3000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p14"] = 183,
          ["p15"] = 183,
          ["p16"] = 183,
        },
        ["source_line"] = 175,
        ["source_path"] = "features/game/chance.feature",
      },
      ["name"] = "穷神和财神影响向他人支付和从他人收取效果",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家附有<神灵>",
            ["source_line"] = 176,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p14",
          },
          ["text"] = "玩家附有<p14>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "抽到<效果类型>3000金币的多人机会卡",
            ["source_line"] = 177,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p15",
          },
          ["text"] = "抽到<p15>3000金币的多人机会卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏中有1名持有10000金币的对手",
            ["source_line"] = 178,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏中有1名持有10000金币的对手",
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
            ["original_text"] = "对手的金币变化量为<变化量>",
            ["source_line"] = 180,
            ["source_path"] = "features/game/chance.feature",
          },
          ["parameters"] = {
            "p16",
          },
          ["text"] = "对手的金币变化量为<p16>",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
