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
      ["倍率"] = 48,
      ["原始点数"] = 49,
      ["实际步数"] = 50,
      ["总步数"] = 33,
      ["最大值"] = 12,
      ["最小值"] = 12,
      ["设定值"] = 29,
      ["验证骰子数"] = 14,
      ["骰子数"] = 10,
    },
    ["field_names"] = {
      ["倍率"] = "倍率",
      ["原始点数"] = "原始点数",
      ["实际步数"] = "实际步数",
      ["总步数"] = "总步数",
      ["最大值"] = "最大值",
      ["最小值"] = "最小值",
      ["设定值"] = "设定值",
      ["验证骰子数"] = "验证骰子数",
      ["骰子数"] = "骰子数",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/dice.feature",
  },
  ["name"] = "掷骰子",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["最大值"] = "6",
          ["最小值"] = "1",
          ["验证骰子数"] = "2",
          ["骰子数"] = "2",
        },
        {
          ["最大值"] = "6",
          ["最小值"] = "1",
          ["验证骰子数"] = "1",
          ["骰子数"] = "1",
        },
        {
          ["最大值"] = "6",
          ["最小值"] = "1",
          ["验证骰子数"] = "3",
          ["骰子数"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["最大值"] = 17,
          ["最小值"] = 17,
          ["验证骰子数"] = 17,
          ["骰子数"] = 17,
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
            "骰子数",
          },
          ["text"] = "玩家的骰子数量为<骰子数>",
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
            "最小值",
            "最大值",
          },
          ["text"] = "每颗骰子的结果在<最小值>到<最大值>之间",
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
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "掷出骰子数为<验证骰子数>颗",
            ["source_line"] = 14,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "验证骰子数",
          },
          ["text"] = "掷出骰子数为<验证骰子数>颗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 22,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "掷骰结果记录到事件日志",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家名为小明",
            ["source_line"] = 23,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家名为小明",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰得到结果3和5",
            ["source_line"] = 24,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家掷骰得到结果3和5",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "事件日志包含投骰记录",
            ["source_line"] = 25,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "事件日志包含投骰记录",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "记录显示各骰子值和总数8",
            ["source_line"] = 26,
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
          ["总步数"] = "12",
          ["设定值"] = "6",
          ["骰子数"] = "2",
        },
        {
          ["总步数"] = "6",
          ["设定值"] = "3",
          ["骰子数"] = "2",
        },
        {
          ["总步数"] = "1",
          ["设定值"] = "1",
          ["骰子数"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["总步数"] = 36,
          ["设定值"] = 36,
          ["骰子数"] = 36,
        },
        ["source_line"] = 28,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "遥控骰子覆盖随机结果",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用了遥控骰子设定点数为<设定值>",
            ["source_line"] = 29,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "设定值",
          },
          ["text"] = "玩家使用了遥控骰子设定点数为<设定值>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家的骰子数量为<骰子数>",
            ["source_line"] = 30,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "骰子数",
          },
          ["text"] = "玩家的骰子数量为<骰子数>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰",
            ["source_line"] = 31,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家掷骰",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "每颗骰子结果均为<设定值>",
            ["source_line"] = 32,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "设定值",
          },
          ["text"] = "每颗骰子结果均为<设定值>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "移动步数为<总步数>",
            ["source_line"] = 33,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "总步数",
          },
          ["text"] = "移动步数为<总步数>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 41,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "遥控骰子使用后消耗",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用了遥控骰子设定点数为5",
            ["source_line"] = 42,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用了遥控骰子设定点数为5",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰",
            ["source_line"] = 43,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家掷骰",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "遥控骰子效果被消耗",
            ["source_line"] = 44,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "遥控骰子效果被消耗",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "下次掷骰恢复随机",
            ["source_line"] = 45,
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
          ["倍率"] = "2",
          ["原始点数"] = "4",
          ["实际步数"] = "8",
        },
        {
          ["倍率"] = "3",
          ["原始点数"] = "3",
          ["实际步数"] = "9",
        },
        {
          ["倍率"] = "4",
          ["原始点数"] = "2",
          ["实际步数"] = "8",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["倍率"] = 54,
          ["原始点数"] = 54,
          ["实际步数"] = 54,
        },
        ["source_line"] = 47,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "骰子加倍卡倍增移动步数",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有骰子加倍卡且倍率为<倍率>",
            ["source_line"] = 48,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "倍率",
          },
          ["text"] = "玩家持有骰子加倍卡且倍率为<倍率>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰得到原始点数<原始点数>",
            ["source_line"] = 49,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "原始点数",
          },
          ["text"] = "玩家掷骰得到原始点数<原始点数>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "实际移动步数为<实际步数>",
            ["source_line"] = 50,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {
            "实际步数",
          },
          ["text"] = "实际移动步数为<实际步数>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "加倍卡效果消耗后倍率重置为1",
            ["source_line"] = 51,
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
        ["source_line"] = 59,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "骰子加倍卡不影响遥控骰子设定值",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用了遥控骰子设定点数为6",
            ["source_line"] = 60,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用了遥控骰子设定点数为6",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有骰子加倍卡且倍率为2",
            ["source_line"] = 61,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有骰子加倍卡且倍率为2",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰",
            ["source_line"] = 62,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家掷骰",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "每颗骰子结果为6",
            ["source_line"] = 63,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "每颗骰子结果为6",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "实际移动步数为24",
            ["source_line"] = 64,
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
        ["source_line"] = 66,
        ["source_path"] = "features/game/dice.feature",
      },
      ["name"] = "无加倍卡时步数等于原始点数",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家没有骰子加倍卡",
            ["source_line"] = 67,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家没有骰子加倍卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷骰得到原始点数7",
            ["source_line"] = 68,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家掷骰得到原始点数7",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "实际移动步数为7",
            ["source_line"] = 69,
            ["source_path"] = "features/game/dice.feature",
          },
          ["parameters"] = {},
          ["text"] = "实际移动步数为7",
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
