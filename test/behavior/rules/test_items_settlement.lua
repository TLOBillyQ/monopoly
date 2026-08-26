-- items/settlement 直测:道具结算深模块的消耗时机(默认 before_apply / 偷窃卡
-- applier_owned 例外 / already_applied 绕行)、escrow 种子三来源、commit 契约、
-- 兜底动画队列(名称/时长/序号护栏)、abandon 退还优先级。
-- 集成 spec 覆盖主流程(变异清扫 #259 survivor 真缺口闭合);inventory /
-- 遥测 / 动画口全桩,canonicalize 与被测模块本体走真实现。
--
-- 原生 LuaUnit(busted → LuaUnit 迁移):无钩子 describe 拍平为 TestItemsSettlement
-- 类,describe 级 local 提升到文件级,用例数与改写前一一对应(14 例)。
local lu = require("luaunit")
local luax = require("test.support.luax")
local support = require("test.support.shared_support")
local with_patches = support.with_patches
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")
local flow_context = require("src.rules.items.use_flow_context")
local achievement_progress = require("src.rules.ports.achievement_progress")
local action_anim_port = require("src.foundation.ports.action_anim")
local use_result = require("src.rules.items.use_result")
local settlement = require("src.rules.items.settlement")

local _player = { id = 1, name = "P", inventory = {} }
local _ITEM = 2001

-- 桩集:consume/add/cfg 记录调用,广播/遥测计数,动画口按用例开关。
-- step 计数器给 consume 与 apply 定序(消耗时机的直接证据)。
local function _make_patches(opts)
  opts = opts or {}
  local calls = { consume = {}, add = {}, queued = {}, progress = 0, apply_at = nil }
  local clock = { now = 0 }
  local function _tick()
    clock.now = clock.now + 1
    return clock.now
  end
  local patches = {
    { target = inventory, key = "consume", value = function(_, item_id)
      calls.consume[#calls.consume + 1] = { item_id = item_id, at = _tick() }
      return true
    end },
    { target = inventory, key = "add", value = function(_, item)
      calls.add[#calls.add + 1] = item
      return true
    end },
    { target = inventory, key = "cfg", value = function(item_id)
      return (opts.cfg or {})[item_id]
    end },
    { target = achievement_progress, key = "item_used", value = function()
      calls.progress = calls.progress + 1
    end },
    { target = action_anim_port, key = "is_enabled", value = function()
      return opts.anim_enabled == true
    end },
    { target = action_anim_port, key = "queue", value = function(game, anim)
      calls.queued[#calls.queued + 1] = anim
      game.turn.action_anim_seq = (game.turn.action_anim_seq or 0) + 1
    end },
    { target = flow_context, key = "count_item", value = function()
      return opts.count_item or 0
    end },
  }
  local function _mark_apply()
    calls.apply_at = _tick()
  end
  return calls, patches, _mark_apply
end

local function _make_game()
  return { turn = {}, find_player_by_id = function(_, pid)
    if pid == nil then
      return nil
    end
    return { id = pid, name = "P" .. tostring(pid), inventory = {} }
  end }
end

TestItemsSettlement = {}

function TestItemsSettlement:test_default_consume_mode_is_before_apply_the_item_leaves_before_the_applier_runs()
  local calls, patches, mark_apply = _make_patches()
  with_patches(patches, function()
    local result = settlement.execute(_make_game(), _player, _ITEM, function()
      mark_apply()
      return use_result.applied()
    end, {})

    lu.assertEvalToTrue(#calls.consume == 1 and calls.consume[1].item_id == _ITEM, "item consumed once")
    lu.assertEvalToTrue(calls.consume[1].at < calls.apply_at, "consumption happens before apply")
    lu.assertEvalToTrue(result.ok == true and result.status == "applied" and result.item_consumed == true,
      "settled applied with consumption recorded")
    lu.assertEvalToTrue(calls.progress == 1, "item use telemetry fires exactly once")
  end)
end

function TestItemsSettlement:test_steal_overrides_the_consume_mode_to_applier_owned()
  local calls, patches, mark_apply = _make_patches()
  with_patches(patches, function()
    local result = settlement.execute(_make_game(), _player, item_ids.steal, function(commit)
      mark_apply()
      lu.assertEvalToTrue(commit() == true, "commit reports success")
      return use_result.applied()
    end, {})

    lu.assertEvalToTrue(#calls.consume == 1 and calls.consume[1].at > calls.apply_at,
      "steal is consumed by commit inside apply, never before it")
    lu.assertEvalToTrue(result.ok == true and result.item_consumed == true, "consumption recorded")
  end)
end

function TestItemsSettlement:test_already_applied_bypasses_the_steal_override_and_reconciles_by_count_diff()
  local calls, patches = _make_patches({ count_item = 0 })
  with_patches(patches, function()
    local result = settlement.execute(_make_game(), _player, item_ids.steal, function()
      return use_result.applied()
    end, { consume = "already_applied", preapplied_count = 1 })

    lu.assertEvalToTrue(#calls.consume == 0, "already_applied never consumes through the ledger")
    lu.assertEvalToTrue(result.item_consumed == true, "positive count diff marks the item consumed")
  end)
end

function TestItemsSettlement:test_already_applied_without_preapplied_count_reconciles_nothing()
  local calls, patches = _make_patches()
  with_patches(patches, function()
    local result = settlement.execute(_make_game(), _player, _ITEM, function()
      return use_result.applied()
    end, { consume = "already_applied" })

    lu.assertEvalToTrue(#calls.consume == 0, "no consumption without a baseline count")
    lu.assertEvalToTrue(result.item_consumed == false, "nothing reconciled")
  end)
end

function TestItemsSettlement:test_escrow_token_seeds_the_ledger_and_skips_before_apply_consumption()
  local calls, patches = _make_patches()
  with_patches(patches, function()
    local result = settlement.execute(_make_game(), _player, _ITEM, function()
      return use_result.applied()
    end, {
      choice = { meta = { [settlement.ESCROW_META_KEY] = {
        consumed = true, item_id = _ITEM, player_id = 1,
      } } },
    })

    lu.assertEvalToTrue(#calls.consume == 0, "escrowed item is not consumed again")
    lu.assertEvalToTrue(result.item_consumed == true, "escrow counts as consumed")
  end)
end

function TestItemsSettlement:test_a_refunded_escrow_token_no_longer_seeds_the_ledger()
  local calls, patches = _make_patches()
  with_patches(patches, function()
    local result = settlement.execute(_make_game(), _player, _ITEM, function()
      return use_result.applied()
    end, {
      choice = { meta = { [settlement.ESCROW_META_KEY] = {
        consumed = true, refunded = true, item_id = _ITEM, player_id = 1,
      } } },
    })

    lu.assertEvalToTrue(#calls.consume == 1, "refunded escrow falls back to before_apply consumption")
    lu.assertEvalToTrue(result.item_consumed == true, "consumption recorded")
  end)
end

function TestItemsSettlement:test_the_public_item_preconsumed_flag_and_context_preconsumed_also_seed_escrow()
  for _, opts in ipairs({
    { choice = { meta = { item_preconsumed = true } } },
    { context_preconsumed = true },
  }) do
    local calls, patches = _make_patches()
    with_patches(patches, function()
      local result = settlement.execute(_make_game(), _player, _ITEM, function()
        return use_result.applied()
      end, opts)

      lu.assertEvalToTrue(#calls.consume == 0, "preconsumed markers skip before_apply consumption")
      lu.assertEvalToTrue(result.item_consumed == true, "escrow counts as consumed")
    end)
  end
end

function TestItemsSettlement:test_commit_is_one_shot_and_reports_success_on_both_branches()
  -- 消耗分支:applier_owned 未耗,commit 走 inventory.consume 后返回 true。
  local _, patches = _make_patches()
  with_patches(patches, function()
    local commit_returns = {}
    settlement.execute(_make_game(), _player, item_ids.steal, function(commit)
      commit_returns[#commit_returns + 1] = commit()
      luax.has_error(function()
        commit()
      end, "item use already committed: " .. tostring(item_ids.steal))
      return use_result.applied()
    end, {})
    lu.assertEvalToTrue(commit_returns[1] == true, "consuming commit returns true")
  end)

  -- escrow 分支:已托管时 commit 短路返回 true,不再消耗。
  local calls2, patches2 = _make_patches()
  with_patches(patches2, function()
    local commit_returns = {}
    settlement.execute(_make_game(), _player, item_ids.steal, function(commit)
      commit_returns[#commit_returns + 1] = commit()
      return use_result.applied()
    end, { choice = { meta = { [settlement.ESCROW_META_KEY] = {
      consumed = true, item_id = item_ids.steal, player_id = 1,
    } } } })
    lu.assertEvalToTrue(commit_returns[1] == true, "escrowed commit returns true")
    lu.assertEvalToTrue(#calls2.consume == 0, "escrowed commit consumes nothing")
  end)
end

function TestItemsSettlement:test_applier_owned_without_a_commit_raises_a_loud_error()
  local _, patches = _make_patches()
  with_patches(patches, function()
    luax.has_error(function()
      settlement.execute(_make_game(), _player, item_ids.steal, function()
        return use_result.applied()
      end, {})
    end, "applier-owned item applied without commit: " .. tostring(item_ids.steal))
  end)
end

function TestItemsSettlement:test_fallback_anim_queues_with_the_item_name_and_default_duration_when_apply_stays_silent()
  local calls, patches = _make_patches({ anim_enabled = true, cfg = { [_ITEM] = { name = "强租卡" } } })
  with_patches(patches, function()
    local result = settlement.execute(_make_game(), _player, _ITEM, function()
      return use_result.applied()
    end, {})

    lu.assertEvalToTrue(result.action_anim == true, "fallback anim flagged on the frozen result")
    lu.assertEvalToTrue(#calls.queued == 1, "exactly one fallback anim queued")
    local anim = calls.queued[1]
    lu.assertEvalToTrue(anim.kind == "item_use" and anim.player_id == 1 and anim.item_id == _ITEM,
      "anim identifies the item use")
    lu.assertEvalToTrue(anim.item_name == "强租卡", "anim carries the config item name")
    lu.assertEvalToTrue(anim.duration == 1.0, "anim carries the configured default duration")
  end)
end

function TestItemsSettlement:test_fallback_anim_is_skipped_when_apply_already_queued_an_anim()
  -- apply 期间 action_anim_seq 前进(> 执行前基线),结算不再补兜底动画。
  local calls, patches = _make_patches({ anim_enabled = true })
  with_patches(patches, function()
    local game = _make_game()
    local result = settlement.execute(game, _player, _ITEM, function()
      action_anim_port.queue(game, { kind = "custom" })
      return use_result.applied()
    end, {})

    lu.assertEvalToTrue(#calls.queued == 1, "only the applier's own anim is queued")
    lu.assertEvalToTrue(calls.queued[1].kind == "custom", "no fallback follows an applier anim")
    lu.assertEvalToTrue(result.action_anim == nil, "no fallback flagged")
  end)
end

function TestItemsSettlement:test_escrow_requires_a_choice_spec_table()
  luax.has_error(function()
    settlement.escrow(_player, _ITEM, nil)
  end, "escrow needs a choice spec")
end

function TestItemsSettlement:test_abandon_refunds_the_token_item_with_token_identity_winning_over_meta()
  local calls, patches = _make_patches()
  with_patches(patches, function()
    local token = { consumed = true, item_id = 100, player_id = 1 }
    local meta = { [settlement.ESCROW_META_KEY] = token, item_id = 200, item_preconsumed = true }
    local choice = { meta = meta, owner_role_id = 1 }

    lu.assertEvalToTrue(settlement.abandon(_make_game(), choice) == true, "refund succeeds")
    lu.assertEvalToTrue(#calls.add == 1 and calls.add[1].id == 100, "token item_id wins over meta.item_id")
    lu.assertEvalToTrue(token.refunded == true, "token marked refunded")
    lu.assertEvalToTrue(meta.item_preconsumed == false, "public flag cleared")

    lu.assertEvalToTrue(settlement.abandon(_make_game(), choice) == false, "refund is one-shot")
    lu.assertEvalToTrue(#calls.add == 1, "no second refund")
  end)
end

function TestItemsSettlement:test_abandon_returns_false_when_the_actor_cannot_take_the_card_back()
  local _, patches = _make_patches()
  with_patches(patches, function()
    -- 收卡人必须持有背包;解析出的玩家没有 inventory 字段时退还中止。
    local game = { find_player_by_id = function(_, pid)
      return { id = pid }
    end }
    local meta = { [settlement.ESCROW_META_KEY] = { consumed = true, item_id = 100, player_id = 9 } }
    lu.assertEvalToTrue(settlement.abandon(game, { meta = meta }) == false,
      "inventory-less actor aborts the refund")
  end)
end


return TestItemsSettlement
