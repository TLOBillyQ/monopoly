-- settlement_card_choice 直测:租金/税收卡选择的三路裁决(用卡 / 自动免租 / 现金兜底)。
-- 集成 spec 只覆盖少数路径(变异清扫 #259 survivor 真缺口闭合);执行器桩打在
-- landing_rules 上(land_actions 在 load 期把规则函数捕获进转发闭包,打它拦不住),
-- inventory 持卡判定同桩,shared 助手(settlement_shared)走真实现。
-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):describe 拍平为文件级 Test* 类,
-- 裸 assert 转 lu.assertEvalToTrue,用例数与改写前一一对应(9 例)。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local with_patches = support.with_patches
local inventory = require("src.rules.items.inventory")
local landing_rules = require("src.rules.land.landing_rules")
local card_choice = require("src.rules.land.settlement_card_choice")

local function _make_game()
  return {
    find_player_by_id = function(_, pid)
      return { id = pid }
    end,
  }
end

local function _executor_recorder()
  local calls = {}
  local patches = {}
  for _, name in ipairs({
    "execute_strong_card", "execute_free_card", "execute_pay_rent",
    "execute_tax_free_card", "execute_pay_tax",
  }) do
    patches[#patches + 1] = { target = landing_rules, key = name, value = function()
      calls[#calls + 1] = name
    end }
  end
  return calls, patches
end

local function _has_free_rent(has_card)
  return { target = inventory, key = "find_index", value = function()
    return has_card and 1 or nil
  end }
end

local function _rent_choice(card_kind)
  return { meta = { player_id = 1, tile_id = 7, card_kind = card_kind } }
end

TestSettlementCardChoice = {}

function TestSettlementCardChoice:test_resolve_rent_rejects_when_the_choice_carries_no_meta_table()
  local result = card_choice.resolve_rent(_make_game(), {}, { option_id = "use" })

  lu.assertEvalToTrue(result.ok == false and result.status == "rejected"
    and result.reason == "missing_landing_choice_meta",
    "missing meta rejects with missing_landing_choice_meta")
end

function TestSettlementCardChoice:test_resolve_rent_use_strong_executes_the_strong_card_and_resolves_as_pay_rent()
  local calls, patches = _executor_recorder()
  local result
  with_patches(patches, function()
    result = card_choice.resolve_rent(_make_game(), _rent_choice("strong"), { option_id = "use" })
  end)

  lu.assertEvalToTrue(#calls == 1 and calls[1] == "execute_strong_card", "strong card executes once")
  lu.assertEvalToTrue(result.ok == true and result.status == "resolved" and result.effect_id == "pay_rent",
    "card path resolves with pay_rent effect")
end

function TestSettlementCardChoice:test_resolve_rent_use_free_executes_the_free_card_and_resolves_as_pay_rent()
  local calls, patches = _executor_recorder()
  local result
  with_patches(patches, function()
    result = card_choice.resolve_rent(_make_game(), _rent_choice("free"), { option_id = "use" })
  end)

  lu.assertEvalToTrue(#calls == 1 and calls[1] == "execute_free_card", "free card executes once")
  lu.assertEvalToTrue(result.ok == true and result.status == "resolved" and result.effect_id == "pay_rent",
    "card path resolves with pay_rent effect")
end

function TestSettlementCardChoice:test_resolve_rent_use_with_an_unknown_card_kind_ignores_the_card_and_pays_rent()
  local calls, patches = _executor_recorder()
  local result
  with_patches(patches, function()
    result = card_choice.resolve_rent(_make_game(), _rent_choice("unknown"), { option_id = "use" })
  end)

  lu.assertEvalToTrue(#calls == 1 and calls[1] == "execute_pay_rent", "unknown card falls back to cash rent")
  lu.assertEvalToTrue(result.ok == true and result.status == "resolved" and result.effect_id == "pay_rent",
    "fallback resolves with pay_rent effect")
end

function TestSettlementCardChoice:test_resolve_rent_skip_with_a_free_rent_card_in_hand_auto_plays_it()
  local calls, patches = _executor_recorder()
  patches[#patches + 1] = _has_free_rent(true)
  local result
  with_patches(patches, function()
    result = card_choice.resolve_rent(_make_game(), _rent_choice("strong"), { option_id = "skip" })
  end)

  lu.assertEvalToTrue(#calls == 1 and calls[1] == "execute_free_card", "auto free rent plays the free card")
  lu.assertEvalToTrue(result.ok == true and result.status == "resolved" and result.effect_id == "free_rent",
    "auto path resolves with free_rent effect")
end

function TestSettlementCardChoice:test_resolve_rent_skip_without_a_free_rent_card_pays_cash_rent()
  local calls, patches = _executor_recorder()
  patches[#patches + 1] = _has_free_rent(false)
  local result
  with_patches(patches, function()
    result = card_choice.resolve_rent(_make_game(), _rent_choice("strong"), { option_id = "skip" })
  end)

  lu.assertEvalToTrue(#calls == 1 and calls[1] == "execute_pay_rent", "no free card falls back to cash rent")
  lu.assertEvalToTrue(result.ok == true and result.status == "resolved" and result.effect_id == "pay_rent",
    "fallback resolves with pay_rent effect")
end

function TestSettlementCardChoice:test_resolve_rent_auto_free_rent_rejects_when_the_actor_is_unresolvable()
  local result = card_choice.resolve_rent({}, _rent_choice("strong"), { option_id = "skip" })

  lu.assertEvalToTrue(result.ok == false and result.status == "rejected" and result.reason == "missing_actor",
    "missing actor rejects instead of paying rent")
end

function TestSettlementCardChoice:test_resolve_tax_use_executes_the_tax_free_card_and_resolves_as_tax_free()
  local calls, patches = _executor_recorder()
  local result
  with_patches(patches, function()
    result = card_choice.resolve_tax(_make_game(), { meta = { player_id = 1 } }, { option_id = "use" })
  end)

  lu.assertEvalToTrue(#calls == 1 and calls[1] == "execute_tax_free_card", "tax-free card executes once")
  lu.assertEvalToTrue(result.ok == true and result.status == "resolved" and result.effect_id == "tax_free",
    "card path resolves with tax_free effect")
end

function TestSettlementCardChoice:test_resolve_tax_skip_pays_cash_tax()
  local calls, patches = _executor_recorder()
  local result
  with_patches(patches, function()
    result = card_choice.resolve_tax(_make_game(), { meta = { player_id = 1 } }, { option_id = "skip" })
  end)

  lu.assertEvalToTrue(#calls == 1 and calls[1] == "execute_pay_tax", "skip falls back to cash tax")
  lu.assertEvalToTrue(result.ok == true and result.status == "resolved" and result.effect_id == "pay_tax",
    "fallback resolves with pay_tax effect")
end


return TestSettlementCardChoice
