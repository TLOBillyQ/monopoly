-- luacheck: globals describe it
local runtime = require("acceptance.runtime")
local steps = require("acceptance.steps")

local ir = {
  ["background"] = {
    {
      ["keyword"] = "Given",
      ["metadata"] = {
        ["original_text"] = "游戏已开始",
        ["source_line"] = 6,
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已开始",
    },
    {
      ["keyword"] = "And",
      ["metadata"] = {
        ["original_text"] = "玩家持有初始资金",
        ["source_line"] = 7,
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["parameters"] = {},
      ["text"] = "玩家持有初始资金",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 10,
      ["p2"] = 11,
      ["p3"] = 12,
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
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 15,
          ["p2"] = 15,
          ["p3"] = 15,
        },
        ["source_line"] = 9,
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["name"] = "玩家资金不足时破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家余额为<余额>",
            ["source_line"] = 10,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家余额为<p1>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家需要支付<金额>",
            ["source_line"] = 11,
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
            ["source_line"] = 12,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "玩家<p3>",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
