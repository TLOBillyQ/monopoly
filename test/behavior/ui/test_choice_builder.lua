-- Behavior specs for src/ui/view/choice_builder.lua 守卫消息钉:
-- pending 缺省与自定义 option_label 返回 nil 的报错路径必须保留描述性消息。

local luax = require("test.support.luax")
local choice = require("src.ui.view.choice_builder")

TestChoiceBuilder = {}

function TestChoiceBuilder:test_build_choice_view_asserts_descriptive_error_without_pending()
  -- 杀 L76 "missing pending choice" 消息钉。
  luax.has_error(function()
    choice.build_choice_view(nil)
  end, "missing pending choice")
end

function TestChoiceBuilder:test_custom_option_label_returning_nil_asserts_descriptive_error()
  -- 杀 L54 "missing option label" 消息钉:自定义 label 返回 nil 必须报带消息的错。
  luax.has_error(function()
    choice.build_choice_view({
      options = { { id = 1 } },
    }, {
      option_label = function()
        return nil
      end,
    })
  end, "missing option label")
end

return TestChoiceBuilder
