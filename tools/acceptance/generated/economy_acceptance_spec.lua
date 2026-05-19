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
        ["source_path"] = "features/game/economy.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
    {
      ["keyword"] = "And",
      ["metadata"] = {
        ["original_text"] = "棋盘包含地块邻接关系",
        ["source_line"] = 7,
        ["source_path"] = "features/game/economy.feature",
      },
      ["parameters"] = {},
      ["text"] = "棋盘包含地块邻接关系",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 10,
      ["p10"] = 61,
      ["p11"] = 63,
      ["p12"] = 72,
      ["p13"] = 73,
      ["p14"] = 75,
      ["p15"] = 94,
      ["p16"] = 117,
      ["p17"] = 120,
      ["p18"] = 138,
      ["p2"] = 11,
      ["p3"] = 28,
      ["p4"] = 29,
      ["p5"] = 32,
      ["p6"] = 47,
      ["p7"] = 48,
      ["p8"] = 51,
      ["p9"] = 60,
    },
    ["field_names"] = {
      ["p1"] = "余额",
      ["p10"] = "各块租金",
      ["p11"] = "总租金",
      ["p12"] = "基础租金",
      ["p13"] = "神灵条件",
      ["p14"] = "实际租金",
      ["p15"] = "税金",
      ["p16"] = "累计升级费",
      ["p17"] = "总投入",
      ["p18"] = "实收金额",
      ["p2"] = "地价",
      ["p3"] = "当前等级",
      ["p4"] = "升级费",
      ["p5"] = "新等级",
      ["p6"] = "等级",
      ["p7"] = "租金表",
      ["p8"] = "应付租金",
      ["p9"] = "连片数",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/economy.feature",
  },
  ["name"] = "经济系统",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["p1"] = "5000",
          ["p2"] = "2000",
        },
        {
          ["p1"] = "10000",
          ["p2"] = "3000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 17,
          ["p2"] = 17,
        },
        ["source_line"] = 9,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "购买无主地块",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 10,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家持有<p1>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家落在价格为<地价>的无主地块",
            ["source_line"] = 11,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家落在价格为<p2>的无主地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择购买",
            ["source_line"] = 12,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择购买",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家扣除<地价>金币",
            ["source_line"] = 13,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家扣除<p2>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家成为该地块的所有者",
            ["source_line"] = 14,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家成为该地块的所有者",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 21,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "余额不足时无法购买地块",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有1000金币",
            ["source_line"] = 22,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有1000金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家落在价格为2000的无主地块",
            ["source_line"] = 23,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在价格为2000的无主地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择购买",
            ["source_line"] = 24,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择购买",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "购买失败并提示余额不足",
            ["source_line"] = 25,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "购买失败并提示余额不足",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "5000",
          ["p3"] = "0",
          ["p4"] = "1000",
          ["p5"] = "1",
        },
        {
          ["p1"] = "5000",
          ["p3"] = "1",
          ["p4"] = "1500",
          ["p5"] = "2",
        },
        {
          ["p1"] = "5000",
          ["p3"] = "2",
          ["p4"] = "2000",
          ["p5"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 36,
          ["p3"] = 36,
          ["p4"] = 36,
          ["p5"] = 36,
        },
        ["source_line"] = 27,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "升级自有地块",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家拥有一块等级为<当前等级>的地块",
            ["source_line"] = 28,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "玩家拥有一块等级为<p3>的地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该地块的下一级升级费为<升级费>",
            ["source_line"] = 29,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "该地块的下一级升级费为<p4>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 30,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家持有<p1>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择升级",
            ["source_line"] = 31,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择升级",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地块等级变为<新等级>",
            ["source_line"] = 32,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "地块等级变为<p5>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家扣除<升级费>金币",
            ["source_line"] = 33,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家扣除<p4>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 41,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "地块已达最高等级时无法升级",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家拥有的地块已达最高等级",
            ["source_line"] = 42,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家拥有的地块已达最高等级",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试升级",
            ["source_line"] = 43,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试升级",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "升级选项不可用",
            ["source_line"] = 44,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "升级选项不可用",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p6"] = "0",
          ["p7"] = "100,200,400,800",
          ["p8"] = "100",
        },
        {
          ["p6"] = "1",
          ["p7"] = "100,200,400,800",
          ["p8"] = "200",
        },
        {
          ["p6"] = "2",
          ["p7"] = "100,200,400,800",
          ["p8"] = "400",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p6"] = 54,
          ["p7"] = 54,
          ["p8"] = 54,
        },
        ["source_line"] = 46,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "单块地块收取等级对应租金",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "地块等级为<等级>",
            ["source_line"] = 47,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "地块等级为<p6>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块的租金表为<租金表>",
            ["source_line"] = 48,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p7",
          },
          ["text"] = "地块的租金表为<p7>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块属于对手",
            ["source_line"] = 49,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块属于对手",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在该地块",
            ["source_line"] = 50,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家支付租金<应付租金>给对手",
            ["source_line"] = 51,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p8",
          },
          ["text"] = "玩家支付租金<p8>给对手",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p10"] = "100,200",
          ["p11"] = "300",
          ["p9"] = "2",
        },
        {
          ["p10"] = "100,200,400",
          ["p11"] = "700",
          ["p9"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p10"] = 66,
          ["p11"] = 66,
          ["p9"] = 66,
        },
        ["source_line"] = 59,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "连片地块租金为各块租金之和",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手拥有<连片数>块相邻地块",
            ["source_line"] = 60,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p9",
          },
          ["text"] = "对手拥有<p9>块相邻地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "各块租金分别为<各块租金>",
            ["source_line"] = 61,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p10",
          },
          ["text"] = "各块租金分别为<p10>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在其中任一块",
            ["source_line"] = 62,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在其中任一块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家支付的租金为<总租金>",
            ["source_line"] = 63,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p11",
          },
          ["text"] = "玩家支付的租金为<p11>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p12"] = "100",
          ["p13"] = "租户持有穷神",
          ["p14"] = "200",
        },
        {
          ["p12"] = "100",
          ["p13"] = "房东持有财神",
          ["p14"] = "200",
        },
        {
          ["p12"] = "100",
          ["p13"] = "租户持有穷神且房东持有财神",
          ["p14"] = "400",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p12"] = 78,
          ["p13"] = 78,
          ["p14"] = 78,
        },
        ["source_line"] = 70,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "神灵倍增租金",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在对手拥有的地块",
            ["source_line"] = 71,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在对手拥有的地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "单块基础租金为<基础租金>",
            ["source_line"] = 72,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p12",
          },
          ["text"] = "单块基础租金为<p12>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "<神灵条件>",
            ["source_line"] = 73,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p13",
          },
          ["text"] = "<p13>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "租金结算执行",
            ["source_line"] = 74,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "租金结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "实际支付租金为<实际租金>",
            ["source_line"] = 75,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p14",
          },
          ["text"] = "实际支付租金为<p14>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 83,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "房东在深山时租金不收取",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手拥有一块地块",
            ["source_line"] = 84,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手拥有一块地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手当前在深山状态",
            ["source_line"] = 85,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手当前在深山状态",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在该地块",
            ["source_line"] = 86,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "租金不收取",
            ["source_line"] = 87,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "租金不收取",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "事件日志显示房东在深山",
            ["source_line"] = 88,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "事件日志显示房东在深山",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "10000",
          ["p15"] = "5000",
        },
        {
          ["p1"] = "3000",
          ["p15"] = "1500",
        },
        {
          ["p1"] = "1",
          ["p15"] = "0",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 97,
          ["p15"] = 97,
        },
        ["source_line"] = 90,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "税务局按比例收税",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 91,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家持有<p1>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "税率为50%",
            ["source_line"] = 92,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "税率为50%",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在税务局格",
            ["source_line"] = 93,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在税务局格",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家被收取<税金>金币",
            ["source_line"] = 94,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p15",
          },
          ["text"] = "玩家被收取<p15>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 102,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "天使守护免疫税务局",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家拥有天使守护",
            ["source_line"] = 103,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家拥有天使守护",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在税务局格",
            ["source_line"] = 104,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在税务局格",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家不被收税",
            ["source_line"] = 105,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家不被收税",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 107,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "持有免税卡时弹出使用提示",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在税务局格",
            ["source_line"] = 108,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在税务局格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有免税卡",
            ["source_line"] = 109,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有免税卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 110,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "弹出免税卡使用选择",
            ["source_line"] = 111,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "弹出免税卡使用选择",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "若玩家确认则消耗免税卡并免税",
            ["source_line"] = 112,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "若玩家确认则消耗免税卡并免税",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "5000",
          ["p16"] = "0",
          ["p17"] = "2000",
          ["p2"] = "2000",
          ["p6"] = "0",
        },
        {
          ["p1"] = "10000",
          ["p16"] = "2500",
          ["p17"] = "4500",
          ["p2"] = "2000",
          ["p6"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 124,
          ["p16"] = 124,
          ["p17"] = 124,
          ["p2"] = 124,
          ["p6"] = 124,
        },
        ["source_line"] = 114,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "强夺卡支付总投入获得对手地块",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手的地块等级为<等级>",
            ["source_line"] = 115,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "对手的地块等级为<p6>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块购买价为<地价>",
            ["source_line"] = 116,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "地块购买价为<p2>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "各级累计升级费为<累计升级费>",
            ["source_line"] = 117,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p16",
          },
          ["text"] = "各级累计升级费为<p16>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 118,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家持有<p1>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用强夺卡",
            ["source_line"] = 119,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用强夺卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家支付<总投入>金币给对手",
            ["source_line"] = 120,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p17",
          },
          ["text"] = "玩家支付<p17>金币给对手",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块所有权转移给玩家",
            ["source_line"] = 121,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块所有权转移给玩家",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 128,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "强夺卡余额不足时无法使用",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手的地块总投入为5000",
            ["source_line"] = 129,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手的地块总投入为5000",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有3000金币",
            ["source_line"] = 130,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有3000金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试使用强夺卡",
            ["source_line"] = 131,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试使用强夺卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "强夺卡不可用",
            ["source_line"] = 132,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "强夺卡不可用",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "500",
          ["p18"] = "500",
          ["p8"] = "1000",
        },
        {
          ["p1"] = "0",
          ["p18"] = "0",
          ["p8"] = "200",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 142,
          ["p18"] = 142,
          ["p8"] = 142,
        },
        ["source_line"] = 134,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "支付租金后资金不足触发破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 135,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家持有<p1>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "应付租金为<应付租金>",
            ["source_line"] = 136,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p8",
          },
          ["text"] = "应付租金为<p8>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "租金结算执行",
            ["source_line"] = 137,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "租金结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "房东收到<实收金额>金币",
            ["source_line"] = 138,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "p18",
          },
          ["text"] = "房东收到<p18>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家破产淘汰",
            ["source_line"] = 139,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家破产淘汰",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 146,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "余额为零时落在税务局触发破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有0金币",
            ["source_line"] = 147,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有0金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "税率为50%",
            ["source_line"] = 148,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "税率为50%",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在税务局格",
            ["source_line"] = 149,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在税务局格",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "税金为0",
            ["source_line"] = 150,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "税金为0",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家因余额为零而破产淘汰",
            ["source_line"] = 151,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家因余额为零而破产淘汰",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
