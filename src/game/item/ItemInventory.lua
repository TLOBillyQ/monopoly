local items_cfg = require("Config.Generated.Items")
require "vendor.third_party.Utils"
local logger = require("src.core.Logger")
local monopoly_event = require("src.game.MonopolyEvents")

local inventory = {}

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

local function _resolve_event_name(kind)
  assert(monopoly_event ~= nil, "missing MONOPOLY_EVENT")
  local intent = assert(monopoly_event.intent, "missing MONOPOLY_EVENT.intent")
  assert(kind ~= nil, "missing event kind")
  return intent[kind] or kind
end

local function _dispatch_intent(game, payload)
  assert(payload ~= nil, "missing payload")
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    assert(game ~= nil and game.store ~= nil, "Choice.open requires game.store")
    local spec = intent.choice_spec
    local seq = game.store:get({ "turn", "choice_seq" }) or 0
    seq = seq + 1
    game.store:set({ "turn", "choice_seq" }, seq)
    local entry = {
      id = seq,
      kind = spec.kind,
      title = spec.title or "请选择",
      body_lines = spec.body_lines or {},
      options = spec.options or {},
      allow_cancel = spec.allow_cancel ~= false,
      cancel_label = spec.cancel_label or "取消",
      meta = spec.meta,
    }
    game.store:set({ "turn", "pending_choice" }, entry)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = _resolve_event_name("need_choice")
    TriggerCustomEvent(event_name, { game = game, choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = assert(game.ui_port, "missing ui_port")
    assert(ui_port.push_popup ~= nil, "missing ui_port.PushPopup")
    ui_port:push_popup(intent.payload)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = _resolve_event_name("push_popup")
    TriggerCustomEvent(event_name, { game = game, payload = intent.payload })
  end
end

function inventory.cfg(item_id)
  return cfg_by_id[item_id]
end

function inventory.item_name(item_id)
  local cfg = cfg_by_id[item_id]
  assert(cfg ~= nil, "missing item cfg: " .. tostring(item_id))
  return cfg.name
end

function inventory.items(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return assert(player.inventory.items, "missing inventory items")
end

function inventory.count(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:count()
end

function inventory.is_full(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:is_full()
end

function inventory.add(player, item)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  assert(item ~= nil, "missing item")
  return player.inventory:add(item)
end

function inventory.find_index(player, item_id)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:find_index(function(it)
    return it.id == item_id
  end)
end

function inventory.consume(player, item_id)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  local idx = assert(inventory.find_index(player, item_id), "missing item: " .. tostring(item_id))
  player.inventory:remove_by_index(idx)
  return true
end

function inventory.remove_by_index(player, idx)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  assert(idx ~= nil, "missing index")
  return player.inventory:remove_by_index(idx)
end

function inventory.clear(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  player.inventory._suspend_on_change = true
  player.inventory.items = {}
  player.inventory._suspend_on_change = false
end

function inventory.draw_random(_)
  local picked = Utils.choice_weight_list(items_cfg, 1, function(item)
    return item.weight or 0
  end, true)
  return picked[1] or items_cfg[1]
end

local function _notify_full(game, player, item_id)
  assert(game ~= nil, "missing game")
  assert(game.ui_port ~= nil, "missing ui_port")
  assert(player ~= nil, "missing player")
  if player.is_ai or player.auto then
    return
  end
  _dispatch_intent(game, {
    kind = "push_popup",
    payload = {
      title = "道具",
      body = player.name .. " 背包已满，无法获得道具 " .. inventory.item_name(item_id),
    },
  })
end

function inventory.give(player, item_id, context)
  if inventory.is_full(player) then
    logger.warn(player.name .. " 的背包已满，无法获得道具 " .. item_id)
    assert(context ~= nil and context.game ~= nil, "missing context.game")
    _notify_full(context.game, player, item_id)
    return false
  end
  assert(inventory.add(player, { id = item_id }) == true, "inventory add failed: " .. tostring(item_id))
  logger.event(player.name .. " 获得道具 " .. inventory.item_name(item_id))
  return true
end

function inventory.draw_and_give(player, rng, context)
  local cfg = inventory.draw_random(rng)
  assert(cfg ~= nil, "missing drawn item cfg")
  inventory.give(player, cfg.id, context)
end

return inventory


