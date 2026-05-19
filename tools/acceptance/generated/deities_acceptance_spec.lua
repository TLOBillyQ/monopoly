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
        ["source_path"] = "features/game/deities.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 9,
      ["p2"] = 9,
      ["p3"] = 27,
    },
    ["field_names"] = {
      ["p1"] = "神灵",
      ["p2"] = "持续回合",
      ["p3"] = "道具",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/deities.feature",
  },
  ["name"] = "神灵系统",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["p1"] = "财神",
          ["p2"] = "3",
        },
        {
          ["p1"] = "穷神",
          ["p2"] = "5",
        },
        {
          ["p1"] = "天使",
          ["p2"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 14,
          ["p2"] = 14,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/game/deities.feature",
      },
      ["name"] = "神灵在有效回合结束后自动消失",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家1附体<神灵>持续<持续回合>回合",
            ["source_line"] = 9,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {
            "p1",
            "p2",
          },
          ["text"] = "玩家1附体<p1>持续<p2>回合",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家1的回合结束<持续回合>次",
            ["source_line"] = 10,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家1的回合结束<p2>次",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家1不再持有任何神灵",
            ["source_line"] = 11,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家1不再持有任何神灵",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 19,
        ["source_path"] = "features/game/deities.feature",
      },
      ["name"] = "淘汰玩家的神灵不随回合递减",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家2附体穷神持续3回合",
            ["source_line"] = 20,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2附体穷神持续3回合",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家2已被淘汰",
            ["source_line"] = 21,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2已被淘汰",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "游戏进行一个完整回合",
            ["source_line"] = 22,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏进行一个完整回合",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家2的神灵剩余回合仍为3",
            ["source_line"] = 23,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2的神灵剩余回合仍为3",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p3"] = "均富卡",
        },
        {
          ["p3"] = "偷窃卡",
        },
        {
          ["p3"] = "查税卡",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p3"] = 32,
        },
        ["source_line"] = 25,
        ["source_path"] = "features/game/deities.feature",
      },
      ["name"] = "天使守护免疫针对玩家的负面道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家2附体天使",
            ["source_line"] = 26,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2附体天使",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家1对玩家2使用<道具>",
            ["source_line"] = 27,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "玩家1对玩家2使用<p3>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具效果被阻断",
            ["source_line"] = 28,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具效果被阻断",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "系统记录天使保护事件",
            ["source_line"] = 29,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "系统记录天使保护事件",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 37,
        ["source_path"] = "features/game/deities.feature",
      },
      ["name"] = "天使守护免疫地雷",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家2附体天使",
            ["source_line"] = 38,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2附体天使",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前棋盘存在地雷",
            ["source_line"] = 39,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前棋盘存在地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家2落在地雷格",
            ["source_line"] = 40,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2落在地雷格",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地雷不触发",
            ["source_line"] = 41,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "地雷不触发",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家2不进医院",
            ["source_line"] = 42,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2不进医院",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
