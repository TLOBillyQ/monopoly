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
        ["source_path"] = "features/v102/base_screen.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["入口"] = 108,
      ["托管状态"] = 10,
      ["按钮文字"] = 12,
      ["节点"] = 23,
      ["行动角色ID"] = 21,
      ["角色ID"] = 9,
      ["预期行动角色ID"] = 50,
    },
    ["field_names"] = {
      ["入口"] = "入口",
      ["托管状态"] = "托管状态",
      ["按钮文字"] = "按钮文字",
      ["节点"] = "节点",
      ["行动角色ID"] = "行动角色ID",
      ["角色ID"] = "角色ID",
      ["预期行动角色ID"] = "预期行动角色ID",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/v102/base_screen.feature",
  },
  ["name"] = "基础屏",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["托管状态"] = "关闭",
          ["按钮文字"] = "托管",
          ["角色ID"] = "1",
        },
        {
          ["托管状态"] = "开启",
          ["按钮文字"] = "托管",
          ["角色ID"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["托管状态"] = 15,
          ["按钮文字"] = 15,
          ["角色ID"] = 15,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/v102/base_screen.feature",
      },
      ["name"] = "托管按钮只显示固定文案",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 9,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家托管状态为<托管状态>",
            ["source_line"] = 10,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "托管状态",
          },
          ["text"] = "玩家托管状态为<托管状态>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "基础屏刷新",
            ["source_line"] = 11,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "基础屏刷新",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "基础屏托管按钮文字为\"<按钮文字>\"",
            ["source_line"] = 12,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "按钮文字",
          },
          ["text"] = "基础屏托管按钮文字为\"<按钮文字>\"",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["节点"] = "按钮",
          ["行动角色ID"] = "1",
          ["角色ID"] = "1",
        },
        {
          ["节点"] = "文字",
          ["行动角色ID"] = "1",
          ["角色ID"] = "1",
        },
        {
          ["节点"] = "按钮",
          ["行动角色ID"] = "2",
          ["角色ID"] = "2",
        },
        {
          ["节点"] = "文字",
          ["行动角色ID"] = "2",
          ["角色ID"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["节点"] = 26,
          ["行动角色ID"] = 26,
          ["角色ID"] = 26,
        },
        ["source_line"] = 19,
        ["source_path"] = "features/v102/base_screen.feature",
      },
      ["name"] = "自己回合内隐藏皮肤入口",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 20,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前轮到角色ID为<行动角色ID>",
            ["source_line"] = 21,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "行动角色ID",
          },
          ["text"] = "当前轮到角色ID为<行动角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "基础屏为该玩家刷新",
            ["source_line"] = 22,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "基础屏为该玩家刷新",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "基础屏皮肤<节点>已隐藏",
            ["source_line"] = 23,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "节点",
          },
          ["text"] = "基础屏皮肤<节点>已隐藏",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["节点"] = "按钮",
          ["行动角色ID"] = "2",
          ["角色ID"] = "1",
        },
        {
          ["节点"] = "文字",
          ["行动角色ID"] = "2",
          ["角色ID"] = "1",
        },
        {
          ["节点"] = "按钮",
          ["行动角色ID"] = "1",
          ["角色ID"] = "2",
        },
        {
          ["节点"] = "文字",
          ["行动角色ID"] = "1",
          ["角色ID"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["节点"] = 39,
          ["行动角色ID"] = 39,
          ["角色ID"] = 39,
        },
        ["source_line"] = 32,
        ["source_path"] = "features/v102/base_screen.feature",
      },
      ["name"] = "非自己回合展示皮肤入口",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 33,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前轮到角色ID为<行动角色ID>",
            ["source_line"] = 34,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "行动角色ID",
          },
          ["text"] = "当前轮到角色ID为<行动角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "基础屏为该玩家刷新",
            ["source_line"] = 35,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "基础屏为该玩家刷新",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "基础屏皮肤<节点>已展示",
            ["source_line"] = 36,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "节点",
          },
          ["text"] = "基础屏皮肤<节点>已展示",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["节点"] = "按钮",
          ["行动角色ID"] = "2",
          ["角色ID"] = "1",
          ["预期行动角色ID"] = "2",
        },
        {
          ["节点"] = "文字",
          ["行动角色ID"] = "2",
          ["角色ID"] = "1",
          ["预期行动角色ID"] = "2",
        },
        {
          ["节点"] = "按钮",
          ["行动角色ID"] = "3",
          ["角色ID"] = "2",
          ["预期行动角色ID"] = "3",
        },
        {
          ["节点"] = "文字",
          ["行动角色ID"] = "3",
          ["角色ID"] = "2",
          ["预期行动角色ID"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["节点"] = 54,
          ["行动角色ID"] = 54,
          ["角色ID"] = 54,
          ["预期行动角色ID"] = 54,
        },
        ["source_line"] = 45,
        ["source_path"] = "features/v102/base_screen.feature",
      },
      ["name"] = "非自己回合时即使输入门已锁皮肤入口仍展示",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 46,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前轮到角色ID为<行动角色ID>",
            ["source_line"] = 47,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "行动角色ID",
          },
          ["text"] = "当前轮到角色ID为<行动角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "输入门已锁",
            ["source_line"] = 48,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "输入门已锁",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "基础屏为该玩家刷新",
            ["source_line"] = 49,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "基础屏为该玩家刷新",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "基础屏当前行动角色ID为<预期行动角色ID>",
            ["source_line"] = 50,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "预期行动角色ID",
          },
          ["text"] = "基础屏当前行动角色ID为<预期行动角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "基础屏皮肤<节点>已展示",
            ["source_line"] = 51,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "节点",
          },
          ["text"] = "基础屏皮肤<节点>已展示",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["节点"] = "按钮",
          ["行动角色ID"] = "1",
          ["角色ID"] = "1",
        },
        {
          ["节点"] = "文字",
          ["行动角色ID"] = "1",
          ["角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["节点"] = 68,
          ["行动角色ID"] = 68,
          ["角色ID"] = 68,
        },
        ["source_line"] = 60,
        ["source_path"] = "features/v102/base_screen.feature",
      },
      ["name"] = "自己回合内即使输入门已锁皮肤入口仍隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 61,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前轮到角色ID为<行动角色ID>",
            ["source_line"] = 62,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "行动角色ID",
          },
          ["text"] = "当前轮到角色ID为<行动角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "输入门已锁",
            ["source_line"] = 63,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "输入门已锁",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "基础屏为该玩家刷新",
            ["source_line"] = 64,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "基础屏为该玩家刷新",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "基础屏皮肤<节点>已隐藏",
            ["source_line"] = 65,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "节点",
          },
          ["text"] = "基础屏皮肤<节点>已隐藏",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["节点"] = "按钮",
          ["行动角色ID"] = "2",
          ["角色ID"] = "1",
          ["预期行动角色ID"] = "2",
        },
        {
          ["节点"] = "文字",
          ["行动角色ID"] = "2",
          ["角色ID"] = "1",
          ["预期行动角色ID"] = "2",
        },
        {
          ["节点"] = "按钮",
          ["行动角色ID"] = "3",
          ["角色ID"] = "2",
          ["预期行动角色ID"] = "3",
        },
        {
          ["节点"] = "文字",
          ["行动角色ID"] = "3",
          ["角色ID"] = "2",
          ["预期行动角色ID"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["节点"] = 82,
          ["行动角色ID"] = 82,
          ["角色ID"] = 82,
          ["预期行动角色ID"] = 82,
        },
        ["source_line"] = 74,
        ["source_path"] = "features/v102/base_screen.feature",
      },
      ["name"] = "刷新后应用输入锁仍展示非自己回合皮肤入口",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 75,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前轮到角色ID为<行动角色ID>",
            ["source_line"] = 76,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "行动角色ID",
          },
          ["text"] = "当前轮到角色ID为<行动角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "基础屏刷新后应用输入锁",
            ["source_line"] = 77,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "基础屏刷新后应用输入锁",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "基础屏当前行动角色ID为<预期行动角色ID>",
            ["source_line"] = 78,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "预期行动角色ID",
          },
          ["text"] = "基础屏当前行动角色ID为<预期行动角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "基础屏皮肤<节点>已展示",
            ["source_line"] = 79,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "节点",
          },
          ["text"] = "基础屏皮肤<节点>已展示",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["节点"] = "按钮",
          ["行动角色ID"] = "1",
          ["角色ID"] = "1",
        },
        {
          ["节点"] = "文字",
          ["行动角色ID"] = "1",
          ["角色ID"] = "1",
        },
        {
          ["节点"] = "按钮",
          ["行动角色ID"] = "2",
          ["角色ID"] = "2",
        },
        {
          ["节点"] = "文字",
          ["行动角色ID"] = "2",
          ["角色ID"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["节点"] = 95,
          ["行动角色ID"] = 95,
          ["角色ID"] = 95,
        },
        ["source_line"] = 88,
        ["source_path"] = "features/v102/base_screen.feature",
      },
      ["name"] = "刷新后应用输入锁仍隐藏自己回合皮肤入口",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 89,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前轮到角色ID为<行动角色ID>",
            ["source_line"] = 90,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "行动角色ID",
          },
          ["text"] = "当前轮到角色ID为<行动角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "基础屏刷新后应用输入锁",
            ["source_line"] = 91,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "基础屏刷新后应用输入锁",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "基础屏皮肤<节点>已隐藏",
            ["source_line"] = 92,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "节点",
          },
          ["text"] = "基础屏皮肤<节点>已隐藏",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["入口"] = "道具图鉴",
          ["行动角色ID"] = "2",
          ["角色ID"] = "1",
          ["预期行动角色ID"] = "2",
        },
        {
          ["入口"] = "托管按钮",
          ["行动角色ID"] = "2",
          ["角色ID"] = "1",
          ["预期行动角色ID"] = "2",
        },
        {
          ["入口"] = "行动日志",
          ["行动角色ID"] = "2",
          ["角色ID"] = "1",
          ["预期行动角色ID"] = "2",
        },
        {
          ["入口"] = "道具图鉴",
          ["行动角色ID"] = "1",
          ["角色ID"] = "2",
          ["预期行动角色ID"] = "1",
        },
        {
          ["入口"] = "托管按钮",
          ["行动角色ID"] = "1",
          ["角色ID"] = "2",
          ["预期行动角色ID"] = "1",
        },
        {
          ["入口"] = "行动日志",
          ["行动角色ID"] = "1",
          ["角色ID"] = "2",
          ["预期行动角色ID"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["入口"] = 112,
          ["行动角色ID"] = 112,
          ["角色ID"] = 112,
          ["预期行动角色ID"] = 112,
        },
        ["source_line"] = 103,
        ["source_path"] = "features/v102/base_screen.feature",
      },
      ["name"] = "刷新后应用输入锁仍保留基础屏辅助入口",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 104,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前轮到角色ID为<行动角色ID>",
            ["source_line"] = 105,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "行动角色ID",
          },
          ["text"] = "当前轮到角色ID为<行动角色ID>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "基础屏刷新后应用输入锁",
            ["source_line"] = 106,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "基础屏刷新后应用输入锁",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "基础屏当前行动角色ID为<预期行动角色ID>",
            ["source_line"] = 107,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "预期行动角色ID",
          },
          ["text"] = "基础屏当前行动角色ID为<预期行动角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "基础屏<入口>未被输入锁隐藏",
            ["source_line"] = 108,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "入口",
          },
          ["text"] = "基础屏<入口>未被输入锁隐藏",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "基础屏<入口>未被输入锁禁用",
            ["source_line"] = 109,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "入口",
          },
          ["text"] = "基础屏<入口>未被输入锁禁用",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["节点"] = "按钮",
          ["角色ID"] = "1",
        },
        {
          ["节点"] = "文字",
          ["角色ID"] = "1",
        },
        {
          ["节点"] = "按钮",
          ["角色ID"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["节点"] = 127,
          ["角色ID"] = 127,
        },
        ["source_line"] = 120,
        ["source_path"] = "features/v102/base_screen.feature",
      },
      ["name"] = "未定回合时隐藏皮肤入口",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 121,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "角色ID",
          },
          ["text"] = "玩家角色ID为<角色ID>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前轮次未定",
            ["source_line"] = 122,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前轮次未定",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "基础屏为该玩家刷新",
            ["source_line"] = 123,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {},
          ["text"] = "基础屏为该玩家刷新",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "基础屏皮肤<节点>已隐藏",
            ["source_line"] = 124,
            ["source_path"] = "features/v102/base_screen.feature",
          },
          ["parameters"] = {
            "节点",
          },
          ["text"] = "基础屏皮肤<节点>已隐藏",
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
