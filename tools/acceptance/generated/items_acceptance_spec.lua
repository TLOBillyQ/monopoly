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
        ["source_path"] = "features/game/items.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
    {
      ["keyword"] = "And",
      ["metadata"] = {
        ["original_text"] = "玩家背包上限为5格",
        ["source_line"] = 7,
        ["source_path"] = "features/game/items.feature",
      },
      ["parameters"] = {},
      ["text"] = "玩家背包上限为5格",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["余额"] = 206,
      ["使用时机"] = 13,
      ["停留回合"] = 228,
      ["可选距离"] = 115,
      ["固定点数"] = 144,
      ["埋设位置"] = 133,
      ["布置者"] = 347,
      ["平分后"] = 210,
      ["当前位置"] = 131,
      ["总余额"] = 208,
      ["持续回合"] = 333,
      ["攻击距离"] = 263,
      ["来源"] = 51,
      ["目标余额"] = 207,
      ["目标初始道具数"] = 179,
      ["目标剩余道具数"] = 182,
      ["神灵类型"] = 295,
      ["税金"] = 243,
      ["结果"] = 74,
      ["编号"] = 11,
      ["选择点数"] = 143,
      ["道具"] = 71,
      ["道具名"] = 10,
      ["键"] = 12,
      ["阶段"] = 73,
      ["障碍"] = 347,
      ["预期距离"] = 118,
    },
    ["field_names"] = {
      ["余额"] = "余额",
      ["使用时机"] = "使用时机",
      ["停留回合"] = "停留回合",
      ["可选距离"] = "可选距离",
      ["固定点数"] = "固定点数",
      ["埋设位置"] = "埋设位置",
      ["布置者"] = "布置者",
      ["平分后"] = "平分后",
      ["当前位置"] = "当前位置",
      ["总余额"] = "总余额",
      ["持续回合"] = "持续回合",
      ["攻击距离"] = "攻击距离",
      ["来源"] = "来源",
      ["目标余额"] = "目标余额",
      ["目标初始道具数"] = "目标初始道具数",
      ["目标剩余道具数"] = "目标剩余道具数",
      ["神灵类型"] = "神灵类型",
      ["税金"] = "税金",
      ["结果"] = "结果",
      ["编号"] = "编号",
      ["选择点数"] = "选择点数",
      ["道具"] = "道具",
      ["道具名"] = "道具名",
      ["键"] = "键",
      ["阶段"] = "阶段",
      ["障碍"] = "障碍",
      ["预期距离"] = "预期距离",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/items.feature",
  },
  ["name"] = "道具系统",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["使用时机"] = "post_action",
          ["编号"] = "2001",
          ["道具名"] = "免费卡",
          ["键"] = "free_rent",
        },
        {
          ["使用时机"] = "pre_action",
          ["编号"] = "2002",
          ["道具名"] = "遥控骰子卡",
          ["键"] = "remote_dice",
        },
        {
          ["使用时机"] = "pre_move",
          ["编号"] = "2003",
          ["道具名"] = "骰子加倍卡",
          ["键"] = "dice_multiplier",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2004",
          ["道具名"] = "路障卡",
          ["键"] = "roadblock",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2005",
          ["道具名"] = "地雷卡",
          ["键"] = "mine",
        },
        {
          ["使用时机"] = "pre_action",
          ["编号"] = "2006",
          ["道具名"] = "清障卡",
          ["键"] = "clear_obstacles",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2007",
          ["道具名"] = "偷窃卡",
          ["键"] = "steal",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2008",
          ["道具名"] = "怪兽卡",
          ["键"] = "monster",
        },
        {
          ["使用时机"] = "post_action",
          ["编号"] = "2009",
          ["道具名"] = "强征卡",
          ["键"] = "strong",
        },
        {
          ["使用时机"] = "tax_prompt",
          ["编号"] = "2010",
          ["道具名"] = "免税卡",
          ["键"] = "tax_free",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2011",
          ["道具名"] = "均富卡",
          ["键"] = "share_wealth",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2012",
          ["道具名"] = "流放卡",
          ["键"] = "exile",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2013",
          ["道具名"] = "导弹卡",
          ["键"] = "missile",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2014",
          ["道具名"] = "查税卡",
          ["键"] = "tax",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2015",
          ["道具名"] = "请神卡",
          ["键"] = "invite_deity",
        },
        {
          ["使用时机"] = "trigger_poor_god",
          ["编号"] = "2016",
          ["道具名"] = "送神卡",
          ["键"] = "send_poor",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2017",
          ["道具名"] = "财神卡",
          ["键"] = "rich",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2018",
          ["道具名"] = "穷神卡",
          ["键"] = "poor",
        },
        {
          ["使用时机"] = "manual",
          ["编号"] = "2019",
          ["道具名"] = "天使卡",
          ["键"] = "angel",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["使用时机"] = 16,
          ["编号"] = 16,
          ["道具名"] = 16,
          ["键"] = 16,
        },
        ["source_line"] = 9,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "策划案道具卡目录完整",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "策划案道具卡目录包含<道具名>",
            ["source_line"] = 10,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具名",
          },
          ["text"] = "策划案道具卡目录包含<道具名>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具<道具名>的编号为<编号>",
            ["source_line"] = 11,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具名",
            "编号",
          },
          ["text"] = "道具<道具名>的编号为<编号>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具<道具名>的键为<键>",
            ["source_line"] = 12,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具名",
            "键",
          },
          ["text"] = "道具<道具名>的键为<键>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具<道具名>的使用时机为<使用时机>",
            ["source_line"] = 13,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具名",
            "使用时机",
          },
          ["text"] = "道具<道具名>的使用时机为<使用时机>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 37,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "落在道具格随机获得道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在道具格",
            ["source_line"] = 38,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在道具格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "背包未满",
            ["source_line"] = 39,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "背包未满",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 40,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家随机获得一张道具卡",
            ["source_line"] = 41,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家随机获得一张道具卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具按权重抽取",
            ["source_line"] = 42,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具按权重抽取",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 44,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "背包已满时无法获得道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家背包已有5张道具",
            ["source_line"] = 45,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家背包已有5张道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家触发获得道具",
            ["source_line"] = 46,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家触发获得道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具不入包",
            ["source_line"] = 47,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具不入包",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "弹出背包已满提示",
            ["source_line"] = 48,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "弹出背包已满提示",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["来源"] = "购买",
        },
        {
          ["来源"] = "道具格",
        },
        {
          ["来源"] = "机会卡",
        },
        {
          ["来源"] = "偷窃",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["来源"] = 58,
        },
        ["source_line"] = 50,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "获得道具时先展示放大卡牌再收入卡槽",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家通过<来源>获得道具卡",
            ["source_line"] = 51,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "来源",
          },
          ["text"] = "玩家通过<来源>获得道具卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家背包未满",
            ["source_line"] = 52,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家背包未满",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "道具获得表现播放",
            ["source_line"] = 53,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具获得表现播放",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "新获得的道具卡放大展示3秒",
            ["source_line"] = 54,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "新获得的道具卡放大展示3秒",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "展示结束后道具卡收入玩家卡槽",
            ["source_line"] = 55,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "展示结束后道具卡收入玩家卡槽",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 64,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "背包已满时黑市购买道具失败",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家背包已有5张道具",
            ["source_line"] = 65,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家背包已有5张道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家在黑市购买道具",
            ["source_line"] = 66,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家在黑市购买道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "购买失败",
            ["source_line"] = 67,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "购买失败",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "提示你的卡槽满了",
            ["source_line"] = 68,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "提示你的卡槽满了",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["结果"] = "使用成功",
          ["道具"] = "遥控骰子卡",
          ["阶段"] = "行动前",
        },
        {
          ["结果"] = "提示该卡只能在行动前使用",
          ["道具"] = "遥控骰子卡",
          ["阶段"] = "行动中",
        },
        {
          ["结果"] = "提示该卡只能在行动前使用",
          ["道具"] = "遥控骰子卡",
          ["阶段"] = "行动后",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["结果"] = 77,
          ["道具"] = 77,
          ["阶段"] = 77,
        },
        ["source_line"] = 70,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "行动前道具只能在投骰前使用",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<道具>",
            ["source_line"] = 71,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具",
          },
          ["text"] = "玩家持有<道具>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "<道具>属于行动前使用道具",
            ["source_line"] = 72,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具",
          },
          ["text"] = "<道具>属于行动前使用道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家在<阶段>尝试使用<道具>",
            ["source_line"] = 73,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "阶段",
            "道具",
          },
          ["text"] = "玩家在<阶段>尝试使用<道具>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具使用结果为<结果>",
            ["source_line"] = 74,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "结果",
          },
          ["text"] = "道具使用结果为<结果>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["结果"] = "使用成功",
          ["道具"] = "偷窃卡",
          ["阶段"] = "行动前",
        },
        {
          ["结果"] = "使用成功",
          ["道具"] = "偷窃卡",
          ["阶段"] = "行动后",
        },
        {
          ["结果"] = "提示该卡需在你的回合使用",
          ["道具"] = "偷窃卡",
          ["阶段"] = "行动中",
        },
        {
          ["结果"] = "提示该卡需在你的回合使用",
          ["道具"] = "偷窃卡",
          ["阶段"] = "他人回合",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["结果"] = 89,
          ["道具"] = 89,
          ["阶段"] = 89,
        },
        ["source_line"] = 82,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "主动道具只能在自己回合行动前或行动后使用",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<道具>",
            ["source_line"] = 83,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具",
          },
          ["text"] = "玩家持有<道具>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "<道具>属于主动使用道具",
            ["source_line"] = 84,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具",
          },
          ["text"] = "<道具>属于主动使用道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家在<阶段>尝试使用<道具>",
            ["source_line"] = 85,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "阶段",
            "道具",
          },
          ["text"] = "玩家在<阶段>尝试使用<道具>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具使用结果为<结果>",
            ["source_line"] = 86,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "结果",
          },
          ["text"] = "道具使用结果为<结果>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 95,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "触发型道具未到时机时不能主动使用",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有触发型道具",
            ["source_line"] = 96,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有触发型道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家手动点击使用该道具",
            ["source_line"] = 97,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家手动点击使用该道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具使用结果为提示该卡未到使用时机",
            ["source_line"] = 98,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具使用结果为提示该卡未到使用时机",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 100,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "点击道具槽位弹出使用和丢弃按钮",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家在槽位1持有遥控骰子卡",
            ["source_line"] = 101,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家在槽位1持有遥控骰子卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家点击道具槽位1",
            ["source_line"] = 102,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击道具槽位1",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具操作面板显示使用按钮",
            ["source_line"] = 103,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具操作面板显示使用按钮",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具操作面板显示丢弃按钮",
            ["source_line"] = 104,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具操作面板显示丢弃按钮",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 106,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "丢弃道具删除该卡并空出卡槽",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家在槽位1持有遥控骰子卡",
            ["source_line"] = 107,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家在槽位1持有遥控骰子卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家点击道具槽位1",
            ["source_line"] = 108,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击道具槽位1",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家点击丢弃按钮",
            ["source_line"] = 109,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家点击丢弃按钮",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "槽位1变为空",
            ["source_line"] = 110,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "槽位1变为空",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "遥控骰子卡从玩家背包移除",
            ["source_line"] = 111,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "遥控骰子卡从玩家背包移除",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["可选距离"] = "3",
          ["预期距离"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["可选距离"] = 122,
          ["预期距离"] = 122,
        },
        ["source_line"] = 113,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "路障卡放置在前方或后方格子",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用路障卡",
            ["source_line"] = 114,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用路障卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "可选范围为前后各<可选距离>格",
            ["source_line"] = 115,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "可选距离",
          },
          ["text"] = "可选范围为前后各<可选距离>格",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择放置位置",
            ["source_line"] = 116,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择放置位置",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "路障放置在指定格子",
            ["source_line"] = 117,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "路障放置在指定格子",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "路障候选范围为<预期距离>格",
            ["source_line"] = 118,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "预期距离",
          },
          ["text"] = "路障候选范围为<预期距离>格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "路障卡被消耗",
            ["source_line"] = 119,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "路障卡被消耗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 125,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "已有路障或地雷的格子不可再放路障",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "格子已存在路障或地雷",
            ["source_line"] = 126,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "格子已存在路障或地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择路障放置目标",
            ["source_line"] = 127,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择路障放置目标",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "该格子不出现在候选列表中",
            ["source_line"] = 128,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "该格子不出现在候选列表中",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["埋设位置"] = "5",
          ["当前位置"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["埋设位置"] = 138,
          ["当前位置"] = 138,
        },
        ["source_line"] = 130,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "地雷卡埋设在当前位置",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家位于格子<当前位置>",
            ["source_line"] = 131,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "当前位置",
          },
          ["text"] = "玩家位于格子<当前位置>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用地雷卡",
            ["source_line"] = 132,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用地雷卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地雷埋设在格子<埋设位置>",
            ["source_line"] = 133,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "埋设位置",
          },
          ["text"] = "地雷埋设在格子<埋设位置>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地雷状态为已激活",
            ["source_line"] = 134,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地雷状态为已激活",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地雷记录布置者和布置回合",
            ["source_line"] = 135,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地雷记录布置者和布置回合",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["固定点数"] = "1",
          ["选择点数"] = "1",
        },
        {
          ["固定点数"] = "6",
          ["选择点数"] = "6",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["固定点数"] = 148,
          ["选择点数"] = 148,
        },
        ["source_line"] = 141,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "遥控骰子选择点数",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用遥控骰子",
            ["source_line"] = 142,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用遥控骰子",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择点数<选择点数>",
            ["source_line"] = 143,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "选择点数",
          },
          ["text"] = "玩家选择点数<选择点数>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "下次掷骰每颗骰子固定为<固定点数>",
            ["source_line"] = 144,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "固定点数",
          },
          ["text"] = "下次掷骰每颗骰子固定为<固定点数>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "遥控骰子被消耗",
            ["source_line"] = 145,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "遥控骰子被消耗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 152,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "骰子加倍卡设置倍率",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用骰子加倍卡",
            ["source_line"] = 153,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用骰子加倍卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果生效",
            ["source_line"] = 154,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果生效",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家的骰子倍率设为2",
            ["source_line"] = 155,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的骰子倍率设为2",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "骰子加倍卡被消耗",
            ["source_line"] = 156,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "骰子加倍卡被消耗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 158,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "免费卡设置下次免租状态",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用免费卡",
            ["source_line"] = 159,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用免费卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果生效",
            ["source_line"] = 160,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果生效",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家的免租状态设为待触发",
            ["source_line"] = 161,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的免租状态设为待触发",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "免费卡被消耗",
            ["source_line"] = 162,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "免费卡被消耗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 164,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "强征卡支付总价值并获得目标地块",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在目标地块且持有强征卡",
            ["source_line"] = 165,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在目标地块且持有强征卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择使用强征卡",
            ["source_line"] = 166,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择使用强征卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标地块归玩家所有",
            ["source_line"] = 167,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标地块归玩家所有",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家支付目标地块总价值",
            ["source_line"] = 168,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家支付目标地块总价值",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "强征卡被消耗",
            ["source_line"] = 169,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "强征卡被消耗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 171,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "免税卡设置下次免税状态",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用免税卡",
            ["source_line"] = 172,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用免税卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果生效",
            ["source_line"] = 173,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果生效",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家的免税状态设为待触发",
            ["source_line"] = 174,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的免税状态设为待触发",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "免税卡被消耗",
            ["source_line"] = 175,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "免税卡被消耗",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["目标初始道具数"] = "1",
          ["目标剩余道具数"] = "0",
        },
        {
          ["目标初始道具数"] = "3",
          ["目标剩余道具数"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["目标初始道具数"] = 187,
          ["目标剩余道具数"] = 187,
        },
        ["source_line"] = 177,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "偷窃卡从目标随机偷取一张道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用偷窃卡",
            ["source_line"] = 178,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用偷窃卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标持有<目标初始道具数>张道具",
            ["source_line"] = 179,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "目标初始道具数",
          },
          ["text"] = "目标持有<目标初始道具数>张道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果执行",
            ["source_line"] = 180,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标随机失去一张道具",
            ["source_line"] = 181,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标随机失去一张道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标剩余<目标剩余道具数>张道具",
            ["source_line"] = 182,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "目标剩余道具数",
          },
          ["text"] = "目标剩余<目标剩余道具数>张道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该道具转入玩家背包",
            ["source_line"] = 183,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "该道具转入玩家背包",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "偷窃卡被消耗",
            ["source_line"] = 184,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "偷窃卡被消耗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 191,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "偷窃卡目标无道具时失败",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用偷窃卡",
            ["source_line"] = 192,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用偷窃卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标持有0张道具",
            ["source_line"] = 193,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标持有0张道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果执行",
            ["source_line"] = 194,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "偷窃失败",
            ["source_line"] = 195,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "偷窃失败",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "提示目标没有道具",
            ["source_line"] = 196,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "提示目标没有道具",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 198,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "路过其他玩家不会被动触发偷窃卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有偷窃卡并路过持有道具的目标",
            ["source_line"] = 199,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有偷窃卡并路过持有道具的目标",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "路过后的落地结算执行",
            ["source_line"] = 200,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "路过后的落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "不弹出偷窃选择",
            ["source_line"] = 201,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "不弹出偷窃选择",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "偷窃卡未被消耗",
            ["source_line"] = 202,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "偷窃卡未被消耗",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标仍持有道具",
            ["source_line"] = 203,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标仍持有道具",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["余额"] = "2000",
          ["平分后"] = "5000",
          ["总余额"] = "10000",
          ["目标余额"] = "8000",
        },
        {
          ["余额"] = "1000",
          ["平分后"] = "2000",
          ["总余额"] = "4000",
          ["目标余额"] = "3000",
        },
        {
          ["余额"] = "5001",
          ["平分后"] = "5000",
          ["总余额"] = "10000",
          ["目标余额"] = "4999",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["余额"] = 213,
          ["平分后"] = 213,
          ["总余额"] = 213,
          ["目标余额"] = 213,
        },
        ["source_line"] = 205,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "均富卡平分双方资金",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<余额>金币",
            ["source_line"] = 206,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "余额",
          },
          ["text"] = "玩家持有<余额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标持有<目标余额>金币",
            ["source_line"] = 207,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "目标余额",
          },
          ["text"] = "目标持有<目标余额>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "使用前双方总额为<总余额>金币",
            ["source_line"] = 208,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "总余额",
          },
          ["text"] = "使用前双方总额为<总余额>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用均富卡",
            ["source_line"] = 209,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用均富卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "双方各持有<平分后>金币",
            ["source_line"] = 210,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "平分后",
          },
          ["text"] = "双方各持有<平分后>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 218,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "天使守护免疫均富卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标拥有天使守护",
            ["source_line"] = 219,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标拥有天使守护",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用均富卡",
            ["source_line"] = 220,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用均富卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "均富无效",
            ["source_line"] = 221,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "均富无效",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "天使守护抵消提示",
            ["source_line"] = 222,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "天使守护抵消提示",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["停留回合"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["停留回合"] = 231,
        },
        ["source_line"] = 224,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "流放卡将目标送往深山",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用流放卡",
            ["source_line"] = 225,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用流放卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果执行",
            ["source_line"] = 226,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标被传送到深山格",
            ["source_line"] = 227,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标被传送到深山格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标需停留<停留回合>回合",
            ["source_line"] = 228,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "停留回合",
          },
          ["text"] = "目标需停留<停留回合>回合",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 234,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "天使守护免疫流放卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标拥有天使守护",
            ["source_line"] = 235,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标拥有天使守护",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用流放卡",
            ["source_line"] = 236,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用流放卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "流放无效",
            ["source_line"] = 237,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "流放无效",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "天使守护抵消提示",
            ["source_line"] = 238,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "天使守护抵消提示",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["余额"] = "10000",
          ["税金"] = "5000",
        },
        {
          ["余额"] = "3000",
          ["税金"] = "1500",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["余额"] = 246,
          ["税金"] = 246,
        },
        ["source_line"] = 240,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "查税卡对目标收取50%税金",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标持有<余额>金币",
            ["source_line"] = 241,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "余额",
          },
          ["text"] = "目标持有<余额>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用查税卡",
            ["source_line"] = 242,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用查税卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标被收取<税金>金币",
            ["source_line"] = 243,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "税金",
          },
          ["text"] = "目标被收取<税金>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 250,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "查税卡目标持有免税卡时自动抵消",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标持有免税卡",
            ["source_line"] = 251,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标持有免税卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用查税卡",
            ["source_line"] = 252,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用查税卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标的免税卡被消耗",
            ["source_line"] = 253,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标的免税卡被消耗",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标不被收税",
            ["source_line"] = 254,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标不被收税",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 256,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "天使守护免疫查税卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标拥有天使守护",
            ["source_line"] = 257,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标拥有天使守护",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用查税卡",
            ["source_line"] = 258,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用查税卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "查税无效",
            ["source_line"] = 259,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "查税无效",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "天使守护抵消提示",
            ["source_line"] = 260,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "天使守护抵消提示",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["攻击距离"] = "3",
          ["预期距离"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["攻击距离"] = 270,
          ["预期距离"] = 270,
        },
        ["source_line"] = 262,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "怪兽卡摧毁对手建筑",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手在范围<攻击距离>格内有等级大于0的地块",
            ["source_line"] = 263,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "攻击距离",
          },
          ["text"] = "对手在范围<攻击距离>格内有等级大于0的地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用怪兽卡选择该地块",
            ["source_line"] = 264,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用怪兽卡选择该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地块等级重置为0",
            ["source_line"] = 265,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块等级重置为0",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "怪兽攻击范围为<预期距离>格",
            ["source_line"] = 266,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "预期距离",
          },
          ["text"] = "怪兽攻击范围为<预期距离>格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "怪兽卡被消耗",
            ["source_line"] = 267,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "怪兽卡被消耗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 273,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "导弹卡摧毁建筑并送伤者住院",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手位于目标地块上",
            ["source_line"] = 274,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手位于目标地块上",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块等级大于0",
            ["source_line"] = 275,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块等级大于0",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用导弹卡轰炸该地块",
            ["source_line"] = 276,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用导弹卡轰炸该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地块等级重置为0",
            ["source_line"] = 277,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块等级重置为0",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块上的对手被送往医院",
            ["source_line"] = 278,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块上的对手被送往医院",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 280,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "导弹卡轰炸自己地块也摧毁建筑",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家自己的地块等级大于0",
            ["source_line"] = 281,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家自己的地块等级大于0",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手位于该地块上",
            ["source_line"] = 282,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手位于该地块上",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用导弹卡轰炸该地块",
            ["source_line"] = 283,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用导弹卡轰炸该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地块等级重置为0",
            ["source_line"] = 284,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块等级重置为0",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块上的对手被送往医院",
            ["source_line"] = 285,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块上的对手被送往医院",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 287,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "天使守护免疫建筑摧毁",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手拥有天使守护",
            ["source_line"] = 288,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手拥有天使守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手的地块等级大于0",
            ["source_line"] = 289,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手的地块等级大于0",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对该地块使用怪兽卡",
            ["source_line"] = 290,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对该地块使用怪兽卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "建筑不被摧毁",
            ["source_line"] = 291,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "建筑不被摧毁",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "天使守护抵消提示",
            ["source_line"] = 292,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "天使守护抵消提示",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["神灵类型"] = "财神",
        },
        {
          ["神灵类型"] = "穷神",
        },
        {
          ["神灵类型"] = "天使",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["神灵类型"] = 300,
        },
        ["source_line"] = 294,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "请神卡夺取目标的神灵",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标身上附有<神灵类型>",
            ["source_line"] = 295,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "神灵类型",
          },
          ["text"] = "目标身上附有<神灵类型>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用请神卡",
            ["source_line"] = 296,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用请神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<神灵类型>转移到玩家身上",
            ["source_line"] = 297,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "神灵类型",
          },
          ["text"] = "<神灵类型>转移到玩家身上",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 305,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "送神卡将穷神转给目标",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家身上附有穷神",
            ["source_line"] = 306,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家身上附有穷神",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用送神卡",
            ["source_line"] = 307,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用送神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "穷神转移到目标身上",
            ["source_line"] = 308,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "穷神转移到目标身上",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 310,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "送神卡可覆盖目标的天使附身",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标拥有天使守护",
            ["source_line"] = 311,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标拥有天使守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家身上附有穷神",
            ["source_line"] = 312,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家身上附有穷神",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用送神卡",
            ["source_line"] = 313,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用送神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标天使附身被清除",
            ["source_line"] = 314,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标天使附身被清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "穷神转移到目标身上",
            ["source_line"] = 315,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "穷神转移到目标身上",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 317,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "穷神卡令目标附体",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用穷神卡",
            ["source_line"] = 318,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用穷神卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果生效",
            ["source_line"] = 319,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果生效",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标获得穷神守护",
            ["source_line"] = 320,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标获得穷神守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标神灵持续10回合",
            ["source_line"] = 321,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标神灵持续10回合",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 323,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "穷神卡可覆盖目标的天使附身",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标拥有天使守护",
            ["source_line"] = 324,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标拥有天使守护",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用穷神卡",
            ["source_line"] = 325,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用穷神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标天使附身被清除",
            ["source_line"] = 326,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标天使附身被清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标获得穷神守护",
            ["source_line"] = 327,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标获得穷神守护",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["持续回合"] = "10",
          ["神灵类型"] = "财神",
          ["道具名"] = "财神卡",
        },
        {
          ["持续回合"] = "10",
          ["神灵类型"] = "天使",
          ["道具名"] = "天使卡",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["持续回合"] = 336,
          ["神灵类型"] = 336,
          ["道具名"] = 336,
        },
        ["source_line"] = 329,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "财神卡和天使卡自身附体",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用<道具名>",
            ["source_line"] = 330,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具名",
          },
          ["text"] = "玩家使用<道具名>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果生效",
            ["source_line"] = 331,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果生效",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家获得<神灵类型>守护",
            ["source_line"] = 332,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "神灵类型",
          },
          ["text"] = "玩家获得<神灵类型>守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "持续<持续回合>回合",
            ["source_line"] = 333,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "持续回合",
          },
          ["text"] = "持续<持续回合>回合",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 340,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "清障卡清除前方障碍物",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家前方12格内有路障和地雷",
            ["source_line"] = 341,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家前方12格内有路障和地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用清障卡",
            ["source_line"] = 342,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用清障卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "前方12格内的路障和地雷被清除",
            ["source_line"] = 343,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "前方12格内的路障和地雷被清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "清障卡被消耗",
            ["source_line"] = 344,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "清障卡被消耗",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["布置者"] = "自己",
          ["障碍"] = "路障",
        },
        {
          ["布置者"] = "自己",
          ["障碍"] = "地雷",
        },
        {
          ["布置者"] = "对手",
          ["障碍"] = "路障",
        },
        {
          ["布置者"] = "对手",
          ["障碍"] = "地雷",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["布置者"] = 353,
          ["障碍"] = 353,
        },
        ["source_line"] = 346,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "清障卡清除任意玩家布置的障碍",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家前方12格内有<布置者>布置的<障碍>",
            ["source_line"] = 347,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "布置者",
            "障碍",
          },
          ["text"] = "玩家前方12格内有<布置者>布置的<障碍>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用清障卡",
            ["source_line"] = 348,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用清障卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "前方12格内的<障碍>被清除",
            ["source_line"] = 349,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "障碍",
          },
          ["text"] = "前方12格内的<障碍>被清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "清障卡被消耗",
            ["source_line"] = 350,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "清障卡被消耗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 359,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "天使守护免疫导弹伤害",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手拥有天使守护",
            ["source_line"] = 360,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手拥有天使守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手位于目标地块上",
            ["source_line"] = 361,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手位于目标地块上",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用导弹卡轰炸该地块",
            ["source_line"] = 362,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用导弹卡轰炸该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地块建筑不被摧毁",
            ["source_line"] = 363,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块建筑不被摧毁",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手不被送往医院",
            ["source_line"] = 364,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手不被送往医院",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "天使守护抵消提示",
            ["source_line"] = 365,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "天使守护抵消提示",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 367,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "针对玩家的道具不可对自己使用",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有需指定目标的道具",
            ["source_line"] = 368,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有需指定目标的道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试对自己使用该道具",
            ["source_line"] = 369,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试对自己使用该道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "自己不出现在目标候选列表中",
            ["source_line"] = 370,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "自己不出现在目标候选列表中",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 372,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "请神卡目标无神灵时不可使用",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标身上没有任何神灵",
            ["source_line"] = 373,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标身上没有任何神灵",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试对目标使用请神卡",
            ["source_line"] = 374,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试对目标使用请神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标不出现在候选列表中",
            ["source_line"] = 375,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标不出现在候选列表中",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["道具"] = "偷窃卡",
        },
        {
          ["道具"] = "均富卡",
        },
        {
          ["道具"] = "流放卡",
        },
        {
          ["道具"] = "导弹卡",
        },
        {
          ["道具"] = "查税卡",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["道具"] = 383,
        },
        ["source_line"] = 377,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "天使守护让目标退出可选玩家列表",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标拥有天使守护",
            ["source_line"] = 378,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标拥有天使守护",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试对目标使用<道具>",
            ["source_line"] = 379,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具",
          },
          ["text"] = "玩家尝试对目标使用<道具>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标不出现在候选列表中",
            ["source_line"] = 380,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标不出现在候选列表中",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 390,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "送神卡使用者无穷神时不可使用",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家身上没有穷神",
            ["source_line"] = 391,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家身上没有穷神",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试使用送神卡",
            ["source_line"] = 392,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试使用送神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "送神卡不可用",
            ["source_line"] = 393,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "送神卡不可用",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["道具名"] = "遥控骰子",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["道具名"] = 401,
        },
        ["source_line"] = 395,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "同组道具单回合内只能使用一次",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有两张<道具名>",
            ["source_line"] = 396,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具名",
          },
          ["text"] = "玩家持有两张<道具名>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家在本回合已使用一张<道具名>",
            ["source_line"] = 397,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具名",
          },
          ["text"] = "玩家在本回合已使用一张<道具名>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "第二张<道具名>在本回合不可再选用",
            ["source_line"] = 398,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "道具名",
          },
          ["text"] = "第二张<道具名>在本回合不可再选用",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 404,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "道具使用分组限制在回合结束时重置",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家本回合已使用过遥控骰子",
            ["source_line"] = 405,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本回合已使用过遥控骰子",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家的回合结束并进入下一回合",
            ["source_line"] = 406,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的回合结束并进入下一回合",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家可以再次使用遥控骰子",
            ["source_line"] = 407,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家可以再次使用遥控骰子",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 409,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "偷窃时背包已满则失败且不消耗偷窃卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家背包已满且持有偷窃卡",
            ["source_line"] = 410,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家背包已满且持有偷窃卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标持有道具",
            ["source_line"] = 411,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标持有道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果执行",
            ["source_line"] = 412,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "偷窃失败",
            ["source_line"] = 413,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "偷窃失败",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "偷窃卡未被消耗",
            ["source_line"] = 414,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "偷窃卡未被消耗",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "弹出背包已满提示",
            ["source_line"] = 415,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "弹出背包已满提示",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 417,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "未激活的地雷不触发",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于格子2",
            ["source_line"] = 418,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前位于格子2",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子3放置了未激活的地雷",
            ["source_line"] = 419,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "格子3放置了未激活的地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动1步到达格子3",
            ["source_line"] = 420,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家移动1步到达格子3",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地雷不触发",
            ["source_line"] = 421,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地雷不触发",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家不被送往医院",
            ["source_line"] = 422,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家不被送往医院",
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
