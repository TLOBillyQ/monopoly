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
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["p1"] = 9,
      ["p10"] = 121,
      ["p11"] = 122,
      ["p2"] = 10,
      ["p3"] = 12,
      ["p4"] = 27,
      ["p5"] = 30,
      ["p6"] = 54,
      ["p7"] = 84,
      ["p8"] = 85,
      ["p9"] = 87,
    },
    ["field_names"] = {
      ["p1"] = "玩家人数",
      ["p10"] = "警告阈值",
      ["p11"] = "警告级别",
      ["p2"] = "当前玩家",
      ["p3"] = "下一玩家",
      ["p4"] = "剩余回合",
      ["p5"] = "减后回合",
      ["p6"] = "阶段序列",
      ["p7"] = "选择类型",
      ["p8"] = "超时秒数",
      ["p9"] = "警告秒数",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/turn_flow.feature",
  },
  ["name"] = "回合流程",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["p1"] = "4",
          ["p2"] = "1",
          ["p3"] = "2",
        },
        {
          ["p1"] = "4",
          ["p2"] = "4",
          ["p3"] = "1",
        },
        {
          ["p1"] = "2",
          ["p2"] = "1",
          ["p3"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p1"] = 15,
          ["p2"] = 15,
          ["p3"] = 15,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "玩家按顺序轮流行动",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "游戏有<玩家人数>名玩家参与",
            ["source_line"] = 9,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p1",
          },
          ["text"] = "游戏有<p1>名玩家参与",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前是玩家<当前玩家>的回合",
            ["source_line"] = 10,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p2",
          },
          ["text"] = "当前是玩家<p2>的回合",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "回合结束",
            ["source_line"] = 11,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "回合结束",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "下一回合轮到玩家<下一玩家>",
            ["source_line"] = 12,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p3",
          },
          ["text"] = "下一回合轮到玩家<p3>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 20,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "已淘汰玩家的回合被跳过",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家2已被淘汰",
            ["source_line"] = 21,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2已被淘汰",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前是玩家1的回合",
            ["source_line"] = 22,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前是玩家1的回合",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家1的回合结束",
            ["source_line"] = 23,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家1的回合结束",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "跳过玩家2直接轮到玩家3",
            ["source_line"] = 24,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "跳过玩家2直接轮到玩家3",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p4"] = "3",
          ["p5"] = "2",
        },
        {
          ["p4"] = "1",
          ["p5"] = "0",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p4"] = 34,
          ["p5"] = 34,
        },
        ["source_line"] = 26,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "被扣留玩家无法行动且剩余回合递减",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家需停留<剩余回合>回合",
            ["source_line"] = 27,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p4",
          },
          ["text"] = "玩家需停留<p4>回合",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "该玩家的回合开始",
            ["source_line"] = 28,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "该玩家的回合开始",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家无法掷骰和移动",
            ["source_line"] = 29,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家无法掷骰和移动",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "剩余停留回合变为<减后回合>",
            ["source_line"] = 30,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p5",
          },
          ["text"] = "剩余停留回合变为<p5>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "回合直接结束",
            ["source_line"] = 31,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "回合直接结束",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 38,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "扣留结束后恢复正常行动",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家剩余停留回合为1",
            ["source_line"] = 39,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家剩余停留回合为1",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "该玩家的扣留回合结束",
            ["source_line"] = 40,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "该玩家的扣留回合结束",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "下一次轮到该玩家",
            ["source_line"] = 41,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "下一次轮到该玩家",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家可以正常掷骰",
            ["source_line"] = 42,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家可以正常掷骰",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 44,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "回合结束时清除临时状态",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家本回合使用了遥控骰子",
            ["source_line"] = 45,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本回合使用了遥控骰子",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家本回合触发了骰子加倍卡",
            ["source_line"] = 46,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本回合触发了骰子加倍卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家的回合结束",
            ["source_line"] = 47,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的回合结束",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "遥控骰子效果被清除",
            ["source_line"] = 48,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "遥控骰子效果被清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "骰子加倍倍率重置为1",
            ["source_line"] = 49,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "骰子加倍倍率重置为1",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p6"] = "开始 → 等待行动 → 掷骰 → 移动 → 落地 → 结束",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p6"] = 57,
        },
        ["source_line"] = 51,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "标准回合阶段按序执行",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家未被扣留且未被淘汰",
            ["source_line"] = 52,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家未被扣留且未被淘汰",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家的回合开始",
            ["source_line"] = 53,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的回合开始",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "依次经过阶段<阶段序列>",
            ["source_line"] = 54,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p6",
          },
          ["text"] = "依次经过阶段<p6>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 60,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "黑市售罄时落地自动跳过选择",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在黑市格",
            ["source_line"] = 61,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在黑市格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "黑市所有商品已售罄",
            ["source_line"] = 62,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市所有商品已售罄",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 63,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "不弹出购买选择",
            ["source_line"] = 64,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "不弹出购买选择",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "回合直接进入结束阶段",
            ["source_line"] = 65,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "回合直接进入结束阶段",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 67,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "落在对手地块且持有免租卡时自动消耗",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在对手拥有的地块",
            ["source_line"] = 68,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在对手拥有的地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有免租卡",
            ["source_line"] = 69,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有免租卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 70,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "免租卡被自动消耗",
            ["source_line"] = 71,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "免租卡被自动消耗",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "不需要玩家手动选择",
            ["source_line"] = 72,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "不需要玩家手动选择",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家不支付租金",
            ["source_line"] = 73,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家不支付租金",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 75,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "落在对手地块持有强夺卡和免租卡时优先提示强夺",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在对手拥有的地块",
            ["source_line"] = 76,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在对手拥有的地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家同时持有强夺卡和免租卡",
            ["source_line"] = 77,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家同时持有强夺卡和免租卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 78,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "先弹出强夺卡使用提示",
            ["source_line"] = 79,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "先弹出强夺卡使用提示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "若玩家拒绝强夺则自动消耗免租卡",
            ["source_line"] = 80,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "若玩家拒绝强夺则自动消耗免租卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家不支付租金",
            ["source_line"] = 81,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家不支付租金",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p7"] = "普通选择",
          ["p8"] = "15",
          ["p9"] = "5",
        },
        {
          ["p7"] = "黑市购买",
          ["p8"] = "60",
          ["p9"] = "5",
        },
        {
          ["p7"] = "道具目标选择",
          ["p8"] = "15",
          ["p9"] = "5",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p7"] = 91,
          ["p8"] = 91,
          ["p9"] = 91,
        },
        ["source_line"] = 83,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "选择超时后系统自动决定",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家面临<选择类型>选择",
            ["source_line"] = 84,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p7",
          },
          ["text"] = "玩家面临<p7>选择",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "超时时间为<超时秒数>秒",
            ["source_line"] = 85,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p8",
          },
          ["text"] = "超时时间为<p8>秒",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家在超时时间内未操作",
            ["source_line"] = 86,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家在超时时间内未操作",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "系统在剩余<警告秒数>秒时发出警告",
            ["source_line"] = 87,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p9",
          },
          ["text"] = "系统在剩余<p9>秒时发出警告",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "超时后自动执行默认选项",
            ["source_line"] = 88,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "超时后自动执行默认选项",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 96,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "回合间有短暂等待间隔",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "回合间等待时间已配置",
            ["source_line"] = 97,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "回合间等待时间已配置",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "当前玩家的回合结束",
            ["source_line"] = 98,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前玩家的回合结束",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "经过等待间隔后下一玩家回合才开始",
            ["source_line"] = 99,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "经过等待间隔后下一玩家回合才开始",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 101,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "路障停留不影响下一回合行动",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家本回合因路障停止移动",
            ["source_line"] = 102,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本回合因路障停止移动",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "下一回合轮到该玩家",
            ["source_line"] = 103,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "下一回合轮到该玩家",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家可以正常掷骰和移动",
            ["source_line"] = 104,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家可以正常掷骰和移动",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "不会被额外扣留",
            ["source_line"] = 105,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "不会被额外扣留",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 107,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "选择超时温和跳过不扣玩家金币",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家面临黑市购买选择",
            ["source_line"] = 108,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家面临黑市购买选择",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家当前金币为5000",
            ["source_line"] = 109,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前金币为5000",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "超时未操作系统自动跳过",
            ["source_line"] = 110,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "超时未操作系统自动跳过",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家金币仍为5000",
            ["source_line"] = 111,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家金币仍为5000",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 113,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "道具目标选择超时后退还预消耗道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家已选择使用需指定目标的道具",
            ["source_line"] = 114,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家已选择使用需指定目标的道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具已被预先从背包扣除",
            ["source_line"] = 115,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具已被预先从背包扣除",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "目标选择超时系统自动取消",
            ["source_line"] = 116,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标选择超时系统自动取消",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具被退还至玩家背包",
            ["source_line"] = 117,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具被退还至玩家背包",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["p10"] = "5",
          ["p11"] = "警告",
          ["p8"] = "15",
        },
        {
          ["p10"] = "3",
          ["p11"] = "紧急",
          ["p8"] = "15",
        },
        {
          ["p10"] = "0",
          ["p11"] = "到期",
          ["p8"] = "15",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["p10"] = 126,
          ["p11"] = 126,
          ["p8"] = 126,
        },
        ["source_line"] = 119,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "超时倒计时分阶段发出警告",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家面临选择且超时时间为<超时秒数>秒",
            ["source_line"] = 120,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p8",
          },
          ["text"] = "玩家面临选择且超时时间为<p8>秒",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "剩余时间降至<警告阈值>秒",
            ["source_line"] = 121,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p10",
          },
          ["text"] = "剩余时间降至<p10>秒",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "倒计时状态变为<警告级别>",
            ["source_line"] = 122,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "p11",
          },
          ["text"] = "倒计时状态变为<p11>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "每个警告级别仅触发一次",
            ["source_line"] = 123,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "每个警告级别仅触发一次",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 131,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "超时自动结算后关闭选择弹窗",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家面临选择且弹窗已打开",
            ["source_line"] = 132,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家面临选择且弹窗已打开",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "选择超时系统自动决定",
            ["source_line"] = 133,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "选择超时系统自动决定",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "选择弹窗被关闭",
            ["source_line"] = 134,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "选择弹窗被关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "待处理选择指示被清除",
            ["source_line"] = 135,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "待处理选择指示被清除",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 137,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "黑市浏览期间行动计时器不暂停",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家路过黑市且黑市窗口打开",
            ["source_line"] = 138,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家路过黑市且黑市窗口打开",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "行动计时器运行中",
            ["source_line"] = 139,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "行动计时器运行中",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "计时器继续倒计时不暂停",
            ["source_line"] = 140,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "计时器继续倒计时不暂停",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 142,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "阻断性提示显示完毕前回合不切换",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "当前玩家的回合已结束",
            ["source_line"] = 143,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前玩家的回合已结束",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "正在显示阻断性游戏提示",
            ["source_line"] = 144,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "正在显示阻断性游戏提示",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "回合间等待时间到期",
            ["source_line"] = 145,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "回合间等待时间到期",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "等待提示显示完毕后才切换到下一玩家回合",
            ["source_line"] = 146,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "等待提示显示完毕后才切换到下一玩家回合",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
