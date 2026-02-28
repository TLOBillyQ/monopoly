local support = require("TestSupport")
local runtime_constants = require("Config.RuntimeConstants")
local turn_engine = require("src.game.core.runtime.TurnEngine")

local function _with_coroutine_flag(enabled, fn)
  support.with_patches({
    { target = runtime_constants, key = "experimental_coroutine_turn", value = enabled == true },
  }, fn)
end

local function _test_turn_engine_defaults_to_legacy_mode()
  _with_coroutine_flag(false, function()
    local g = support.new_game()
    assert(g.turn_engine ~= nil, "game should have turn_engine")
    assert(g.turn_engine:is_coroutine_mode() == false, "default turn_engine mode should be legacy")
  end)
end

local function _test_turn_engine_coroutine_mode_resolves_wait_choice()
  _with_coroutine_flag(true, function()
    local g = support.new_game()
    g.turn_engine = turn_engine:new(g, {
      start = function()
        return "wait_choice", { resume_state = "done", resume_args = {} }
      end,
      done = function()
        return nil
      end,
    }, {
      experimental_coroutine_turn = true,
    })

    local choice = support.open_choice(g, {
      kind = "item_phase_choice",
      title = "行动前：使用道具？",
      options = { { id = 2001, label = "路障卡" } },
      allow_cancel = true,
      cancel_label = "结束阶段",
      meta = {
        phase = "pre_action",
        player_id = g:current_player().id,
      },
    })

    g:advance_turn()
    assert(g.turn.phase == "wait_choice", "coroutine turn_engine should enter wait_choice")

    g:dispatch_action({
      type = "choice_cancel",
      choice_id = choice.id,
      actor_role_id = g:current_player().id,
    })

    assert(g.turn.pending_choice == nil, "choice_cancel should clear pending choice in coroutine mode")
    assert(g.turn.phase ~= "wait_choice", "coroutine mode should leave wait_choice after cancel")
  end)
end

return {
  name = "gameplay.coroutine",
  tests = {
    {
      name = "turn_engine_defaults_to_legacy_mode",
      run = _test_turn_engine_defaults_to_legacy_mode,
    },
    {
      name = "turn_engine_coroutine_mode_resolves_wait_choice",
      run = _test_turn_engine_coroutine_mode_resolves_wait_choice,
    },
  },
}
