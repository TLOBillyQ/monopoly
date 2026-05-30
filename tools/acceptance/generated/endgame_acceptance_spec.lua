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
        ["source_path"] = "features/game/endgame.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["停留回合"] = 79,
      ["地块投入"] = 44,
      ["总资产"] = 46,
      ["时间上限"] = 21,
      ["格子类型"] = 77,
      ["淘汰人数"] = 10,
      ["玩家人数"] = 9,
      ["现金"] = 43,
      ["资产列表"] = 24,
      ["验证时间上限"] = 23,
      ["验证最高资产"] = 28,
      ["验证资产列表"] = 25,
    },
    ["field_names"] = {
      ["停留回合"] = "停留回合",
      ["地块投入"] = "地块投入",
      ["总资产"] = "总资产",
      ["时间上限"] = "时间上限",
      ["格子类型"] = "格子类型",
      ["淘汰人数"] = "淘汰人数",
      ["玩家人数"] = "玩家人数",
      ["现金"] = "现金",
      ["资产列表"] = "资产列表",
      ["验证时间上限"] = "验证时间上限",
      ["验证最高资产"] = "验证最高资产",
      ["验证资产列表"] = "验证资产列表",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/endgame.feature",
  },
  ["name"] = "终局与淘汰",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["淘汰人数"] = "3",
          ["玩家人数"] = "4",
        },
        {
          ["淘汰人数"] = "1",
          ["玩家人数"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["淘汰人数"] = 16,
          ["玩家人数"] = 16,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "仅剩一名玩家时该玩家获胜",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "游戏有<玩家人数>名玩家",
            ["source_line"] = 9,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "玩家人数",
          },
          ["text"] = "游戏有<玩家人数>名玩家",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "<淘汰人数>名玩家已被淘汰",
            ["source_line"] = 10,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "淘汰人数",
          },
          ["text"] = "<淘汰人数>名玩家已被淘汰",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "胜利条件检查执行",
            ["source_line"] = 11,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "胜利条件检查执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "唯一存活玩家获胜",
            ["source_line"] = 12,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "唯一存活玩家获胜",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏标记为已结束",
            ["source_line"] = 13,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏标记为已结束",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["时间上限"] = "900",
          ["资产列表"] = "50000,30000,20000",
          ["验证时间上限"] = "900",
          ["验证最高资产"] = "50000",
          ["验证资产列表"] = "50000,30000,20000",
        },
        {
          ["时间上限"] = "900",
          ["资产列表"] = "80000,40000",
          ["验证时间上限"] = "900",
          ["验证最高资产"] = "80000",
          ["验证资产列表"] = "80000,40000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["时间上限"] = 32,
          ["资产列表"] = 32,
          ["验证时间上限"] = 32,
          ["验证最高资产"] = 32,
          ["验证资产列表"] = 32,
        },
        ["source_line"] = 20,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "游戏时间结束时资产最高者获胜",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "游戏时间上限为<时间上限>秒",
            ["source_line"] = 21,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "时间上限",
          },
          ["text"] = "游戏时间上限为<时间上限>秒",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前游戏时间已达到<时间上限>秒",
            ["source_line"] = 22,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "时间上限",
          },
          ["text"] = "当前游戏时间已达到<时间上限>秒",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏时间上限记录为<验证时间上限>秒",
            ["source_line"] = 23,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "验证时间上限",
          },
          ["text"] = "游戏时间上限记录为<验证时间上限>秒",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "存活玩家的总资产分别为<资产列表>",
            ["source_line"] = 24,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "资产列表",
          },
          ["text"] = "存活玩家的总资产分别为<资产列表>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "存活玩家资产逐一为<验证资产列表>",
            ["source_line"] = 25,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "验证资产列表",
          },
          ["text"] = "存活玩家资产逐一为<验证资产列表>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "胜利条件检查执行",
            ["source_line"] = 26,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "胜利条件检查执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "资产最高的玩家获胜",
            ["source_line"] = 27,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "资产最高的玩家获胜",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "获胜者资产为<验证最高资产>",
            ["source_line"] = 28,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "验证最高资产",
          },
          ["text"] = "获胜者资产为<验证最高资产>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏标记为已结束",
            ["source_line"] = 29,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏标记为已结束",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 36,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "游戏时间结束时资产相同则并列获胜",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "游戏时间已结束",
            ["source_line"] = 37,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏时间已结束",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "两名玩家总资产相同且为最高",
            ["source_line"] = 38,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "两名玩家总资产相同且为最高",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "胜利条件检查执行",
            ["source_line"] = 39,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "胜利条件检查执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "两名玩家并列获胜",
            ["source_line"] = 40,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "两名玩家并列获胜",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["地块投入"] = "5000",
          ["总资产"] = "15000",
          ["现金"] = "10000",
        },
        {
          ["地块投入"] = "20000",
          ["总资产"] = "20000",
          ["现金"] = "0",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["地块投入"] = 49,
          ["总资产"] = 49,
          ["现金"] = 49,
        },
        ["source_line"] = 42,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "总资产等于现金加地块总投入",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<现金>金币",
            ["source_line"] = 43,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "现金",
          },
          ["text"] = "玩家持有<现金>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家拥有地块总投入为<地块投入>",
            ["source_line"] = 44,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "地块投入",
          },
          ["text"] = "玩家拥有地块总投入为<地块投入>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "计算总资产",
            ["source_line"] = 45,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "计算总资产",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "总资产为<总资产>",
            ["source_line"] = 46,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "总资产",
          },
          ["text"] = "总资产为<总资产>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 53,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "破产淘汰清空地块所有权",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家拥有3块地块",
            ["source_line"] = 54,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家拥有3块地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "执行破产淘汰清算",
            ["source_line"] = 55,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "执行破产淘汰清算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家的所有地块重置为无主",
            ["source_line"] = 56,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的所有地块重置为无主",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块等级重置为0",
            ["source_line"] = 57,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块等级重置为0",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 59,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "破产淘汰清空背包和神灵",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有道具且附有神灵",
            ["source_line"] = 60,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有道具且附有神灵",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "执行破产淘汰清算",
            ["source_line"] = 61,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "执行破产淘汰清算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家的背包被清空",
            ["source_line"] = 62,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的背包被清空",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家的神灵被移除",
            ["source_line"] = 63,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的神灵被移除",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 65,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "已淘汰玩家从所有格子占位中移除",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家位于格子5",
            ["source_line"] = 66,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家位于格子5",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "执行破产淘汰清算",
            ["source_line"] = 67,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "执行破产淘汰清算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "格子5的占位列表不再包含该玩家",
            ["source_line"] = 68,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "格子5的占位列表不再包含该玩家",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 70,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "游戏结束后不再检查胜利条件",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "游戏已标记为结束",
            ["source_line"] = 71,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏已标记为结束",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "再次检查胜利条件",
            ["source_line"] = 72,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "再次检查胜利条件",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "直接返回已结束状态",
            ["source_line"] = 73,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "直接返回已结束状态",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "不重复判定胜者",
            ["source_line"] = 74,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "不重复判定胜者",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["停留回合"] = "2",
          ["格子类型"] = "医院",
        },
        {
          ["停留回合"] = "2",
          ["格子类型"] = "深山",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["停留回合"] = 82,
          ["格子类型"] = 82,
        },
        ["source_line"] = 76,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "落在医院或深山触发停留",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在<格子类型>",
            ["source_line"] = 77,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "格子类型",
          },
          ["text"] = "玩家落在<格子类型>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地效果执行",
            ["source_line"] = 78,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地效果执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家被扣留<停留回合>回合",
            ["source_line"] = 79,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "停留回合",
          },
          ["text"] = "玩家被扣留<停留回合>回合",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 86,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "落在医院时先支付5000金币医药费",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有10000金币",
            ["source_line"] = 87,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有10000金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在医院格",
            ["source_line"] = 88,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在医院格",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家支付5000金币医药费",
            ["source_line"] = 89,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家支付5000金币医药费",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家需停留2回合",
            ["source_line"] = 90,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家需停留2回合",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["格子类型"] = "医院",
        },
        {
          ["格子类型"] = "深山",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["格子类型"] = 99,
        },
        ["source_line"] = 92,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "天使守护不免疫医院和深山停留",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家拥有天使守护",
            ["source_line"] = 93,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家拥有天使守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家落在<格子类型>",
            ["source_line"] = 94,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "格子类型",
          },
          ["text"] = "玩家落在<格子类型>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地效果执行",
            ["source_line"] = 95,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地效果执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家被扣留2回合",
            ["source_line"] = 96,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家被扣留2回合",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 103,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "游戏时间结束时所有玩家均已淘汰则无人获胜",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "游戏时间已结束",
            ["source_line"] = 104,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏时间已结束",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "所有玩家均已被淘汰",
            ["source_line"] = 105,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "所有玩家均已被淘汰",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "胜利条件检查执行",
            ["source_line"] = 106,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "胜利条件检查执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "获胜者列表为空",
            ["source_line"] = 107,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "获胜者列表为空",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏标记为已结束",
            ["source_line"] = 108,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏标记为已结束",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 110,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "获胜玩家看到胜利结算面板",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "游戏已结束",
            ["source_line"] = 111,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏已结束",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家是获胜者",
            ["source_line"] = 112,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家是获胜者",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "结算画面显示",
            ["source_line"] = 113,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "结算画面显示",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家进入胜利结算面板",
            ["source_line"] = 114,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家进入胜利结算面板",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 116,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "落败玩家看到失败结算面板",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "游戏已结束",
            ["source_line"] = 117,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏已结束",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家不是获胜者",
            ["source_line"] = 118,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家不是获胜者",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "结算画面显示",
            ["source_line"] = 119,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "结算画面显示",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家进入失败结算面板",
            ["source_line"] = 120,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家进入失败结算面板",
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
