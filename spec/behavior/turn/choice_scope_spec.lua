-- src/turn/deadlines/choice_scope.lua 的直测。
-- for_choice 是 pending choice → deadline scope 桶的唯一分类点:
-- market_buy 落 "market_buy",其余一律 "choice"。逐 kind 钉死真值表,
-- 顶掉「market_buy->nil」「and->or」「返回串对调」等变异。
local choice_scope = require("src.turn.deadlines.choice_scope")

describe("turn.deadlines.choice_scope.for_choice", function()
  it("maps a market_buy choice to the market_buy scope", function()
    assert(choice_scope.for_choice({ kind = "market_buy" }) == "market_buy",
      "market_buy kind resolves the market_buy scope")
  end)

  it("maps any other kind to the choice scope", function()
    assert(choice_scope.for_choice({ kind = "normal" }) == "choice",
      "a non-market kind resolves the default choice scope")
  end)

  it("maps a choice without kind to the choice scope", function()
    assert(choice_scope.for_choice({}) == "choice",
      "a choice missing kind resolves the default choice scope")
  end)

  it("maps a nil choice to the choice scope without erroring", function()
    assert(choice_scope.for_choice(nil) == "choice",
      "a nil choice falls through to the default choice scope")
  end)
end)
