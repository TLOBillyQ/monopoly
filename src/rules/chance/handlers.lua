local inventory = require("src.rules.items.inventory")
local tile = require("src.rules.board.tile")
local monopoly_event = require("src.foundation.events")
local movement = require("src.rules.movement")
local bankruptcy_port = require("src.rules.ports.bankruptcy")
local timing = require("src.config.gameplay.timing")
local number_utils = require("src.foundation.number")
local action_anim_port = require("src.foundation.ports.action_anim")
local move_anim_port = require("src.foundation.ports.move_anim")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")
local angel_feedback = require("src.rules.items.angel_feedback")

local shared = {}

local action_anim_duration = timing.action_anim_default_seconds or 1.0
local tile_state = tile.get_state

function shared.emit_event(game, kind, payload)
  payload = payload or {}
  monopoly_event.emit(kind, payload)
  if game and type(payload.text) == "string" then
    event_feed.publish(game, {
      kind = event_kinds.chance_card,
      text = payload.text,
    })
  end
end

shared.abs_value = math.abs

function shared.apply_cash_change(game, player, delta, opts)
  game:add_player_cash(player, delta, opts)
end

function shared.adjust_chance_delta(game, player, delta)
  if delta > 0 and game:player_has_deity(player, "rich") then
    return delta * 2
  end
  if delta < 0 and game:player_has_deity(player, "poor") then
    return delta * 2
  end
  return delta
end

function shared.handle_bankruptcy_if_non_positive(game, player, reason)
  if game:player_balance(player, "金币") > 0 then
    return
  end
  bankruptcy_port.eliminate(game, player, { reason = reason })
end

function shared.apply_cash_and_maybe_bankrupt(game, player, delta, reason)
  shared.apply_cash_change(game, player, delta)
  shared.handle_bankruptcy_if_non_positive(game, player, reason)
end

function shared.queue_action_anim(game, payload)
  if not payload then
    return false
  end
  return action_anim_port.queue(game, payload)
end

local function _queue_relocation_anim(game, kind, player, from_index, to_index, visited)
  if not player then
    return false
  end
  local payload = {
    kind = kind,
    player_id = player.id,
    from_index = from_index,
    to_index = to_index,
    visited = visited,
    duration = action_anim_duration,
  }
  return shared.queue_action_anim(game, payload)
end

function shared.queue_move_effect(game, player, from_index, to_index, visited)
  return _queue_relocation_anim(game, "move_effect", player, from_index, to_index, visited)
end

function shared.queue_forced_relocation(game, player, from_index, to_index)
  return _queue_relocation_anim(game, "forced_relocation", player, from_index, to_index, nil)
end

local function _build_chance_move_anim_payload(player, from_index, move_result)
  return {
    player_id = player.id,
    from_index = from_index,
    to_index = player.position,
    visited = move_result.visited,
    steps = move_result.steps,
    source = "chance_move",
  }
end

function shared.move_steps(game, player, steps, opts)
  local from_index = player.position
  local res = movement.move(game, player, steps, opts)
  assert(res ~= nil, "missing move result")
  local queued = move_anim_port.queue(game, _build_chance_move_anim_payload(player, from_index, res))
  if not queued then
    shared.queue_move_effect(game, player, from_index, player.position, res.visited)
  end
  return {
    kind = "need_landing",
    player_id = player.id,
    board_index = player.position,
    move_result = res,
    wait_move_anim = queued == true,
  }
end

function shared.dependencies()
  return {
    inventory = inventory,
    tile_state = tile_state,
    monopoly_event = monopoly_event,
    number_utils = number_utils,
  }
end

local function _register_cash_handlers(handlers, common)
  local deps = common.dependencies()

  local function _apply_to_all_players(game, fn)
    for _, p in ipairs(game.players) do
      if not p.eliminated then
        fn(p)
      end
    end
  end

  handlers.add_cash = function(game, player, card)
    if card.target == "all" then
      _apply_to_all_players(game, function(p)
        local delta = common.adjust_chance_delta(game, p, card.amount)
        common.apply_cash_change(game, p, delta)
        common.emit_event(game, deps.monopoly_event.chance.applied, {
          player = p,
          card = card,
          effect = card.effect,
          text = "￥ " .. p.name .. " 获得 " .. deps.number_utils.format_integer_part(delta) .. " 金币",
        })
      end)
      return
    end

    local delta = common.adjust_chance_delta(game, player, card.amount)
    common.apply_cash_change(game, player, delta)
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "￥ " .. player.name .. " 获得 " .. deps.number_utils.format_integer_part(delta) .. " 金币",
    })
  end

  handlers.pay_cash = function(game, player, card)
    if card.target == "all" then
      _apply_to_all_players(game, function(p)
        if card.negative and game:player_has_angel(p) then
          angel_feedback.publish(game, p, "机会卡扣费")
          return
        end
        local delta = common.adjust_chance_delta(game, p, -card.amount)
        local reason = p.name .. " 支付机会卡费用 " .. common.abs_value(delta) .. " 后破产"
        common.apply_cash_and_maybe_bankrupt(game, p, delta, reason)
        common.emit_event(game, deps.monopoly_event.chance.applied, {
          player = p,
          card = card,
          effect = card.effect,
          text = "￥ " .. p.name .. " 支付 " .. deps.number_utils.format_integer_part(common.abs_value(delta)) .. " 金币",
        })
      end)
      return
    end

    local delta = common.adjust_chance_delta(game, player, -card.amount)
    local reason = player.name .. " 支付机会卡费用 " .. common.abs_value(delta) .. " 后破产"
    common.apply_cash_and_maybe_bankrupt(game, player, delta, reason)
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "￥ " .. player.name .. " 支付 " .. deps.number_utils.format_integer_part(common.abs_value(delta)) .. " 金币",
    })
  end

  handlers.percent_pay_cash = function(game, player, card)
    if card.target == "all" then
      _apply_to_all_players(game, function(p)
        if card.negative and game:player_has_angel(p) then
          angel_feedback.publish(game, p, "机会卡扣费")
          return
        end
        local fee = math.floor(game:player_balance(p, "金币") * (card.percent / 100))
        local delta = common.adjust_chance_delta(game, p, -fee)
        local reason = p.name .. " 按比例支付机会卡费用 " .. common.abs_value(delta) .. " 后破产"
        common.apply_cash_and_maybe_bankrupt(game, p, delta, reason)
        common.emit_event(game, deps.monopoly_event.chance.applied, {
          player = p,
          card = card,
          effect = card.effect,
          text = "￥ " .. p.name .. " 按比例支付 " .. deps.number_utils.format_integer_part(common.abs_value(delta)) .. " 金币",
        })
      end)
      return
    end

    local fee = math.floor(game:player_balance(player, "金币") * (card.percent / 100))
    local delta = common.adjust_chance_delta(game, player, -fee)
    local reason = player.name .. " 按比例支付机会卡费用 " .. common.abs_value(delta) .. " 后破产"
    common.apply_cash_and_maybe_bankrupt(game, player, delta, reason)
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "￥ " .. player.name .. " 按比例支付 " .. deps.number_utils.format_integer_part(common.abs_value(delta)) .. " 金币",
    })
  end

  handlers.pay_others = function(game, player, card)
    for _, other in ipairs(game.players) do
      if player.eliminated then
        break
      end
      if other.id ~= player.id and not other.eliminated then
        local fee = math.abs(common.adjust_chance_delta(game, player, -card.amount))
        if not game:player_is_in_mountain(other) then
          local reason = player.name .. " 向他人支付后破产"
          common.apply_cash_change(game, player, -fee, { suppress_cash_receive_anim = true })
          common.handle_bankruptcy_if_non_positive(game, player, reason)
          common.apply_cash_change(game, other, fee, { suppress_cash_receive_anim = true })
        end
      end
    end
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "￥ " .. player.name .. " 向每位玩家支付 " .. deps.number_utils.format_integer_part(card.amount),
    })
  end

  handlers.collect_from_others = function(game, player, card)
    local total_collected = 0
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = common.adjust_chance_delta(game, player, card.amount)
        if not game:player_is_in_mountain(player) then
          local other_cash = game:player_balance(other, "金币")
          local liquid = math.min(other_cash, fee)
          common.apply_cash_change(game, other, -fee, { suppress_cash_receive_anim = true })
          common.apply_cash_change(game, player, liquid, { suppress_cash_receive_anim = true })
          total_collected = total_collected + liquid
          local reason = other.name .. " 被收款资金不足破产"
          common.handle_bankruptcy_if_non_positive(game, other, reason)
        end
      end
    end
    if total_collected > 0 then
      common.queue_action_anim(game, {
        kind = "cash_receive",
        player_id = player.id,
        amount = total_collected,
      })
    end
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = "￥ " .. player.name .. " 收取每位玩家 " .. deps.number_utils.format_integer_part(card.amount),
    })
  end
end

local function _register_asset_handlers(handlers, common)
  local deps = common.dependencies()

  handlers.destroy_buildings_on_path = function(game, _, _, context)
    assert(context ~= nil and context.visited ~= nil, "missing context.visited")
    for _, idx in ipairs(context.visited) do
      local t = game.board:get_tile(idx)
      assert(t ~= nil, "missing tile: " .. tostring(idx))
      if t.type == "land" and (t.level or 0) > 0 then
        game:set_tile_level(t, 0)
        common.emit_event(game, deps.monopoly_event.chance.applied, {
          card = { effect = "destroy_buildings_on_path" },
          effect = "destroy_buildings_on_path",
          tile = t,
          text = "台风摧毁 " .. t.name .. " 上的建筑",
        })
      end
    end
  end

  handlers.reset_tiles_on_path = function(game, _, _, context)
    assert(context ~= nil and context.visited ~= nil, "missing context.visited")
    for _, idx in ipairs(context.visited) do
      local t = game.board:get_tile(idx)
      assert(t ~= nil, "missing tile: " .. tostring(idx))
      if t.type == "land" then
        local st = deps.tile_state(game, t)
        assert(st ~= nil, "missing tile state: " .. tostring(t.id))
        if st.owner_id then
          local owner = assert(game:find_player_by_id(st.owner_id), "missing owner: " .. tostring(st.owner_id))
          game:set_player_property(owner, t.id, false)
        end
        game:reset_tile(t)
        common.emit_event(game, deps.monopoly_event.chance.applied, {
          card = { effect = "reset_tiles_on_path" },
          effect = "reset_tiles_on_path",
          tile = t,
          text = "强制征地重置 " .. t.name,
        })
      end
    end
  end

  handlers.grant_item = function(game, player, card)
    deps.inventory.give(player, card.item_id, { game = game })
  end

  handlers.discard_items = function(game, player, card)
    local to_drop = card.count
    if to_drop == 0 then
      to_drop = deps.inventory.count(player)
    end
    local dropped_names = {}
    local rng = assert(game and game.rng, "missing game.rng for discard_items")
    assert(type(rng.next_int) == "function", "missing game.rng.next_int for discard_items")
    for _ = 1, to_drop do
      local item_count = deps.inventory.count(player)
      if item_count == 0 then
        break
      end
      local item = deps.inventory.remove_by_index(player, rng:next_int(1, item_count))
      table.insert(dropped_names, deps.inventory.item_name(item.id))
    end
    local text = player.name .. " 丢弃道具 " .. #dropped_names .. " 张"
    if #dropped_names > 0 then
      text = text .. ": " .. table.concat(dropped_names, "、")
    end
    common.emit_event(game, deps.monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = text,
    })
  end

  handlers.discard_properties = function(game, player, card)
    local to_drop = card.count
    local property_ids = {}
    for tile_id in pairs(player.properties or {}) do
      property_ids[#property_ids + 1] = tile_id
    end
    table.sort(property_ids, function(a, b)
      local ai = deps.number_utils.to_integer(a)
      local bi = deps.number_utils.to_integer(b)
      if ai ~= nil and bi ~= nil then
        return ai < bi
      end
      return tostring(a) < tostring(b)
    end)

    if to_drop == 0 then
      to_drop = #property_ids
    end

    local rng = nil
    local needs_random_pick = to_drop > 0 and to_drop < #property_ids and #property_ids > 1
    if needs_random_pick then
      rng = assert(game and game.rng, "missing game.rng for discard_properties")
      assert(type(rng.next_int) == "function", "missing game.rng.next_int for discard_properties")
    end

    for _ = 1, to_drop do
      if #property_ids == 0 then
        break
      end
      local pick_index = 1
      if rng then
        pick_index = rng:next_int(1, #property_ids)
      end
      local tile_id = table.remove(property_ids, pick_index)
      local t = game.board:get_tile_by_id(tile_id)
      assert(t ~= nil, "missing tile: " .. tostring(tile_id))
      game:reset_tile(t)
      common.emit_event(game, deps.monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        tile = t,
        text = player.name .. " 丢失地块 " .. t.name,
      })
      game:set_player_property(player, tile_id, false)
    end
  end
end

local teleport_tile_types = {
  hospital = true,
  mountain = true,
  tax = true,
  market = true,
}

local function _register_movement_handlers(handlers, common)
  handlers.move_backward = function(game, player, card, context)
    local move_opts = {
      facing_mode = "relative_backward",
      skip_market_check = true,
    }
    if context and context.arrival_direction ~= nil then
      move_opts.direction = context.arrival_direction
    end
    local res = common.move_steps(game, player, -(card.steps or 0), move_opts)
    if res and res.move_result then
      res.move_result.allow_optional = true
    end
    return res
  end

  handlers.move_forward = function(game, player, card)
    return common.move_steps(game, player, card.steps or 0)
  end

  handlers.forced_move = function(game, player, card, context)
    local from_index = player.position
    local idx, t = game:player_relocate(player, {
      destination_tile_id = assert(card.destination_tile_id, "forced_move requires destination_tile_id"),
      move_dir_mode = "forced_move",
    })
    if teleport_tile_types[t.type] == true then
      common.queue_forced_relocation(game, player, from_index, idx)
    else
      common.queue_move_effect(game, player, from_index, idx, nil)
    end
    return {
      kind = "need_landing",
      player_id = player.id,
      board_index = idx,
      move_result = context,
    }
  end
end

local handlers = {}

function handlers.build()
  local built = {}
  _register_cash_handlers(built, shared)
  _register_asset_handlers(built, shared)
  _register_movement_handlers(built, shared)
  built.handlers = built
  return built
end

handlers._cash = { register = _register_cash_handlers }
handlers._asset = { register = _register_asset_handlers }

return handlers
