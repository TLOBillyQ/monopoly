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
      ["p1"] = 24,
      ["p10"] = 129,
      ["p11"] = 167,
      ["p12"] = 182,
      ["p13"] = 185,
      ["p2"] = 39,
      ["p3"] = 51,
      ["p4"] = 80,
      ["p5"] = 99,
      ["p6"] = 100,
      ["p7"] = 102,
      ["p8"] = 114,
      ["p9"] = 127,
    },
    ["field_names"] = {
      ["p1"] = "距离",
      ["p10"] = "税金",
      ["p11"] = "神灵类型",
      ["p12"] = "道具名",
      ["p13"] = "持续回合",
      ["p2"] = "位置",
      ["p3"] = "设定值",
      ["p4"] = "目标道具数",
      ["p5"] = "玩家余额",
      ["p6"] = "目标余额",
      ["p7"] = "平分后",
      ["p8"] = "停留回合",
      ["p9"] = "余额",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/items.feature",
  },
  ["name"] = "道具系统",
  ["scenarios"] = {
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 9,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "落在道具格随机获得道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在道具格",
            ["source_line"] = 10,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在道具格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "背包未满",
            ["source_line"] = 11,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "背包未满",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 12,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家随机获得一张道具卡",
            ["source_line"] = 13,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家随机获得一张道具卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具按权重抽取",
            ["source_line"] = 14,
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
        ["source_line"] = 16,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "背包已满时无法获得道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家背包已有5张道具",
            ["source_line"] = 17,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家背包已有5张道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家触发获得道具",
            ["source_line"] = 18,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家触发获得道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具不入包",
            ["source_line"] = 19,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具不入包",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "弹出背包已满提示",
            ["source_line"] = 20,
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
          ["p1"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 30,
        },
        ["source_line"] = 22,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "路障卡放置在前方或后方格子",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用路障卡",
            ["source_line"] = 23,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用路障卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "可选范围为前后各<距离>格",
            ["source_line"] = 24,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "可选范围为前后各<p1>格",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择放置位置",
            ["source_line"] = 25,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择放置位置",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "路障放置在指定格子",
            ["source_line"] = 26,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "路障放置在指定格子",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "路障卡被消耗",
            ["source_line"] = 27,
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
        ["source_line"] = 33,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "已有路障或地雷的格子不可再放路障",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "格子已存在路障或地雷",
            ["source_line"] = 34,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "格子已存在路障或地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择路障放置目标",
            ["source_line"] = 35,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择路障放置目标",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "该格子不出现在候选列表中",
            ["source_line"] = 36,
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
          ["p2"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p2"] = 46,
        },
        ["source_line"] = 38,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "地雷卡埋设在当前位置",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家位于格子<位置>",
            ["source_line"] = 39,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家位于格子<p2>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用地雷卡",
            ["source_line"] = 40,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用地雷卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地雷埋设在格子<位置>",
            ["source_line"] = 41,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "地雷埋设在格子<p2>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地雷状态为已激活",
            ["source_line"] = 42,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地雷状态为已激活",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地雷记录布置者和布置回合",
            ["source_line"] = 43,
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
          ["p3"] = "1",
        },
        {
          ["p3"] = "6",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p3"] = 56,
        },
        ["source_line"] = 49,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "遥控骰子选择点数",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用遥控骰子",
            ["source_line"] = 50,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用遥控骰子",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择点数<设定值>",
            ["source_line"] = 51,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "玩家选择点数<p3>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "下次掷骰每颗骰子固定为<设定值>",
            ["source_line"] = 52,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "下次掷骰每颗骰子固定为<p3>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "遥控骰子被消耗",
            ["source_line"] = 53,
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
        ["source_line"] = 60,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "骰子加倍卡设置倍率",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用骰子加倍卡",
            ["source_line"] = 61,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用骰子加倍卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果生效",
            ["source_line"] = 62,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果生效",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家的骰子倍率设为2",
            ["source_line"] = 63,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的骰子倍率设为2",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "骰子加倍卡被消耗",
            ["source_line"] = 64,
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
        ["source_line"] = 66,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "免费卡设置下次免租状态",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用免费卡",
            ["source_line"] = 67,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用免费卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果生效",
            ["source_line"] = 68,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果生效",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家的免租状态设为待触发",
            ["source_line"] = 69,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的免租状态设为待触发",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "免费卡被消耗",
            ["source_line"] = 70,
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
        ["source_line"] = 72,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "免税卡设置下次免税状态",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用免税卡",
            ["source_line"] = 73,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用免税卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果生效",
            ["source_line"] = 74,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果生效",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家的免税状态设为待触发",
            ["source_line"] = 75,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的免税状态设为待触发",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "免税卡被消耗",
            ["source_line"] = 76,
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
          ["p4"] = "1",
        },
        {
          ["p4"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p4"] = 87,
        },
        ["source_line"] = 78,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "偷窃卡从目标随机偷取一张道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用偷窃卡",
            ["source_line"] = 79,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用偷窃卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标持有<目标道具数>张道具",
            ["source_line"] = 80,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "目标持有<p4>张道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果执行",
            ["source_line"] = 81,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标随机失去一张道具",
            ["source_line"] = 82,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标随机失去一张道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该道具转入玩家背包",
            ["source_line"] = 83,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "该道具转入玩家背包",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "偷窃卡被消耗",
            ["source_line"] = 84,
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
        ["source_line"] = 91,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "偷窃卡目标无道具时失败",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用偷窃卡",
            ["source_line"] = 92,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用偷窃卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标持有0张道具",
            ["source_line"] = 93,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标持有0张道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果执行",
            ["source_line"] = 94,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "偷窃失败",
            ["source_line"] = 95,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "偷窃失败",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "提示目标没有道具",
            ["source_line"] = 96,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "提示目标没有道具",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p5"] = "2000",
          ["p6"] = "8000",
          ["p7"] = "5000",
        },
        {
          ["p5"] = "1000",
          ["p6"] = "3000",
          ["p7"] = "2000",
        },
        {
          ["p5"] = "5001",
          ["p6"] = "4999",
          ["p7"] = "5000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p5"] = 105,
          ["p6"] = 105,
          ["p7"] = 105,
        },
        ["source_line"] = 98,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "均富卡平分双方资金",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有<玩家余额>金币",
            ["source_line"] = 99,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "玩家持有<p5>金币",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标持有<目标余额>金币",
            ["source_line"] = 100,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "目标持有<p6>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用均富卡",
            ["source_line"] = 101,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用均富卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "双方各持有<平分后>金币",
            ["source_line"] = 102,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p7",
          },
          ["text"] = "双方各持有<p7>金币",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p8"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p8"] = 117,
        },
        ["source_line"] = 110,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "流放卡将目标送往深山",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用流放卡",
            ["source_line"] = 111,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用流放卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果执行",
            ["source_line"] = 112,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标被传送到深山格",
            ["source_line"] = 113,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标被传送到深山格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标需停留<停留回合>回合",
            ["source_line"] = 114,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p8",
          },
          ["text"] = "目标需停留<p8>回合",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 120,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "天使守护免疫流放卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标拥有天使守护",
            ["source_line"] = 121,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标拥有天使守护",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用流放卡",
            ["source_line"] = 122,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用流放卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "流放无效",
            ["source_line"] = 123,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "流放无效",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "天使守护抵消提示",
            ["source_line"] = 124,
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
          ["p10"] = "5000",
          ["p9"] = "10000",
        },
        {
          ["p10"] = "1500",
          ["p9"] = "3000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p10"] = 132,
          ["p9"] = 132,
        },
        ["source_line"] = 126,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "查税卡对目标收取50%税金",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标持有<余额>金币",
            ["source_line"] = 127,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p9",
          },
          ["text"] = "目标持有<p9>金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用查税卡",
            ["source_line"] = 128,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用查税卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标被收取<税金>金币",
            ["source_line"] = 129,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p10",
          },
          ["text"] = "目标被收取<p10>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 136,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "查税卡目标持有免税卡时自动抵消",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标持有免税卡",
            ["source_line"] = 137,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标持有免税卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用查税卡",
            ["source_line"] = 138,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用查税卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标的免税卡被消耗",
            ["source_line"] = 139,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标的免税卡被消耗",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标不被收税",
            ["source_line"] = 140,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标不被收税",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 149,
        },
        ["source_line"] = 142,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "怪兽卡摧毁对手建筑",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手在范围<距离>格内有等级大于0的地块",
            ["source_line"] = 143,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "对手在范围<p1>格内有等级大于0的地块",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用怪兽卡选择该地块",
            ["source_line"] = 144,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用怪兽卡选择该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地块等级重置为0",
            ["source_line"] = 145,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块等级重置为0",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "怪兽卡被消耗",
            ["source_line"] = 146,
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
        ["source_line"] = 152,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "导弹卡摧毁建筑并送伤者住院",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手位于目标地块上",
            ["source_line"] = 153,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手位于目标地块上",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块等级大于0",
            ["source_line"] = 154,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块等级大于0",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用导弹卡轰炸该地块",
            ["source_line"] = 155,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用导弹卡轰炸该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地块等级重置为0",
            ["source_line"] = 156,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块等级重置为0",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "地块上的对手被送往医院",
            ["source_line"] = 157,
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
        ["source_line"] = 159,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "天使守护免疫建筑摧毁",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手拥有天使守护",
            ["source_line"] = 160,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手拥有天使守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手的地块等级大于0",
            ["source_line"] = 161,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手的地块等级大于0",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对该地块使用怪兽卡",
            ["source_line"] = 162,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对该地块使用怪兽卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "建筑不被摧毁",
            ["source_line"] = 163,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "建筑不被摧毁",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "天使守护抵消提示",
            ["source_line"] = 164,
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
          ["p11"] = "财神",
        },
        {
          ["p11"] = "穷神",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p11"] = 172,
        },
        ["source_line"] = 166,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "请神卡夺取目标的神灵",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标身上附有<神灵类型>",
            ["source_line"] = 167,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p11",
          },
          ["text"] = "目标身上附有<p11>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用请神卡",
            ["source_line"] = 168,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用请神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<神灵类型>转移到玩家身上",
            ["source_line"] = 169,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p11",
          },
          ["text"] = "<p11>转移到玩家身上",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 176,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "送神卡将穷神转给目标",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家身上附有穷神",
            ["source_line"] = 177,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家身上附有穷神",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用送神卡",
            ["source_line"] = 178,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用送神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "穷神转移到目标身上",
            ["source_line"] = 179,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "穷神转移到目标身上",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p11"] = "财神",
          ["p12"] = "财神卡",
          ["p13"] = "10",
        },
        {
          ["p11"] = "天使",
          ["p12"] = "天使卡",
          ["p13"] = "10",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p11"] = 188,
          ["p12"] = 188,
          ["p13"] = 188,
        },
        ["source_line"] = 181,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "财神卡和天使卡自身附体",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家使用<道具名>",
            ["source_line"] = 182,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p12",
          },
          ["text"] = "玩家使用<p12>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "效果生效",
            ["source_line"] = 183,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "效果生效",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家获得<神灵类型>守护",
            ["source_line"] = 184,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p11",
          },
          ["text"] = "玩家获得<p11>守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "持续<持续回合>回合",
            ["source_line"] = 185,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p13",
          },
          ["text"] = "持续<p13>回合",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 192,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "清障卡清除前方障碍物",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家前方12格内有路障和地雷",
            ["source_line"] = 193,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家前方12格内有路障和地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用清障卡",
            ["source_line"] = 194,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用清障卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "前方12格内的路障和地雷被清除",
            ["source_line"] = 195,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "前方12格内的路障和地雷被清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "清障卡被消耗",
            ["source_line"] = 196,
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
        ["source_line"] = 198,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "天使守护免疫导弹伤害",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "对手拥有天使守护",
            ["source_line"] = 199,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手拥有天使守护",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手位于目标地块上",
            ["source_line"] = 200,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手位于目标地块上",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家使用导弹卡轰炸该地块",
            ["source_line"] = 201,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家使用导弹卡轰炸该地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地块建筑不被摧毁",
            ["source_line"] = 202,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "地块建筑不被摧毁",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "对手不被送往医院",
            ["source_line"] = 203,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "对手不被送往医院",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "天使守护抵消提示",
            ["source_line"] = 204,
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
        ["source_line"] = 206,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "针对玩家的道具不可对自己使用",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有需指定目标的道具",
            ["source_line"] = 207,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有需指定目标的道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试对自己使用该道具",
            ["source_line"] = 208,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试对自己使用该道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "自己不出现在目标候选列表中",
            ["source_line"] = 209,
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
        ["source_line"] = 211,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "请神卡目标无神灵时不可使用",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "目标身上没有任何神灵",
            ["source_line"] = 212,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标身上没有任何神灵",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试对目标使用请神卡",
            ["source_line"] = 213,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试对目标使用请神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "目标不出现在候选列表中",
            ["source_line"] = 214,
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
        ["source_line"] = 216,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "送神卡使用者无穷神时不可使用",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家身上没有穷神",
            ["source_line"] = 217,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家身上没有穷神",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试使用送神卡",
            ["source_line"] = 218,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试使用送神卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "送神卡不可用",
            ["source_line"] = 219,
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
          ["p12"] = "遥控骰子",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p12"] = 227,
        },
        ["source_line"] = 221,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "同组道具单回合内只能使用一次",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家持有两张<道具名>",
            ["source_line"] = 222,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p12",
          },
          ["text"] = "玩家持有两张<p12>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家在本回合已使用一张<道具名>",
            ["source_line"] = 223,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p12",
          },
          ["text"] = "玩家在本回合已使用一张<p12>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "第二张<道具名>在本回合不可再选用",
            ["source_line"] = 224,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {
            "p12",
          },
          ["text"] = "第二张<p12>在本回合不可再选用",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 230,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "道具使用分组限制在回合结束时重置",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家本回合已使用过遥控骰子",
            ["source_line"] = 231,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本回合已使用过遥控骰子",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家的回合结束并进入下一回合",
            ["source_line"] = 232,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的回合结束并进入下一回合",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家可以再次使用遥控骰子",
            ["source_line"] = 233,
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
        ["source_line"] = 235,
        ["source_path"] = "features/game/items.feature",
      },
      ["name"] = "偷窃时背包满仍消耗偷窃卡并获得道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家背包已满且持有偷窃卡",
            ["source_line"] = 236,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家背包已满且持有偷窃卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "目标持有道具",
            ["source_line"] = 237,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标持有道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家对目标使用偷窃卡",
            ["source_line"] = 238,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家对目标使用偷窃卡",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "偷窃卡被消耗",
            ["source_line"] = 239,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "偷窃卡被消耗",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "偷窃到的道具替入背包",
            ["source_line"] = 240,
            ["source_path"] = "features/game/items.feature",
          },
          ["parameters"] = {},
          ["text"] = "偷窃到的道具替入背包",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
