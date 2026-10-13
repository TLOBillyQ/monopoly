-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
-- game_action 分发的 pre-confirm 守卫路径:意图类型无对应 handler 时
-- _dispatch_pre_confirm_handler 返回 false,未知意图整体回落。

local pending_confirmation = require("src.state.pending_confirmation")
local game_action = require("src.ui.input.game_action")

describe("TestGameActionGuard", function()

it("test_dispatch_unknown_intent_with_active_pre_confirm_source", function()
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {})
  local result = game_action.dispatch(state, {}, { type = "unknown_kind" }, {}, {
    dispatch_action = function() end,
  })
  luassert.truthy(result == false, "unknown intent should fall through without a handler")
end)

end)
