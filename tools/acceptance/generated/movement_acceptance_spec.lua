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
        ["source_path"] = "features/game/movement.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
    {
      ["keyword"] = "And",
      ["metadata"] = {
        ["original_text"] = "当前玩家位于起点",
        ["source_line"] = 7,
        ["source_path"] = "features/game/movement.feature",
      },
      ["parameters"] = {},
      ["text"] = "当前玩家位于起点",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 10,
      ["p10"] = 61,
      ["p11"] = 65,
      ["p12"] = 86,
      ["p13"] = 99,
      ["p14"] = 100,
      ["p15"] = 109,
      ["p2"] = 11,
      ["p3"] = 12,
      ["p4"] = 13,
      ["p5"] = 22,
      ["p6"] = 24,
      ["p7"] = 25,
      ["p8"] = 39,
      ["p9"] = 44,
    },
    ["field_names"] = {
      ["p1"] = "起始位置",
      ["p10"] = "地雷位置",
      ["p11"] = "住院回合",
      ["p12"] = "黑市位置",
      ["p13"] = "奇偶值",
      ["p14"] = "选择路径",
      ["p15"] = "面朝方向",
      ["p2"] = "步数",
      ["p3"] = "目标位置",
      ["p4"] = "途经格数",
      ["p5"] = "距离",
      ["p6"] = "经过次数",
      ["p7"] = "奖励金额",
      ["p8"] = "路障位置",
      ["p9"] = "剩余步数",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/movement.feature",
  },
  ["name"] = "棋盘移动",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "3",
          ["p3"] = "42",
          ["p4"] = "3",
        },
        {
          ["p1"] = "4",
          ["p2"] = "6",
          ["p3"] = "9",
          ["p4"] = "6",
        },
        {
          ["p1"] = "5",
          ["p2"] = "1",
          ["p3"] = "6",
          ["p4"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 16,
          ["p2"] = 16,
          ["p3"] = 16,
          ["p4"] = 16,
        },
        ["source_line"] = 9,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "玩家按骰子点数前进",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于格子<起始位置>",
            ["source_line"] = 10,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家当前位于格子<p1>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动<步数>步",
            ["source_line"] = 11,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家移动<p2>步",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家到达格子<目标位置>",
            ["source_line"] = 12,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "玩家到达格子<p3>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "移动路径经过<途经格数>个格子",
            ["source_line"] = 13,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "移动路径经过<p4>个格子",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p2"] = "4",
          ["p5"] = "2",
          ["p6"] = "1",
          ["p7"] = "2000",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p2"] = 28,
          ["p5"] = 28,
          ["p6"] = 28,
          ["p7"] = 28,
        },
        ["source_line"] = 21,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "经过起点获得金币奖励",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家位于起点前<距离>格",
            ["source_line"] = 22,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "玩家位于起点前<p5>格",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动<步数>步经过起点",
            ["source_line"] = 23,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家移动<p2>步经过起点",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家经过起点<经过次数>次",
            ["source_line"] = 24,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "玩家经过起点<p6>次",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家获得<奖励金额>金币",
            ["source_line"] = 25,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p7",
          },
          ["text"] = "玩家获得<p7>金币",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 31,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "持有财神经过起点奖励翻倍",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于起点前2格",
            ["source_line"] = 32,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前位于起点前2格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有财神守护",
            ["source_line"] = 33,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有财神守护",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动3步经过起点",
            ["source_line"] = 34,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家移动3步经过起点",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家获得的经过起点奖励是基础值的2倍",
            ["source_line"] = 35,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家获得的经过起点奖励是基础值的2倍",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p2"] = "6",
          ["p8"] = "3",
          ["p9"] = "4",
        },
        {
          ["p1"] = "5",
          ["p2"] = "4",
          ["p8"] = "6",
          ["p9"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 47,
          ["p2"] = 47,
          ["p8"] = 47,
          ["p9"] = 47,
        },
        ["source_line"] = 37,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "路障中断移动",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于格子<起始位置>",
            ["source_line"] = 38,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家当前位于格子<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子<路障位置>放置了路障",
            ["source_line"] = 39,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p8",
          },
          ["text"] = "格子<p8>放置了路障",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动<步数>步",
            ["source_line"] = 40,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家移动<p2>步",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家停在格子<路障位置>",
            ["source_line"] = 41,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p8",
          },
          ["text"] = "玩家停在格子<p8>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "路障被清除",
            ["source_line"] = 42,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "路障被清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "剩余步数不继续",
            ["source_line"] = 43,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "剩余步数不继续",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "剩余<剩余步数>步未消耗",
            ["source_line"] = 44,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p9",
          },
          ["text"] = "剩余<p9>步未消耗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 51,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "天使守护免疫路障",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于格子1",
            ["source_line"] = 52,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前位于格子1",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子3放置了路障",
            ["source_line"] = 53,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "格子3放置了路障",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家拥有天使守护且可抵御路障",
            ["source_line"] = 54,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家拥有天使守护且可抵御路障",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动6步",
            ["source_line"] = 55,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家移动6步",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家不停在格子3",
            ["source_line"] = 56,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家不停在格子3",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "路障未被清除",
            ["source_line"] = 57,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "路障未被清除",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "2",
          ["p10"] = "3",
          ["p11"] = "2",
          ["p2"] = "1",
          ["p9"] = "0",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 69,
          ["p10"] = 69,
          ["p11"] = 69,
          ["p2"] = 69,
          ["p9"] = 69,
        },
        ["source_line"] = 59,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "地雷触发后玩家住院",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于格子<起始位置>",
            ["source_line"] = 60,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家当前位于格子<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子<地雷位置>放置了对手的已激活地雷",
            ["source_line"] = 61,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p10",
          },
          ["text"] = "格子<p10>放置了对手的已激活地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动<步数>步到达地雷位置",
            ["source_line"] = 62,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家移动<p2>步到达地雷位置",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地雷被触发并清除",
            ["source_line"] = 63,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "地雷被触发并清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家被送往医院",
            ["source_line"] = 64,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家被送往医院",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家需停留<住院回合>回合",
            ["source_line"] = 65,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p11",
          },
          ["text"] = "玩家需停留<p11>回合",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "剩余<剩余步数>步未消耗",
            ["source_line"] = 66,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p9",
          },
          ["text"] = "剩余<p9>步未消耗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 72,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "地雷布置者首回合免疫自己的地雷",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家在本回合布置了地雷于格子5",
            ["source_line"] = 73,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家在本回合布置了地雷于格子5",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "下一回合玩家移动经过格子5",
            ["source_line"] = 74,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "下一回合玩家移动经过格子5",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地雷不触发",
            ["source_line"] = 75,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "地雷不触发",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 77,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "同格路障和地雷按顺序触发",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "格子3同时放置了路障和对手的已激活地雷",
            ["source_line"] = 78,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "格子3同时放置了路障和对手的已激活地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动到格子3",
            ["source_line"] = 79,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家移动到格子3",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "路障先触发并清除",
            ["source_line"] = 80,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "路障先触发并清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "然后地雷触发",
            ["source_line"] = 81,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "然后地雷触发",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家被送往医院",
            ["source_line"] = 82,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家被送往医院",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "1",
          ["p12"] = "42",
          ["p2"] = "6",
          ["p9"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 93,
          ["p12"] = 93,
          ["p2"] = 93,
          ["p9"] = 93,
        },
        ["source_line"] = 84,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "经过黑市中断移动供玩家选择",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于格子<起始位置>",
            ["source_line"] = 85,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家当前位于格子<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子<黑市位置>是黑市格",
            ["source_line"] = 86,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p12",
          },
          ["text"] = "格子<p12>是黑市格",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动<步数>步经过黑市",
            ["source_line"] = 87,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家移动<p2>步经过黑市",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "移动暂停在黑市格",
            ["source_line"] = 88,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "移动暂停在黑市格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家可选择进入黑市或继续移动",
            ["source_line"] = 89,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家可选择进入黑市或继续移动",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "剩余<剩余步数>步待消耗",
            ["source_line"] = 90,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p9",
          },
          ["text"] = "剩余<p9>步待消耗",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p13"] = "偶数",
          ["p14"] = "内圈",
        },
        {
          ["p13"] = "奇数",
          ["p14"] = "外圈",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p13"] = 103,
          ["p14"] = 103,
        },
        ["source_line"] = 96,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "分支路口按奇偶选择路径",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于分支入口格",
            ["source_line"] = 97,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前位于分支入口格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "分支入口连接外圈和内圈",
            ["source_line"] = 98,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "分支入口连接外圈和内圈",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动且分支奇偶为<奇偶值>",
            ["source_line"] = 99,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p13",
          },
          ["text"] = "玩家移动且分支奇偶为<p13>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家进入<选择路径>",
            ["source_line"] = 100,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p14",
          },
          ["text"] = "玩家进入<p14>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p1"] = "6",
          ["p15"] = "左",
          ["p2"] = "2",
          ["p3"] = "4",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 115,
          ["p15"] = 115,
          ["p2"] = 115,
          ["p3"] = 115,
        },
        ["source_line"] = 107,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "后退移动",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于格子<起始位置>",
            ["source_line"] = 108,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "玩家当前位于格子<p1>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家面朝<面朝方向>",
            ["source_line"] = 109,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p15",
          },
          ["text"] = "玩家面朝<p15>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家后退<步数>步",
            ["source_line"] = 110,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "玩家后退<p2>步",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家到达格子<目标位置>",
            ["source_line"] = 111,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "玩家到达格子<p3>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "后退不改变玩家面朝方向",
            ["source_line"] = 112,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "后退不改变玩家面朝方向",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
