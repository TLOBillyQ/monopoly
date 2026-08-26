-- item 流程 choice 的 actor 解析与失败/等待结果:#293 复核——_handle_flow_choice
-- 的 actor-or-validate 回落、失败 reason、等待 stay 均未测,4 个变异存活。
-- 经 choice_handler_factory.build_item_handlers 注入 stub helpers 驱动。
local lu = require("luaunit")

local factory = require("src.rules.choice_handlers.factory")

local function _helpers(resolve_result)
  local finish_choice = function(_, stay)
    return { status = stay and "waiting" or "resolved", stay = stay }
  end
  local finish_active_item_phase = function() end
  return {
    finish_choice = finish_choice,
    finish_active_item_phase = finish_active_item_phase,
    begin_item_use = function() return {} end,
    resolve_item_use_choice = function(_, choice, _, _)
      return resolve_result
    end,
  }
end

local function _handler(resolve_result)
  local registry = factory.build_item_handlers(_helpers(resolve_result))
  local descriptor = registry["item_target_player"]
  lu.assertEvalToTrue(descriptor ~= nil, "item_target_player handler should be built")
  return descriptor
end

local function _game()
  return {
    turn = { item_phase_active = "pre_action", choice_elapsed_seconds = 0 },
    dirty = {},
    find_player_by_id = function(_, role_id)
      if role_id == "p1" then return { id = "p1" } end
      return nil
    end,
  }
end

TestItemFlowChoice = {}

function TestItemFlowChoice:test_resolved_actor_is_used_as_the_completion_player()
  -- #293:result.actor 存在时直接采用(validate 调用→nil 变异可分)。
  local seen_player = nil
  local completions = require("src.rules.choice_handlers.item_completions")
  local original_build = completions.build
  completions.build = function(helpers)
    local base = original_build(helpers)
    local followup_completion = base.followup_completion
    base.followup_completion = function(game, choice, player, result)
      seen_player = player
      return followup_completion(game, choice, player, result)
    end
    return base
  end
  local descriptor = _handler({ ok = true, actor = { id = "actor_9" } })
  local game = _game()
  local result = descriptor.execute(game, { kind = "item_target_player", meta = { player_id = "p1", item_id = "x" } })
  completions.build = original_build
  lu.assertEvalToTrue(seen_player ~= nil and seen_player.id == "actor_9",
    "completion should receive the resolved actor; got " .. tostring(seen_player and seen_player.id))
  lu.assertEvalToTrue(result ~= nil, "execute should produce a result")
end

function TestItemFlowChoice:test_without_actor_validate_resolves_the_player()
  -- #293:无 actor 时 validate_item_player 兜底(调用→nil 变异可分)。
  local seen_player = nil
  local completions = require("src.rules.choice_handlers.item_completions")
  local original_build = completions.build
  completions.build = function(helpers)
    local base = original_build(helpers)
    local followup_completion = base.followup_completion
    base.followup_completion = function(game, choice, player, result)
      seen_player = player
      return followup_completion(game, choice, player, result)
    end
    return base
  end
  local descriptor = _handler({ ok = true })
  local game = _game()
  descriptor.execute(game, { kind = "item_target_player", meta = { player_id = "p1", item_id = "x" } })
  completions.build = original_build
  lu.assertEvalToTrue(seen_player ~= nil and seen_player.id == "p1",
    "completion should receive the validated player; got " .. tostring(seen_player and seen_player.id))
end

function TestItemFlowChoice:test_failed_result_returns_stay_with_reason()
  local descriptor = _handler({ ok = false, reason = "some_failure" })
  local game = _game()
  local result = descriptor.execute(game, { kind = "item_target_player", meta = { player_id = "p1", item_id = "x" } })
  lu.assertEvalToTrue(result ~= nil and result.stay == true and result.reason == "some_failure",
    "failed result should stay with the reason; got " .. tostring(result and result.reason))
end

function TestItemFlowChoice:test_waiting_result_returns_stay()
  local descriptor = _handler({ ok = true, waiting = true })
  local game = _game()
  local result = descriptor.execute(game, { kind = "item_target_player", meta = { player_id = "p1", item_id = "x" } })
  lu.assertEvalToTrue(result ~= nil and result.stay == true,
    "waiting result should stay")
end

return TestItemFlowChoice
