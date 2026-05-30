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
        ["source_path"] = "features/v102/panel_interrupt.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["提示文本"] = 65,
      ["结算"] = 33,
      ["角色ID"] = 9,
      ["面板"] = 10,
    },
    ["field_names"] = {
      ["提示文本"] = "提示文本",
      ["结算"] = "结算",
      ["角色ID"] = "角色ID",
      ["面板"] = "面板",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/v102/panel_interrupt.feature",
  },
  ["name"] = "基础屏面板打断行为",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["角色ID"] = "1",
          ["面板"] = "道具图鉴",
        },
        {
          ["角色ID"] = "1",
          ["面板"] = "行动日志",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["角色ID"] = 15,
          ["面板"] = 15,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/v102/panel_interrupt.feature",
      },
      ["name"] = "回合外打开的基础屏面板在其他玩家行动时保持开启",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 9,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家在回合外打开<面板>",
            ["source_line"] = 10,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "玩家在回合外打开<面板>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "轮到其他玩家行动",
            ["source_line"] = 11,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {},
          ["text"] = "轮到其他玩家行动",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<面板>屏幕已开启",
            ["source_line"] = 12,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "<面板>屏幕已开启",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["角色ID"] = "1",
          ["面板"] = "道具图鉴",
        },
        {
          ["角色ID"] = "1",
          ["面板"] = "行动日志",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["角色ID"] = 26,
          ["面板"] = 26,
        },
        ["source_line"] = 19,
        ["source_path"] = "features/v102/panel_interrupt.feature",
      },
      ["name"] = "其他玩家的黑市屏打开时基础屏面板保持开启",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 20,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家在回合外打开<面板>",
            ["source_line"] = 21,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "玩家在回合外打开<面板>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "其他玩家的黑市屏打开",
            ["source_line"] = 22,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {},
          ["text"] = "其他玩家的黑市屏打开",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<面板>屏幕已开启",
            ["source_line"] = 23,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "<面板>屏幕已开启",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["结算"] = "机会",
          ["角色ID"] = "1",
          ["面板"] = "道具图鉴",
        },
        {
          ["结算"] = "弹窗",
          ["角色ID"] = "1",
          ["面板"] = "道具图鉴",
        },
        {
          ["结算"] = "移动",
          ["角色ID"] = "1",
          ["面板"] = "道具图鉴",
        },
        {
          ["结算"] = "机会",
          ["角色ID"] = "1",
          ["面板"] = "皮肤商店",
        },
        {
          ["结算"] = "弹窗",
          ["角色ID"] = "1",
          ["面板"] = "皮肤商店",
        },
        {
          ["结算"] = "移动",
          ["角色ID"] = "1",
          ["面板"] = "皮肤商店",
        },
        {
          ["结算"] = "机会",
          ["角色ID"] = "1",
          ["面板"] = "行动日志",
        },
        {
          ["结算"] = "弹窗",
          ["角色ID"] = "1",
          ["面板"] = "行动日志",
        },
        {
          ["结算"] = "移动",
          ["角色ID"] = "1",
          ["面板"] = "行动日志",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["结算"] = 37,
          ["角色ID"] = 37,
          ["面板"] = 37,
        },
        ["source_line"] = 30,
        ["source_path"] = "features/v102/panel_interrupt.feature",
      },
      ["name"] = "玩家自己的非黑市结算不关闭基础屏面板",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 31,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开<面板>",
            ["source_line"] = 32,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "玩家打开<面板>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家自己的<结算>结算开始",
            ["source_line"] = 33,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "结算",
          },
          ["text"] = "玩家自己的<结算>结算开始",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<面板>屏幕已开启",
            ["source_line"] = 34,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "<面板>屏幕已开启",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["角色ID"] = "1",
          ["面板"] = "道具图鉴",
        },
        {
          ["角色ID"] = "1",
          ["面板"] = "皮肤商店",
        },
        {
          ["角色ID"] = "1",
          ["面板"] = "行动日志",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["角色ID"] = 55,
          ["面板"] = 55,
        },
        ["source_line"] = 48,
        ["source_path"] = "features/v102/panel_interrupt.feature",
      },
      ["name"] = "玩家自己的黑市屏打开时关闭基础屏面板",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 49,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开<面板>",
            ["source_line"] = 50,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "玩家打开<面板>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家自己的黑市屏打开",
            ["source_line"] = 51,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家自己的黑市屏打开",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<面板>屏幕已关闭",
            ["source_line"] = 52,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "<面板>屏幕已关闭",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["提示文本"] = "结算中，稍后再开",
          ["角色ID"] = "1",
          ["面板"] = "道具图鉴",
        },
        {
          ["提示文本"] = "结算中，稍后再开",
          ["角色ID"] = "1",
          ["面板"] = "皮肤商店",
        },
        {
          ["提示文本"] = "结算中，稍后再开",
          ["角色ID"] = "1",
          ["面板"] = "行动日志",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["提示文本"] = 68,
          ["角色ID"] = 68,
          ["面板"] = 68,
        },
        ["source_line"] = 60,
        ["source_path"] = "features/v102/panel_interrupt.feature",
      },
      ["name"] = "自己的黑市屏正在显示时阻止打开基础屏面板",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 61,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家自己的黑市屏正在显示",
            ["source_line"] = 62,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家自己的黑市屏正在显示",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "触发基础屏<面板>按钮",
            ["source_line"] = 63,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "触发基础屏<面板>按钮",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<面板>屏幕已关闭",
            ["source_line"] = 64,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "<面板>屏幕已关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "提示\"<提示文本>\"已显示",
            ["source_line"] = 65,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "提示文本",
          },
          ["text"] = "提示\"<提示文本>\"已显示",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["角色ID"] = "1",
          ["面板"] = "道具图鉴",
        },
        {
          ["角色ID"] = "1",
          ["面板"] = "行动日志",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["角色ID"] = 80,
          ["面板"] = 80,
        },
        ["source_line"] = 73,
        ["source_path"] = "features/v102/panel_interrupt.feature",
      },
      ["name"] = "其他玩家的黑市屏正在显示时仍可打开基础屏面板",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 74,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "其他玩家的黑市屏正在显示",
            ["source_line"] = 75,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {},
          ["text"] = "其他玩家的黑市屏正在显示",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "触发基础屏<面板>按钮",
            ["source_line"] = 76,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "触发基础屏<面板>按钮",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<面板>屏幕已开启",
            ["source_line"] = 77,
            ["source_path"] = "features/v102/panel_interrupt.feature",
          },
          ["parameters"] = {
            "面板",
          },
          ["text"] = "<面板>屏幕已开启",
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
