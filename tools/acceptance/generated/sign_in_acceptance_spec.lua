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
        ["source_line"] = 9,
        ["source_path"] = "features/v102/sign_in.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["之前金币"] = 12,
      ["之后金币"] = 14,
      ["签到天数"] = 13,
    },
    ["field_names"] = {
      ["之前金币"] = "之前金币",
      ["之后金币"] = "之后金币",
      ["签到天数"] = "签到天数",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/v102/sign_in.feature",
  },
  ["name"] = "签到奖励发放",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["之前金币"] = "0",
          ["之后金币"] = "500",
          ["签到天数"] = "1",
        },
        {
          ["之前金币"] = "0",
          ["之后金币"] = "1000",
          ["签到天数"] = "2",
        },
        {
          ["之前金币"] = "0",
          ["之后金币"] = "2000",
          ["签到天数"] = "3",
        },
        {
          ["之前金币"] = "0",
          ["之后金币"] = "4000",
          ["签到天数"] = "4",
        },
        {
          ["之前金币"] = "0",
          ["之后金币"] = "6000",
          ["签到天数"] = "5",
        },
        {
          ["之前金币"] = "0",
          ["之后金币"] = "8000",
          ["签到天数"] = "6",
        },
        {
          ["之前金币"] = "1000",
          ["之后金币"] = "11000",
          ["签到天数"] = "7",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["之前金币"] = 17,
          ["之后金币"] = 17,
          ["签到天数"] = 17,
        },
        ["source_line"] = 11,
        ["source_path"] = "features/v102/sign_in.feature",
      },
      ["name"] = "领取每日签到奖励发放对应金币",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前金币为<之前金币>",
            ["source_line"] = 12,
            ["source_path"] = "features/v102/sign_in.feature",
          },
          ["parameters"] = {
            "之前金币",
          },
          ["text"] = "玩家当前金币为<之前金币>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家领取第<签到天数>天签到奖励",
            ["source_line"] = 13,
            ["source_path"] = "features/v102/sign_in.feature",
          },
          ["parameters"] = {
            "签到天数",
          },
          ["text"] = "玩家领取第<签到天数>天签到奖励",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家当前金币为<之后金币>",
            ["source_line"] = 14,
            ["source_path"] = "features/v102/sign_in.feature",
          },
          ["parameters"] = {
            "之后金币",
          },
          ["text"] = "玩家当前金币为<之后金币>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 26,
        ["source_path"] = "features/v102/sign_in.feature",
      },
      ["name"] = "未配置奖励的签到事件不发放金币",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前金币为 500",
            ["source_line"] = 27,
            ["source_path"] = "features/v102/sign_in.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前金币为 500",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "触发一个未配置奖励的签到事件",
            ["source_line"] = 28,
            ["source_path"] = "features/v102/sign_in.feature",
          },
          ["parameters"] = {},
          ["text"] = "触发一个未配置奖励的签到事件",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家当前金币保持 500 不变",
            ["source_line"] = 29,
            ["source_path"] = "features/v102/sign_in.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前金币保持 500 不变",
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
