-- state_factory.build_state 直测:参数归一化、守卫、初始状态字段锚定。
-- 初始字段(等待动画/计数/标志)被回合循环直接消费,数值与布尔变异必须钉住。
require("test.bootstrap").install_package_paths()
local luassert = assert

local state_factory = require("src.app.state_factory")

describe("TestStateFactory", function()

local function _build(opts_extra)
  local opts = {
    get_current_game = function()
      return nil
    end,
    build_game_factory = function()
      return { factory = true }
    end,
    auto_runner = { runner = true },
  }
  for k, v in pairs(opts_extra or {}) do
    opts[k] = v
  end
  return state_factory.build_state(opts)
end

local function _test_initial_state_fields_match_the_defaults()
  local state = _build()
  luassert.truthy(state.ui ~= nil, "ui state must be built")
  luassert.truthy(state.pending_choice_elapsed == 0, "pending choice elapsed starts at 0")
  luassert.truthy(state.ui_modal_elapsed == 0, "modal elapsed starts at 0")
  luassert.truthy(state.wait_move_anim == true, "move anim starts waiting")
  luassert.truthy(state.wait_action_anim == true, "action anim starts waiting")
  luassert.truthy(state.tick_started == nil, "retired tick_started flag stays absent")
  luassert.truthy(state.tick_handle == nil, "tick handle starts absent")
  luassert.truthy(state.player_units_missing == false, "player units start present")
  luassert.truthy(state.action_button_elapsed == 0, "action button elapsed starts at 0")
  luassert.truthy(state.action_button_active == false, "action button starts inactive")
end

local function _test_game_factory_and_auto_runner_are_wired()
  local state = _build()
  luassert.truthy(state.game_factory ~= nil and state.game_factory.factory == true,
    "the game factory must be built into the state")
  luassert.truthy(state.auto_runner ~= nil and state.auto_runner.runner == true,
    "the auto runner must be wired into the state")
end

local function _test_guards_missing_get_current_game()
  luassert.has_error(function()
    state_factory.build_state({
      build_game_factory = function()
        return {}
      end,
      auto_runner = {},
    })
  end, "missing get_current_game")
end

local function _test_guards_missing_build_game_factory()
  luassert.has_error(function()
    state_factory.build_state({
      get_current_game = function()
        return nil
      end,
      auto_runner = {},
    })
  end, "missing build_game_factory")
end

local function _test_guards_missing_auto_runner()
  luassert.has_error(function()
    state_factory.build_state({
      get_current_game = function()
        return nil
      end,
      build_game_factory = function()
        return {}
      end,
    })
  end, "missing auto_runner")
end

local function _test_two_argument_form_normalizes_opts()
  -- 双参数调用(arg1 不是 table),走 _normalize_args 的 else 分支(arg1, arg2 or {})。
  local get_current_game = function()
    return nil
  end
  local state = state_factory.build_state(get_current_game, {
    build_game_factory = function()
      return { factory = true }
    end,
    auto_runner = { runner = true },
  })
  luassert.truthy(state.game_factory ~= nil and state.game_factory.factory == true,
    "two-arg form must wire the game factory")
  luassert.truthy(state.auto_runner ~= nil and state.auto_runner.runner == true,
    "two-arg form must wire the auto runner")
end

it("test_initial_state_fields_match_the_defaults", _test_initial_state_fields_match_the_defaults)
it("test_game_factory_and_auto_runner_are_wired", _test_game_factory_and_auto_runner_are_wired)
it("test_guards_missing_get_current_game", _test_guards_missing_get_current_game)
it("test_guards_missing_build_game_factory", _test_guards_missing_build_game_factory)
it("test_guards_missing_auto_runner", _test_guards_missing_auto_runner)
it("test_two_argument_form_normalizes_opts", _test_two_argument_form_normalizes_opts)
end)
