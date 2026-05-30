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
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["下一玩家"] = 13,
      ["减后回合"] = 31,
      ["剩余回合"] = 28,
      ["当前玩家"] = 11,
      ["玩家人数"] = 9,
      ["触发条件"] = 179,
      ["警告秒数"] = 90,
      ["警告级别"] = 126,
      ["警告阈值"] = 125,
      ["超时秒数"] = 87,
      ["选择类型"] = 85,
      ["道具"] = 178,
      ["阶段序列"] = 55,
      ["验证玩家人数"] = 10,
      ["验证超时秒数"] = 88,
      ["验证选择类型"] = 86,
    },
    ["field_names"] = {
      ["下一玩家"] = "下一玩家",
      ["减后回合"] = "减后回合",
      ["剩余回合"] = "剩余回合",
      ["当前玩家"] = "当前玩家",
      ["玩家人数"] = "玩家人数",
      ["触发条件"] = "触发条件",
      ["警告秒数"] = "警告秒数",
      ["警告级别"] = "警告级别",
      ["警告阈值"] = "警告阈值",
      ["超时秒数"] = "超时秒数",
      ["选择类型"] = "选择类型",
      ["道具"] = "道具",
      ["阶段序列"] = "阶段序列",
      ["验证玩家人数"] = "验证玩家人数",
      ["验证超时秒数"] = "验证超时秒数",
      ["验证选择类型"] = "验证选择类型",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/turn_flow.feature",
  },
  ["name"] = "回合流程",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["下一玩家"] = "2",
          ["当前玩家"] = "1",
          ["玩家人数"] = "4",
          ["验证玩家人数"] = "4",
        },
        {
          ["下一玩家"] = "1",
          ["当前玩家"] = "4",
          ["玩家人数"] = "4",
          ["验证玩家人数"] = "4",
        },
        {
          ["下一玩家"] = "2",
          ["当前玩家"] = "1",
          ["玩家人数"] = "2",
          ["验证玩家人数"] = "2",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["下一玩家"] = 16,
          ["当前玩家"] = 16,
          ["玩家人数"] = 16,
          ["验证玩家人数"] = 16,
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
            "玩家人数",
          },
          ["text"] = "游戏有<玩家人数>名玩家参与",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "游戏当前玩家数为<验证玩家人数>名",
            ["source_line"] = 10,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "验证玩家人数",
          },
          ["text"] = "游戏当前玩家数为<验证玩家人数>名",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前是玩家<当前玩家>的回合",
            ["source_line"] = 11,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "当前玩家",
          },
          ["text"] = "当前是玩家<当前玩家>的回合",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "回合结束",
            ["source_line"] = 12,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "回合结束",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "下一回合轮到玩家<下一玩家>",
            ["source_line"] = 13,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "下一玩家",
          },
          ["text"] = "下一回合轮到玩家<下一玩家>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 21,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "已淘汰玩家的回合被跳过",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家2已被淘汰",
            ["source_line"] = 22,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家2已被淘汰",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前是玩家1的回合",
            ["source_line"] = 23,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前是玩家1的回合",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家1的回合结束",
            ["source_line"] = 24,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家1的回合结束",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "跳过玩家2直接轮到玩家3",
            ["source_line"] = 25,
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
          ["减后回合"] = "2",
          ["剩余回合"] = "3",
        },
        {
          ["减后回合"] = "0",
          ["剩余回合"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["减后回合"] = 35,
          ["剩余回合"] = 35,
        },
        ["source_line"] = 27,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "被扣留玩家无法行动且剩余回合递减",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家需停留<剩余回合>回合",
            ["source_line"] = 28,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "剩余回合",
          },
          ["text"] = "玩家需停留<剩余回合>回合",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "该玩家的回合开始",
            ["source_line"] = 29,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "该玩家的回合开始",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家无法掷骰和移动",
            ["source_line"] = 30,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家无法掷骰和移动",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "剩余停留回合变为<减后回合>",
            ["source_line"] = 31,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "减后回合",
          },
          ["text"] = "剩余停留回合变为<减后回合>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "回合直接结束",
            ["source_line"] = 32,
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
        ["source_line"] = 39,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "扣留结束后恢复正常行动",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家剩余停留回合为1",
            ["source_line"] = 40,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家剩余停留回合为1",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "该玩家的扣留回合结束",
            ["source_line"] = 41,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "该玩家的扣留回合结束",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "下一次轮到该玩家",
            ["source_line"] = 42,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "下一次轮到该玩家",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家可以正常掷骰",
            ["source_line"] = 43,
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
        ["source_line"] = 45,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "回合结束时清除临时状态",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家本回合使用了遥控骰子",
            ["source_line"] = 46,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本回合使用了遥控骰子",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家本回合触发了骰子加倍卡",
            ["source_line"] = 47,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本回合触发了骰子加倍卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家的回合结束",
            ["source_line"] = 48,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的回合结束",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "遥控骰子效果被清除",
            ["source_line"] = 49,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "遥控骰子效果被清除",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "骰子加倍倍率重置为1",
            ["source_line"] = 50,
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
          ["阶段序列"] = "开始 → 等待行动 → 掷骰 → 移动 → 落地 → 结束",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["阶段序列"] = 58,
        },
        ["source_line"] = 52,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "标准回合阶段按序执行",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家未被扣留且未被淘汰",
            ["source_line"] = 53,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家未被扣留且未被淘汰",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家的回合开始",
            ["source_line"] = 54,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的回合开始",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "依次经过阶段<阶段序列>",
            ["source_line"] = 55,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "阶段序列",
          },
          ["text"] = "依次经过阶段<阶段序列>",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 61,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "黑市售罄时落地自动跳过选择",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在黑市格",
            ["source_line"] = 62,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在黑市格",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "黑市所有商品已售罄",
            ["source_line"] = 63,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市所有商品已售罄",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 64,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "不弹出购买选择",
            ["source_line"] = 65,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "不弹出购买选择",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "回合直接进入结束阶段",
            ["source_line"] = 66,
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
        ["source_line"] = 68,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "落在对手地块且持有免租卡时自动消耗",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在对手拥有的地块",
            ["source_line"] = 69,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在对手拥有的地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家持有免租卡",
            ["source_line"] = 70,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家持有免租卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 71,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "免租卡被自动消耗",
            ["source_line"] = 72,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "免租卡被自动消耗",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "不需要玩家手动选择",
            ["source_line"] = 73,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "不需要玩家手动选择",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家不支付租金",
            ["source_line"] = 74,
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
        ["source_line"] = 76,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "落在对手地块持有强夺卡和免租卡时优先提示强夺",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家落在对手拥有的地块",
            ["source_line"] = 77,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家落在对手拥有的地块",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家同时持有强夺卡和免租卡",
            ["source_line"] = 78,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家同时持有强夺卡和免租卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "落地结算执行",
            ["source_line"] = 79,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "落地结算执行",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "先弹出强夺卡使用提示",
            ["source_line"] = 80,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "先弹出强夺卡使用提示",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "若玩家拒绝强夺则自动消耗免租卡",
            ["source_line"] = 81,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "若玩家拒绝强夺则自动消耗免租卡",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家不支付租金",
            ["source_line"] = 82,
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
          ["警告秒数"] = "5",
          ["超时秒数"] = "10",
          ["选择类型"] = "普通选择",
          ["验证超时秒数"] = "10",
          ["验证选择类型"] = "普通选择",
        },
        {
          ["警告秒数"] = "5",
          ["超时秒数"] = "10",
          ["选择类型"] = "黑市购买",
          ["验证超时秒数"] = "10",
          ["验证选择类型"] = "黑市购买",
        },
        {
          ["警告秒数"] = "5",
          ["超时秒数"] = "10",
          ["选择类型"] = "道具目标选择",
          ["验证超时秒数"] = "10",
          ["验证选择类型"] = "道具目标选择",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["警告秒数"] = 94,
          ["超时秒数"] = 94,
          ["选择类型"] = 94,
          ["验证超时秒数"] = 94,
          ["验证选择类型"] = 94,
        },
        ["source_line"] = 84,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "选择超时后系统自动决定",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家面临<选择类型>选择",
            ["source_line"] = 85,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "选择类型",
          },
          ["text"] = "玩家面临<选择类型>选择",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选择类型为<验证选择类型>",
            ["source_line"] = 86,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "验证选择类型",
          },
          ["text"] = "当前选择类型为<验证选择类型>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "超时时间为<超时秒数>秒",
            ["source_line"] = 87,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "超时秒数",
          },
          ["text"] = "超时时间为<超时秒数>秒",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "选择超时配置为<验证超时秒数>秒",
            ["source_line"] = 88,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "验证超时秒数",
          },
          ["text"] = "选择超时配置为<验证超时秒数>秒",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家在超时时间内未操作",
            ["source_line"] = 89,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家在超时时间内未操作",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "系统在剩余<警告秒数>秒时发出警告",
            ["source_line"] = 90,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "警告秒数",
          },
          ["text"] = "系统在剩余<警告秒数>秒时发出警告",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "超时后自动执行默认选项",
            ["source_line"] = 91,
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
        ["source_line"] = 99,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "回合间有短暂等待间隔",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "回合间等待时间已配置",
            ["source_line"] = 100,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "回合间等待时间已配置",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "当前玩家的回合结束",
            ["source_line"] = 101,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前玩家的回合结束",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "经过等待间隔后下一玩家回合才开始",
            ["source_line"] = 102,
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
        ["source_line"] = 104,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "路障停留不影响下一回合行动",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家本回合因路障停止移动",
            ["source_line"] = 105,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家本回合因路障停止移动",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "下一回合轮到该玩家",
            ["source_line"] = 106,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "下一回合轮到该玩家",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家可以正常掷骰和移动",
            ["source_line"] = 107,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家可以正常掷骰和移动",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "不会被额外扣留",
            ["source_line"] = 108,
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
        ["source_line"] = 110,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "选择超时温和跳过不扣玩家金币",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家面临黑市购买选择",
            ["source_line"] = 111,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家面临黑市购买选择",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家当前金币为5000",
            ["source_line"] = 112,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家当前金币为5000",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "超时未操作系统自动跳过",
            ["source_line"] = 113,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "超时未操作系统自动跳过",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家金币仍为5000",
            ["source_line"] = 114,
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
        ["source_line"] = 116,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "道具目标选择超时后退还预消耗道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家已选择使用需指定目标的道具",
            ["source_line"] = 117,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家已选择使用需指定目标的道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "道具已被预先从背包扣除",
            ["source_line"] = 118,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具已被预先从背包扣除",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "目标选择超时系统自动取消",
            ["source_line"] = 119,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "目标选择超时系统自动取消",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具被退还至玩家背包",
            ["source_line"] = 120,
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
          ["警告级别"] = "警告",
          ["警告阈值"] = "5",
          ["超时秒数"] = "10",
          ["验证超时秒数"] = "10",
        },
        {
          ["警告级别"] = "紧急",
          ["警告阈值"] = "3",
          ["超时秒数"] = "10",
          ["验证超时秒数"] = "10",
        },
        {
          ["警告级别"] = "到期",
          ["警告阈值"] = "0",
          ["超时秒数"] = "10",
          ["验证超时秒数"] = "10",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["警告级别"] = 130,
          ["警告阈值"] = 130,
          ["超时秒数"] = 130,
          ["验证超时秒数"] = 130,
        },
        ["source_line"] = 122,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "超时倒计时分阶段发出警告",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家面临选择且超时时间为<超时秒数>秒",
            ["source_line"] = 123,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "超时秒数",
          },
          ["text"] = "玩家面临选择且超时时间为<超时秒数>秒",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "选择超时配置为<验证超时秒数>秒",
            ["source_line"] = 124,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "验证超时秒数",
          },
          ["text"] = "选择超时配置为<验证超时秒数>秒",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "剩余时间降至<警告阈值>秒",
            ["source_line"] = 125,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "警告阈值",
          },
          ["text"] = "剩余时间降至<警告阈值>秒",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "倒计时状态变为<警告级别>",
            ["source_line"] = 126,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "警告级别",
          },
          ["text"] = "倒计时状态变为<警告级别>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "每个警告级别仅触发一次",
            ["source_line"] = 127,
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
        ["source_line"] = 135,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "超时自动结算后关闭选择弹窗",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家面临选择且弹窗已打开",
            ["source_line"] = 136,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家面临选择且弹窗已打开",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "选择超时系统自动决定",
            ["source_line"] = 137,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "选择超时系统自动决定",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "选择弹窗被关闭",
            ["source_line"] = 138,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "选择弹窗被关闭",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "待处理选择指示被清除",
            ["source_line"] = 139,
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
        ["source_line"] = 141,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "黑市浏览期间行动计时器不暂停",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家路过黑市且黑市窗口打开",
            ["source_line"] = 142,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家路过黑市且黑市窗口打开",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "行动计时器运行中",
            ["source_line"] = 143,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "行动计时器运行中",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "计时器继续倒计时不暂停",
            ["source_line"] = 144,
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
        ["source_line"] = 146,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "阻断性提示显示完毕前回合不切换",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "当前玩家的回合已结束",
            ["source_line"] = 147,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前玩家的回合已结束",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "正在显示阻断性游戏提示",
            ["source_line"] = 148,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "正在显示阻断性游戏提示",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "回合间等待时间到期",
            ["source_line"] = 149,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "回合间等待时间到期",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "等待提示显示完毕后才切换到下一玩家回合",
            ["source_line"] = 150,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "等待提示显示完毕后才切换到下一玩家回合",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 152,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "电脑玩家自动购买可负担的无主地块",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "当前行动玩家是电脑",
            ["source_line"] = 153,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前行动玩家是电脑",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "电脑玩家持有充足金币",
            ["source_line"] = 154,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家持有充足金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "电脑玩家落在无主地块",
            ["source_line"] = 155,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家落在无主地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "系统自动执行购买",
            ["source_line"] = 156,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "系统自动执行购买",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 158,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "电脑玩家自动升级可负担的自有地块",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "当前行动玩家是电脑",
            ["source_line"] = 159,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前行动玩家是电脑",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "电脑玩家持有充足金币",
            ["source_line"] = 160,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家持有充足金币",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "电脑玩家落在自有可升级地块",
            ["source_line"] = 161,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家落在自有可升级地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "系统自动执行升级",
            ["source_line"] = 162,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "系统自动执行升级",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 164,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "电脑玩家落在对手地块时自动使用免租卡",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "当前行动玩家是电脑",
            ["source_line"] = 165,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前行动玩家是电脑",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "电脑玩家持有免租卡",
            ["source_line"] = 166,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家持有免租卡",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "电脑玩家落在需付租金的对手地块",
            ["source_line"] = 167,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家落在需付租金的对手地块",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "系统自动消耗免租卡",
            ["source_line"] = 168,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "系统自动消耗免租卡",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 170,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "电脑玩家按优先级主动使用背包中的主动道具",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "当前行动玩家是电脑",
            ["source_line"] = 171,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前行动玩家是电脑",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "电脑玩家背包中有主动使用道具",
            ["source_line"] = 172,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家背包中有主动使用道具",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "电脑玩家的道具使用阶段",
            ["source_line"] = 173,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家的道具使用阶段",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "系统按AI道具优先级尝试使用道具",
            ["source_line"] = 174,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "系统按AI道具优先级尝试使用道具",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["触发条件"] = "移动范围内存在道具格",
          ["道具"] = "遥控骰子卡",
        },
        {
          ["触发条件"] = "前方存在道具格",
          ["道具"] = "路障卡",
        },
        {
          ["触发条件"] = "存在持有道具的其他玩家",
          ["道具"] = "偷窃卡",
        },
        {
          ["触发条件"] = "前后3格内存在他人等级最高的建筑",
          ["道具"] = "怪兽卡",
        },
        {
          ["触发条件"] = "电脑玩家不是现金最多的角色",
          ["道具"] = "均富卡",
        },
        {
          ["触发条件"] = "存在其他现金最多的角色",
          ["道具"] = "流放卡",
        },
        {
          ["触发条件"] = "前后3格内存在他人等级最高的建筑",
          ["道具"] = "导弹卡",
        },
        {
          ["触发条件"] = "存在其他现金最多的角色",
          ["道具"] = "查税卡",
        },
        {
          ["触发条件"] = "其他角色附有天使",
          ["道具"] = "请神卡",
        },
        {
          ["触发条件"] = "其他角色附有财神且无人附有天使",
          ["道具"] = "请神卡",
        },
        {
          ["触发条件"] = "电脑玩家附有穷神且存在现金最多对手",
          ["道具"] = "送神卡",
        },
        {
          ["触发条件"] = "存在其他现金最多的角色",
          ["道具"] = "穷神卡",
        },
        {
          ["触发条件"] = "道具当前可用",
          ["道具"] = "其他卡",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["触发条件"] = 184,
          ["道具"] = 184,
        },
        ["source_line"] = 176,
        ["source_path"] = "features/game/turn_flow.feature",
      },
      ["name"] = "电脑玩家主动道具优先级",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "当前行动玩家是电脑",
            ["source_line"] = 177,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前行动玩家是电脑",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "电脑玩家背包中有<道具>",
            ["source_line"] = 178,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "道具",
          },
          ["text"] = "电脑玩家背包中有<道具>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "棋盘状态满足<触发条件>",
            ["source_line"] = 179,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "触发条件",
          },
          ["text"] = "棋盘状态满足<触发条件>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "电脑玩家的道具使用阶段",
            ["source_line"] = 180,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家的道具使用阶段",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "电脑玩家使用<道具>",
            ["source_line"] = 181,
            ["source_path"] = "features/game/turn_flow.feature",
          },
          ["parameters"] = {
            "道具",
          },
          ["text"] = "电脑玩家使用<道具>",
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
