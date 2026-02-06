local items_cfg = require("Config.Generated.Items")

local common = require("src.v2.domain.services.Common")
local land_service = require("src.v2.domain.services.LandService")
local item_service = require("src.v2.domain.services.ItemService")
local chance_service = require("src.v2.domain.services.ChanceService")
local market_service = require("src.v2.domain.services.MarketService")
local bankruptcy_service = require("src.v2.domain.services.BankruptcyService")
local movement_service = require("src.v2.domain.services.MovementService")

local landing_service = {}

local _weighted_items = {}
local _item_weight_total = 0
for _, cfg in ipairs(items_cfg or {}) do
  _weighted_items[#_weighted_items + 1] = cfg
  local weight = cfg.weight or 0
  if weight < 0 then
    weight = 0
  end
  _item_weight_total = _item_weight_total + weight
end

local function _random_pick_item(state)
  if #_weighted_items == 0 then
    return nil
  end
  if _item_weight_total <= 0 then
    return _weighted_items[1]
  end
  local seed = state.rng_seed or 1
  seed = (1103515245 * seed + 12345) % 2147483647
  if seed <= 0 then
    seed = 1
  end
  state.rng_seed = seed
  local picked = (seed % _item_weight_total) + 1
  local acc = 0
  for _, cfg in ipairs(_weighted_items) do
    local weight = cfg.weight or 0
    if weight < 0 then
      weight = 0
    end
    acc = acc + weight
    if picked <= acc then
      return cfg
    end
  end
  return _weighted_items[1]
end

local function _is_indestructible_vehicle(player)
  return player.seat_vehicle_id ~= nil and player.seat_vehicle_id >= 4010
end

local function _first_tile_index_by_type(state, tile_type)
  for index, tile_id in ipairs(state.board.path) do
    local tile = state.board.tile_defs[tile_id]
    if tile and tile.type == tile_type then
      return index
    end
  end
  return nil
end

local function _send_to_hospital(state, seat)
  local player = state.players[seat]
  if not player then
    return
  end
  local hospital_index = _first_tile_index_by_type(state, "hospital") or player.position
  player.position = hospital_index
  player.move_dir = nil
  player.status.stay_turns = state.rules.hospital_stay_turns or 2
  local fee = state.rules.hospital_fee or 0
  player.cash = player.cash - fee
  if player.cash <= 0 then
    bankruptcy_service.eliminate(state, seat)
  end
end

local function _send_to_mountain(state, seat)
  local player = state.players[seat]
  if not player then
    return
  end
  local mountain_index = _first_tile_index_by_type(state, "mountain") or player.position
  player.position = mountain_index
  player.move_dir = nil
  player.status.stay_turns = state.rules.mountain_stay_turns or 2
end

local function _open_choice(kind, title, body_lines, options, meta)
  return {
    kind = kind,
    title = title or "请选择",
    body_lines = body_lines or {},
    options = options or {},
    allow_cancel = true,
    cancel_label = "取消",
    meta = meta or {},
  }
end

local function _build_steal_prompt(state, seat, move_result)
  local player = state.players[seat]
  if not player or not common.has_item(player, common.item_ids.steal) then
    return nil
  end
  local queue = {}
  for _, other_seat in ipairs(move_result.encountered_players or {}) do
    local target = state.players[other_seat]
    if target and not target.eliminated and not common.has_deity(target, "angel") then
      queue[#queue + 1] = other_seat
    end
  end
  if #queue == 0 then
    return nil
  end
  local first_target = state.players[queue[1]]
  return _open_choice(
    "steal_prompt",
    "是否使用偷窃卡",
    { "目标：" .. tostring(first_target.name) },
    {
      { id = "use", label = "使用" },
      { id = "skip", label = "跳过" },
    },
    {
      owner_seat = seat,
      queue = queue,
      index = 1,
      remaining_steps = move_result.steal_interrupt and move_result.steal_interrupt.remaining_steps or 0,
      facing = move_result.steal_interrupt and move_result.steal_interrupt.facing or move_result.facing,
      branch_parity = move_result.steal_interrupt and move_result.steal_interrupt.branch_parity or move_result.branch_parity,
    }
  )
end

local function _apply_rent(state, seat, tile_id)
  local player = state.players[seat]
  local rent, owner_seat = land_service.rent_amount(state, tile_id, seat)
  if rent <= 0 or not owner_seat then
    return { ok = true, rent = 0, owner_seat = owner_seat }
  end
  local owner = state.players[owner_seat]

  if player.status.pending_free_rent then
    return {
      waiting = true,
      choice = _open_choice(
        "rent_card_prompt",
        "是否使用免费卡",
        { "免除本次租金" },
        {
          { id = "use", label = "使用" },
          { id = "skip", label = "放弃" },
        },
        { owner_seat = seat, tile_id = tile_id, card_kind = "free" }
      ),
    }
  end

  if common.has_item(player, common.item_ids.strong) then
    local tile = state.board.tile_defs[tile_id]
    local tile_state = state.board.tile_states[tile_id]
    local total_value = (tile and tile.price or 0)
    local costs = tile and tile.upgrade_costs or {}
    for index = 1, (tile_state and tile_state.level or 0) do
      total_value = total_value + (costs[index] or 0)
    end
    if player.cash >= total_value then
      return {
        waiting = true,
        choice = _open_choice(
          "rent_card_prompt",
          "是否使用强征卡",
          { "支付 " .. tostring(total_value) .. " 强制购入当前地块" },
          {
            { id = "use", label = "使用" },
            { id = "skip", label = "放弃" },
          },
          { owner_seat = seat, tile_id = tile_id, card_kind = "strong", total_value = total_value, owner_target_seat = owner_seat }
        ),
      }
    end
  end

  if player.cash >= rent then
    player.cash = player.cash - rent
    owner.cash = owner.cash + rent
  else
    local paid = math.max(player.cash, 0)
    player.cash = 0
    owner.cash = owner.cash + paid
    bankruptcy_service.eliminate(state, seat)
  end
  return { ok = true, rent = rent, owner_seat = owner_seat }
end

local function _apply_tax(state, seat)
  local player = state.players[seat]
  if player.status.pending_tax_free then
    return {
      waiting = true,
      choice = _open_choice(
        "tax_card_prompt",
        "是否使用免税卡",
        { "使用免税卡可免除本次税金" },
        {
          { id = "use", label = "使用" },
          { id = "skip", label = "放弃" },
        },
        { owner_seat = seat }
      ),
    }
  end

  local fee = land_service.tax_amount(state, seat)
  player.cash = player.cash - fee
  if player.cash <= 0 then
    bankruptcy_service.eliminate(state, seat)
  end
  return { ok = true, fee = fee }
end

local function _apply_chance_outcomes(state, seat, move_result, outcomes)
  local need_landing = nil
  for _, outcome in ipairs(outcomes or {}) do
    if outcome.kind == "cash" then
      local target = state.players[outcome.seat]
      if target and not target.eliminated then
        target.cash = target.cash + (outcome.delta or 0)
        if target.cash <= 0 then
          bankruptcy_service.eliminate(state, outcome.seat)
        end
      end
    elseif outcome.kind == "status" then
      local target = state.players[outcome.seat]
      if target and outcome.key == "seat_vehicle_id" then
        target.seat_vehicle_id = outcome.value
      end
    elseif outcome.kind == "give_item" then
      local target = state.players[outcome.seat]
      if target and not target.eliminated then
        common.give_item(target, outcome.item_id)
      end
    elseif outcome.kind == "discard_item" then
      local target = state.players[outcome.seat]
      if target then
        local count = outcome.count or 0
        if count == 0 then
          target.inventory.items = {}
        else
          for _ = 1, count do
            if #target.inventory.items <= 0 then
              break
            end
            table.remove(target.inventory.items, 1)
          end
        end
      end
    elseif outcome.kind == "discard_property" then
      local target = state.players[outcome.seat]
      if target then
        local count = outcome.count or 1
        local keys = {}
        for tile_id in pairs(target.properties or {}) do
          keys[#keys + 1] = tile_id
        end
        table.sort(keys)
        for _, tile_id in ipairs(keys) do
          if count <= 0 then
            break
          end
          target.properties[tile_id] = nil
          local tile_state = state.board.tile_states[tile_id]
          if tile_state then
            tile_state.owner_id = nil
            tile_state.level = 0
          end
          count = count - 1
        end
      end
    elseif outcome.kind == "move_steps" then
      local move = movement_service.move(state, outcome.seat, outcome.steps or 0, {
        skip_market_check = true,
        skip_steal_check = true,
      })
      local target = state.players[outcome.seat]
      if move and target then
        target.position = move.to_index
        target.move_dir = move.facing
        if move.passed_start and move.passed_start > 0 then
          target.cash = target.cash + (state.rules.pass_start_bonus or 0) * move.passed_start
        end
        need_landing = {
          seat = outcome.seat,
          move_result = move,
        }
      end
    elseif outcome.kind == "forced_move" then
      local target = state.players[outcome.seat]
      if target then
        local destination_index = state.board.index_by_tile_id[outcome.tile_id]
        if destination_index then
          target.position = destination_index
          target.move_dir = nil
          need_landing = {
            seat = outcome.seat,
            move_result = move_result,
          }
        end
      end
    elseif outcome.kind == "destroy_buildings_on_path" then
      for _, idx in ipairs(move_result and move_result.visited or {}) do
        local tile_id = state.board.path[idx]
        local tile = state.board.tile_defs[tile_id]
        local tile_state = state.board.tile_states[tile_id]
        if tile and tile.type == "land" and tile_state and (tile_state.level or 0) > 0 then
          tile_state.level = 0
        end
      end
    elseif outcome.kind == "reset_tiles_on_path" then
      for _, idx in ipairs(move_result and move_result.visited or {}) do
        local tile_id = state.board.path[idx]
        local tile = state.board.tile_defs[tile_id]
        local tile_state = state.board.tile_states[tile_id]
        if tile and tile.type == "land" and tile_state then
          local owner = tile_state.owner_id
          if owner and state.players[owner] then
            state.players[owner].properties[tile_id] = nil
          end
          tile_state.owner_id = nil
          tile_state.level = 0
        end
      end
    end
  end
  return need_landing
end

function landing_service.resolve(state, seat, move_result, depth)
  local player = state.players[seat]
  if not player then
    return { action_kind = "noop" }
  end
  depth = depth or 0
  if depth > 10 then
    return { action_kind = "landing_depth_limit" }
  end

  local steal_choice = _build_steal_prompt(state, seat, move_result or {})
  if steal_choice then
    return { waiting = true, choice = steal_choice }
  end

  local tile_id = state.board.path[player.position]
  local tile = state.board.tile_defs[tile_id]
  if not tile then
    return { action_kind = "noop" }
  end

  if tile.type == "start" and (move_result and move_result.passed_start or 0) == 0 then
    player.cash = player.cash + (state.rules.pass_start_bonus or 0)
  end

  if tile.type == "item" then
    local picked = _random_pick_item(state)
    if picked then
      common.give_item(player, picked.id)
    end
  end

  if tile.type == "chance" then
    local card = chance_service.pick_card(state)
    local outcomes = chance_service.resolve(state, seat, card)
    local next_landing = _apply_chance_outcomes(state, seat, move_result, outcomes)
    if next_landing then
      return landing_service.resolve(state, next_landing.seat, next_landing.move_result, depth + 1)
    end
  end

  if tile.type == "hospital" then
    _send_to_hospital(state, seat)
  elseif tile.type == "mountain" then
    _send_to_mountain(state, seat)
  elseif tile.type == "market" then
    local market_choice = market_service.build_choice(state, seat)
    if market_choice then
      return { waiting = true, choice = market_choice }
    end
  elseif tile.type == "tax" then
    local tax_res = _apply_tax(state, seat)
    if tax_res and tax_res.waiting then
      return { waiting = true, choice = tax_res.choice }
    end
  elseif tile.type == "land" then
    local tile_state = state.board.tile_states[tile_id]
    local owner_seat = tile_state and tile_state.owner_id or nil
    if owner_seat == nil then
      if land_service.can_buy(state, seat, tile_id) then
        return {
          waiting = true,
          choice = _open_choice(
            "landing_optional_effect",
            "是否购买地块",
            { "你可以购买当前地块，或选择跳过" },
            {
              { id = "buy_land", label = "购买" },
              { id = "skip", label = "跳过" },
            },
            { owner_seat = seat, tile_id = tile_id }
          ),
        }
      end
    elseif owner_seat == seat then
      if land_service.can_upgrade(state, seat, tile_id) then
        return {
          waiting = true,
          choice = _open_choice(
            "landing_optional_effect",
            "是否升级地块",
            { "你可以升级当前地块，或选择跳过" },
            {
              { id = "upgrade_land", label = "升级" },
              { id = "skip", label = "跳过" },
            },
            { owner_seat = seat, tile_id = tile_id }
          ),
        }
      end
    else
      local rent_res = _apply_rent(state, seat, tile_id)
      if rent_res and rent_res.waiting then
        return { waiting = true, choice = rent_res.choice }
      end
    end
  end

  if state.board.overlays.mines[player.position] then
    state.board.overlays.mines[player.position] = nil
    if not common.has_deity(player, "angel") and (not _is_indestructible_vehicle(player)) then
      player.seat_vehicle_id = nil
      _send_to_hospital(state, seat)
      return landing_service.resolve(state, seat, move_result, depth + 1)
    end
  end

  return {
    action_kind = "landing_done",
    tile_id = tile_id,
  }
end

return landing_service
