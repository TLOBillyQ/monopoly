local effects = require("src.rules.items.post_effects")
local auto_play_port = require("src.rules.ports.auto_play")
local flow_context = require("src.rules.items.use_flow_context")
local inventory = require("src.rules.items.inventory")
local settlement = require("src.rules.items.settlement")

local executor = {}

local function _resolve_context(game, player, context)
  context = context or {}
  if type(context.by_ai) == "nil" then
    context.by_ai = auto_play_port.is_auto_player(game, player)
  end
  return context
end

local function _resolve_handler(game, item_id)
  local registries = assert(game.registries, "missing game.registries")
  local registry = assert(registries.items, "missing item registry")
  return registry.handlers[item_id]
end

function executor.use_item(game, player, item_id, context)
  context = _resolve_context(game, player, context)
  local cfg = inventory.cfg(item_id)
  assert(cfg ~= nil, "missing item cfg: " .. tostring(item_id))
  local fallback_reason = context.reject_reason_fallback

  local handler = _resolve_handler(game, item_id)
  if handler == nil then
    return settlement.execute(game, player, item_id, function()
      local res = effects.apply_post(game, player, item_id, context)
      assert(res ~= nil, "missing item post effect result: " .. tostring(item_id))
      return res
    end, { consume = "before_apply", fallback_reason = fallback_reason })
  end

  local before_count = flow_context.count_item(player, item_id)
  local res = handler(game, player, item_id, context)
  if settlement.is_settled(res) then
    return res
  end
  if type(res) == "table" and res.waiting == true then
    return res
  end
  -- 历史 handler 契约:效果已在 handler 内部生效(含消耗),结算只负责
  -- 判定/广播/兜底动画;消耗事实经 apply 前后计数回填台账。
  -- 该分支随 step 3 各 kind 迁入 settlement 后仅剩注入式测试 handler 使用。
  return settlement.execute(game, player, item_id, function()
    return res
  end, {
    consume = "already_applied",
    fallback_reason = fallback_reason,
    preapplied_count = before_count,
    context_preconsumed = context.item_preconsumed == true,
  })
end

return executor
