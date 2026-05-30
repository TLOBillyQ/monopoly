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
        ["source_path"] = "features/game/deities.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["持续回合"] = 9,
      ["神灵"] = 9,
      ["道具"] = 28,
      ["验证持续回合"] = 10,
    },
    ["field_names"] = {
      ["持续回合"] = "持续回合",
      ["神灵"] = "神灵",
      ["道具"] = "道具",
      ["验证持续回合"] = "验证持续回合",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/deities.feature",
  },
  ["name"] = "神灵系统",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["持续回合"] = "3",
          ["神灵"] = "财神",
          ["验证持续回合"] = "3",
        },
        {
          ["持续回合"] = "5",
          ["神灵"] = "穷神",
          ["验证持续回合"] = "5",
        },
        {
          ["持续回合"] = "2",
          ["神灵"] = "天使",
          ["验证持续回合"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["持续回合"] = 15,
          ["神灵"] = 15,
          ["验证持续回合"] = 15,
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
            "神灵",
            "持续回合",
          },
          ["text"] = "玩家1附体<神灵>持续<持续回合>回合",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家1神灵剩余回合为<验证持续回合>",
            ["source_line"] = 10,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {
            "验证持续回合",
          },
          ["text"] = "玩家1神灵剩余回合为<验证持续回合>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家1的回合结束<持续回合>次",
            ["source_line"] = 11,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {
            "持续回合",
          },
          ["text"] = "玩家1的回合结束<持续回合>次",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家1不再持有任何神灵",
            ["source_line"] = 12,
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
        ["source_line"] = 20,
        ["source_path"] = "features/game/deities.feature",
      },
      ["name"] = "淘汰玩家的神灵不随回合递减",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家2附体穷神持续3回合",
            ["source_line"] = 21,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2附体穷神持续3回合",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家2已被淘汰",
            ["source_line"] = 22,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2已被淘汰",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "游戏进行一个完整回合",
            ["source_line"] = 23,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "游戏进行一个完整回合",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家2的神灵剩余回合仍为3",
            ["source_line"] = 24,
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
          ["道具"] = "均富卡",
        },
        {
          ["道具"] = "偷窃卡",
        },
        {
          ["道具"] = "查税卡",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["道具"] = 33,
        },
        ["source_line"] = 26,
        ["source_path"] = "features/game/deities.feature",
      },
      ["name"] = "天使守护免疫针对玩家的负面道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家2附体天使",
            ["source_line"] = 27,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2附体天使",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家1对玩家2使用<道具>",
            ["source_line"] = 28,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {
            "道具",
          },
          ["text"] = "玩家1对玩家2使用<道具>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具效果被阻断",
            ["source_line"] = 29,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具效果被阻断",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "系统记录天使保护事件",
            ["source_line"] = 30,
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
        ["source_line"] = 38,
        ["source_path"] = "features/game/deities.feature",
      },
      ["name"] = "天使守护免疫地雷",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家2附体天使",
            ["source_line"] = 39,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2附体天使",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前棋盘存在地雷",
            ["source_line"] = 40,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前棋盘存在地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家2落在地雷格",
            ["source_line"] = 41,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2落在地雷格",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地雷不触发",
            ["source_line"] = 42,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "地雷不触发",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家2不进医院",
            ["source_line"] = 43,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2不进医院",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["持续回合"] = "3",
          ["神灵"] = "财神",
        },
        {
          ["持续回合"] = "4",
          ["神灵"] = "穷神",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["持续回合"] = 52,
          ["神灵"] = 52,
        },
        ["source_line"] = 45,
        ["source_path"] = "features/game/deities.feature",
      },
      ["name"] = "请神卡夺取目标的神灵",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家2附体<神灵>持续<持续回合>回合",
            ["source_line"] = 46,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {
            "神灵",
            "持续回合",
          },
          ["text"] = "玩家2附体<神灵>持续<持续回合>回合",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家1对玩家2使用请神卡",
            ["source_line"] = 47,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家1对玩家2使用请神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<神灵>转移到玩家1身上",
            ["source_line"] = 48,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {
            "神灵",
          },
          ["text"] = "<神灵>转移到玩家1身上",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家2不再持有任何神灵",
            ["source_line"] = 49,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2不再持有任何神灵",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 56,
        ["source_path"] = "features/game/deities.feature",
      },
      ["name"] = "送神卡将穷神转给目标",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家1附体穷神持续3回合",
            ["source_line"] = 57,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家1附体穷神持续3回合",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家1对玩家2使用送神卡",
            ["source_line"] = 58,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家1对玩家2使用送神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "穷神转移到玩家2身上",
            ["source_line"] = 59,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "穷神转移到玩家2身上",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家1不再持有任何神灵",
            ["source_line"] = 60,
            ["source_path"] = "features/game/deities.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家1不再持有任何神灵",
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
