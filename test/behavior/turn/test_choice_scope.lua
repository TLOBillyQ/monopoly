-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
-- src/turn/deadlines/choice_scope.lua 的直测。
-- for_choice 是 pending choice → deadline scope 桶的唯一分类点:
-- market_buy 落 "market_buy",其余一律 "choice"。逐 kind 钉死真值表,
-- 顶掉「market_buy->nil」「and->or」「返回串对调」等变异。
local choice_scope = require("src.turn.deadlines.choice_scope")

describe("TestChoiceScope", function()
  it("test_maps_market_buy_choice_to_market_buy_scope", function()
    luassert.truthy(choice_scope.for_choice({ kind = "market_buy" }) == "market_buy",
      "market_buy kind resolves the market_buy scope")
  end)

  it("test_maps_any_other_kind_to_choice_scope", function()
    luassert.truthy(choice_scope.for_choice({ kind = "normal" }) == "choice",
      "a non-market kind resolves the default choice scope")
  end)

  it("test_maps_choice_without_kind_to_choice_scope", function()
    luassert.truthy(choice_scope.for_choice({}) == "choice",
      "a choice missing kind resolves the default choice scope")
  end)

  it("test_maps_nil_choice_to_choice_scope_without_erroring", function()
    luassert.truthy(choice_scope.for_choice(nil) == "choice",
      "a nil choice falls through to the default choice scope")
  end)
end)
