-- ebutton.lua branch-dense coverage: __update_* 的 client_role 定向分支与全角色广播分支。
local lu = require("luaunit")
local context = require("src.ui.manager.context")
local EButton = require("src.ui.manager.ebutton")
local support = require("test.support.ui_manager_nodes_support")

-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,before_each/after_each 收成
-- setUp/tearDown,共享 local role_a/role_b 收成 self 字段,用例数与改写前一致(9 例)。

TestEButton = {}

function TestEButton:setUp()
  support.clear_context()
  support.install_host_math()
  self.role_a = support.make_role(1)
  self.role_b = support.make_role(2)
end

function TestEButton:tearDown()
  support.clear_context()
  support.restore_host_math()
end

function TestEButton:test_init_defaults_text_to_empty_string()
  local button = EButton:new(301, "btn")

  lu.assertEvalToTrue(button.text == "", "new button text should default to empty string")
end

function TestEButton:test_disabled_targets_only_the_client_role()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local button = EButton:new(302, "btn")

  button.disabled = true

  local touch = support.calls_of(self.role_a, "set_node_touch_enabled")
  local enabled = support.calls_of(self.role_a, "set_button_enabled")
  lu.assertEvalToTrue(#touch == 1, "client role should receive set_node_touch_enabled once")
  lu.assertEvalToTrue(touch[1].args[1] == 302, "host call should carry the eui node id")
  lu.assertEvalToTrue(touch[1].args[2] == false, "disabled=true should disable touch")
  lu.assertEvalToTrue(#enabled == 1, "client role should receive set_button_enabled once")
  lu.assertEvalToTrue(enabled[1].args[2] == false, "disabled=true should disable the button")
  lu.assertEvalToTrue(#self.role_b.calls == 0, "other roles should not be touched when client_role is set")
  lu.assertEvalToTrue(button.disabled == true, "disabled getter should report the stored value")
end

function TestEButton:test_disabled_broadcasts_to_all_roles_when_no_client_role()
  support.install_roles({ self.role_a, self.role_b })
  local button = EButton:new(303, "btn")

  button.disabled = false

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local touch = support.calls_of(role, "set_node_touch_enabled")
    local enabled = support.calls_of(role, "set_button_enabled")
    lu.assertEvalToTrue(#touch == 1 and touch[1].args[2] == true, "disabled=false should enable touch for every role")
    lu.assertEvalToTrue(#enabled == 1 and enabled[1].args[2] == true, "disabled=false should enable the button for every role")
  end
end

function TestEButton:test_text_targets_only_the_client_role()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local button = EButton:new(304, "btn")

  button.text = "roll"

  local calls = support.calls_of(self.role_a, "set_button_text")
  lu.assertEvalToTrue(#calls == 1, "client role should receive set_button_text once")
  lu.assertEvalToTrue(calls[1].args[1] == 304, "host call should carry the eui node id")
  lu.assertEvalToTrue(calls[1].args[2] == "roll", "host call should carry the new text")
  lu.assertEvalToTrue(#self.role_b.calls == 0, "other roles should not receive the text update")
  lu.assertEvalToTrue(button.text == "roll", "text getter should report the stored value")
end

function TestEButton:test_text_broadcasts_to_all_roles_when_no_client_role()
  support.install_roles({ self.role_a, self.role_b })
  local button = EButton:new(305, "btn")

  button.text = "buy"

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_button_text")
    lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == "buy", "every role should receive the text update")
  end
end

function TestEButton:test_text_color_targets_only_the_client_role()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local button = EButton:new(306, "btn")

  button.text_color = 0xff0000

  local calls = support.calls_of(self.role_a, "set_button_text_color")
  lu.assertEvalToTrue(#calls == 1, "client role should receive set_button_text_color once")
  lu.assertEvalToTrue(calls[1].args[2] == 0xff0000, "host call should carry the new color")
  lu.assertEvalToTrue(#self.role_b.calls == 0, "other roles should not receive the color update")
  lu.assertEvalToTrue(button.text_color == 0xff0000, "text_color getter should report the stored value")
end

function TestEButton:test_text_color_broadcasts_to_all_roles_when_no_client_role()
  support.install_roles({ self.role_a, self.role_b })
  local button = EButton:new(307, "btn")

  button.text_color = 0x00ff00

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_button_text_color")
    lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == 0x00ff00, "every role should receive the color update")
  end
end

function TestEButton:test_font_size_targets_only_the_client_role()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local button = EButton:new(308, "btn")

  button.font_size = 30.0

  local calls = support.calls_of(self.role_a, "set_button_font_size")
  lu.assertEvalToTrue(#calls == 1, "client role should receive set_button_font_size once")
  lu.assertEvalToTrue(calls[1].args[2] == 30.0, "host call should carry the fixed font size")
  lu.assertEvalToTrue(#self.role_b.calls == 0, "other roles should not receive the font size update")
  lu.assertEvalToTrue(button.font_size == 30.0, "font_size getter should report the stored value")
end

function TestEButton:test_font_size_broadcasts_to_all_roles_when_no_client_role()
  support.install_roles({ self.role_a, self.role_b })
  local button = EButton:new(309, "btn")

  button.font_size = 24.0

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_button_font_size")
    lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == 24.0, "every role should receive the font size update")
  end
end


return TestEButton
