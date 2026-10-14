-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
-- #293 批3 pin:src/ui/input/command_definitions_buttons.lua 为纯数据表,
-- 4 个幸存者均为字段值换 nil。逐字段钉死数据契约。

local definitions = require("src.ui.input.command_definitions_buttons")

local function _assert_eq(a, b, msg)
  luassert.truthy(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("TestCommandDefinitionsButtons", function()

it("test_next_button_routes_with_turn_actor_source", function()
  -- L11 `actor_source = "turn"` 换 nil:next 按钮的演员来源必须 turn。
  _assert_eq(definitions.UI_BUTTONS.next.reason, "action_button", "next reason must be stable")
  _assert_eq(definitions.UI_BUTTONS.next.actor_source, "turn", "next actor source must be turn")
end)

it("test_auto_button_uses_auto_reason", function()
  -- L14 `reason = "auto_button"` 换 nil:auto 按钮的 reason 必须 auto_button。
  _assert_eq(definitions.UI_BUTTONS.auto.reason, "auto_button", "auto reason must be auto_button")
  _assert_eq(definitions.UI_BUTTONS.auto.actor_source, "local", "auto actor source must be local")
end)

it("test_cancel_button_routes_with_turn_actor_source", function()
  -- L23 `actor_source = "turn"` 换 nil:cancel 按钮的演员来源必须 turn。
  _assert_eq(definitions.UI_BUTTONS.cancel.reason, "cancel_button", "cancel reason must be stable")
  _assert_eq(definitions.UI_BUTTONS.cancel.actor_source, "turn", "cancel actor source must be turn")
end)

it("test_generic_ui_button_reason_is_ui_button", function()
  -- L28 `reason = "ui_button"` 换 nil:通用回退的 reason 必须 ui_button。
  _assert_eq(definitions.GENERIC_UI_BUTTON.reason, "ui_button", "generic reason must be ui_button")
  _assert_eq(definitions.GENERIC_UI_BUTTON.game_handler, "basic", "generic handler must be basic")
end)

end)
