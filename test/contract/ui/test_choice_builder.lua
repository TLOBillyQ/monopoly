local lu = require("luaunit")
local choice_builder = require("src.ui.view.choice_builder")

TestChoiceBuilder = {}

function TestChoiceBuilder:test_builds_phase_title_and_option_fields()
  local view = choice_builder.build_choice_view({
    id = 7,
    kind = "item_phase_passive",
    title = "请选择",
    body_lines = { "第一行", "第二行" },
    options = {
      {
        id = 2001,
        label = "路障卡",
        can_buy = true,
        requires_pre_confirm = true,
        pre_confirm_kind = "secondary_confirm",
        confirm_title = "确认使用",
        confirm_body = "确认文案",
      },
    },
    allow_cancel = false,
    cancel_label = "返回",
    route_key = "base_inline",
  }, {
    game = {
      turn = {
        item_phase_active = "pre_action",
      },
    },
  })

  lu.assertIs(view.title, "请选择", "choice view should return base title without phase label")
  lu.assertIs(view.body, "第一行\n第二行", "choice view should join body_lines")
  lu.assertIs(view.allow_cancel, false, "choice view should preserve explicit allow_cancel")
  lu.assertIs(view.cancel_label, "返回", "choice view should preserve cancel label")
  lu.assertIs(view.route_key, "base_inline", "choice view should copy explicit fields")
  lu.assertIs(view.options[1].requires_pre_confirm, true, "choice view should copy pre-confirm marker")
  lu.assertIs(view.options[1].confirm_title, "确认使用", "choice view should copy confirm title")
end

function TestChoiceBuilder:test_defaults_body_and_option_labels()
  local view = choice_builder.build_choice_view({
    id = 8,
    kind = "remote",
    body = "正文",
    options = {
      { id = 3 },
    },
  }, {
    game = {
      turn = {},
    },
    body_lines_only = true,
  })

  lu.assertIs(view.title, "请选择", "choice view should default missing title")
  lu.assertIs(view.body, "", "body_lines_only should ignore pending.body")
  lu.assertIs(view.cancel_label, "取消", "choice view should default cancel label")
  lu.assertIs(view.allow_cancel, true, "choice view should allow cancel by default")
  lu.assertIs(view.options[1].label, "3", "choice view should default option label from raw option")
  lu.assertIs(view.options[1].id, 3, "choice view should preserve option id")
end

function TestChoiceBuilder:test_defaults_label_from_plain_string_option()
  -- kills _default_option_label 的 "nil" 字符串/type(id)/tostring(opt) 位点:
  -- 无 id 的裸字符串 option 必须以其自身为 label(变异体会产出 "nil" 或 nil)。
  local view = choice_builder.build_choice_view({
    id = 9,
    kind = "remote",
    options = { "路障卡" },
  }, {
    game = {
      turn = {},
    },
  })

  lu.assertIs(view.options[1].label, "路障卡", "a plain string option should be its own label")
  lu.assertIs(view.options[1].id, "路障卡", "a plain string option should carry itself as id")
end


return TestChoiceBuilder
