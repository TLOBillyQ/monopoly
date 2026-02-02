local Inventory = require("Manager.ItemManager.ItemInventory")
local Tile = require("Components.Tile")
local MonopolyEvent = require("Globals.MonopolyEvents")
local ServiceKey = require("Globals.ServiceKeys")

local ChanceRegistry = {}
local handlers = {}
local defaults_registered = false

ChanceRegistry.handlers = handlers

local tile_state = Tile.GetState

local function _EmitEvent(kind, payload)
  assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
  TriggerCustomEvent(kind, payload or {})
end

local function _AbsValue(value)
  if value < 0 then
    return -value
  end
  return value
end

local function _ApplyCashChange(player, delta)
  player:AddCash(delta)
end

local function _AdjustChanceDelta(player, delta)
  if delta > 0 and player:HasDeity("rich") then
    return delta * 2
  end
  if delta < 0 and player:HasDeity("poor") then
    return delta * 2
  end
  return delta
end

local function _HandleBankruptcyIfNegative(game, player)
  if player.cash > 0 then
    return
  end
  local bankruptcy = game:GetService(ServiceKey.bankruptcy)
  bankruptcy.Eliminate(game, player)
end

local function _ApplyCashAndMaybeBankrupt(game, player, delta)
  _ApplyCashChange(player, delta)
  _HandleBankruptcyIfNegative(game, player)
end

local function _MoveSteps(game, player, steps, opts)
  local movement = game:GetService(ServiceKey.movement)
  assert(movement ~= nil, "missing movement service")
  local res = movement.Move(game, player, steps, opts)
  assert(res ~= nil, "missing move result")
  if res.stopped_on_roadblock then
    local stay = player.status.stay_turns or 0
    if stay < 1 then
      game:SetPlayerStatus(player, "stay_turns", 1)
    end
  end
  return {
    kind = "need_landing",
    player_id = player.id,
    board_index = player.position,
    move_result = res,
  }
end

local function _RegisterDefaults()
  ChanceRegistry.Register("add_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local delta = _AdjustChanceDelta(p, card.amount)
          _ApplyCashChange(p, delta)
          _EmitEvent(MonopolyEvent.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 获得 " .. delta .. " 金币",
          })
        end
      end
    else
      local delta = _AdjustChanceDelta(player, card.amount)
      _ApplyCashChange(player, delta)
      _EmitEvent(MonopolyEvent.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 获得 " .. delta .. " 金币",
      })
    end
  end)

  ChanceRegistry.Register("pay_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local delta = _AdjustChanceDelta(p, -card.amount)
          _ApplyCashAndMaybeBankrupt(game, p, delta)
          _EmitEvent(MonopolyEvent.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 支付 " .. _AbsValue(delta) .. " 金币",
          })
        end
      end
    else
      local delta = _AdjustChanceDelta(player, -card.amount)
      _ApplyCashAndMaybeBankrupt(game, player, delta)
      _EmitEvent(MonopolyEvent.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 支付 " .. _AbsValue(delta) .. " 金币",
      })
    end
  end)

  ChanceRegistry.Register("percent_pay_cash", function(game, player, card)
    if card.target == "all" then
      for _, p in ipairs(game.players) do
        if not p.eliminated then
          local fee = math.floor(p.cash * (card.percent / 100))
          local delta = _AdjustChanceDelta(p, -fee)
          _ApplyCashAndMaybeBankrupt(game, p, delta)
          _EmitEvent(MonopolyEvent.chance.applied, {
            player = p,
            card = card,
            effect = card.effect,
            text = p.name .. " 按比例支付 " .. _AbsValue(delta) .. " 金币",
          })
        end
      end
    else
      local fee = math.floor(player.cash * (card.percent / 100))
      local delta = _AdjustChanceDelta(player, -fee)
      _ApplyCashAndMaybeBankrupt(game, player, delta)
      _EmitEvent(MonopolyEvent.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 按比例支付 " .. _AbsValue(delta) .. " 金币",
      })
    end
  end)

  ChanceRegistry.Register("pay_others", function(game, player, card)
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = card.amount
        if player:HasDeity("poor") then
          fee = fee * 2
        end
        if not other:IsInMountain(game) then
          _ApplyCashAndMaybeBankrupt(game, player, -fee)
          _ApplyCashChange(other, fee)
        end
      end
    end
    _EmitEvent(MonopolyEvent.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 向每位玩家支付 " .. card.amount,
    })
  end)

  ChanceRegistry.Register("collect_from_others", function(game, player, card)
    for _, other in ipairs(game.players) do
      if other.id ~= player.id and not other.eliminated then
        local fee = card.amount
        if player:HasDeity("rich") then
          fee = fee * 2
        end
        if not player:IsInMountain(game) then
          if other.cash < fee then
            fee = other.cash
          end
          _ApplyCashChange(other, -fee)
          _ApplyCashChange(player, fee)
        end
      end
    end
    _EmitEvent(MonopolyEvent.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 收取每位玩家 " .. card.amount,
    })
  end)

  ChanceRegistry.Register("set_vehicle", function(game, player, card)
    game:SetPlayerSeat(player, card.vehicle_id)
    _EmitEvent(MonopolyEvent.chance.applied, {
      player = player,
      card = card,
      effect = card.effect,
      text = player.name .. " 获得座驾 " .. tostring(card.vehicle_id),
    })
  end)

  ChanceRegistry.Register("destroy_buildings_on_path", function(game, _, _, context)
    assert(context ~= nil and context.visited ~= nil, "missing context.visited")
    for _, idx in ipairs(context.visited) do
      local t = game.board:GetTile(idx)
      assert(t ~= nil, "missing tile: " .. tostring(idx))
      local snap = game.store:Get({ "board", "tiles", t.id })
      local lvl = 0
      if type(snap) == "table" then
        lvl = snap.level
      end
      if t.type == "land" and lvl > 0 then
        game:SetTileLevel(t, 0)
        _EmitEvent(MonopolyEvent.chance.applied, {
          card = { effect = "destroy_buildings_on_path" },
          effect = "destroy_buildings_on_path",
          tile = t,
          text = "台风摧毁 " .. t.name .. " 上的建筑",
        })
      end
    end
  end)

  ChanceRegistry.Register("reset_tiles_on_path", function(game, _, _, context)
    assert(context ~= nil and context.visited ~= nil, "missing context.visited")
    for _, idx in ipairs(context.visited) do
      local t = game.board:GetTile(idx)
      assert(t ~= nil, "missing tile: " .. tostring(idx))
      if t.type == "land" then
        local st = tile_state(game, t)
        assert(st ~= nil, "missing tile state: " .. tostring(t.id))
        if st.owner_id then
          local owner = assert(game.players[st.owner_id], "missing owner: " .. tostring(st.owner_id))
          game:SetPlayerProperty(owner, t.id, false)
        end
        game:ResetTile(t)
        _EmitEvent(MonopolyEvent.chance.applied, {
          card = { effect = "reset_tiles_on_path" },
          effect = "reset_tiles_on_path",
          tile = t,
          text = "强制征地重置 " .. t.name,
        })
      end
    end
  end)

  ChanceRegistry.Register("move_backward", function(game, player, card)
    return _MoveSteps(game, player, -(card.steps or 0), {
      skip_steal_check = true,
      skip_market_check = true,
    })
  end)

  ChanceRegistry.Register("move_forward", function(game, player, card)
    return _MoveSteps(game, player, card.steps or 0)
  end)

  ChanceRegistry.Register("grant_item", function(game, player, card)
    Inventory.Give(player, card.item_id, { game = game })
  end)

  ChanceRegistry.Register("discard_items", function(game, player, card)
    local to_drop = card.count
    if to_drop == 0 then
      to_drop = Inventory.Count(player)
    end
    local dropped_names = {}
    for _ = 1, to_drop do
      if Inventory.Count(player) == 0 then
        break
      end
      local item = Inventory.RemoveByIndex(player, 1)
      table.insert(dropped_names, Inventory.ItemName(item.id))
    end
    if #dropped_names > 0 then
      _EmitEvent(MonopolyEvent.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 丢弃道具 " .. #dropped_names .. " 张: " .. table.concat(dropped_names, "、"),
      })
    else
      _EmitEvent(MonopolyEvent.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        text = player.name .. " 丢弃道具 0 张",
      })
    end
  end)

  ChanceRegistry.Register("discard_properties", function(game, player, card)
    local to_drop = card.count
    for tile_id in pairs(player.properties) do
      local tile = game.board:GetTileById(tile_id)
      assert(tile ~= nil, "missing tile: " .. tostring(tile_id))
      game:ResetTile(tile)
      _EmitEvent(MonopolyEvent.chance.applied, {
        player = player,
        card = card,
        effect = card.effect,
        tile = tile,
        text = player.name .. " 丢失地块 " .. tile.name,
      })
      game:SetPlayerProperty(player, tile_id, false)
      to_drop = to_drop - 1
      if to_drop == 0 then
        break
      end
    end
  end)

  ChanceRegistry.Register("forced_move", function(game, player, card, context)
    if card.destination_tile_id then
      local idx = game.board:IndexOfTileId(card.destination_tile_id)
      assert(idx ~= nil, "missing destination tile index: " .. tostring(card.destination_tile_id))
      game:UpdatePlayerPosition(player, idx)
      game:SetPlayerStatus(player, "move_dir", nil)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    end
    if card.destination == "hospital" then
      player:SendToHospital(game)
    elseif card.destination == "mountain" then
      player:SendToMountain(game)
    elseif card.destination == "tax" then
      local idx = game.board:FindFirstByType("tax")
      assert(idx ~= nil, "missing tax tile")
      game:UpdatePlayerPosition(player, idx)
      game:SetPlayerStatus(player, "move_dir", nil)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    elseif card.destination == "market" then
      local idx = game.board:FindFirstByType("market")
      assert(idx ~= nil, "missing market tile")
      game:UpdatePlayerPosition(player, idx)
      game:SetPlayerStatus(player, "move_dir", nil)
      return {
        kind = "need_landing",
        player_id = player.id,
        board_index = idx,
        move_result = context,
      }
    end
  end)
end

function ChanceRegistry.Register(effect, handler)
  handlers[effect] = handler
end

function ChanceRegistry.RegisterDefaults()
  if defaults_registered then
    return
  end
  defaults_registered = true
  _RegisterDefaults()
end

return ChanceRegistry
