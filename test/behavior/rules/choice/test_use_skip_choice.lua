local lu = require("luaunit")
local use_skip_choice = require("src.rules.choice.use_skip_choice")

-- use_skip_choice.build 是「使用 / 放弃」二次确认选择的唯一形状源(工单 #126 变异补测)。
-- 此前零直测:变异显示 17 个位点存活 15 个(11.8%)—— route_key、requires_confirm、
-- 两个 option id、allow_cancel、以及每一个默认文案 fallback 全都改得动而无一测试响。
-- 也就是说「这个选择长什么样」完全没被钉住。下面把形状和每一条 fallback 都钉死。

-- 调用方(land/choice_specs)总是传 meta.player_id,并按需覆盖部分 label。
-- overrides.meta 缺省时用默认 meta;显式传 no_meta=true 时才不传 meta(测无 meta 分支)。
local _DEFAULT_META = { player_id = 3 }
local function _build(overrides)
  overrides = overrides or {}
  local meta = _DEFAULT_META
  if overrides.no_meta then
    meta = nil
  elseif overrides.meta then
    meta = overrides.meta
  end
  return use_skip_choice.build(
    overrides.kind or "rent_card_prompt",
    overrides.title or "是否使用强征卡",
    overrides.body_lines or { "支付 100 强制购入 A" },
    meta,
    overrides.labels or {}
  )
end

TestUseSkipChoice = {}

function TestUseSkipChoice:test_routes_to_secondary_confirm_and_requires_confirmation()
  local c = _build()
  lu.assertIs(c.route_key, "secondary_confirm")
  lu.assertTrue(c.requires_confirm)
  lu.assertTrue(c.allow_cancel)
end

function TestUseSkipChoice:test_carries_the_kind_title_and_body_lines_through_verbatim()
  local c = _build({ kind = "tax_card_prompt", title = "是否使用免税卡", body_lines = { "L1", "L2" } })
  lu.assertIs(c.kind, "tax_card_prompt")
  lu.assertIs(c.title, "是否使用免税卡")
  lu.assertEquals(c.body_lines, { "L1", "L2" })
end

function TestUseSkipChoice:test_offers_exactly_a_use_option_then_a_skip_option_in_that_order()
  local c = _build()
  lu.assertIs(#c.options, 2)
  lu.assertIs(c.options[1].id, "use")
  lu.assertIs(c.options[2].id, "skip")
end

function TestUseSkipChoice:test_takes_owner_role_id_from_meta_player_id()
  local c = _build({ meta = { player_id = 7 } })
  lu.assertIs(c.owner_role_id, 7)
  lu.assertEquals(c.meta, { player_id = 7 })
end

-- 杀 `meta and meta.player_id`:无 meta 时 owner_role_id 必须是 nil,不能炸、也不能瞎填。
function TestUseSkipChoice:test_leaves_owner_role_id_nil_when_meta_is_absent()
  local c = _build({ no_meta = true })
  lu.assertNil(c.owner_role_id)
  lu.assertNil(c.meta)
end

-- 每条都两面钉:给了用给的(杀 or->and),没给用默认(杀默认文案->nil)。
TestUseSkipChoice["test_defaults the use label to 使用 but honors an override"] = function(self)
  lu.assertIs(_build().options[1].label, "使用")
  lu.assertIs(_build({ labels = { use = "用卡" } }).options[1].label, "用卡")
end

TestUseSkipChoice["test_defaults the skip label to 放弃, driving both the option and cancel_label"] = function(self)
  local c = _build()
  lu.assertIs(c.options[2].label, "放弃")
  lu.assertIs(c.cancel_label, "放弃")
  local overridden = _build({ labels = { skip = "不用" } })
  lu.assertIs(overridden.options[2].label, "不用")
  lu.assertIs(overridden.cancel_label, "不用")
end

function TestUseSkipChoice:test_defaults_confirm_title_to_the_title_but_honors_an_override()
  lu.assertIs(_build().confirm_title, "是否使用强征卡")
  lu.assertIs(_build({ labels = { confirm_title = "强征卡" } }).confirm_title, "强征卡")
end

-- 杀 _build_confirm_body 整体被换成 nil,以及 join_or_default 的两条分支。
function TestUseSkipChoice:test_joins_the_body_lines_with_newlines_when_no_override_is_given()
  lu.assertIs(_build({ body_lines = { "A", "B" } }).confirm_body, "A\nB")
end

TestUseSkipChoice["test_falls back to 请再确认一次 when there are no body lines"] = function(self)
  lu.assertIs(_build({ body_lines = {} }).confirm_body, "请再确认一次")
end

function TestUseSkipChoice:test_honors_an_explicit_confirm_body_override()
  lu.assertIs(_build({ labels = { confirm_body = "这次要用免费卡吗？" } }).confirm_body, "这次要用免费卡吗？")
end


return TestUseSkipChoice
