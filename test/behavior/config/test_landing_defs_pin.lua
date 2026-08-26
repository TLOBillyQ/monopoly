-- landing_defs.lua 数据契约 pin:landing 效果清单(文案/必选标志)逐条深等
-- (#293 变异清扫)。提示文案是用户可见产品面,改表必须改契约。
local lu = require("luaunit")

local landing_defs = require("src.rules.land.landing_defs")

TestLandingDefsPin = {}

function TestLandingDefsPin:test_landing_effects_match_the_pinned_contract()
  lu.assertEvalToTrue(#landing_defs == 11, "landing effect count must match")
  local expected = {
    { id = "mine", label = "地雷", mandatory = true },
    { id = "start_reward", label = "起点奖励", mandatory = true },
    { id = "item_draw_and_give", label = "道具", mandatory = true },
    { id = "chance_draw_and_resolve", label = "机会卡", mandatory = true },
    { id = "hospital", label = "医院", mandatory = true },
    { id = "mountain", label = "深山", mandatory = true },
    { id = "market", label = "黑市", mandatory = true },
    { id = "buy_land", label = "购买地块", mandatory = false },
    { id = "upgrade_land", label = "加盖建筑", mandatory = false },
    { id = "pay_rent", mandatory = true },
    { id = "tax", mandatory = true },
  }
  for i, want in ipairs(expected) do
    lu.assertEvalToTrue(landing_defs[i] ~= nil, "landing effect " .. i .. " must exist")
    lu.assertEvalToTrue(landing_defs[i].id == want.id, "landing effect " .. i .. " id")
    lu.assertEvalToTrue(landing_defs[i].label == want.label, "landing effect " .. i .. " label")
    lu.assertEvalToTrue(landing_defs[i].mandatory == want.mandatory, "landing effect " .. i .. " mandatory")
  end
end

return TestLandingDefsPin
