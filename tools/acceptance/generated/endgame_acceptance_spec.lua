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
        ["source_path"] = "features/game/endgame.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 9,
      ["p2"] = 10,
      ["p3"] = 21,
      ["p4"] = 23,
      ["p5"] = 40,
      ["p6"] = 41,
      ["p7"] = 43,
      ["p8"] = 74,
      ["p9"] = 77,
    },
    ["field_names"] = {
      ["p1"] = "玩家人数",
      ["p2"] = "淘汰人数",
      ["p3"] = "回合上限",
      ["p4"] = "资产列表",
      ["p5"] = "现金",
      ["p6"] = "地块投入",
      ["p7"] = "总资产",
      ["p8"] = "格子类型",
      ["p9"] = "停留回合",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/endgame.feature",
  },
  ["name"] = "终局与淘汰",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["p1"] = "4",
          ["p2"] = "3",
        },
        {
          ["p1"] = "2",
          ["p2"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 16,
          ["p2"] = 16,
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
            "p1",
          },
          ["text"] = "游戏有<p1>名玩家",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "<淘汰人数>名玩家已被淘汰",
            ["source_line"] = 10,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "<p2>名玩家已被淘汰",
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
          ["p3"] = "1000",
          ["p4"] = "50000,30000,20000",
        },
        {
          ["p3"] = "1000",
          ["p4"] = "80000,40000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p3"] = 29,
          ["p4"] = 29,
        },
        ["source_line"] = 20,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "回合数达到上限时资产最高者获胜",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "回合上限为<回合上限>",
            ["source_line"] = 21,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "回合上限为<p3>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前回合数为<回合上限>",
            ["source_line"] = 22,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前回合数为<p3>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "存活玩家的总资产分别为<资产列表>",
            ["source_line"] = 23,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "存活玩家的总资产分别为<p4>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "胜利条件检查执行",
            ["source_line"] = 24,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "胜利条件检查执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "资产最高的玩家获胜",
            ["source_line"] = 25,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "资产最高的玩家获胜",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏标记为已结束",
            ["source_line"] = 26,
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
        ["source_line"] = 33,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "回合上限时资产相同则并列获胜",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "回合上限到达",
            ["source_line"] = 34,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "回合上限到达",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "两名玩家总资产相同且为最高",
            ["source_line"] = 35,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "两名玩家总资产相同且为最高",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "胜利条件检查执行",
            ["source_line"] = 36,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "胜利条件检查执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "两名玩家并列获胜",
            ["source_line"] = 37,
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
          ["p5"] = "10000",
          ["p6"] = "5000",
          ["p7"] = "15000",
        },
        {
          ["p5"] = "0",
          ["p6"] = "20000",
          ["p7"] = "20000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p5"] = 46,
          ["p6"] = 46,
          ["p7"] = 46,
        },
        ["source_line"] = 39,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "总资产等于现金加地块总投入",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<现金>金币",
            ["source_line"] = 40,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "玩家持有<p5>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家拥有地块总投入为<地块投入>",
            ["source_line"] = 41,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "玩家拥有地块总投入为<p6>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "计算总资产",
            ["source_line"] = 42,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "计算总资产",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "总资产为<总资产>",
            ["source_line"] = 43,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "p7",
          },
          ["text"] = "总资产为<p7>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 50,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "破产淘汰清空地块所有权",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家拥有3块地块",
            ["source_line"] = 51,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家拥有3块地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "执行破产淘汰清算",
            ["source_line"] = 52,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "执行破产淘汰清算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家的所有地块重置为无主",
            ["source_line"] = 53,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的所有地块重置为无主",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块等级重置为0",
            ["source_line"] = 54,
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
        ["source_line"] = 56,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "破产淘汰清空背包和神灵",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有道具且附有神灵",
            ["source_line"] = 57,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有道具且附有神灵",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "执行破产淘汰清算",
            ["source_line"] = 58,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "执行破产淘汰清算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家的背包被清空",
            ["source_line"] = 59,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的背包被清空",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家的神灵被移除",
            ["source_line"] = 60,
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
        ["source_line"] = 62,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "已淘汰玩家从所有格子占位中移除",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家位于格子5",
            ["source_line"] = 63,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家位于格子5",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "执行破产淘汰清算",
            ["source_line"] = 64,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "执行破产淘汰清算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "格子5的占位列表不再包含该玩家",
            ["source_line"] = 65,
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
        ["source_line"] = 67,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "游戏结束后不再检查胜利条件",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "游戏已标记为结束",
            ["source_line"] = 68,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏已标记为结束",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "再次检查胜利条件",
            ["source_line"] = 69,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "再次检查胜利条件",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "直接返回已结束状态",
            ["source_line"] = 70,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "直接返回已结束状态",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "不重复判定胜者",
            ["source_line"] = 71,
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
          ["p8"] = "医院",
          ["p9"] = "2",
        },
        {
          ["p8"] = "深山",
          ["p9"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p8"] = 80,
          ["p9"] = 80,
        },
        ["source_line"] = 73,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "落在医院或深山触发停留",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在<格子类型>",
            ["source_line"] = 74,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "p8",
          },
          ["text"] = "玩家落在<p8>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家无天使守护",
            ["source_line"] = 75,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家无天使守护",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地效果执行",
            ["source_line"] = 76,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地效果执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家被扣留<停留回合>回合",
            ["source_line"] = 77,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {
            "p9",
          },
          ["text"] = "玩家被扣留<p9>回合",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 84,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "天使守护免疫医院和深山停留",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家拥有天使守护",
            ["source_line"] = 85,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家拥有天使守护",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家落在医院或深山",
            ["source_line"] = 86,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在医院或深山",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家不被扣留",
            ["source_line"] = 87,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家不被扣留",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "天使守护抵消提示",
            ["source_line"] = 88,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "天使守护抵消提示",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 90,
        ["source_path"] = "features/game/endgame.feature",
      },
      ["name"] = "回合上限时所有玩家均已淘汰则无人获胜",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "回合上限到达",
            ["source_line"] = 91,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "回合上限到达",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "所有玩家均已被淘汰",
            ["source_line"] = 92,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "所有玩家均已被淘汰",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "胜利条件检查执行",
            ["source_line"] = 93,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "胜利条件检查执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "获胜者列表为空",
            ["source_line"] = 94,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "获胜者列表为空",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏标记为已结束",
            ["source_line"] = 95,
            ["source_path"] = "features/game/endgame.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏标记为已结束",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
