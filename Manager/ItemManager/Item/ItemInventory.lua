local ItemsCfg = require("Config.Generated.Items")
require "Library.Utils"
local Logger = require("Components.Logger")
local MonopolyEvent = require("Globals.MonopolyEvents")

local Inventory = {}

local cfg_by_id = {}
for _, cfg in ipairs(ItemsCfg) do
  cfg_by_id[cfg.id] = cfg
end

local function resolve_event_name(kind)
  assert(MonopolyEvent ~= nil, "missing MONOPOLY_EVENT")
  local intent = assert(MonopolyEvent.intent, "missing MONOPOLY_EVENT.intent")
  assert(kind ~= nil, "missing event kind")
  return intent[kind] or kind
end

local function dispatch_intent(game, payload)
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
    local event_name = resolve_event_name("need_choice")
    TriggerCustomEvent(event_name, { game = game, choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = assert(game.ui_port, "missing ui_port")
    assert(ui_port.push_popup ~= nil, "missing ui_port.push_popup")
    ui_port:push_popup(intent.payload)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = resolve_event_name("push_popup")
    TriggerCustomEvent(event_name, { game = game, payload = intent.payload })
  end
end

function Inventory.cfg(item_id)
  return cfg_by_id[item_id]
end

function Inventory.item_name(item_id)
  local cfg = cfg_by_id[item_id]
  assert(cfg ~= nil, "missing item cfg: " .. tostring(item_id))
  return cfg.name
end

function Inventory.items(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return assert(player.inventory.items, "missing inventory items")
end

function Inventory.count(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:count()
end

function Inventory.is_full(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:is_full()
end

function Inventory.add(player, item)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  assert(item ~= nil, "missing item")
  return player.inventory:add(item)
end

function Inventory.find_index(player, item_id)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:find_index(function(it)
    return it.id == item_id
  end)
end

function Inventory.consume(player, item_id)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  local idx = assert(Inventory.find_index(player, item_id), "missing item: " .. tostring(item_id))
  player.inventory:remove_by_index(idx)
  return true
end

function Inventory.remove_by_index(player, idx)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  assert(idx ~= nil, "missing index")
  return player.inventory:remove_by_index(idx)
end

function Inventory.clear(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  player.inventory._suspend_on_change = true
  player.inventory.items = {}
  player.inventory._suspend_on_change = false
end

function Inventory.draw_random(_)
  local picked = Utils.choice_weight_list(ItemsCfg, 1, function(item)
    return item.weight or 0
  end, true)
  return picked[1] or ItemsCfg[1]
end

local function notify_full(game, player, item_id)
  assert(game ~= nil, "missing game")
  assert(game.ui_port ~= nil, "missing ui_port")
  assert(player ~= nil, "missing player")
  if player.is_ai or player.auto then
    return
  end
  dispatch_intent(game, {
    kind = "push_popup",
    payload = {
      title = "道具",
      body = player.name .. " 背包已满，无法获得道具 " .. Inventory.item_name(item_id),
    },
  })
end

function Inventory.give(player, item_id, context)
  if Inventory.is_full(player) then
    Logger.warn(player.name .. " 的背包已满，无法获得道具 " .. item_id)
    assert(context ~= nil and context.game ~= nil, "missing context.game")
    notify_full(context.game, player, item_id)
    return false
  end
  assert(Inventory.add(player, { id = item_id }) == true, "inventory add failed: " .. tostring(item_id))
  Logger.event(player.name .. " 获得道具 " .. Inventory.item_name(item_id))
  return true
end

function Inventory.draw_and_give(player, rng, context)
  local cfg = Inventory.draw_random(rng)
  assert(cfg ~= nil, "missing drawn item cfg")
  Inventory.give(player, cfg.id, context)
end

return Inventory


