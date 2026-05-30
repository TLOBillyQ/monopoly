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
        ["source_path"] = "features/game/market.feature",
      },
      ["parameters"] = {},
      ["text"] = "游戏已初始化标准棋盘",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {},
    ["field_names"] = {},
    ["language"] = "zh-CN",
    ["source_path"] = "features/game/market.feature",
  },
  ["name"] = "黑市",
  ["scenarios"] = {
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 8,
        ["source_path"] = "features/game/market.feature",
      },
      ["name"] = "背包已满时道具类商品从黑市列表移除",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家的背包已满",
            ["source_line"] = 9,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家的背包已满",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开黑市",
            ["source_line"] = 10,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开黑市",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "黑市列表中不展示任何道具商品",
            ["source_line"] = 11,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市列表中不展示任何道具商品",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 13,
        ["source_path"] = "features/game/market.feature",
      },
      ["name"] = "黑市只展示道具商品并去掉皮肤分页和皮肤购买入口",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "黑市配置已加载",
            ["source_line"] = 14,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市配置已加载",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家查看黑市陈列",
            ["source_line"] = 15,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家查看黑市陈列",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "黑市列表只展示道具商品",
            ["source_line"] = 16,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市列表只展示道具商品",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "黑市不展示皮肤分页",
            ["source_line"] = 17,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市不展示皮肤分页",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "黑市不存在皮肤购买入口",
            ["source_line"] = 18,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市不存在皮肤购买入口",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 20,
        ["source_path"] = "features/game/market.feature",
      },
      ["name"] = "商品售罄后仍可见但标记为不可购买",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "某商品的全局库存限额为1",
            ["source_line"] = 21,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "某商品的全局库存限额为1",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该商品已被购买1次",
            ["source_line"] = 22,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "该商品已被购买1次",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家查看黑市",
            ["source_line"] = 23,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家查看黑市",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "该商品仍出现在列表中",
            ["source_line"] = 24,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "该商品仍出现在列表中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该商品标记为已售罄",
            ["source_line"] = 25,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "该商品标记为已售罄",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该商品不可点击购买",
            ["source_line"] = 26,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "该商品不可点击购买",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 28,
        ["source_path"] = "features/game/market.feature",
      },
      ["name"] = "库存充足时商品标记为可购买",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "某商品的全局库存限额为2",
            ["source_line"] = 29,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "某商品的全局库存限额为2",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该商品已被购买1次",
            ["source_line"] = 30,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "该商品已被购买1次",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家查看黑市",
            ["source_line"] = 31,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家查看黑市",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "该商品不标记为已售罄",
            ["source_line"] = 32,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "该商品不标记为已售罄",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该商品可以购买",
            ["source_line"] = 33,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "该商品可以购买",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 35,
        ["source_path"] = "features/game/market.feature",
      },
      ["name"] = "禁用商品从黑市完全隐藏",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "配置中存在市场禁用的商品",
            ["source_line"] = 36,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "配置中存在市场禁用的商品",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家打开黑市",
            ["source_line"] = 37,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家打开黑市",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "禁用商品不出现在列表中",
            ["source_line"] = 38,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "禁用商品不出现在列表中",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "禁用商品无法被购买",
            ["source_line"] = 39,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "禁用商品无法被购买",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 41,
        ["source_path"] = "features/game/market.feature",
      },
      ["name"] = "购买失败后黑市选择窗口保持开放",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家黑市选择窗口已打开",
            ["source_line"] = 42,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家黑市选择窗口已打开",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家购买失败",
            ["source_line"] = 43,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家购买失败",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "黑市选择窗口仍保持开放",
            ["source_line"] = 44,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市选择窗口仍保持开放",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家可以继续选购",
            ["source_line"] = 45,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家可以继续选购",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 47,
        ["source_path"] = "features/game/market.feature",
      },
      ["name"] = "尝试购买已售罄商品失败后刷新售罄状态",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家黑市选择窗口已打开",
            ["source_line"] = 48,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家黑市选择窗口已打开",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "某商品已售罄",
            ["source_line"] = 49,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "某商品已售罄",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家尝试购买该已售罄商品",
            ["source_line"] = 50,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家尝试购买该已售罄商品",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "购买被拒绝",
            ["source_line"] = 51,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "购买被拒绝",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "该商品在选择窗口中保持售罄标记",
            ["source_line"] = 52,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "该商品在选择窗口中保持售罄标记",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "全局库存限额不被消耗",
            ["source_line"] = 53,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "全局库存限额不被消耗",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 55,
        ["source_path"] = "features/game/market.feature",
      },
      ["name"] = "道具购买成功后黑市窗口保持开放可继续选购",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家金币充足",
            ["source_line"] = 56,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家金币充足",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家背包未满",
            ["source_line"] = 57,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家背包未满",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "玩家在黑市成功购买一个道具",
            ["source_line"] = 58,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家在黑市成功购买一个道具",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "黑市选择窗口仍保持开放",
            ["source_line"] = 59,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "黑市选择窗口仍保持开放",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "玩家可以继续选购其他商品",
            ["source_line"] = 60,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家可以继续选购其他商品",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 62,
        ["source_path"] = "features/game/market.feature",
      },
      ["name"] = "电脑玩家路过黑市不自动购买",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "当前行动玩家是电脑",
            ["source_line"] = 63,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前行动玩家是电脑",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "电脑玩家路过黑市",
            ["source_line"] = 64,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家路过黑市",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "电脑玩家不自动购买任何商品",
            ["source_line"] = 65,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家不自动购买任何商品",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "电脑玩家金币保持不变",
            ["source_line"] = 66,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "电脑玩家金币保持不变",
        },
      },
    },
    {
      ["examples"] = {},
      ["metadata"] = {
        ["example_field_lines"] = {},
        ["source_line"] = 68,
        ["source_path"] = "features/game/market.feature",
      },
      ["name"] = "当前选中商品不可购买时自动切到首个可购买商品",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "玩家黑市选择窗口已打开",
            ["source_line"] = 69,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "玩家黑市选择窗口已打开",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "当前选中的商品变为不可购买",
            ["source_line"] = 70,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "当前选中的商品变为不可购买",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "选择列表刷新",
            ["source_line"] = 71,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "选择列表刷新",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "自动选中列表中首个可购买的商品",
            ["source_line"] = 72,
            ["source_path"] = "features/game/market.feature",
          },
          ["parameters"] = {},
          ["text"] = "自动选中列表中首个可购买的商品",
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
