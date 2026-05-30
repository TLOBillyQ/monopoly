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
      ["余额"] = 10,
      ["加盖次数"] = 52,
      ["升级费"] = 31,
      ["各块租金"] = 67,
      ["地价"] = 12,
      ["基础租金"] = 78,
      ["实收金额"] = 149,
      ["实际租金"] = 81,
      ["应付租金"] = 55,
      ["当前等级"] = 30,
      ["总投入"] = 130,
      ["总租金"] = 69,
      ["新等级"] = 36,
      ["神灵条件"] = 79,
      ["税金"] = 100,
      ["等级"] = 123,
      ["累计升级费"] = 126,
      ["连片数"] = 65,
      ["验证余额"] = 11,
      ["验证升级费"] = 32,
      ["验证地价"] = 13,
      ["验证应付租金"] = 147,
      ["验证等级"] = 124,
      ["验证连片数"] = 66,
    },
    ["field_names"] = {
      ["余额"] = "余额",
      ["加盖次数"] = "加盖次数",
      ["升级费"] = "升级费",
      ["各块租金"] = "各块租金",
      ["地价"] = "地价",
      ["基础租金"] = "基础租金",
      ["实收金额"] = "实收金额",
      ["实际租金"] = "实际租金",
      ["应付租金"] = "应付租金",
      ["当前等级"] = "当前等级",
      ["总投入"] = "总投入",
      ["总租金"] = "总租金",
      ["新等级"] = "新等级",
      ["神灵条件"] = "神灵条件",
      ["税金"] = "税金",
      ["等级"] = "等级",
      ["累计升级费"] = "累计升级费",
      ["连片数"] = "连片数",
      ["验证余额"] = "验证余额",
      ["验证升级费"] = "验证升级费",
      ["验证地价"] = "验证地价",
      ["验证应付租金"] = "验证应付租金",
      ["验证等级"] = "验证等级",
      ["验证连片数"] = "验证连片数",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/economy.feature",
  },
  ["name"] = "经济系统",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["余额"] = "5000",
          ["地价"] = "2000",
          ["验证余额"] = "5000",
          ["验证地价"] = "2000",
        },
        {
          ["余额"] = "10000",
          ["地价"] = "3000",
          ["验证余额"] = "10000",
          ["验证地价"] = "3000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["余额"] = 19,
          ["地价"] = 19,
          ["验证余额"] = 19,
          ["验证地价"] = 19,
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
            "余额",
          },
          ["text"] = "玩家持有<余额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家初始余额为<验证余额>金币",
            ["source_line"] = 11,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "验证余额",
          },
          ["text"] = "玩家初始余额为<验证余额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家落在价格为<地价>的无主地块",
            ["source_line"] = 12,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "地价",
          },
          ["text"] = "玩家落在价格为<地价>的无主地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块价格为<验证地价>金币",
            ["source_line"] = 13,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "验证地价",
          },
          ["text"] = "地块价格为<验证地价>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择购买",
            ["source_line"] = 14,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择购买",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家扣除<地价>金币",
            ["source_line"] = 15,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "地价",
          },
          ["text"] = "玩家扣除<地价>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家成为该地块的所有者",
            ["source_line"] = 16,
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
        ["source_line"] = 23,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "余额不足时无法购买地块",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有1000金币",
            ["source_line"] = 24,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有1000金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家落在价格为2000的无主地块",
            ["source_line"] = 25,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在价格为2000的无主地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择购买",
            ["source_line"] = 26,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择购买",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "购买失败并提示余额不足",
            ["source_line"] = 27,
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
          ["余额"] = "5000",
          ["升级费"] = "1000",
          ["当前等级"] = "0",
          ["新等级"] = "1",
          ["验证余额"] = "5000",
          ["验证升级费"] = "1000",
        },
        {
          ["余额"] = "5000",
          ["升级费"] = "1500",
          ["当前等级"] = "1",
          ["新等级"] = "2",
          ["验证余额"] = "5000",
          ["验证升级费"] = "1500",
        },
        {
          ["余额"] = "5000",
          ["升级费"] = "2000",
          ["当前等级"] = "2",
          ["新等级"] = "3",
          ["验证余额"] = "5000",
          ["验证升级费"] = "2000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["余额"] = 40,
          ["升级费"] = 40,
          ["当前等级"] = 40,
          ["新等级"] = 40,
          ["验证余额"] = 40,
          ["验证升级费"] = 40,
        },
        ["source_line"] = 29,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "升级自有地块",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家拥有一块等级为<当前等级>的地块",
            ["source_line"] = 30,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "当前等级",
          },
          ["text"] = "玩家拥有一块等级为<当前等级>的地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该地块的下一级升级费为<升级费>",
            ["source_line"] = 31,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "升级费",
          },
          ["text"] = "该地块的下一级升级费为<升级费>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前升级费为<验证升级费>金币",
            ["source_line"] = 32,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "验证升级费",
          },
          ["text"] = "当前升级费为<验证升级费>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 33,
            ["source_path"] = "features/game/economy.feature",
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
            ["source_line"] = 34,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "验证余额",
          },
          ["text"] = "玩家初始余额为<验证余额>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择升级",
            ["source_line"] = 35,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择升级",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地块等级变为<新等级>",
            ["source_line"] = 36,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "新等级",
          },
          ["text"] = "地块等级变为<新等级>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家扣除<升级费>金币",
            ["source_line"] = 37,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "升级费",
          },
          ["text"] = "玩家扣除<升级费>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 45,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "地块已达最高等级时无法升级",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家拥有的地块已达最高等级",
            ["source_line"] = 46,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家拥有的地块已达最高等级",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试升级",
            ["source_line"] = 47,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试升级",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "升级选项不可用",
            ["source_line"] = 48,
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
          ["加盖次数"] = "0",
          ["地价"] = "100",
          ["应付租金"] = "50",
        },
        {
          ["加盖次数"] = "1",
          ["地价"] = "100",
          ["应付租金"] = "100",
        },
        {
          ["加盖次数"] = "2",
          ["地价"] = "100",
          ["应付租金"] = "200",
        },
        {
          ["加盖次数"] = "3",
          ["地价"] = "100",
          ["应付租金"] = "400",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["加盖次数"] = 58,
          ["地价"] = 58,
          ["应付租金"] = 58,
        },
        ["source_line"] = 50,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "单块地块按地价和加盖次数计算租金",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "该地块购买价为<地价>",
            ["source_line"] = 51,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "地价",
          },
          ["text"] = "该地块购买价为<地价>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块加盖次数为<加盖次数>",
            ["source_line"] = 52,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "加盖次数",
          },
          ["text"] = "地块加盖次数为<加盖次数>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块属于对手",
            ["source_line"] = 53,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块属于对手",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在该地块",
            ["source_line"] = 54,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家支付租金<应付租金>给对手",
            ["source_line"] = 55,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "应付租金",
          },
          ["text"] = "玩家支付租金<应付租金>给对手",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["各块租金"] = "100,200",
          ["总租金"] = "300",
          ["连片数"] = "2",
          ["验证连片数"] = "2",
        },
        {
          ["各块租金"] = "100,200,400",
          ["总租金"] = "700",
          ["连片数"] = "3",
          ["验证连片数"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["各块租金"] = 72,
          ["总租金"] = 72,
          ["连片数"] = 72,
          ["验证连片数"] = 72,
        },
        ["source_line"] = 64,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "连片地块租金为各块租金之和",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手拥有<连片数>块相邻地块",
            ["source_line"] = 65,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "连片数",
          },
          ["text"] = "对手拥有<连片数>块相邻地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "相邻地块数量为<验证连片数>块",
            ["source_line"] = 66,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "验证连片数",
          },
          ["text"] = "相邻地块数量为<验证连片数>块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "各块租金分别为<各块租金>",
            ["source_line"] = 67,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "各块租金",
          },
          ["text"] = "各块租金分别为<各块租金>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在其中任一块",
            ["source_line"] = 68,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在其中任一块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家支付的租金为<总租金>",
            ["source_line"] = 69,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "总租金",
          },
          ["text"] = "玩家支付的租金为<总租金>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["基础租金"] = "100",
          ["实际租金"] = "200",
          ["神灵条件"] = "租户持有穷神",
        },
        {
          ["基础租金"] = "100",
          ["实际租金"] = "200",
          ["神灵条件"] = "房东持有财神",
        },
        {
          ["基础租金"] = "100",
          ["实际租金"] = "400",
          ["神灵条件"] = "租户持有穷神且房东持有财神",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["基础租金"] = 84,
          ["实际租金"] = 84,
          ["神灵条件"] = 84,
        },
        ["source_line"] = 76,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "神灵倍增租金",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在对手拥有的地块",
            ["source_line"] = 77,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在对手拥有的地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "单块基础租金为<基础租金>",
            ["source_line"] = 78,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "基础租金",
          },
          ["text"] = "单块基础租金为<基础租金>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "<神灵条件>",
            ["source_line"] = 79,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "神灵条件",
          },
          ["text"] = "<神灵条件>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "租金结算执行",
            ["source_line"] = 80,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "租金结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "实际支付租金为<实际租金>",
            ["source_line"] = 81,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "实际租金",
          },
          ["text"] = "实际支付租金为<实际租金>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 89,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "房东在深山时租金不收取",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手拥有一块地块",
            ["source_line"] = 90,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手拥有一块地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手当前在深山状态",
            ["source_line"] = 91,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手当前在深山状态",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在该地块",
            ["source_line"] = 92,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "租金不收取",
            ["source_line"] = 93,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "租金不收取",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "事件日志显示房东在深山",
            ["source_line"] = 94,
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
          ["余额"] = "10000",
          ["税金"] = "5000",
        },
        {
          ["余额"] = "3000",
          ["税金"] = "1500",
        },
        {
          ["余额"] = "1",
          ["税金"] = "0",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["余额"] = 103,
          ["税金"] = 103,
        },
        ["source_line"] = 96,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "税务局按比例收税",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 97,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "余额",
          },
          ["text"] = "玩家持有<余额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "税率为50%",
            ["source_line"] = 98,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "税率为50%",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在税务局格",
            ["source_line"] = 99,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在税务局格",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家被收取<税金>金币",
            ["source_line"] = 100,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "税金",
          },
          ["text"] = "玩家被收取<税金>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 108,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "天使守护不免疫税务局",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有10000金币",
            ["source_line"] = 109,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有10000金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家附有天使守护",
            ["source_line"] = 110,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家附有天使守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "税率为50%",
            ["source_line"] = 111,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "税率为50%",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在税务局格",
            ["source_line"] = 112,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在税务局格",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家被收取5000金币",
            ["source_line"] = 113,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家被收取5000金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 115,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "持有免税卡时弹出使用提示",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在税务局格",
            ["source_line"] = 116,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在税务局格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有免税卡",
            ["source_line"] = 117,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有免税卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 118,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "弹出免税卡使用选择",
            ["source_line"] = 119,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "弹出免税卡使用选择",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "若玩家确认则消耗免税卡并免税",
            ["source_line"] = 120,
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
          ["余额"] = "5000",
          ["地价"] = "2000",
          ["总投入"] = "2000",
          ["等级"] = "0",
          ["累计升级费"] = "0",
          ["验证余额"] = "5000",
          ["验证等级"] = "0",
        },
        {
          ["余额"] = "10000",
          ["地价"] = "2000",
          ["总投入"] = "4500",
          ["等级"] = "2",
          ["累计升级费"] = "2500",
          ["验证余额"] = "10000",
          ["验证等级"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["余额"] = 134,
          ["地价"] = 134,
          ["总投入"] = 134,
          ["等级"] = 134,
          ["累计升级费"] = 134,
          ["验证余额"] = 134,
          ["验证等级"] = 134,
        },
        ["source_line"] = 122,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "强夺卡支付总投入获得对手地块",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手的地块等级为<等级>",
            ["source_line"] = 123,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "等级",
          },
          ["text"] = "对手的地块等级为<等级>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手地块等级为<验证等级>",
            ["source_line"] = 124,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "验证等级",
          },
          ["text"] = "对手地块等级为<验证等级>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块购买价为<地价>",
            ["source_line"] = 125,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "地价",
          },
          ["text"] = "地块购买价为<地价>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "各级累计升级费为<累计升级费>",
            ["source_line"] = 126,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "累计升级费",
          },
          ["text"] = "各级累计升级费为<累计升级费>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 127,
            ["source_path"] = "features/game/economy.feature",
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
            ["source_line"] = 128,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "验证余额",
          },
          ["text"] = "玩家初始余额为<验证余额>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用强夺卡",
            ["source_line"] = 129,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用强夺卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家支付<总投入>金币给对手",
            ["source_line"] = 130,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "总投入",
          },
          ["text"] = "玩家支付<总投入>金币给对手",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块所有权转移给玩家",
            ["source_line"] = 131,
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
        ["source_line"] = 138,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "强夺卡余额不足时无法使用",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手的地块总投入为5000",
            ["source_line"] = 139,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手的地块总投入为5000",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有3000金币",
            ["source_line"] = 140,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有3000金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试使用强夺卡",
            ["source_line"] = 141,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试使用强夺卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "强夺卡不可用",
            ["source_line"] = 142,
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
          ["余额"] = "500",
          ["实收金额"] = "500",
          ["应付租金"] = "1000",
          ["验证应付租金"] = "1000",
        },
        {
          ["余额"] = "0",
          ["实收金额"] = "0",
          ["应付租金"] = "200",
          ["验证应付租金"] = "200",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["余额"] = 153,
          ["实收金额"] = 153,
          ["应付租金"] = 153,
          ["验证应付租金"] = 153,
        },
        ["source_line"] = 144,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "支付租金后资金不足触发破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 145,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "余额",
          },
          ["text"] = "玩家持有<余额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "应付租金为<应付租金>",
            ["source_line"] = 146,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "应付租金",
          },
          ["text"] = "应付租金为<应付租金>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "应付租金记为<验证应付租金>金币",
            ["source_line"] = 147,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "验证应付租金",
          },
          ["text"] = "应付租金记为<验证应付租金>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "租金结算执行",
            ["source_line"] = 148,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "租金结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "房东收到<实收金额>金币",
            ["source_line"] = 149,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {
            "实收金额",
          },
          ["text"] = "房东收到<实收金额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家破产淘汰",
            ["source_line"] = 150,
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
        ["source_line"] = 157,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "余额为零时落在税务局触发破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有0金币",
            ["source_line"] = 158,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有0金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "税率为50%",
            ["source_line"] = 159,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "税率为50%",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在税务局格",
            ["source_line"] = 160,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在税务局格",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "税金为0",
            ["source_line"] = 161,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "税金为0",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家因余额为零而破产淘汰",
            ["source_line"] = 162,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家因余额为零而破产淘汰",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 164,
        ["source_path"] = "features/game/economy.feature",
      },
      ["name"] = "房东已淘汰时租金不收取",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手拥有一块地块",
            ["source_line"] = 165,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手拥有一块地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手已被淘汰",
            ["source_line"] = 166,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手已被淘汰",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在该地块",
            ["source_line"] = 167,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "租金不收取",
            ["source_line"] = 168,
            ["source_path"] = "features/game/economy.feature",
          },
          ["parameters"] = {},
          ["text"] = "租金不收取",
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
