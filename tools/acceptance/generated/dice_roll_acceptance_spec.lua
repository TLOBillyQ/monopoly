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
        ["source_path"] = "features/game/dice_roll.feature",
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
      ["p4"] = 21,
      ["p5"] = 24,
    },
    ["field_names"] = {
      ["p1"] = "起始位置",
      ["p2"] = "点数",
      ["p3"] = "期望位置",
      ["p4"] = "格数",
      ["p5"] = "经过起点次数",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/dice_roll.feature",
  },
  ["name"] = "骰子投掷",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["p1"] = "0",
          ["p2"] = "3",
          ["p3"] = "3",
        },
        {
          ["p1"] = "5",
          ["p2"] = "7",
          ["p3"] = "12",
        },
        {
          ["p1"] = "13",
          ["p2"] = "3",
          ["p3"] = "16",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 14,
          ["p2"] = 14,
          ["p3"] = 14,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/game/dice_roll.feature",
      },
      ["name"] = "玩家掷骰子前进",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "当前玩家位于位置<起始位置>",
            ["source_line"] = 9,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "当前玩家位于位置<p1>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷出<点数>",
            ["source_line"] = 10,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家掷出<p2>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家位于位置<期望位置>",
            ["source_line"] = 11,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "玩家位于位置<p3>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "27",
          ["p2"] = "5",
          ["p3"] = "0",
          ["p4"] = "32",
          ["p5"] = "1",
        },
        {
          ["p1"] = "29",
          ["p2"] = "3",
          ["p3"] = "0",
          ["p4"] = "32",
          ["p5"] = "1",
        },
        {
          ["p1"] = "25",
          ["p2"] = "9",
          ["p3"] = "2",
          ["p4"] = "32",
          ["p5"] = "1",
        },
        {
          ["p1"] = "0",
          ["p2"] = "3",
          ["p3"] = "3",
          ["p4"] = "32",
          ["p5"] = "0",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 27,
          ["p2"] = 27,
          ["p3"] = 27,
          ["p4"] = 27,
          ["p5"] = 27,
        },
        ["source_line"] = 19,
        ["source_path"] = "features/game/dice_roll.feature",
      },
      ["name"] = "玩家前进超过起点时绕圈",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "当前玩家位于位置<起始位置>",
            ["source_line"] = 20,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "当前玩家位于位置<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "棋盘共有<格数>格",
            ["source_line"] = 21,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "棋盘共有<p4>格",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷出<点数>",
            ["source_line"] = 22,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家掷出<p2>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家位于位置<期望位置>",
            ["source_line"] = 23,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "玩家位于位置<p3>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家经过起点<经过起点次数>次",
            ["source_line"] = 24,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "玩家经过起点<p5>次",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
