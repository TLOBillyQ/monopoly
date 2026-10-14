-- ebutton.lua branch-dense coverage: __update_* 的 client_role 定向分支与全角色广播分支。
local luassert = assert
local context = require("src.ui.manager.context")
local EButton = require("src.ui.manager.ebutton")
local support = require("test.support.ui_manager_nodes_support")

describe("TestEButton", function()
local role_a, role_b

before_each(function()
  support.clear_context()
  support.install_host_math()
  role_a = support.make_role(1)
  role_b = support.make_role(2)
end)

after_each(function()
  support.clear_context()
  support.restore_host_math()
end)

it("test_init_defaults_text_to_empty_string", function()
  local button = EButton:new(301, "btn")

  luassert.truthy(button.text == "", "new button text should default to empty string")
end)

it("test_disabled_targets_only_the_client_role", function()
  context.client_role = role_a
  support.install_roles({ role_a, role_b })
  local button = EButton:new(302, "btn")

  button.disabled = true

  local touch = support.calls_of(role_a, "set_node_touch_enabled")
  local enabled = support.calls_of(role_a, "set_button_enabled")
  luassert.truthy(#touch == 1, "client role should receive set_node_touch_enabled once")
  luassert.truthy(touch[1].args[1] == 302, "host call should carry the eui node id")
  luassert.truthy(touch[1].args[2] == false, "disabled=true should disable touch")
  luassert.truthy(#enabled == 1, "client role should receive set_button_enabled once")
  luassert.truthy(enabled[1].args[2] == false, "disabled=true should disable the button")
  luassert.truthy(#role_b.calls == 0, "other roles should not be touched when client_role is set")
  luassert.truthy(button.disabled == true, "disabled getter should report the stored value")
end)

it("test_disabled_broadcasts_to_all_roles_when_no_client_role", function()
  support.install_roles({ role_a, role_b })
  local button = EButton:new(303, "btn")

  button.disabled = false

  for _, role in ipairs({ role_a, role_b }) do
    local touch = support.calls_of(role, "set_node_touch_enabled")
    local enabled = support.calls_of(role, "set_button_enabled")
    luassert.truthy(#touch == 1 and touch[1].args[2] == true, "disabled=false should enable touch for every role")
    luassert.truthy(#enabled == 1 and enabled[1].args[2] == true, "disabled=false should enable the button for every role")
  end
end)

it("test_text_targets_only_the_client_role", function()
  context.client_role = role_a
  support.install_roles({ role_a, role_b })
  local button = EButton:new(304, "btn")

  button.text = "roll"

  local calls = support.calls_of(role_a, "set_button_text")
  luassert.truthy(#calls == 1, "client role should receive set_button_text once")
  luassert.truthy(calls[1].args[1] == 304, "host call should carry the eui node id")
  luassert.truthy(calls[1].args[2] == "roll", "host call should carry the new text")
  luassert.truthy(#role_b.calls == 0, "other roles should not receive the text update")
  luassert.truthy(button.text == "roll", "text getter should report the stored value")
end)

it("test_text_broadcasts_to_all_roles_when_no_client_role", function()
  support.install_roles({ role_a, role_b })
  local button = EButton:new(305, "btn")

  button.text = "buy"

  for _, role in ipairs({ role_a, role_b }) do
    local calls = support.calls_of(role, "set_button_text")
    luassert.truthy(#calls == 1 and calls[1].args[2] == "buy", "every role should receive the text update")
  end
end)

it("test_text_color_targets_only_the_client_role", function()
  context.client_role = role_a
  support.install_roles({ role_a, role_b })
  local button = EButton:new(306, "btn")

  button.text_color = 0xff0000

  local calls = support.calls_of(role_a, "set_button_text_color")
  luassert.truthy(#calls == 1, "client role should receive set_button_text_color once")
  luassert.truthy(calls[1].args[2] == 0xff0000, "host call should carry the new color")
  luassert.truthy(#role_b.calls == 0, "other roles should not receive the color update")
  luassert.truthy(button.text_color == 0xff0000, "text_color getter should report the stored value")
end)

it("test_text_color_broadcasts_to_all_roles_when_no_client_role", function()
  support.install_roles({ role_a, role_b })
  local button = EButton:new(307, "btn")

  button.text_color = 0x00ff00

  for _, role in ipairs({ role_a, role_b }) do
    local calls = support.calls_of(role, "set_button_text_color")
    luassert.truthy(#calls == 1 and calls[1].args[2] == 0x00ff00, "every role should receive the color update")
  end
end)

it("test_font_size_targets_only_the_client_role", function()
  context.client_role = role_a
  support.install_roles({ role_a, role_b })
  local button = EButton:new(308, "btn")

  button.font_size = 30.0

  local calls = support.calls_of(role_a, "set_button_font_size")
  luassert.truthy(#calls == 1, "client role should receive set_button_font_size once")
  luassert.truthy(calls[1].args[2] == 30.0, "host call should carry the fixed font size")
  luassert.truthy(#role_b.calls == 0, "other roles should not receive the font size update")
  luassert.truthy(button.font_size == 30.0, "font_size getter should report the stored value")
end)

it("test_font_size_broadcasts_to_all_roles_when_no_client_role", function()
  support.install_roles({ role_a, role_b })
  local button = EButton:new(309, "btn")

  button.font_size = 24.0

  for _, role in ipairs({ role_a, role_b }) do
    local calls = support.calls_of(role, "set_button_font_size")
    luassert.truthy(#calls == 1 and calls[1].args[2] == 24.0, "every role should receive the font size update")
  end
end)


end)
