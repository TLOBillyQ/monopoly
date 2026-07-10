-- Regression pin (wayfinder: item-multi-use-regression, ticket 01).
-- Baseline: 掷骰前的可选行动窗口里，玩家可连续使用任意数量合法道具；
-- 唯一数量限制是同组道具单回合一次（used_effect_groups）。用完一张
-- 非掷骰道具后窗口必须重新开放，直到玩家主动结束或超时才推进。
local support = require("spec.support.shared_support")
local turn_engine = require("src.turn.loop.scheduler_runtime")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local item_phase = require("src.rules.items.phase")
local config_reset = require("spec.support.config_reset")

describe("pre_action item window multi-use", function()
  before_each(function() config_reset.reset_all() end)

  -- 全真实回合机：phase start 自己打开 pre_action 窗口（wait_action 挂起），
  -- 与实际游戏同一条链路。这是钉症状的主用例。
  it("real turn machine keeps the item window open across consecutive item uses", function()
    local g = support.new_game()
    local p = g:current_player()
    inventory.clear(p)
    p.inventory:add({ id = item_ids.mine })
    p.inventory:add({ id = item_ids.angel })

    g:advance_turn()

    local window = g.turn.pending_choice
    assert(window ~= nil and window.kind == "item_phase_passive",
      "turn start should open the pre_action item window")

    g:dispatch_action({
      type = "choice_select",
      choice_id = window.id,
      option_id = item_ids.mine,
      actor_role_id = p.id,
    })

    local reopened = g.turn.pending_choice
    assert(reopened ~= nil, "item window should reopen after a non-dice item use, not advance the turn")
    assert(reopened.kind == "item_phase_passive", "reopened window should still be the passive item window")

    g:dispatch_action({
      type = "choice_select",
      choice_id = reopened.id,
      option_id = item_ids.angel,
      actor_role_id = p.id,
    })

    assert(inventory.count(p) == 0, "both items should be consumed within the same turn")
  end)

  -- followup 链路：路障需要跟随选格子，走 item_completions 完成链
  -- （与地雷/天使的立即执行链不同）。完成后窗口同样必须重开。
  it("real turn machine reopens the window after a followup item completes", function()
    local g = support.new_game()
    local p = g:current_player()
    inventory.clear(p)
    p.inventory:add({ id = item_ids.roadblock })
    p.inventory:add({ id = item_ids.mine })

    g:advance_turn()
    local window = g.turn.pending_choice
    assert(window ~= nil and window.kind == "item_phase_passive",
      "turn start should open the pre_action item window")

    g:dispatch_action({
      type = "choice_select",
      choice_id = window.id,
      option_id = item_ids.roadblock,
      actor_role_id = p.id,
    })

    local followup = g.turn.pending_choice
    assert(followup ~= nil and followup.kind == "roadblock_target",
      "roadblock should open its target follow-up choice")

    g:dispatch_action({
      type = "choice_select",
      choice_id = followup.id,
      option_id = assert(followup.options[1], "roadblock follow-up should offer tiles").id,
      actor_role_id = p.id,
    })

    local reopened = g.turn.pending_choice
    assert(reopened ~= nil and reopened.kind == "item_phase_passive",
      "item window should reopen after the follow-up completes, not advance the turn")
    assert(inventory.count(p) == 1, "mine should remain usable after the roadblock was consumed")
  end)

  -- RED（已知缺陷，修复票的红灯）：post_action 窗口 + followup/target 道具
  -- 用完后窗口应重开（地雷仍可用），当前被 item_completions.lua 的
  -- phase=="post_action" 早退分支直接 finish，回合推进（flow.resumed==true 处红）。
  -- 修复时把 pending 换回 it。
  it("post_action window reopens after a followup item completes", function()
    local g = support.new_game()
    local flow = { resumed = false }
    g.turn_engine = turn_engine:new(g, {
      start = function()
        return "wait_choice", { next_state = "after_items", next_args = {} }
      end,
      after_items = function()
        flow.resumed = true
        return nil
      end,
    })
    local p = g:current_player()
    inventory.clear(p)
    p.inventory:add({ id = item_ids.roadblock })
    p.inventory:add({ id = item_ids.mine })

    local window = support.open_choice(g, assert(item_phase.build_passive_choice_spec(g, p, "post_action", {
      next_state = "after_items",
      next_args = {},
    }), "post_action item window should open with two usable items"))
    g:advance_turn()

    g:dispatch_action({
      type = "choice_select",
      choice_id = window.id,
      option_id = item_ids.roadblock,
      actor_role_id = p.id,
    })
    local followup = g.turn.pending_choice
    assert(followup ~= nil and followup.kind == "roadblock_target",
      "roadblock should open its target follow-up choice")

    g:dispatch_action({
      type = "choice_select",
      choice_id = followup.id,
      option_id = assert(followup.options[1], "roadblock follow-up should offer tiles").id,
      actor_role_id = p.id,
    })

    assert(flow.resumed == false,
      "post_action followup completion must not advance the turn while legal items remain")
    local reopened = g.turn.pending_choice
    assert(reopened ~= nil and reopened.kind == "item_phase_passive",
      "post_action item window should reopen after the follow-up completes")
    assert(inventory.count(p) == 1, "mine should remain usable after the roadblock was consumed")
  end)

  -- 缩窄用例：合成 turn_engine 直接挂 wait_choice，只覆盖 dispatch→resolve→reopen
  -- 子链路。真实用例红、这条绿时，断裂点在两者的差集（wait_action 转移 / decide 策略）。
  it("wait_choice sub-chain reopens the window after a non-dice item", function()
    local g = support.new_game()
    local flow = { resumed = false }
    g.turn_engine = turn_engine:new(g, {
      start = function()
        return "wait_choice", { next_state = "after_items", next_args = {} }
      end,
      after_items = function()
        flow.resumed = true
        return nil
      end,
    })
    local p = g:current_player()
    inventory.clear(p)
    p.inventory:add({ id = item_ids.mine })
    p.inventory:add({ id = item_ids.angel })

    local choice = support.open_choice(g, assert(item_phase.build_passive_choice_spec(g, p, "pre_action", {
      next_state = "after_items",
      next_args = {},
    }), "pre_action item window should open with two usable items"))

    g:advance_turn()
    assert(g.turn.phase == "wait_choice", "turn should wait on the item window")

    g:dispatch_action({
      type = "choice_select",
      choice_id = choice.id,
      option_id = item_ids.mine,
      actor_role_id = p.id,
    })

    assert(flow.resumed == false, "using one item must not advance the turn past the item window")
    local reopened = g.turn.pending_choice
    assert(reopened ~= nil, "item window should reopen after a non-dice item use")
    assert(reopened.kind == "item_phase_passive", "reopened window should still be the passive item window")

    g:dispatch_action({
      type = "choice_select",
      choice_id = reopened.id,
      option_id = item_ids.angel,
      actor_role_id = p.id,
    })

    assert(inventory.count(p) == 0, "both items should be consumed within the same turn")
  end)
end)
