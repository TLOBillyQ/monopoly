-- 道具使用结果结算深模块:唯一解释者。
-- 成功判定(经 use_result.canonicalize)、消耗/留存时机、使用广播 + 成就遥测
-- (恰好一次)、兜底 action_anim 全部收敛于此;waiting 原样放行(不广播、
-- 不消耗、不补动画)。外部 seam(ADR-0019 begin/resolve)保持冻结,
-- 本模块只被 use_flow implementation 与自身测试穿过。
local achievement_progress = require("src.rules.ports.achievement_progress")
local action_anim_port = require("src.foundation.ports.action_anim")
local flow_context = require("src.rules.items.use_flow_context")
local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local use_broadcast = require("src.rules.items.use_broadcast")
local use_result = require("src.rules.items.use_result")

local settlement = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

-- 消耗时机:kind 级默认由调用方描述符经 opts.consume 声明
-- (before_apply | after_success | applier_owned | already_applied),
-- 道具级例外只登记在这张表——偷窃卡在 apply 中途经 commit() 自耗。
local _item_consume_overrides = {
  [item_ids.steal] = "applier_owned",
}

local ESCROW_META_KEY = "item_use_escrow"

local function _resolve_consume_mode(item_id, opts)
  local mode = opts.consume or "before_apply"
  if mode == "already_applied" then
    return mode
  end
  return _item_consume_overrides[item_id] or mode
end

-- 台账的 escrow 种子:优先读结算私有令牌,同时承认公共跨层布尔
-- choice.meta.item_preconsumed(turn/choice 层与既有 fixture 的既定接口)。
local function _seed_escrow(ledger, opts)
  local meta = opts.choice and opts.choice.meta or nil
  local token = meta and meta[ESCROW_META_KEY] or nil
  if token and token.consumed == true and token.refunded ~= true then
    ledger.escrowed = true
    return
  end
  if meta and meta.item_preconsumed == true then
    ledger.escrowed = true
    return
  end
  if opts.context_preconsumed == true then
    ledger.escrowed = true
  end
end

local function _make_commit(player, item_id, ledger)
  return function()
    assert(ledger.committed ~= true, "item use already committed: " .. tostring(item_id))
    ledger.committed = true
    if ledger.escrowed or ledger.consumed then
      return true
    end
    assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
    ledger.consumed = true
    return true
  end
end

local function _item_consumed(ledger)
  return ledger.escrowed == true or ledger.consumed == true
end

local function _queue_fallback_anim(game, player, item_id, before_seq, canonical)
  if canonical.action_anim then
    return canonical.action_anim
  end
  if not action_anim_port.is_enabled(game) then
    return canonical.action_anim
  end
  local current_seq = game.turn and game.turn.action_anim_seq or 0
  if current_seq > before_seq then
    return canonical.action_anim
  end
  local cfg = inventory.cfg(item_id)
  action_anim_port.queue(game, {
    kind = "item_use",
    player_id = player.id,
    item_id = item_id,
    item_name = cfg and cfg.name or nil,
    duration = action_anim_duration,
  })
  return true
end

local function _frozen_base(status, ok, player, item_id, ledger, canonical)
  return {
    ok = ok,
    status = status,
    actor = player,
    actor_id = player and player.id or nil,
    item_id = item_id,
    item_consumed = _item_consumed(ledger),
    result = canonical.raw,
    _settled_item_use = true,
  }
end

local function _settle_applied(game, player, item_id, ledger, canonical, consume_mode, before_seq)
  if canonical.consumed_by_applier then
    ledger.consumed = true
  end
  if consume_mode == "after_success" and not _item_consumed(ledger) then
    assert(inventory.consume(player, item_id) == true, "consume applied item failed: " .. tostring(item_id))
    ledger.consumed = true
  end
  if consume_mode == "applier_owned" then
    assert(ledger.committed == true or _item_consumed(ledger),
      "applier-owned item applied without commit: " .. tostring(item_id))
  end
  local frozen = _frozen_base("applied", true, player, item_id, ledger, canonical)
  frozen.action_anim = _queue_fallback_anim(game, player, item_id, before_seq, canonical)
  frozen.after_action_anim = canonical.after_action_anim
  achievement_progress.item_used(game, player)
  use_broadcast.dispatch(game, player, item_id)
  return frozen
end

local function _settle_rejected(player, item_id, ledger, canonical)
  if canonical.consumed_by_applier then
    ledger.consumed = true
  end
  local frozen = _frozen_base("rejected", false, player, item_id, ledger, canonical)
  frozen.reason = canonical.reason
  return frozen
end

-- 一次道具效果的完整结算事务。固定排序:
--   台账 escrow 种子 → before_apply 消耗 → 动画基线 → apply(commit) →
--   canonicalize → 解释(await 原样放行 / rejected 留卡 / applied 补耗 +
--   兜底动画 + 广播/遥测恰好一次)。
-- opts:
--   consume            消耗时机,默认 before_apply
--   fallback_reason    失败无 reason 时的稳定兜底
--   choice             resolve 路径的 pending choice(escrow 令牌来源)
--   context_preconsumed 迁移期 context.item_preconsumed 种子(step 4 收归令牌)
--   preapplied_count   already_applied 模式的 apply 前计数(count-diff 过渡)
function settlement.execute(game, player, item_id, apply, opts)
  opts = opts or {}
  local consume_mode = _resolve_consume_mode(item_id, opts)
  local ledger = { consumed = false, escrowed = false, committed = false }
  _seed_escrow(ledger, opts)

  if consume_mode == "before_apply" and not ledger.escrowed then
    assert(inventory.consume(player, item_id) == true, "consume item failed: " .. tostring(item_id))
    ledger.consumed = true
  end

  local before_seq = game.turn and game.turn.action_anim_seq or 0
  local raw = apply(_make_commit(player, item_id, ledger))
  local canonical = use_result.canonicalize(raw, opts.fallback_reason)

  if canonical.status == "await_choice" then
    return raw
  end
  if consume_mode == "already_applied" and opts.preapplied_count ~= nil
      and flow_context.count_item(player, item_id) < opts.preapplied_count then
    ledger.consumed = true
  end
  if canonical.status == "rejected" then
    return _settle_rejected(player, item_id, ledger, canonical)
  end
  return _settle_applied(game, player, item_id, ledger, canonical, consume_mode, before_seq)
end

-- 非重复阶段 followup 的预消耗托管:卡即刻入台账 escrow(令牌随 choice 走),
-- resolve 时 _seed_escrow 认领不二次消耗,放弃路径经 settlement.abandon 退还。
-- 同时写公共跨层布尔 item_preconsumed(turn/choice 层既定接口)并禁用取消。
function settlement.escrow(player, item_id, choice_spec)
  assert(type(choice_spec) == "table", "escrow needs a choice spec")
  assert(inventory.consume(player, item_id) == true, "escrow consume failed: " .. tostring(item_id))
  local meta = choice_spec.meta or {}
  choice_spec.meta = meta
  meta[ESCROW_META_KEY] = { consumed = true, item_id = item_id, player_id = player.id }
  meta.item_preconsumed = true
  meta.item_id = meta.item_id or item_id
  meta.player_id = meta.player_id or player.id
  choice_spec.allow_cancel = false
  choice_spec.cancel_label = nil
  return choice_spec
end

-- 托管卡退还(force_skip / 目标失效放弃)。幂等:令牌只退一次;
-- 仅有公共布尔的旧 fixture 退还后翻转布尔防重复。
function settlement.abandon(game, choice, _)
  local meta = type(choice) == "table" and choice.meta or nil
  if type(meta) ~= "table" then
    return false
  end
  local token = meta[ESCROW_META_KEY]
  if token ~= nil and (token.consumed ~= true or token.refunded == true) then
    return false
  end
  if token == nil and meta.item_preconsumed ~= true then
    return false
  end
  local item_id = (token and token.item_id) or meta.item_id
  if item_id == nil then
    return false
  end
  local actor_id = (token and token.player_id) or meta.player_id or choice.owner_role_id
  local player = flow_context.resolve_actor(game, actor_id)
  if not (player and player.inventory) then
    return false
  end
  if inventory.add(player, { id = item_id }) ~= true then
    return false
  end
  if token ~= nil then
    token.refunded = true
  end
  meta.item_preconsumed = false
  return true
end

function settlement.is_settled(value)
  return type(value) == "table" and value._settled_item_use == true
end

settlement.ESCROW_META_KEY = ESCROW_META_KEY

return settlement
