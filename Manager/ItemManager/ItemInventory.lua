local ItemsCfg = require("Config.Generated.Items")
require "Library.Utils"
local Logger = require("Components.Logger")
local MonopolyEvent = require("Globals.MonopolyEvents")

local Inventory = {}

local cfg_by_id = {}
for _, cfg in ipairs(ItemsCfg) do
  cfg_by_id[cfg.id] = cfg
end

local function _ResolveEventName(kind)
  assert(MonopolyEvent ~= nil, "missing MONOPOLY_EVENT")
  local intent = assert(MonopolyEvent.intent, "missing MONOPOLY_EVENT.intent")
  assert(kind ~= nil, "missing event kind")
  return intent[kind] or kind
end

local function _DispatchIntent(game, payload)
  assert(payload ~= nil, "missing payload")
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    assert(game ~= nil and game.store ~= nil, "Choice.open requires game.store")
    local spec = intent.choice_spec
    local seq = game.store:Get({ "turn", "choice_seq" }) or 0
    seq = seq + 1
    game.store:Set({ "turn", "choice_seq" }, seq)
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
    game.store:Set({ "turn", "pending_choice" }, entry)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = _ResolveEventName("need_choice")
    TriggerCustomEvent(event_name, { game = game, choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = assert(game.ui_port, "missing ui_port")
    assert(ui_port.PushPopup ~= nil, "missing ui_port.PushPopup")
    ui_port:PushPopup(intent.payload)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = _ResolveEventName("push_popup")
    TriggerCustomEvent(event_name, { game = game, payload = intent.payload })
  end
end

function Inventory.Cfg(item_id)
  return cfg_by_id[item_id]
end

function Inventory.ItemName(item_id)
  local cfg = cfg_by_id[item_id]
  assert(cfg ~= nil, "missing item cfg: " .. tostring(item_id))
  return cfg.name
end

function Inventory.Items(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return assert(player.inventory.items, "missing inventory items")
end

function Inventory.Count(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:Count()
end

function Inventory.IsFull(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:IsFull()
end

function Inventory.Add(player, item)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  assert(item ~= nil, "missing item")
  return player.inventory:Add(item)
end

function Inventory.FindIndex(player, item_id)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  return player.inventory:FindIndex(function(it)
    return it.id == item_id
  end)
end

function Inventory.Consume(player, item_id)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  local idx = assert(Inventory.FindIndex(player, item_id), "missing item: " .. tostring(item_id))
  player.inventory:RemoveByIndex(idx)
  return true
end

function Inventory.RemoveByIndex(player, idx)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  assert(idx ~= nil, "missing index")
  return player.inventory:RemoveByIndex(idx)
end

function Inventory.Clear(player)
  assert(player ~= nil, "missing player")
  assert(player.inventory ~= nil, "missing player.inventory")
  player.inventory._suspend_on_change = true
  player.inventory.items = {}
  player.inventory._suspend_on_change = false
end

function Inventory.DrawRandom(_)
  local picked = Utils.choice_weight_list(ItemsCfg, 1, function(item)
    return item.weight or 0
  end, true)
  return picked[1] or ItemsCfg[1]
end

local function _NotifyFull(game, player, item_id)
  assert(game ~= nil, "missing game")
  assert(game.ui_port ~= nil, "missing ui_port")
  assert(player ~= nil, "missing player")
  if player.is_ai or player.auto then
    return
  end
  _DispatchIntent(game, {
    kind = "push_popup",
    payload = {
      title = "道具",
      body = player.name .. " 背包已满，无法获得道具 " .. Inventory.ItemName(item_id),
    },
  })
end

function Inventory.Give(player, item_id, context)
  if Inventory.IsFull(player) then
    Logger.Warn(player.name .. " 的背包已满，无法获得道具 " .. item_id)
    assert(context ~= nil and context.game ~= nil, "missing context.game")
    _NotifyFull(context.game, player, item_id)
    return false
  end
  assert(Inventory.Add(player, { id = item_id }) == true, "inventory add failed: " .. tostring(item_id))
  Logger.Event(player.name .. " 获得道具 " .. Inventory.ItemName(item_id))
  return true
end

function Inventory.DrawAndGive(player, rng, context)
  local cfg = Inventory.DrawRandom(rng)
  assert(cfg ~= nil, "missing drawn item cfg")
  Inventory.Give(player, cfg.id, context)
end

return Inventory


