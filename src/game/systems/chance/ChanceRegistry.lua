local inventory = require("src.game.systems.items.ItemInventory")
local tile = require("src.game.systems.board.Tile")
local monopoly_event = require("src.game.core.runtime.events.MonopolyEvents")
local movement = require("src.game.systems.movement.Movement")
local bankruptcy = require("src.game.core.runtime.policies.Bankruptcy")
local gameplay_rules = require("Config.GameplayRules")
local vehicles_cfg = require("Config.Generated.Vehicles")
local vehicle_feature = require("src.game.systems.vehicle.VehicleFeature")
local number_utils = require("src.core.NumberUtils")
require "vendor.third_party.ClassUtils"

local chance_registry = Class("ChanceRegistry")
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

local tile_state = tile.get_state
local vehicle_name_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicle_name_by_id[cfg.id] = cfg.name
end

local function _emit_event(kind, payload)
  if TriggerCustomEvent then
    TriggerCustomEvent(kind, payload or {})
  end
end

local function _abs_value(value)
  if value < 0 then
    return -value
  end
  return value
end

local function _apply_cash_change(game, player, delta)
  game:add_player_cash(player, delta)
end

local function _adjust_chance_delta(game, player, delta)
  if delta > 0 and game:player_has_deity(player, "rich") then
    return delta * 2
  end
  if delta < 0 and game:player_has_deity(player, "poor") then
    return delta * 2
  end
  return delta
end

local function _handle_bankruptcy_if_negative(game, player, reason)
  if game:player_balance(player, "金币") > 0 then
    return
  end
  bankruptcy.eliminate(game, player, { reason = reason })
end

local function _apply_cash_and_maybe_bankrupt(game, player, delta, reason)
  _apply_cash_change(game, player, delta)
  _handle_bankruptcy_if_negative(game, player, reason)
end

local function _queue_action_anim(game, payload)
  if not game or not payload then
    return false
  end
  local ui_port = game.ui_port
  if not (ui_port and ui_port.wait_action_anim) then
    return false
  end
  if not game.queue_action_anim then
    return false
  end
  game:queue_action_anim(payload)
  return true
end

local function _queue_move_effect(game, player, from_index, to_index, visited)
  if not player then
    return false
  end
  local payload = {
    kind = "move_effect",
    player_id = player.id,
    from_index = from_index,
    to_index = to_index,
    visited = visited,
    duration = action_anim_duration,
  }
  return _queue_action_anim(game, payload)
end

local function _move_steps(game, player, steps, opts)
  local from_index = player.position
  local res = movement.move(game, player, steps, opts)
  assert(res ~= nil, "missing move result")
  _queue_move_effect(game, player, from_index, player.position, res.visited)
  if res.stopped_on_roadblock then
    local stay = player.status.stay_turns or 0
    if stay < 1 then
      game:set_player_status(player, "stay_turns", 1)
    end
  end
  return {
    kind = "need_landing",
    player_id = player.id,
    board_index = player.position,
    move_result = res,
  }
end

local function _register_defaults(registry)
  registry:register("add_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local delta = _adjust_chance_delta(game, p, card.amount)
          _apply_cash_change(game, p, delta)
          _emit_event(monopoly_event.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 获得 " .. number_utils.format_integer_part(delta) .. " 金币",
          })
        end
      end
    else
      local delta = _adjust_chance_delta(game, player, card.amount)
      _apply_cash_change(game, player, delta)
      _emit_event(monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 获得 " .. number_utils.format_integer_part(delta) .. " 金币",
      })
    end
  end)

  registry:register("pay_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local delta = _adjust_chance_delta(game, p, -card.amount)
          local reason = p.name .. " 支付机会卡费用 " .. _abs_value(delta) .. " 后破产"
          _apply_cash_and_maybe_bankrupt(game, p, delta, reason)
          _emit_event(monopoly_event.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 支付 " .. number_utils.format_integer_part(_abs_value(delta)) .. " 金币",
          })
        end
      end
    else
      local delta = _adjust_chance_delta(game, player, -card.amount)
      local reason = player.name .. " 支付机会卡费用 " .. _abs_value(delta) .. " 后破产"
      _apply_cash_and_maybe_bankrupt(game, player, delta, reason)
      _emit_event(monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 支付 " .. number_utils.format_integer_part(_abs_value(delta)) .. " 金币",
      })
    end
  end)

  registry:register("percent_pay_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local fee = math.floor(game:player_balance(p, "金币") * (card.percent / 100))
          local delta = _adjust_chance_delta(game, p, -fee)
          local reason = p.name .. " 按比例支付机会卡费用 " .. _abs_value(delta) .. " 后破产"
          _apply_cash_and_maybe_bankrupt(game, p, delta, reason)
          _emit_event(monopoly_event.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 按比例支付 " .. number_utils.format_integer_part(_abs_value(delta)) .. " 金币",
          })
        end
      end
    else
      local fee = math.floor(game:player_balance(player, "金币") * (card.percent / 100))
      local delta = _adjust_chance_delta(game, player, -fee)
      local reason = player.name .. " 按比例支付机会卡费用 " .. _abs_value(delta) .. " 后破产"
      _apply_cash_and_maybe_bankrupt(game, player, delta, reason)
      _emit_event(monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 按比例支付 " .. number_utils.format_integer_part(_abs_value(delta)) .. " 金币",
      })
    end
  end)

  registry:register("pay_others", function(game, player, card)
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = card.amount
        if game:player_has_deity(player, "poor") then
          fee = fee * 2
        end
        if not game:player_is_in_mountain(other) then
          local reason = player.name .. " 向他人支付后破产"
          _apply_cash_and_maybe_bankrupt(game, player, -fee, reason)
          _apply_cash_change(game, other, fee)
        end
      end
    end
    _emit_event(monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 向每位玩家支付 " .. number_utils.format_integer_part(card.amount),
    })
  end)

  registry:register("collect_from_others", function(game, player, card)
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = card.amount
        if game:player_has_deity(player, "rich") then
          fee = fee * 2
        end
        if not game:player_is_in_mountain(player) then
          local other_cash = game:player_balance(other, "金币")
          if other_cash < fee then
            fee = other_cash
          end
          _apply_cash_change(game, other, -fee)
          _apply_cash_change(game, player, fee)
        end
      end
    end
    _emit_event(monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 收取每位玩家 " .. number_utils.format_integer_part(card.amount),
    })
  end)

  registry:register("set_vehicle", function(game, player, card)
    if not vehicle_feature.is_enabled() then
      return
    end
    game:set_player_seat(player, card.vehicle_id)
    local vehicle_name = vehicle_name_by_id[card.vehicle_id] or tostring(card.vehicle_id)
    _emit_event(monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 获得座驾 " .. vehicle_name,
    })
  end)

  registry:register("destroy_buildings_on_path", function(game, _, _, context)
    assert(context ~= nil and context.visited ~= nil, "missing context.visited")
    for _, idx in ipairs(context.visited) do
      local t = game.board:get_tile(idx)
      assert(t ~= nil, "missing tile: " .. tostring(idx))
      if t.type == "land" and (t.level or 0) > 0 then
        game:set_tile_level(t, 0)
        _emit_event(monopoly_event.chance.applied, {
          card = { effect = "destroy_buildings_on_path" },
          effect = "destroy_buildings_on_path",
          tile = t,
          text = "台风摧毁 " .. t.name .. " 上的建筑",
        })
      end
    end
  end)

  registry:register("reset_tiles_on_path", function(game, _, _, context)
    assert(context ~= nil and context.visited ~= nil, "missing context.visited")
    for _, idx in ipairs(context.visited) do
      local t = game.board:get_tile(idx)
      assert(t ~= nil, "missing tile: " .. tostring(idx))
      if t.type == "land" then
        local st = tile_state(game, t)
        assert(st ~= nil, "missing tile state: " .. tostring(t.id))
        if st.owner_id then
          local owner = assert(game:find_player_by_id(st.owner_id), "missing owner: " .. tostring(st.owner_id))
          game:set_player_property(owner, t.id, false)
        end
        game:reset_tile(t)
        _emit_event(monopoly_event.chance.applied, {
          card = { effect = "reset_tiles_on_path" },
          effect = "reset_tiles_on_path",
          tile = t,
          text = "强制征地重置 " .. t.name,
        })
      end
    end
  end)

  registry:register("move_backward", function(game, player, card)
    local res = _move_steps(game, player, -(card.steps or 0), {
      skip_steal_check = true,
      skip_market_check = true,
    })
    if res and res.move_result then
      res.move_result.allow_optional = true
    end
    return res
  end)

  registry:register("move_forward", function(game, player, card)
    return _move_steps(game, player, card.steps or 0)
  end)

  registry:register("grant_item", function(game, player, card)
    inventory.give(player, card.item_id, { game = game })
  end)

  registry:register("discard_items", function(game, player, card)
    local to_drop = card.count
    if to_drop == 0 then
      to_drop = inventory.count(player)
    end
    local dropped_names = {}
    for _ = 1, to_drop do
      if inventory.count(player) == 0 then
        break
      end
      local item = inventory.remove_by_index(player, 1)
      table.insert(dropped_names, inventory.item_name(item.id))
    end
    if #dropped_names > 0 then
      _emit_event(monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 丢弃道具 " .. #dropped_names .. " 张: " .. table.concat(dropped_names, "、"),
      })
    else
      _emit_event(monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 丢弃道具 0 张",
      })
    end
  end)

  registry:register("discard_properties", function(game, player, card)
    local to_drop = card.count
    local property_ids = {}
    for tile_id in pairs(player.properties or {}) do
      property_ids[#property_ids + 1] = tile_id
    end
    table.sort(property_ids, function(a, b)
      local ai = number_utils.to_integer(a)
      local bi = number_utils.to_integer(b)
      if ai ~= nil and bi ~= nil then
        return ai < bi
      end
      return tostring(a) < tostring(b)
    end)
    for _, tile_id in ipairs(property_ids) do
      local tile = game.board:get_tile_by_id(tile_id)
      assert(tile ~= nil, "missing tile: " .. tostring(tile_id))
      game:reset_tile(tile)
      _emit_event(monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        tile = tile,
        text = player.name .. " 丢失地块 " .. tile.name,
      })
      game:set_player_property(player, tile_id, false)
      to_drop = to_drop - 1
      if to_drop == 0 then
        break
      end
    end
  end)

  registry:register("forced_move", function(game, player, card, context)
    local from_index = player.position
    if card.destination_tile_id then
      local idx = game.board:index_of_tile_id(card.destination_tile_id)
      assert(idx ~= nil, "missing destination tile index: " .. tostring(card.destination_tile_id))
      game:update_player_position(player, idx)
      game:set_player_status(player, "move_dir", nil)
      _queue_move_effect(game, player, from_index, idx, nil)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    end
    if card.destination == "hospital" then
      game:player_send_to_hospital(player)
      _queue_move_effect(game, player, from_index, player.position, nil)
    elseif card.destination == "mountain" then
      game:player_send_to_mountain(player)
      _queue_move_effect(game, player, from_index, player.position, nil)
    elseif card.destination == "tax" then
      local idx = game.board:find_first_by_type("tax")
      assert(idx ~= nil, "missing tax tile")
      game:update_player_position(player, idx)
      game:set_player_status(player, "move_dir", nil)
      _queue_move_effect(game, player, from_index, idx, nil)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    elseif card.destination == "market" then
      local idx = game.board:find_first_by_type("market")
      assert(idx ~= nil, "missing market tile")
      game:update_player_position(player, idx)
      game:set_player_status(player, "move_dir", nil)
      _queue_move_effect(game, player, from_index, idx, nil)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    end
  end)
end

function chance_registry:init()
  self.handlers = {}
end

function chance_registry:register(effect, handler)
  self.handlers[effect] = handler
end

function chance_registry:register_defaults()
  _register_defaults(self)
end

return chance_registry
