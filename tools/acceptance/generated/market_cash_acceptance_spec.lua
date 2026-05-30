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
        ["source_path"] = "features/v102/market_cash.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["显示金额"] = 13,
      ["角色ID"] = 9,
      ["设置金额"] = 11,
      ["验证角色ID"] = 10,
    },
    ["field_names"] = {
      ["显示金额"] = "显示金额",
      ["角色ID"] = "角色ID",
      ["设置金额"] = "设置金额",
      ["验证角色ID"] = "验证角色ID",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/v102/market_cash.feature",
  },
  ["name"] = "黑市现金显示",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["显示金额"] = "1000",
          ["角色ID"] = "1",
          ["设置金额"] = "1000",
          ["验证角色ID"] = "1",
        },
        {
          ["显示金额"] = "500",
          ["角色ID"] = "1",
          ["设置金额"] = "500",
          ["验证角色ID"] = "1",
        },
        {
          ["显示金额"] = "3000",
          ["角色ID"] = "2",
          ["设置金额"] = "3000",
          ["验证角色ID"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["显示金额"] = 16,
          ["角色ID"] = 16,
          ["设置金额"] = 16,
          ["验证角色ID"] = 16,
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
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前角色ID为<验证角色ID>",
            ["source_line"] = 10,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "当前角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家当前现金为<设置金额>",
            ["source_line"] = 11,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "设置金额",
          },
          ["text"] = "玩家当前现金为<设置金额>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "黑市向玩家开放",
            ["source_line"] = 12,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市向玩家开放",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "黑市现金显示区显示金额<显示金额>",
            ["source_line"] = 13,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "显示金额",
          },
          ["text"] = "黑市现金显示区显示金额<显示金额>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["显示金额"] = "0",
          ["角色ID"] = "1",
          ["设置金额"] = "0",
          ["验证角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["显示金额"] = 29,
          ["角色ID"] = 29,
          ["设置金额"] = 29,
          ["验证角色ID"] = 29,
        },
        ["source_line"] = 21,
        ["source_path"] = "features/v102/market_cash.feature",
      },
      ["name"] = "现金不足时黑市仍可开启",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 22,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前角色ID为<验证角色ID>",
            ["source_line"] = 23,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "验证角色ID",
          },
          ["text"] = "当前角色ID为<验证角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家当前现金为<设置金额>",
            ["source_line"] = 24,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "设置金额",
          },
          ["text"] = "玩家当前现金为<设置金额>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "黑市向玩家开放",
            ["source_line"] = 25,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市向玩家开放",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "黑市现金显示区显示金额<显示金额>",
            ["source_line"] = 26,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "显示金额",
          },
          ["text"] = "黑市现金显示区显示金额<显示金额>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["显示金额"] = "5000",
          ["设置金额"] = "10000",
        },
        {
          ["显示金额"] = "15000",
          ["设置金额"] = "20000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["显示金额"] = 39,
          ["设置金额"] = 39,
        },
        ["source_line"] = 32,
        ["source_path"] = "features/v102/market_cash.feature",
      },
      ["name"] = "购买道具后黑市现金同步更新",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前现金为<设置金额>",
            ["source_line"] = 33,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "设置金额",
          },
          ["text"] = "玩家当前现金为<设置金额>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家在黑市成功购买一个道具",
            ["source_line"] = 34,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家在黑市成功购买一个道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "黑市现金显示区刷新",
            ["source_line"] = 35,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市现金显示区刷新",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "黑市现金显示区显示金额<显示金额>",
            ["source_line"] = 36,
            ["source_path"] = "features/v102/market_cash.feature",
          },
          ["parameters"] = {
            "显示金额",
          },
          ["text"] = "黑市现金显示区显示金额<显示金额>",
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
