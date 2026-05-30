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
        ["source_path"] = "features/v102/leaderboard.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["之前累计资产"] = 24,
      ["之前胜利次数"] = 12,
      ["之后累计资产"] = 28,
      ["之后胜利次数"] = 15,
      ["本局剩余资产"] = 26,
      ["胜负结果"] = 13,
    },
    ["field_names"] = {
      ["之前累计资产"] = "之前累计资产",
      ["之前胜利次数"] = "之前胜利次数",
      ["之后累计资产"] = "之后累计资产",
      ["之后胜利次数"] = "之后胜利次数",
      ["本局剩余资产"] = "本局剩余资产",
      ["胜负结果"] = "胜负结果",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/v102/leaderboard.feature",
  },
  ["name"] = "排行榜数据累计",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["之前胜利次数"] = "0",
          ["之后胜利次数"] = "1",
          ["胜负结果"] = "获胜",
        },
        {
          ["之前胜利次数"] = "3",
          ["之后胜利次数"] = "4",
          ["胜负结果"] = "获胜",
        },
        {
          ["之前胜利次数"] = "3",
          ["之后胜利次数"] = "3",
          ["胜负结果"] = "未获胜",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["之前胜利次数"] = 18,
          ["之后胜利次数"] = 18,
          ["胜负结果"] = 18,
        },
        ["source_line"] = 11,
        ["source_path"] = "features/v102/leaderboard.feature",
      },
      ["name"] = "获胜玩家的胜利次数累加一次",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家本局之前的胜利次数为<之前胜利次数>",
            ["source_line"] = 12,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {
            "之前胜利次数",
          },
          ["text"] = "玩家本局之前的胜利次数为<之前胜利次数>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家本局<胜负结果>",
            ["source_line"] = 13,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {
            "胜负结果",
          },
          ["text"] = "玩家本局<胜负结果>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "排行榜结算执行",
            ["source_line"] = 14,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "排行榜结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家本局之后的胜利次数为<之后胜利次数>",
            ["source_line"] = 15,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {
            "之后胜利次数",
          },
          ["text"] = "玩家本局之后的胜利次数为<之后胜利次数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["之前累计资产"] = "0",
          ["之后累计资产"] = "50000",
          ["本局剩余资产"] = "50000",
        },
        {
          ["之前累计资产"] = "50000",
          ["之后累计资产"] = "80000",
          ["本局剩余资产"] = "30000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["之前累计资产"] = 31,
          ["之后累计资产"] = 31,
          ["本局剩余资产"] = 31,
        },
        ["source_line"] = 23,
        ["source_path"] = "features/v102/leaderboard.feature",
      },
      ["name"] = "在场玩家的剩余总资产累计入富豪榜",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家本局之前的累计资产为<之前累计资产>",
            ["source_line"] = 24,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {
            "之前累计资产",
          },
          ["text"] = "玩家本局之前的累计资产为<之前累计资产>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家本局结束时仍在场",
            ["source_line"] = 25,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本局结束时仍在场",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家本局结束时的剩余总资产为<本局剩余资产>",
            ["source_line"] = 26,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {
            "本局剩余资产",
          },
          ["text"] = "玩家本局结束时的剩余总资产为<本局剩余资产>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "排行榜结算执行",
            ["source_line"] = 27,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "排行榜结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家本局之后的累计资产为<之后累计资产>",
            ["source_line"] = 28,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {
            "之后累计资产",
          },
          ["text"] = "玩家本局之后的累计资产为<之后累计资产>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["之前累计资产"] = "50000",
          ["之后累计资产"] = "50000",
        },
        {
          ["之前累计资产"] = "0",
          ["之后累计资产"] = "0",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["之前累计资产"] = 42,
          ["之后累计资产"] = 42,
        },
        ["source_line"] = 35,
        ["source_path"] = "features/v102/leaderboard.feature",
      },
      ["name"] = "中途退出的玩家剩余资产不计入富豪榜",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家本局之前的累计资产为<之前累计资产>",
            ["source_line"] = 36,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {
            "之前累计资产",
          },
          ["text"] = "玩家本局之前的累计资产为<之前累计资产>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家本局中途退出且退出时仍持有可观剩余资产",
            ["source_line"] = 37,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本局中途退出且退出时仍持有可观剩余资产",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "排行榜结算执行",
            ["source_line"] = 38,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "排行榜结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家本局之后的累计资产为<之后累计资产>",
            ["source_line"] = 39,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {
            "之后累计资产",
          },
          ["text"] = "玩家本局之后的累计资产为<之后累计资产>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 46,
        ["source_path"] = "features/v102/leaderboard.feature",
      },
      ["name"] = "并列获胜时每名获胜者的胜利次数各加一",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "本局两名玩家并列获胜",
            ["source_line"] = 47,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "本局两名玩家并列获胜",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "每名获胜者本局之前的胜利次数为 2",
            ["source_line"] = 48,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "每名获胜者本局之前的胜利次数为 2",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "排行榜结算执行",
            ["source_line"] = 49,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "排行榜结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "每名获胜者本局之后的胜利次数为 3",
            ["source_line"] = 50,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "每名获胜者本局之后的胜利次数为 3",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 52,
        ["source_path"] = "features/v102/leaderboard.feature",
      },
      ["name"] = "重复结算不重复累计",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家本局已完成排行榜结算",
            ["source_line"] = 53,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本局已完成排行榜结算",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "排行榜结算再次执行",
            ["source_line"] = 54,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "排行榜结算再次执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家的胜利次数不再增加",
            ["source_line"] = 55,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的胜利次数不再增加",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家的累计资产不再增加",
            ["source_line"] = 56,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的累计资产不再增加",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 58,
        ["source_path"] = "features/v102/leaderboard.feature",
      },
      ["name"] = "未开启自定义存档时跳过排行榜结算",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "宿主未开启自定义存档",
            ["source_line"] = 59,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "宿主未开启自定义存档",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "排行榜结算执行",
            ["source_line"] = 60,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "排行榜结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "不写入任何排行榜存档",
            ["source_line"] = 61,
            ["source_path"] = "features/v102/leaderboard.feature",
          },
          ["parameters"] = {},
          ["text"] = "不写入任何排行榜存档",
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
