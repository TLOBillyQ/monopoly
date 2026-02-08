local inventory = require("src.game.item.ItemInventory")
local tile = require("src.game.board.Tile")
local monopoly_event = require("src.game.game.MonopolyEvents")
local movement_manager = require("src.game.movement.MovementManager")
local bankruptcy_manager = require("src.game.game.BankruptcyManager")

local chance_registry = {}
local handlers = {}
local defaults_registered = false

chance_registry.handlers = handlers

local tile_state = tile.get_state

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

local function _handle_bankruptcy_if_negative(game, player)
  if game:player_balance(player, "金币") > 0 then
    return
  end
  bankruptcy_manager.eliminate(game, player)
end

local function _apply_cash_and_maybe_bankrupt(game, player, delta)
  _apply_cash_change(game, player, delta)
  _handle_bankruptcy_if_negative(game, player)
end

local function _move_steps(game, player, steps, opts)
  local res = movement_manager.move(game, player, steps, opts)
  assert(res ~= nil, "missing move result")
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

local function _register_defaults()
  chance_registry.register("add_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local delta = _adjust_chance_delta(game, p, card.amount)
          _apply_cash_change(game, p, delta)
          _emit_event(monopoly_event.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 获得 " .. delta .. " 金币",
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
        text = player.name .. " 获得 " .. delta .. " 金币",
      })
    end
  end)

  chance_registry.register("pay_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local delta = _adjust_chance_delta(game, p, -card.amount)
          _apply_cash_and_maybe_bankrupt(game, p, delta)
          _emit_event(monopoly_event.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 支付 " .. _abs_value(delta) .. " 金币",
          })
        end
      end
    else
      local delta = _adjust_chance_delta(game, player, -card.amount)
      _apply_cash_and_maybe_bankrupt(game, player, delta)
      _emit_event(monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 支付 " .. _abs_value(delta) .. " 金币",
      })
    end
  end)

  chance_registry.register("percent_pay_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local fee = math.floor(game:player_balance(p, "金币") * (card.percent / 100))
          local delta = _adjust_chance_delta(game, p, -fee)
          _apply_cash_and_maybe_bankrupt(game, p, delta)
          _emit_event(monopoly_event.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 按比例支付 " .. _abs_value(delta) .. " 金币",
          })
        end
      end
    else
      local fee = math.floor(game:player_balance(player, "金币") * (card.percent / 100))
      local delta = _adjust_chance_delta(game, player, -fee)
      _apply_cash_and_maybe_bankrupt(game, player, delta)
      _emit_event(monopoly_event.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 按比例支付 " .. _abs_value(delta) .. " 金币",
      })
    end
  end)

  chance_registry.register("pay_others", function(game, player, card)
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = card.amount
        if game:player_has_deity(player, "poor") then
          fee = fee * 2
        end
        if not game:player_is_in_mountain(other) then
          _apply_cash_and_maybe_bankrupt(game, player, -fee)
          _apply_cash_change(game, other, fee)
        end
      end
    end
    _emit_event(monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 向每位玩家支付 " .. card.amount,
    })
  end)

  chance_registry.register("collect_from_others", function(game, player, card)
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
      text = player.name .. " 收取每位玩家 " .. card.amount,
    })
  end)

  chance_registry.register("set_vehicle", function(game, player, card)
    game:set_player_seat(player, card.vehicle_id)
    _emit_event(monopoly_event.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 获得座驾 " .. tostring(card.vehicle_id),
    })
  end)

  chance_registry.register("destroy_buildings_on_path", function(game, _, _, context)
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

  chance_registry.register("reset_tiles_on_path", function(game, _, _, context)
    assert(context ~= nil and context.visited ~= nil, "missing context.visited")
    for _, idx in ipairs(context.visited) do
      local t = game.board:get_tile(idx)
      assert(t ~= nil, "missing tile: " .. tostring(idx))
      if t.type == "land" then
        local st = tile_state(game, t)
        assert(st ~= nil, "missing tile state: " .. tostring(t.id))
        if st.owner_id then
          local owner = assert(game.players[st.owner_id], "missing owner: " .. tostring(st.owner_id))
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

  chance_registry.register("move_backward", function(game, player, card)
    return _move_steps(game, player, -(card.steps or 0), {
      skip_steal_check = true,
      skip_market_check = true,
    })
  end)

  chance_registry.register("move_forward", function(game, player, card)
    return _move_steps(game, player, card.steps or 0)
  end)

  chance_registry.register("grant_item", function(game, player, card)
    inventory.give(player, card.item_id, { game = game })
  end)

  chance_registry.register("discard_items", function(game, player, card)
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

  chance_registry.register("discard_properties", function(game, player, card)
    local to_drop = card.count
    for tile_id in pairs(player.properties) do
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

  chance_registry.register("forced_move", function(game, player, card, context)
    if card.destination_tile_id then
      local idx = game.board:index_of_tile_id(card.destination_tile_id)
      assert(idx ~= nil, "missing destination tile index: " .. tostring(card.destination_tile_id))
      game:update_player_position(player, idx)
      game:set_player_status(player, "move_dir", nil)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    end
    if card.destination == "hospital" then
      game:player_send_to_hospital(player)
    elseif card.destination == "mountain" then
      game:player_send_to_mountain(player)
    elseif card.destination == "tax" then
      local idx = game.board:find_first_by_type("tax")
      assert(idx ~= nil, "missing tax tile")
      game:update_player_position(player, idx)
      game:set_player_status(player, "move_dir", nil)
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
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    end
  end)
end

function chance_registry.register(effect, handler)
  handlers[effect] = handler
end

function chance_registry.register_defaults()
  if defaults_registered then
    return
  end
  defaults_registered = true
  _register_defaults()
end

return chance_registry
