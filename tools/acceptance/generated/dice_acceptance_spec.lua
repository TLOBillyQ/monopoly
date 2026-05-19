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
        ["source_path"] = "features/game/dice.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
    {
      ["keyword"] = "And",
      ["metadata"] = {
        ["original_text"] = "当前玩家准备掷骰",
        ["source_line"] = 7,
        ["source_path"] = "features/game/dice.feature",
      },
      ["parameters"] = {},
      ["text"] = "当前玩家准备掷骰",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 10,
      ["p2"] = 12,
      ["p3"] = 12,
      ["p4"] = 28,
      ["p5"] = 32,
      ["p6"] = 47,
      ["p7"] = 48,
      ["p8"] = 49,
    },
    ["field_names"] = {
      ["p1"] = "骰子数",
      ["p2"] = "最小值",
      ["p3"] = "最大值",
      ["p4"] = "设定值",
      ["p5"] = "总步数",
      ["p6"] = "倍率",
      ["p7"] = "原始点数",
      ["p8"] = "实际步数",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/dice.feature",
  },
  ["name"] = "掷骰子",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["p1"] = "2",
          ["p2"] = "1",
          ["p3"] = "6",
        },
        {
          ["p1"] = "1",
          ["p2"] = "1",
          ["p3"] = "6",
        },
        {
          ["p1"] = "3",
          ["p2"] = "1",
          ["p3"] = "6",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 16,
          ["p2"] = 16,
          ["p3"] = 16,
        },
        ["source_line"] = 9,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "玩家掷骰获得随机点数",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家的骰子数量为<骰子数>",
            ["source_line"] = 10,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家的骰子数量为<p1>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰",
            ["source_line"] = 11,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家掷骰",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "每颗骰子的结果在<最小值>到<最大值>之间",
            ["source_line"] = 12,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "p2",
            "p3",
          },
          ["text"] = "每颗骰子的结果在<p2>到<p3>之间",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "移动步数等于所有骰子结果之和",
            ["source_line"] = 13,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "移动步数等于所有骰子结果之和",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 21,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "掷骰结果记录到事件日志",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家名为小明",
            ["source_line"] = 22,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家名为小明",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰得到结果3和5",
            ["source_line"] = 23,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家掷骰得到结果3和5",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "事件日志包含投骰记录",
            ["source_line"] = 24,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "事件日志包含投骰记录",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "记录显示各骰子值和总数8",
            ["source_line"] = 25,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "记录显示各骰子值和总数8",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "2",
          ["p4"] = "6",
          ["p5"] = "12",
        },
        {
          ["p1"] = "2",
          ["p4"] = "3",
          ["p5"] = "6",
        },
        {
          ["p1"] = "1",
          ["p4"] = "1",
          ["p5"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 35,
          ["p4"] = 35,
          ["p5"] = 35,
        },
        ["source_line"] = 27,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "遥控骰子覆盖随机结果",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用了遥控骰子设定点数为<设定值>",
            ["source_line"] = 28,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家使用了遥控骰子设定点数为<p4>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家的骰子数量为<骰子数>",
            ["source_line"] = 29,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家的骰子数量为<p1>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰",
            ["source_line"] = 30,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家掷骰",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "每颗骰子结果均为<设定值>",
            ["source_line"] = 31,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "每颗骰子结果均为<p4>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "移动步数为<总步数>",
            ["source_line"] = 32,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "移动步数为<p5>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 40,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "遥控骰子使用后消耗",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用了遥控骰子设定点数为5",
            ["source_line"] = 41,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用了遥控骰子设定点数为5",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰",
            ["source_line"] = 42,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家掷骰",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "遥控骰子效果被消耗",
            ["source_line"] = 43,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "遥控骰子效果被消耗",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "下次掷骰恢复随机",
            ["source_line"] = 44,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "下次掷骰恢复随机",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p6"] = "2",
          ["p7"] = "4",
          ["p8"] = "8",
        },
        {
          ["p6"] = "3",
          ["p7"] = "3",
          ["p8"] = "9",
        },
        {
          ["p6"] = "4",
          ["p7"] = "2",
          ["p8"] = "8",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p6"] = 53,
          ["p7"] = 53,
          ["p8"] = 53,
        },
        ["source_line"] = 46,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "骰子加倍卡倍增移动步数",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有骰子加倍卡且倍率为<倍率>",
            ["source_line"] = 47,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "玩家持有骰子加倍卡且倍率为<p6>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰得到原始点数<原始点数>",
            ["source_line"] = 48,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "p7",
          },
          ["text"] = "玩家掷骰得到原始点数<p7>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "实际移动步数为<实际步数>",
            ["source_line"] = 49,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "p8",
          },
          ["text"] = "实际移动步数为<p8>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "加倍卡效果消耗后倍率重置为1",
            ["source_line"] = 50,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "加倍卡效果消耗后倍率重置为1",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 58,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "骰子加倍卡不影响遥控骰子设定值",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用了遥控骰子设定点数为6",
            ["source_line"] = 59,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用了遥控骰子设定点数为6",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有骰子加倍卡且倍率为2",
            ["source_line"] = 60,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有骰子加倍卡且倍率为2",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰",
            ["source_line"] = 61,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家掷骰",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "每颗骰子结果为6",
            ["source_line"] = 62,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "每颗骰子结果为6",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "实际移动步数为24",
            ["source_line"] = 63,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "实际移动步数为24",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 65,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "无加倍卡时步数等于原始点数",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家没有骰子加倍卡",
            ["source_line"] = 66,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家没有骰子加倍卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰得到原始点数7",
            ["source_line"] = 67,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家掷骰得到原始点数7",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "实际移动步数为7",
            ["source_line"] = 68,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "实际移动步数为7",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
