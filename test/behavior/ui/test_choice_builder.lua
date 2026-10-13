require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
-- Behavior specs for src/ui/view/choice_builder.lua 守卫消息钉:
-- pending 缺省与自定义 option_label 返回 nil 的报错路径必须保留描述性消息。

local choice = require("src.ui.view.choice_builder")
describe("TestChoiceBuilder", function()
it("test_build_choice_view_asserts_descriptive_error_without_pending", function()
  -- 杀 L76 "missing pending choice" 消息钉。
  luassert.has_error(function()
    choice.build_choice_view(nil)
  end, "missing pending choice")
end)

it("test_custom_option_label_returning_nil_asserts_descriptive_error", function()
  -- 杀 L54 "missing option label" 消息钉:自定义 label 返回 nil 必须报带消息的错。
  luassert.has_error(function()
    choice.build_choice_view({
      options = { { id = 1 } },
    }, {
      option_label = function()
        return nil
      end,
    })
  end, "missing option label")
end)

end)
