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
        ["source_path"] = "features/game/dice_roll.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["步数"] = 10,
      ["目标位置"] = 11,
      ["起始位置"] = 9,
      ["距离"] = 24,
      ["途经格数"] = 21,
    },
    ["field_names"] = {
      ["步数"] = "步数",
      ["目标位置"] = "目标位置",
      ["起始位置"] = "起始位置",
      ["距离"] = "距离",
      ["途经格数"] = "途经格数",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/dice_roll.feature",
  },
  ["name"] = "骰子投掷",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["步数"] = "3",
          ["目标位置"] = "3",
          ["起始位置"] = "0",
        },
        {
          ["步数"] = "7",
          ["目标位置"] = "12",
          ["起始位置"] = "5",
        },
        {
          ["步数"] = "3",
          ["目标位置"] = "16",
          ["起始位置"] = "13",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["步数"] = 14,
          ["目标位置"] = 14,
          ["起始位置"] = 14,
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
            "起始位置",
          },
          ["text"] = "当前玩家位于位置<起始位置>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷出<步数>",
            ["source_line"] = 10,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "步数",
          },
          ["text"] = "玩家掷出<步数>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家位于位置<目标位置>",
            ["source_line"] = 11,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "目标位置",
          },
          ["text"] = "玩家位于位置<目标位置>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["步数"] = "5",
          ["目标位置"] = "0",
          ["起始位置"] = "27",
          ["距离"] = "1",
          ["途经格数"] = "32",
        },
        {
          ["步数"] = "3",
          ["目标位置"] = "0",
          ["起始位置"] = "29",
          ["距离"] = "1",
          ["途经格数"] = "32",
        },
        {
          ["步数"] = "9",
          ["目标位置"] = "2",
          ["起始位置"] = "25",
          ["距离"] = "1",
          ["途经格数"] = "32",
        },
        {
          ["步数"] = "3",
          ["目标位置"] = "3",
          ["起始位置"] = "0",
          ["距离"] = "0",
          ["途经格数"] = "32",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["步数"] = 27,
          ["目标位置"] = 27,
          ["起始位置"] = 27,
          ["距离"] = 27,
          ["途经格数"] = 27,
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
            "起始位置",
          },
          ["text"] = "当前玩家位于位置<起始位置>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "棋盘共有<途经格数>格",
            ["source_line"] = 21,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "途经格数",
          },
          ["text"] = "棋盘共有<途经格数>格",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家掷出<步数>",
            ["source_line"] = 22,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "步数",
          },
          ["text"] = "玩家掷出<步数>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家位于位置<目标位置>",
            ["source_line"] = 23,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "目标位置",
          },
          ["text"] = "玩家位于位置<目标位置>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家经过起点<距离>次",
            ["source_line"] = 24,
            ["source_path"] = "features/game/dice_roll.feature",
          },
          ["parameters"] = {
            "距离",
          },
          ["text"] = "玩家经过起点<距离>次",
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
