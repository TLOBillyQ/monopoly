-- luacheck: globals describe it
local runtime = require("acceptance.runtime")
local steps = require("acceptance.steps")

local ir = {
  ["background"] = {
    {
      ["keyword"] = "Given",
      ["metadata"] = {
        ["original_text"] = "游戏已初始化标准棋盘",
        ["source_line"] = 6,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 9,
      ["p2"] = 19,
      ["p3"] = 22,
      ["p4"] = 33,
      ["p5"] = 47,
    },
    ["field_names"] = {
      ["p1"] = "角色ID",
      ["p2"] = "道具数",
      ["p3"] = "槽位数",
      ["p4"] = "槽位",
      ["p5"] = "页码",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/v102/item_atlas.feature",
  },
  ["name"] = "道具图鉴",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["p1"] = "1",
        },
        {
          ["p1"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 14,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "打开道具图鉴后图鉴开启",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 9,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 10,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已开启",
            ["source_line"] = 11,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具图鉴屏幕已开启",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p3"] = "8",
        },
        {
          ["p1"] = "1",
          ["p2"] = "5",
          ["p3"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 25,
          ["p2"] = 25,
          ["p3"] = 25,
        },
        ["source_line"] = 18,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "道具图鉴每页展示8个道具槽位",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 19,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 20,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 21,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 22,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个道具槽位",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p3"] = "8",
          ["p4"] = "1",
        },
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p3"] = "8",
          ["p4"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 38,
          ["p2"] = 38,
          ["p3"] = 38,
          ["p4"] = 38,
        },
        ["source_line"] = 29,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "选中道具槽位记录选中道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 30,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 31,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 32,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选中第<槽位>格道具",
            ["source_line"] = 33,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家选中第<p4>格道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前选中道具为第<槽位>格对应道具",
            ["source_line"] = 34,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "当前选中道具为第<p4>格对应道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 35,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个道具槽位",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "16",
          ["p3"] = "8",
          ["p5"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 51,
          ["p2"] = 51,
          ["p3"] = 51,
          ["p5"] = 51,
        },
        ["source_line"] = 42,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "翻到下一页",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 43,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 44,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 45,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 46,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 47,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前图鉴页码为<p5>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前页面展示<槽位数>个道具槽位",
            ["source_line"] = 48,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "当前页面展示<p3>个道具槽位",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "8",
          ["p5"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 63,
          ["p2"] = 63,
          ["p5"] = 63,
        },
        ["source_line"] = 54,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "图鉴翻页不超出范围",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "道具目录共有<道具数>种道具",
            ["source_line"] = 55,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "道具目录共有<p2>种道具",
        },
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 56,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 57,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 58,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家翻到图鉴下一页",
            ["source_line"] = 59,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家翻到图鉴下一页",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "当前图鉴页码为<页码>",
            ["source_line"] = 60,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "当前图鉴页码为<p5>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 73,
        },
        ["source_line"] = 66,
        ["source_path"] = "features/v102/item_atlas.feature",
      },
      ["name"] = "关闭道具图鉴",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家角色ID为<角色ID>",
            ["source_line"] = 67,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家角色ID为<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家打开道具图鉴",
            ["source_line"] = 68,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开道具图鉴",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家关闭道具图鉴",
            ["source_line"] = 69,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭道具图鉴",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具图鉴屏幕已关闭",
            ["source_line"] = 70,
            ["source_path"] = "features/v102/item_atlas.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具图鉴屏幕已关闭",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
