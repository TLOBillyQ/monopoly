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
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["余额"] = 9,
      ["结果"] = 13,
      ["金额"] = 11,
      ["验证余额"] = 10,
      ["验证金额"] = 12,
    },
    ["field_names"] = {
      ["余额"] = "余额",
      ["结果"] = "结果",
      ["金额"] = "金额",
      ["验证余额"] = "验证余额",
      ["验证金额"] = "验证金额",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/bankruptcy.feature",
  },
  ["name"] = "破产判定",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["余额"] = "100",
          ["结果"] = "破产",
          ["金额"] = "200",
          ["验证余额"] = "100",
          ["验证金额"] = "200",
        },
        {
          ["余额"] = "500",
          ["结果"] = "存活",
          ["金额"] = "200",
          ["验证余额"] = "500",
          ["验证金额"] = "200",
        },
        {
          ["余额"] = "0",
          ["结果"] = "破产",
          ["金额"] = "100",
          ["验证余额"] = "0",
          ["验证金额"] = "100",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["余额"] = 16,
          ["结果"] = 16,
          ["金额"] = 16,
          ["验证余额"] = 16,
          ["验证金额"] = 16,
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
            "余额",
          },
          ["text"] = "玩家持有<余额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家初始余额为<验证余额>金币",
            ["source_line"] = 10,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {
            "验证余额",
          },
          ["text"] = "玩家初始余额为<验证余额>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家需要支付<金额>",
            ["source_line"] = 11,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {
            "金额",
          },
          ["text"] = "玩家需要支付<金额>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "应支付金额为<验证金额>金币",
            ["source_line"] = 12,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {
            "验证金额",
          },
          ["text"] = "应支付金额为<验证金额>金币",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家<结果>",
            ["source_line"] = 13,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {
            "结果",
          },
          ["text"] = "玩家<结果>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 21,
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["name"] = "机会卡支付他人效果中途破产则停止后续支付",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有800金币",
            ["source_line"] = 22,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有800金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为向每位玩家支付500金币",
            ["source_line"] = 23,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡效果为向每位玩家支付500金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏中有3名未淘汰对手",
            ["source_line"] = 24,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏中有3名未淘汰对手",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 25,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家向第一位对手支付500金币后破产",
            ["source_line"] = 26,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家向第一位对手支付500金币后破产",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "后续对手不再收到支付",
            ["source_line"] = 27,
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
        ["source_line"] = 29,
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["name"] = "机会卡收取他人效果中无力支付者破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "抽到的机会卡效果为向每位玩家收取1000金币",
            ["source_line"] = 30,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "抽到的机会卡效果为向每位玩家收取1000金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手A持有500金币",
            ["source_line"] = 31,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手A持有500金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "机会卡效果结算",
            ["source_line"] = 32,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "机会卡效果结算",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "对手A支付全部500金币后破产淘汰",
            ["source_line"] = 33,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手A支付全部500金币后破产淘汰",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家收到对手A的500金币",
            ["source_line"] = 34,
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
        ["source_line"] = 36,
        ["source_path"] = "features/game/bankruptcy.feature",
      },
      ["name"] = "落在医院费用不足触发破产",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有0金币",
            ["source_line"] = 37,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有0金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家因效果被送往医院且需支付住院费",
            ["source_line"] = 38,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家因效果被送往医院且需支付住院费",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家破产淘汰",
            ["source_line"] = 39,
            ["source_path"] = "features/game/bankruptcy.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家破产淘汰",
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
