require("test.bootstrap").install_package_paths()
local luassert = assert
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

describe("TestUseSkipChoice", function()
it("test_routes_to_secondary_confirm_and_requires_confirmation", function()
  local c = _build()
  luassert.is.equal(c.route_key, "secondary_confirm")
  luassert.is_true(c.requires_confirm)
  luassert.is_true(c.allow_cancel)
end)

it("test_carries_the_kind_title_and_body_lines_through_verbatim", function()
  local c = _build({ kind = "tax_card_prompt", title = "是否使用免税卡", body_lines = { "L1", "L2" } })
  luassert.is.equal(c.kind, "tax_card_prompt")
  luassert.is.equal(c.title, "是否使用免税卡")
  luassert.is.same({ "L1", "L2" }, c.body_lines)
end)

it("test_offers_exactly_a_use_option_then_a_skip_option_in_that_order", function()
  local c = _build()
  luassert.is.equal(#c.options, 2)
  luassert.is.equal(c.options[1].id, "use")
  luassert.is.equal(c.options[2].id, "skip")
end)

it("test_takes_owner_role_id_from_meta_player_id", function()
  local c = _build({ meta = { player_id = 7 } })
  luassert.is.equal(c.owner_role_id, 7)
  luassert.is.same({ player_id = 7 }, c.meta)
end)

-- 杀 `meta and meta.player_id`:无 meta 时 owner_role_id 必须是 nil,不能炸、也不能瞎填。
it("test_leaves_owner_role_id_nil_when_meta_is_absent", function()
  local c = _build({ no_meta = true })
  luassert.is_nil(c.owner_role_id)
  luassert.is_nil(c.meta)
end)

-- 每条都两面钉:给了用给的(杀 or->and),没给用默认(杀默认文案->nil)。
it("test_defaults the use label to 使用 but honors an override", function()
  luassert.is.equal(_build().options[1].label, "使用")
  luassert.is.equal(_build({ labels = { use = "用卡" } }).options[1].label, "用卡")
end)

it("test_defaults the skip label to 放弃, driving both the option and cancel_label", function()
  local c = _build()
  luassert.is.equal(c.options[2].label, "放弃")
  luassert.is.equal(c.cancel_label, "放弃")
  local overridden = _build({ labels = { skip = "不用" } })
  luassert.is.equal(overridden.options[2].label, "不用")
  luassert.is.equal(overridden.cancel_label, "不用")
end)

it("test_defaults_confirm_title_to_the_title_but_honors_an_override", function()
  luassert.is.equal(_build().confirm_title, "是否使用强征卡")
  luassert.is.equal(_build({ labels = { confirm_title = "强征卡" } }).confirm_title, "强征卡")
end)

-- 杀 _build_confirm_body 整体被换成 nil,以及 join_or_default 的两条分支。
it("test_joins_the_body_lines_with_newlines_when_no_override_is_given", function()
  luassert.is.equal(_build({ body_lines = { "A", "B" } }).confirm_body, "A\nB")
end)

it("test_falls back to 请再确认一次 when there are no body lines", function()
  luassert.is.equal(_build({ body_lines = {} }).confirm_body, "请再确认一次")
end)

it("test_honors_an_explicit_confirm_body_override", function()
  luassert.is.equal(_build({ labels = { confirm_body = "这次要用免费卡吗？" } }).confirm_body, "这次要用免费卡吗？")
end)


end)
