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
        ["source_path"] = "features/v102/skin_persistence.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["产品ID"] = 40,
      ["占用槽位"] = 18,
      ["总页数"] = 22,
      ["按钮文本"] = 21,
      ["槽位"] = 17,
      ["皮肤数"] = 14,
      ["角色ID"] = 15,
    },
    ["field_names"] = {
      ["产品ID"] = "产品ID",
      ["占用槽位"] = "占用槽位",
      ["总页数"] = "总页数",
      ["按钮文本"] = "按钮文本",
      ["槽位"] = "槽位",
      ["皮肤数"] = "皮肤数",
      ["角色ID"] = "角色ID",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/v102/skin_persistence.feature",
  },
  ["name"] = "皮肤购买存档",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["占用槽位"] = "2",
          ["总页数"] = "1",
          ["按钮文本"] = "穿上",
          ["槽位"] = "1",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
        {
          ["占用槽位"] = "4",
          ["总页数"] = "1",
          ["按钮文本"] = "穿上",
          ["槽位"] = "3",
          ["皮肤数"] = "6",
          ["角色ID"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["占用槽位"] = 25,
          ["总页数"] = 25,
          ["按钮文本"] = 25,
          ["槽位"] = 25,
          ["皮肤数"] = 25,
          ["角色ID"] = 25,
        },
        ["source_line"] = 13,
        ["source_path"] = "features/v102/skin_persistence.feature",
      },
      ["name"] = "付费购买的皮肤在重新开局后仍归玩家持有",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 14,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 15,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 16,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家付费购买槽位<槽位>的皮肤",
            ["source_line"] = 17,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家付费购买槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家付费购买槽位<占用槽位>的皮肤",
            ["source_line"] = 18,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "占用槽位",
          },
          ["text"] = "玩家付费购买槽位<占用槽位>的皮肤",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家重新开局并打开皮肤商店",
            ["source_line"] = 19,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家重新开局并打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已归玩家持有",
            ["source_line"] = 20,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已归玩家持有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 21,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 22,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["产品ID"] = "skin_1",
          ["总页数"] = "1",
          ["按钮文本"] = "脱下",
          ["槽位"] = "1",
          ["皮肤数"] = "6",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["产品ID"] = 44,
          ["总页数"] = 44,
          ["按钮文本"] = 44,
          ["槽位"] = 44,
          ["皮肤数"] = 44,
          ["角色ID"] = 44,
        },
        ["source_line"] = 31,
        ["source_path"] = "features/v102/skin_persistence.feature",
      },
      ["name"] = "重新开局自动穿上上次装备的皮肤并还原宿主模型",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "皮肤目录共有<皮肤数>款皮肤",
            ["source_line"] = 32,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "皮肤数",
          },
          ["text"] = "皮肤目录共有<皮肤数>款皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 33,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开皮肤商店",
            ["source_line"] = 34,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开皮肤商店",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家付费购买槽位<槽位>的皮肤",
            ["source_line"] = 35,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "玩家付费购买槽位<槽位>的皮肤",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "换装回调已注册",
            ["source_line"] = 36,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {},
          ["text"] = "换装回调已注册",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家重新开局并打开皮肤商店",
            ["source_line"] = 37,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家重新开局并打开皮肤商店",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位<槽位>的皮肤已装备成功",
            ["source_line"] = 38,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "槽位",
          },
          ["text"] = "槽位<槽位>的皮肤已装备成功",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
            ["source_line"] = 39,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "槽位",
            "按钮文本",
          },
          ["text"] = "皮肤卡牌槽位<槽位>按钮文本为\"<按钮文本>\"",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "换装回调收到的皮肤产品ID为<产品ID>",
            ["source_line"] = 40,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "产品ID",
          },
          ["text"] = "换装回调收到的皮肤产品ID为<产品ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "皮肤总页数为<总页数>",
            ["source_line"] = 41,
            ["source_path"] = "features/v102/skin_persistence.feature",
          },
          ["parameters"] = {
            "总页数",
          },
          ["text"] = "皮肤总页数为<总页数>",
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
