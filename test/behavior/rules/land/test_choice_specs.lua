-- choice_specs.lua 直测:租金/税金二次确认弹窗的文案与结构契约。
-- 文案由宿主直接展示,删字/改字/换卡名都是行为回归,必须钉住;
-- requires_confirm 等形状字段同时被消费方依赖。
local lu = require("luaunit")

local choice_specs = require("src.rules.land.choice_specs")

TestChoiceSpecs = {}

-- strong 强征卡:金额与地名入正文,confirm 标题为卡名(经 decorate 覆盖)。
function TestChoiceSpecs:test_strong_rent_prompt_pins_text_and_shape()
  local choice = choice_specs.rent_prompt(1, 5, "strong", 320, "上海")
  lu.assertEvalToTrue(choice.kind == "rent_card_prompt", "the kind must be pinned")
  lu.assertEvalToTrue(choice.owner_role_id == 1, "the owner role must be the player")
  lu.assertEvalToTrue(choice.route_key == "secondary_confirm", "the route must be pinned")
  lu.assertEvalToTrue(choice.requires_confirm == true, "a secondary confirm must be required")
  lu.assertEvalToTrue(choice.allow_cancel == true, "the prompt must allow cancel")
  lu.assertEvalToTrue(choice.title == "是否使用强征卡", "the title must be pinned")
  lu.assertEvalToTrue(choice.body_lines[1] == "支付 320 强制购入 上海",
    "the body must embed the amount and tile")
  lu.assertEvalToTrue(choice.cancel_label == "不用", "the cancel label must be pinned")
  lu.assertEvalToTrue(choice.options[1].id == "use" and choice.options[1].label == "使用",
    "the use option must be pinned")
  lu.assertEvalToTrue(choice.options[2].id == "skip" and choice.options[2].label == "不用",
    "the skip option must be pinned")
  lu.assertEvalToTrue(choice.confirm_title == "强征卡", "the confirm title must be the card name")
  lu.assertEvalToTrue(choice.confirm_body == "支付 320 强制购入 上海",
    "the confirm body must mirror the prompt body")
  lu.assertEvalToTrue(choice.meta.player_id == 1 and choice.meta.tile_id == 5
    and choice.meta.card_kind == "strong", "the meta must carry the context")
end

-- free 免费卡:免除文案 + 自带的 confirm 文案(不经 decorate)。
function TestChoiceSpecs:test_free_rent_prompt_pins_text_and_shape()
  local choice = choice_specs.rent_prompt(2, 9, "free_rent", 0, "广州")
  lu.assertEvalToTrue(choice.kind == "rent_card_prompt", "the kind must be pinned")
  lu.assertEvalToTrue(choice.route_key == "secondary_confirm" and choice.requires_confirm == true
    and choice.allow_cancel == true, "the secondary confirm shape must be pinned")
  lu.assertEvalToTrue(choice.title == "是否使用免费卡", "the title must be pinned")
  lu.assertEvalToTrue(choice.body_lines[1] == "免除本次租金", "the body must be pinned")
  lu.assertEvalToTrue(choice.cancel_label == "不用", "the cancel label must be pinned")
  lu.assertEvalToTrue(choice.options[2].label == "不用", "the skip option label must be pinned")
  lu.assertEvalToTrue(choice.confirm_title == "免费卡", "the confirm title must be pinned")
  lu.assertEvalToTrue(choice.confirm_body == "这次要用免费卡吗？", "the confirm body must be pinned")
  lu.assertEvalToTrue(choice.meta.card_kind == "free_rent", "the meta must carry the card kind")
end

-- tax 免税卡:confirm 标题是税务局(与 free/strong 不同源,须钉住)。
function TestChoiceSpecs:test_tax_prompt_pins_text_and_shape()
  local choice = choice_specs.tax_prompt(3)
  lu.assertEvalToTrue(choice.kind == "tax_card_prompt", "the kind must be pinned")
  lu.assertEvalToTrue(choice.owner_role_id == 3, "the owner role must be the player")
  lu.assertEvalToTrue(choice.route_key == "secondary_confirm" and choice.requires_confirm == true,
    "the secondary confirm shape must be pinned")
  lu.assertEvalToTrue(choice.title == "是否使用免税卡", "the title must be pinned")
  lu.assertEvalToTrue(choice.body_lines[1] == "使用免税卡可免除本次税金", "the body must be pinned")
  lu.assertEvalToTrue(choice.cancel_label == "不用", "the cancel label must be pinned")
  lu.assertEvalToTrue(choice.options[2].label == "不用", "the skip option label must be pinned")
  lu.assertEvalToTrue(choice.confirm_title == "税务局", "the confirm title must be pinned")
  lu.assertEvalToTrue(choice.confirm_body == "这次要用免税卡吗？", "the confirm body must be pinned")
end

return TestChoiceSpecs
