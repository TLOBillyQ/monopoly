local items_cfg = require("Config.Generated.Items")
require "Library.Utils"
local logger = require("Library.Monopoly.Logger")
local MONOPOLY_EVENT = require("Globals.MonopolyEvents")

local Inventory = {}

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

local function resolve_event_name(kind)
  if not kind then
    return nil
  end
  local intent = MONOPOLY_EVENT and MONOPOLY_EVENT.intent
  if intent and intent[kind] then
    return intent[kind]
  end
  return kind
end

local function dispatch_intent(game, payload)
  if not payload then
    return
  end
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    assert(game and game.store, "Choice.open requires game.store")
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
    if TriggerCustomEvent then
      local event_name = resolve_event_name("need_choice")
      if event_name then
        TriggerCustomEvent(event_name, { game = game, choice = entry, choice_spec = spec })
      end
    end
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = game and game.ui_port
    if ui_port and ui_port.push_popup then
      ui_port:push_popup(intent.payload)
    end
    if TriggerCustomEvent then
      local event_name = resolve_event_name("push_popup")
      if event_name then
        TriggerCustomEvent(event_name, { game = game, payload = intent.payload })
      end
    end
  end
end

function Inventory.cfg(item_id)
  return cfg_by_id[item_id]
end

function Inventory.item_name(item_id)
  local cfg = cfg_by_id[item_id]
  return cfg.name
end

function Inventory.items(player)
  if not player or not player.inventory then
    return {}
  end
  return player.inventory.items or {}
end

function Inventory.count(player)
  if not player or not player.inventory then
    return 0
  end
  return player.inventory:count()
end

function Inventory.is_full(player)
  if not player or not player.inventory then
    return false
  end
  return player.inventory:is_full()
end

function Inventory.add(player, item)
  if not player or not player.inventory or not item then
    return false
  end
  return player.inventory:add(item)
end

function Inventory.find_index(player, item_id)
  if not player or not player.inventory then
    return nil
  end
  return player.inventory:find_index(function(it)
    return it.id == item_id
  end)
end

function Inventory.consume(player, item_id)
  if not player or not player.inventory then
    return false
  end
  local idx = Inventory.find_index(player, item_id)
  if idx then
    player.inventory:remove_by_index(idx)
    return true
  end
  return false
end

function Inventory.remove_by_index(player, idx)
  if not player or not player.inventory or not idx then
    return nil
  end
  return player.inventory:remove_by_index(idx)
end

function Inventory.clear(player)
  if not player or not player.inventory then
    return
  end
  player.inventory._suspend_on_change = true
  player.inventory.items = {}
  player.inventory._suspend_on_change = false
end

function Inventory.draw_random(_)
  local picked = Utils.choice_weight_list(items_cfg, 1, function(item)
    return item.weight or 0
  end, true)
  return picked[1] or items_cfg[1]
end

local function notify_full(game, player, item_id)
  if not game or not game.ui_port or not player or player.is_ai or player.auto then
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
    logger.warn(player.name .. " 的背包已满，无法获得道具 " .. item_id)
    notify_full(context and context.game, player, item_id)
    return false
  end
  if not Inventory.add(player, { id = item_id }) then
    return false
  end
  logger.event(player.name .. " 获得道具 " .. Inventory.item_name(item_id))
  return true
end

function Inventory.draw_and_give(player, rng, context)
  local cfg = Inventory.draw_random(rng)
  if not cfg then
    return
  end
  Inventory.give(player, cfg.id, context)
end

return Inventory
