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
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 9,
      ["p2"] = 10,
      ["p3"] = 11,
    },
    ["field_names"] = {
      ["p1"] = "余额",
      ["p2"] = "金额",
      ["p3"] = "结果",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/bankruptcy.feature",
  },
  ["name"] = "破产判定",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["p1"] = "100",
          ["p2"] = "200",
          ["p3"] = "破产",
        },
        {
          ["p1"] = "500",
          ["p2"] = "200",
          ["p3"] = "存活",
        },
        {
          ["p1"] = "0",
          ["p2"] = "100",
          ["p3"] = "破产",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 14,
          ["p2"] = 14,
          ["p3"] = 14,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["name"] = "支付超过余额时破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 9,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家持有<p1>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家需要支付<金额>",
            ["source_line"] = 10,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家需要支付<p2>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家<结果>",
            ["source_line"] = 11,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "玩家<p3>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 19,
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["name"] = "机会卡支付他人效果中途破产则停止后续支付",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有800金币",
            ["source_line"] = 20,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有800金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为向每位玩家支付500金币",
            ["source_line"] = 21,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡效果为向每位玩家支付500金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏中有3名未淘汰对手",
            ["source_line"] = 22,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏中有3名未淘汰对手",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 23,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家向第一位对手支付500金币后破产",
            ["source_line"] = 24,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家向第一位对手支付500金币后破产",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "后续对手不再收到支付",
            ["source_line"] = 25,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "后续对手不再收到支付",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 27,
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["name"] = "机会卡收取他人效果中无力支付者破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为向每位玩家收取1000金币",
            ["source_line"] = 28,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡效果为向每位玩家收取1000金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手A持有500金币",
            ["source_line"] = 29,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手A持有500金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 30,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "对手A支付全部500金币后破产淘汰",
            ["source_line"] = 31,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手A支付全部500金币后破产淘汰",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家收到对手A的500金币",
            ["source_line"] = 32,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家收到对手A的500金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 34,
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["name"] = "落在医院费用不足触发破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有0金币",
            ["source_line"] = 35,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有0金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家因效果被送往医院且需支付住院费",
            ["source_line"] = 36,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家因效果被送往医院且需支付住院费",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家破产淘汰",
            ["source_line"] = 37,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家破产淘汰",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
