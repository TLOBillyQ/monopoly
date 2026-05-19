local runtime = require("acceptance.runtime")
local steps = require("acceptance.steps")

local ir = {
  ["background"] = {
    {
      ["keyword"] = "Given",
      ["metadata"] = {
        ["original_text"] = "游戏已初始化标准棋盘",
        ["source_line"] = 6,
        ["source_path"] = "features/game/paid_currency.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {},
    ["field_names"] = {},
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/paid_currency.feature",
  },
  ["name"] = "付费货币购买",
  ["scenarios"] = {
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 8,
        ["source_path"] = "features/game/paid_currency.feature",
      },
      ["name"] = "付费道具购买通过宿主支付面板发起",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "黑市中存在付费货币商品",
            ["source_line"] = 9,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市中存在付费货币商品",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家选择购买该付费道具",
            ["source_line"] = 10,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家选择购买该付费道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "宿主支付面板被打开一次",
            ["source_line"] = 11,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "宿主支付面板被打开一次",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "黑市选择窗口保持开放等待支付回调",
            ["source_line"] = 12,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市选择窗口保持开放等待支付回调",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 14,
        ["source_path"] = "features/game/paid_currency.feature",
      },
      ["name"] = "支付回调到达后道具入库并消耗全局限额",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家已发起付费道具购买",
            ["source_line"] = 15,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家已发起付费道具购买",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "宿主支付回调成功到达",
            ["source_line"] = 16,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "宿主支付回调成功到达",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "道具被加入玩家背包",
            ["source_line"] = 17,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "道具被加入玩家背包",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该商品全局库存减少1",
            ["source_line"] = 18,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "该商品全局库存减少1",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 20,
        ["source_path"] = "features/game/paid_currency.feature",
      },
      ["name"] = "缺少商品映射时付费购买被拒绝",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "付费道具在宿主商品列表中没有对应映射",
            ["source_line"] = 21,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "付费道具在宿主商品列表中没有对应映射",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试购买该付费道具",
            ["source_line"] = 22,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试购买该付费道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "购买被拒绝",
            ["source_line"] = 23,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "购买被拒绝",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "支付面板不被打开",
            ["source_line"] = 24,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "支付面板不被打开",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "系统记录缺少映射的警告",
            ["source_line"] = 25,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "系统记录缺少映射的警告",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 27,
        ["source_path"] = "features/game/paid_currency.feature",
      },
      ["name"] = "同一商品缺少映射的警告仅记录一次",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "付费道具在宿主商品列表中没有对应映射",
            ["source_line"] = 28,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "付费道具在宿主商品列表中没有对应映射",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家连续两次尝试购买该付费道具",
            ["source_line"] = 29,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家连续两次尝试购买该付费道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "缺少映射的警告仅被记录一次",
            ["source_line"] = 30,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "缺少映射的警告仅被记录一次",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 32,
        ["source_path"] = "features/game/paid_currency.feature",
      },
      ["name"] = "付费购买进行中时重复请求被阻断",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家已发起付费道具购买且回调尚未到达",
            ["source_line"] = 33,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家已发起付费道具购买且回调尚未到达",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家再次尝试购买同一付费道具",
            ["source_line"] = 34,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家再次尝试购买同一付费道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "第二次请求被拒绝",
            ["source_line"] = 35,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "第二次请求被拒绝",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "支付面板不被再次打开",
            ["source_line"] = 36,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "支付面板不被再次打开",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 38,
        ["source_path"] = "features/game/paid_currency.feature",
      },
      ["name"] = "购买超时后恢复购买能力",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家已发起付费道具购买且回调尚未到达",
            ["source_line"] = 39,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家已发起付费道具购买且回调尚未到达",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "购买请求已超时",
            ["source_line"] = 40,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "购买请求已超时",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家再次尝试购买该付费道具",
            ["source_line"] = 41,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家再次尝试购买该付费道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "购买请求被正常发起",
            ["source_line"] = 42,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "购买请求被正常发起",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "支付面板被打开",
            ["source_line"] = 43,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "支付面板被打开",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 45,
        ["source_path"] = "features/game/paid_currency.feature",
      },
      ["name"] = "同一商品在回调后可连续多次购买",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "黑市中存在付费货币商品且库存充足",
            ["source_line"] = 46,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市中存在付费货币商品且库存充足",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家完成第一次付费购买并收到回调",
            ["source_line"] = 47,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家完成第一次付费购买并收到回调",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家发起第二次相同商品的付费购买并收到回调",
            ["source_line"] = 48,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家发起第二次相同商品的付费购买并收到回调",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "玩家背包中收到两件该道具",
            ["source_line"] = 49,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家背包中收到两件该道具",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该商品全局库存减少2",
            ["source_line"] = 50,
            ["source_path"] = "features/game/paid_currency.feature",
          },
          ["parameters"] = {},
          ["text"] = "该商品全局库存减少2",
        },
      },
    },
  },
}

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
