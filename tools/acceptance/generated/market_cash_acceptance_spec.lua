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
        ["source_path"] = "features/v102/market_cash.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 9,
      ["p2"] = 10,
      ["p3"] = 12,
    },
    ["field_names"] = {
      ["p1"] = "角色ID",
      ["p2"] = "设置金额",
      ["p3"] = "显示金额",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/v102/market_cash.feature",
  },
  ["name"] = "黑市现金显示",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "1000",
          ["p3"] = "1000",
        },
        {
          ["p1"] = "1",
          ["p2"] = "500",
          ["p3"] = "500",
        },
        {
          ["p1"] = "2",
          ["p2"] = "3000",
          ["p3"] = "3000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 15,
          ["p2"] = 15,
          ["p3"] = 15,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/v102/market_cash.feature",
      },
      ["name"] = "黑市开启时显示操作玩家当前现金",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 9,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家当前现金为<设置金额>",
            ["source_line"] = 10,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家当前现金为<p2>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "黑市向玩家开放",
            ["source_line"] = 11,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市向玩家开放",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "黑市现金显示区显示金额<显示金额>",
            ["source_line"] = 12,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "黑市现金显示区显示金额<p3>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "0",
          ["p3"] = "0",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 27,
          ["p2"] = 27,
          ["p3"] = 27,
        },
        ["source_line"] = 20,
        ["source_path"] = "features/v102/market_cash.feature",
      },
      ["name"] = "现金不足时黑市仍可开启",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 21,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家当前现金为<设置金额>",
            ["source_line"] = 22,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家当前现金为<p2>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "黑市向玩家开放",
            ["source_line"] = 23,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市向玩家开放",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "黑市现金显示区显示金额<显示金额>",
            ["source_line"] = 24,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "黑市现金显示区显示金额<p3>",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
