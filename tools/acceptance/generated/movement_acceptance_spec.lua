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
      ["住院回合"] = 65,
      ["剩余步数"] = 44,
      ["地雷位置"] = 61,
      ["奇偶值"] = 106,
      ["奖励金额"] = 25,
      ["步数"] = 11,
      ["目标位置"] = 12,
      ["经过次数"] = 24,
      ["起始位置"] = 10,
      ["距离"] = 22,
      ["路障位置"] = 39,
      ["选择路径"] = 107,
      ["途经格数"] = 13,
      ["面朝方向"] = 116,
      ["黑市位置"] = 93,
    },
    ["field_names"] = {
      ["住院回合"] = "住院回合",
      ["剩余步数"] = "剩余步数",
      ["地雷位置"] = "地雷位置",
      ["奇偶值"] = "奇偶值",
      ["奖励金额"] = "奖励金额",
      ["步数"] = "步数",
      ["目标位置"] = "目标位置",
      ["经过次数"] = "经过次数",
      ["起始位置"] = "起始位置",
      ["距离"] = "距离",
      ["路障位置"] = "路障位置",
      ["选择路径"] = "选择路径",
      ["途经格数"] = "途经格数",
      ["面朝方向"] = "面朝方向",
      ["黑市位置"] = "黑市位置",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/movement.feature",
  },
  ["name"] = "棋盘移动",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["步数"] = "3",
          ["目标位置"] = "42",
          ["起始位置"] = "1",
          ["途经格数"] = "3",
        },
        {
          ["步数"] = "6",
          ["目标位置"] = "9",
          ["起始位置"] = "4",
          ["途经格数"] = "6",
        },
        {
          ["步数"] = "1",
          ["目标位置"] = "6",
          ["起始位置"] = "5",
          ["途经格数"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["步数"] = 16,
          ["目标位置"] = 16,
          ["起始位置"] = 16,
          ["途经格数"] = 16,
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
            "起始位置",
          },
          ["text"] = "玩家当前位于格子<起始位置>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动<步数>步",
            ["source_line"] = 11,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "步数",
          },
          ["text"] = "玩家移动<步数>步",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家到达格子<目标位置>",
            ["source_line"] = 12,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "目标位置",
          },
          ["text"] = "玩家到达格子<目标位置>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "移动路径经过<途经格数>个格子",
            ["source_line"] = 13,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "途经格数",
          },
          ["text"] = "移动路径经过<途经格数>个格子",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["奖励金额"] = "2000",
          ["步数"] = "4",
          ["经过次数"] = "1",
          ["距离"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["奖励金额"] = 28,
          ["步数"] = 28,
          ["经过次数"] = 28,
          ["距离"] = 28,
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
            "距离",
          },
          ["text"] = "玩家位于起点前<距离>格",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动<步数>步经过起点",
            ["source_line"] = 23,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "步数",
          },
          ["text"] = "玩家移动<步数>步经过起点",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家经过起点<经过次数>次",
            ["source_line"] = 24,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "经过次数",
          },
          ["text"] = "玩家经过起点<经过次数>次",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家获得<奖励金额>金币",
            ["source_line"] = 25,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "奖励金额",
          },
          ["text"] = "玩家获得<奖励金额>金币",
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
          ["剩余步数"] = "4",
          ["步数"] = "6",
          ["起始位置"] = "1",
          ["路障位置"] = "3",
        },
        {
          ["剩余步数"] = "3",
          ["步数"] = "4",
          ["起始位置"] = "5",
          ["路障位置"] = "6",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["剩余步数"] = 47,
          ["步数"] = 47,
          ["起始位置"] = 47,
          ["路障位置"] = 47,
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
            "起始位置",
          },
          ["text"] = "玩家当前位于格子<起始位置>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子<路障位置>放置了路障",
            ["source_line"] = 39,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "路障位置",
          },
          ["text"] = "格子<路障位置>放置了路障",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动<步数>步",
            ["source_line"] = 40,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "步数",
          },
          ["text"] = "玩家移动<步数>步",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家停在格子<路障位置>",
            ["source_line"] = 41,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "路障位置",
          },
          ["text"] = "玩家停在格子<路障位置>",
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
            ["original_text"] = "继续访问路障所在格事件",
            ["source_line"] = 43,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "继续访问路障所在格事件",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "剩余<剩余步数>步未消耗",
            ["source_line"] = 44,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "剩余步数",
          },
          ["text"] = "剩余<剩余步数>步未消耗",
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
      ["name"] = "天使守护不免疫路障",
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
            ["original_text"] = "玩家仅拥有天使守护",
            ["source_line"] = 54,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家仅拥有天使守护",
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
            ["original_text"] = "玩家仍停在格子3",
            ["source_line"] = 56,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家仍停在格子3",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "路障被清除",
            ["source_line"] = 57,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "路障被清除",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["住院回合"] = "2",
          ["剩余步数"] = "0",
          ["地雷位置"] = "3",
          ["步数"] = "1",
          ["起始位置"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["住院回合"] = 69,
          ["剩余步数"] = 69,
          ["地雷位置"] = 69,
          ["步数"] = 69,
          ["起始位置"] = 69,
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
            "起始位置",
          },
          ["text"] = "玩家当前位于格子<起始位置>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子<地雷位置>放置了对手的已激活地雷",
            ["source_line"] = 61,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "地雷位置",
          },
          ["text"] = "格子<地雷位置>放置了对手的已激活地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动<步数>步到达地雷位置",
            ["source_line"] = 62,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "步数",
          },
          ["text"] = "玩家移动<步数>步到达地雷位置",
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
            "住院回合",
          },
          ["text"] = "玩家需停留<住院回合>回合",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "剩余<剩余步数>步未消耗",
            ["source_line"] = 66,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "剩余步数",
          },
          ["text"] = "剩余<剩余步数>步未消耗",
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
      ["name"] = "地雷布置者在布置回合和下一己方回合免疫自己的地雷",
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
            ["original_text"] = "下一己方回合玩家移动经过格子5",
            ["source_line"] = 74,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "下一己方回合玩家移动经过格子5",
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
      ["name"] = "地雷布置者第三己方回合不再免疫",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家在之前的回合布置了地雷于格子5",
            ["source_line"] = 78,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家在之前的回合布置了地雷于格子5",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "已过去2个己方回合",
            ["source_line"] = 79,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "已过去2个己方回合",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动经过格子5",
            ["source_line"] = 80,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家移动经过格子5",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地雷正常触发",
            ["source_line"] = 81,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "地雷正常触发",
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
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 84,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "同格路障和地雷按顺序触发",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "格子3同时放置了路障和对手的已激活地雷",
            ["source_line"] = 85,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "格子3同时放置了路障和对手的已激活地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动到格子3",
            ["source_line"] = 86,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家移动到格子3",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "路障先触发并清除",
            ["source_line"] = 87,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "路障先触发并清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "然后地雷触发",
            ["source_line"] = 88,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "然后地雷触发",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家被送往医院",
            ["source_line"] = 89,
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
          ["剩余步数"] = "3",
          ["步数"] = "6",
          ["起始位置"] = "1",
          ["黑市位置"] = "42",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["剩余步数"] = 100,
          ["步数"] = 100,
          ["起始位置"] = 100,
          ["黑市位置"] = 100,
        },
        ["source_line"] = 91,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "经过黑市自动打开并中断移动",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于格子<起始位置>",
            ["source_line"] = 92,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "起始位置",
          },
          ["text"] = "玩家当前位于格子<起始位置>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子<黑市位置>是黑市格",
            ["source_line"] = 93,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "黑市位置",
          },
          ["text"] = "格子<黑市位置>是黑市格",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动<步数>步经过黑市",
            ["source_line"] = 94,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "步数",
          },
          ["text"] = "玩家移动<步数>步经过黑市",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "移动暂停在黑市格",
            ["source_line"] = 95,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "移动暂停在黑市格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "黑市窗口自动打开",
            ["source_line"] = 96,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市窗口自动打开",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "剩余<剩余步数>步待消耗",
            ["source_line"] = 97,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "剩余步数",
          },
          ["text"] = "剩余<剩余步数>步待消耗",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["奇偶值"] = "偶数",
          ["选择路径"] = "内圈",
        },
        {
          ["奇偶值"] = "奇数",
          ["选择路径"] = "外圈",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["奇偶值"] = 110,
          ["选择路径"] = 110,
        },
        ["source_line"] = 103,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "分支路口按奇偶选择路径",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于分支入口格",
            ["source_line"] = 104,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前位于分支入口格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "分支入口连接外圈和内圈",
            ["source_line"] = 105,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "分支入口连接外圈和内圈",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动且分支奇偶为<奇偶值>",
            ["source_line"] = 106,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "奇偶值",
          },
          ["text"] = "玩家移动且分支奇偶为<奇偶值>",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家进入<选择路径>",
            ["source_line"] = 107,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "选择路径",
          },
          ["text"] = "玩家进入<选择路径>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["步数"] = "2",
          ["目标位置"] = "4",
          ["起始位置"] = "6",
          ["面朝方向"] = "左",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["步数"] = 122,
          ["目标位置"] = 122,
          ["起始位置"] = 122,
          ["面朝方向"] = 122,
        },
        ["source_line"] = 114,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "后退移动",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于格子<起始位置>",
            ["source_line"] = 115,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "起始位置",
          },
          ["text"] = "玩家当前位于格子<起始位置>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家面朝<面朝方向>",
            ["source_line"] = 116,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "面朝方向",
          },
          ["text"] = "玩家面朝<面朝方向>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家后退<步数>步",
            ["source_line"] = 117,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "步数",
          },
          ["text"] = "玩家后退<步数>步",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家到达格子<目标位置>",
            ["source_line"] = 118,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {
            "目标位置",
          },
          ["text"] = "玩家到达格子<目标位置>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "后退不改变玩家面朝方向",
            ["source_line"] = 119,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "后退不改变玩家面朝方向",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 125,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "落在起点格也获得经过起点奖励",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于起点前3格",
            ["source_line"] = 126,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前位于起点前3格",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动恰好3步到达起点",
            ["source_line"] = 127,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家移动恰好3步到达起点",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家获得经过起点的金币奖励",
            ["source_line"] = 128,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家获得经过起点的金币奖励",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 130,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "黑市格有地雷时先触发地雷后跳过黑市",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于格子1",
            ["source_line"] = 131,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前位于格子1",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子42是黑市格",
            ["source_line"] = 132,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "格子42是黑市格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子42同时放置了对手的已激活地雷",
            ["source_line"] = 133,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "格子42同时放置了对手的已激活地雷",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动到格子42",
            ["source_line"] = 134,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家移动到格子42",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地雷被触发并清除",
            ["source_line"] = 135,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "地雷被触发并清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家被送往医院",
            ["source_line"] = 136,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家被送往医院",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "不打开黑市窗口",
            ["source_line"] = 137,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "不打开黑市窗口",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 139,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "天使守护免疫黑市格地雷后正常进入黑市",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家当前位于格子1",
            ["source_line"] = 140,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前位于格子1",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子42是黑市格",
            ["source_line"] = 141,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "格子42是黑市格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "格子42同时放置了对手的已激活地雷",
            ["source_line"] = 142,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "格子42同时放置了对手的已激活地雷",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家拥有天使守护且可抵御路障",
            ["source_line"] = 143,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家拥有天使守护且可抵御路障",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家移动到格子42",
            ["source_line"] = 144,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家移动到格子42",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "地雷不触发",
            ["source_line"] = 145,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "地雷不触发",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "黑市窗口自动打开",
            ["source_line"] = 146,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市窗口自动打开",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 148,
        ["source_path"] = "features/game/movement.feature",
      },
      ["name"] = "从黑市恢复移动时保持原方向和剩余步数",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家经过黑市格时移动被中断",
            ["source_line"] = 149,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家经过黑市格时移动被中断",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "剩余3步未消耗",
            ["source_line"] = 150,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "剩余3步未消耗",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家关闭黑市继续移动",
            ["source_line"] = 151,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家关闭黑市继续移动",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家沿原方向继续前进3步",
            ["source_line"] = 152,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家沿原方向继续前进3步",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "分支奇偶状态保持不变",
            ["source_line"] = 153,
            ["source_path"] = "features/game/movement.feature",
          },
          ["parameters"] = {},
          ["text"] = "分支奇偶状态保持不变",
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
