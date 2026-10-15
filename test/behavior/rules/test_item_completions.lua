require("test.bootstrap").install_package_paths()
-- luacheck: ignore 143 (busted injects the verified luassert object)
local luassert = assert
-- item_completions 直测:completion 组装与 item_target_handler 描述表的边界契约。
-- 集成 spec(item_completions_closure 等)覆盖成功路径;本 spec 补 helper 桩直驱的
-- 参数形状与描述表默认值(变异清扫 #259 survivor 真缺口闭合)。
--
local support = require("test.support.shared_support")
local with_patches = support.with_patches
local item_phase = require("src.rules.items.phase")
local normalize = require("src.rules.choice_handlers.item_normalize")
local completions = require("src.rules.choice_handlers.item_completions")

local function _make_game()
  return {
    turn = {},
    find_player_by_id = function(_, pid)
      return { id = pid }
    end,
  }
end


describe("TestItemCompletions", function()
  it("test_settle_choice_window_finishes_the_settled_window_with_an_explicit_false_flag", function()
    local calls = {}
    local complete = completions.build({
      finish_choice = function(game, flag)
        calls[#calls + 1] = { game = game, flag = flag }
      end,
      finish_active_item_phase = function() end,
    })
    local game = _make_game()

    luassert.is_nil(complete.settle_choice_window(game, nil))
    luassert.truthy(#calls == 1 and calls[1].game == game, "nil completion settles the window")
    luassert.is.same(false, calls[1].flag, "finish_choice receives an explicit false, not true")
  end)

  it("test_settle_choice_window_keeps_the_window_untouched_on_stay_or_reopened", function()
    local calls = 0
    local complete = completions.build({
      finish_choice = function()
        calls = calls + 1
      end,
      finish_active_item_phase = function() end,
    })
    local game = _make_game()

    local stay = { stay = true }
    local stay_result = complete.settle_choice_window(game, stay)
    luassert.is.equal(stay, stay_result)
    local reopened = { reopened = true }
    local reopened_result = complete.settle_choice_window(game, reopened)
    luassert.is.equal(reopened, reopened_result)
    luassert.is.same(0, calls, "stay/reopened completions must not finish the choice window")
  end)

  it("test_followup_cancel_defaults_elapsed_seconds_to_0_when_the_clock_field_is_absent", function()
    local complete = completions.build({
      finish_choice = function() end,
      finish_active_item_phase = function() end,
    })
    local game = _make_game()

    local captured = nil
    with_patches({
      { target = item_phase, key = "reopen_or_finish", value = function(_, _, _, open_opts)
        captured = open_opts
        return true
      end },
    }, function()
      local result = complete.followup_cancel(game, {
        kind = "k",
        meta = { player_id = 1, phase = "pre_action" },
      })
      luassert.truthy(result and result.stay == true, "reopened phase asks the flow to stay")
    end)

    luassert.is_not_nil(captured, "reopen_or_finish should be consulted")
    luassert.is.same(0, captured.elapsed_seconds, "absent choice_elapsed_seconds falls back to 0")
  end)

  it("test_item_target_handler_pins_required_meta_and_default_seams", function()
    local execute_fn = function() end
    local handler = completions.item_target_handler("k", execute_fn, {})

    luassert.truthy(#handler.required_meta == 2
      and handler.required_meta[1] == "player_id"
      and handler.required_meta[2] == "item_id", "required_meta declares player_id and item_id")
    luassert.is.equal(normalize.item_target_meta, handler.normalize_meta)
    luassert.is.equal(normalize.validate_item_owner_meta, handler.meta_validator)
    luassert.is.equal(execute_fn, handler.execute)
  end)

  it("test_item_target_handler_normalize_action_normalizes_option_id_through_the_kind", function()
    local handler = completions.item_target_handler("k", function() end, {})
    local action = { option_id = 7 }

    local normalized = handler.normalize_action(nil, nil, action)

    luassert.truthy(normalized ~= nil and normalized.option_id == 7, "option_id survives normalization")
    luassert.is_not.equal(action, normalized, "normalization returns a copy, not the original")
    luassert.has_error(function()
      handler.normalize_action(nil, nil, {})
    end, "k requires numeric action.option_id")
  end)


end)
