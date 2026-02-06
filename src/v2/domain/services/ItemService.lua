local items_cfg = require("Config.Generated.Items")
local gameplay_rules = require("Config.GameplayRules")
local constants = require("Config.Generated.Constants")

local common = require("src.v2.domain.services.Common")
local movement_service = require("src.v2.domain.services.MovementService")

local item_service = {}

local item_ids = gameplay_rules.item_ids or {}

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

local phase_titles = {
  pre_action = "行动前：使用道具？",
  pre_move = "投骰后：使用道具？",
  post_action = "行动后：使用道具？",
}

local phase_timing = {
  pre_action = { pre_action = true, turn = true },
  pre_move = { pre_move = true, turn = true },
  post_action = { post_action = true, manual = true, turn = true },
}

local function _timing_allowed(phase, timing)
  local allowed = phase_timing[phase]
  if not allowed or not timing then
    return false
  end
  return allowed[timing] == true
end

local function _discard_first(player)
  if common.count_item(player) <= 0 then
    return nil
  end
  return table.remove(player.inventory.items, 1)
end

function item_service.item_cfg(item_id)
  return cfg_by_id[item_id]
end

function item_service.item_name(item_id)
  local cfg = cfg_by_id[item_id]
  return cfg and cfg.name or tostring(item_id)
end

function item_service.build_item_phase_choice(state, seat, phase)
  local player = state.players[seat]
  if not player then
    return nil
  end
  local options = {}
  local lines = {}
  for _, item in ipairs(player.inventory.items or {}) do
    local cfg = cfg_by_id[item.id]
    if cfg and _timing_allowed(phase, cfg.timing) then
      options[#options + 1] = { id = item.id, label = cfg.name }
      local line = cfg.name
      if cfg.usage and #cfg.usage > 0 then
        line = line .. "：" .. cfg.usage
      end
      lines[#lines + 1] = line
    end
  end
  if #player.inventory.items > 0 then
    options[#options + 1] = { id = "discard_item", label = "丢弃道具" }
    lines[#lines + 1] = "丢弃道具：从背包丢弃一张"
  end
  if #options == 0 then
    return nil
  end
  return {
    kind = "item_phase_choice",
    title = phase_titles[phase] or "道具阶段",
    body_lines = lines,
    options = options,
    allow_cancel = true,
    cancel_label = "结束阶段",
    meta = {
      owner_seat = seat,
      phase = phase,
    },
  }
end

function item_service.pick_target_player(state, seat)
  local options = {}
  local actor = state.players[seat]
  if not actor then
    return options
  end
  for target_seat, target in ipairs(state.players) do
    if target_seat ~= seat and not target.eliminated then
      options[#options + 1] = {
        id = target_seat,
        label = target.name,
      }
    end
  end
  return options
end

function item_service.pick_roadblock_targets(state, seat, distance)
  local player = state.players[seat]
  if not player then
    return {}
  end
  local indices = movement_service.indices_in_range(state, player.position, distance or 3)
  local options = {}
  for _, index in ipairs(indices) do
    if index ~= player.position and not state.board.overlays.roadblocks[index] and not state.board.overlays.mines[index] then
      local tile_id = state.board.path[index]
      local tile = state.board.tile_defs[tile_id]
      if tile then
        options[#options + 1] = {
          id = index,
          label = "位置" .. tostring(index) .. "：" .. tostring(tile.name),
        }
      end
    end
  end
  return options
end

function item_service.pick_demolish_targets(state, seat, distance)
  local player = state.players[seat]
  if not player then
    return {}
  end
  local indices = movement_service.indices_in_range(state, player.position, distance or 3)
  local options = {}
  for _, index in ipairs(indices) do
    local tile_id = state.board.path[index]
    local tile = state.board.tile_defs[tile_id]
    local tile_state = state.board.tile_states[tile_id]
    if tile and tile.type == "land" and tile_state and tile_state.owner_id and tile_state.owner_id ~= seat and (tile_state.level or 0) > 0 then
      options[#options + 1] = {
        id = index,
        label = "位置" .. tostring(index) .. "：" .. tostring(tile.name),
      }
    end
  end
  return options
end

function item_service.apply_manual_item(state, seat, item_id)
  local player = state.players[seat]
  if not player then
    return { ok = false, reason = "missing_player" }
  end
  if not common.has_item(player, item_id) then
    return { ok = false, reason = "missing_item" }
  end

  if item_id == item_ids.remote_dice then
    local options = {}
    for value = 1, 6 do
      options[#options + 1] = { id = value, label = tostring(value) }
    end
    return {
      ok = false,
      waiting = true,
      choice = {
        kind = "remote_dice_value",
        title = "遥控骰子：选择点数",
        body_lines = { "选择 1~6 的点数" },
        options = options,
        allow_cancel = true,
        cancel_label = "放弃",
        meta = { owner_seat = seat, item_id = item_id },
      },
    }
  end

  if item_id == item_ids.roadblock then
    local options = item_service.pick_roadblock_targets(state, seat, 3)
    if #options == 0 then
      return { ok = false, reason = "no_target" }
    end
    return {
      ok = false,
      waiting = true,
      choice = {
        kind = "roadblock_target",
        title = "路障卡：选择位置",
        body_lines = { "选择前后 3 格放置路障" },
        options = options,
        allow_cancel = true,
        cancel_label = "放弃",
        meta = { owner_seat = seat, item_id = item_id },
      },
    }
  end

  if item_id == item_ids.monster or item_id == item_ids.missile then
    local options = item_service.pick_demolish_targets(state, seat, 3)
    if #options == 0 then
      return { ok = false, reason = "no_target" }
    end
    local title = item_id == item_ids.monster and "怪兽卡：选择目标格子" or "导弹卡：选择目标格子"
    return {
      ok = false,
      waiting = true,
      choice = {
        kind = "demolish_target",
        title = title,
        body_lines = { "选择前后 3 格的目标地块" },
        options = options,
        allow_cancel = true,
        cancel_label = "放弃",
        meta = { owner_seat = seat, item_id = item_id },
      },
    }
  end

  if item_id == item_ids.share_wealth
      or item_id == item_ids.exile
      or item_id == item_ids.tax
      or item_id == item_ids.invite_deity
      or item_id == item_ids.send_poor
      or item_id == item_ids.poor then
    local options = item_service.pick_target_player(state, seat)
    if #options == 0 then
      return { ok = false, reason = "no_target" }
    end
    return {
      ok = false,
      waiting = true,
      choice = {
        kind = "item_target_player",
        title = item_service.item_name(item_id) .. "：选择目标玩家",
        body_lines = { "请选择目标玩家" },
        options = options,
        allow_cancel = true,
        cancel_label = "取消",
        meta = { owner_seat = seat, item_id = item_id },
      },
    }
  end

  if item_id == item_ids.dice_multiplier then
    common.consume_item(player, item_id)
    player.status.pending_dice_multiplier = 2
    return { ok = true, effect = "dice_multiplier" }
  end

  if item_id == item_ids.free_rent then
    common.consume_item(player, item_id)
    player.status.pending_free_rent = true
    return { ok = true, effect = "free_rent" }
  end

  if item_id == item_ids.tax_free then
    common.consume_item(player, item_id)
    player.status.pending_tax_free = true
    return { ok = true, effect = "tax_free" }
  end

  if item_id == item_ids.mine then
    common.consume_item(player, item_id)
    state.board.overlays.mines[player.position] = true
    return { ok = true, effect = "mine_here", index = player.position }
  end

  if item_id == item_ids.clear_obstacles then
    common.consume_item(player, item_id)
    local indices = movement_service.indices_in_range(state, player.position, 12)
    local cleared = {}
    for _, index in ipairs(indices) do
      if state.board.overlays.roadblocks[index] or state.board.overlays.mines[index] then
        state.board.overlays.roadblocks[index] = nil
        state.board.overlays.mines[index] = nil
        cleared[#cleared + 1] = index
      end
    end
    return { ok = true, effect = "clear_obstacles", cleared = cleared }
  end

  if item_id == item_ids.rich then
    common.consume_item(player, item_id)
    player.status.deity = {
      type = "rich",
      remaining = constants.deity_duration_turns or 5,
    }
    return { ok = true, effect = "deity_rich" }
  end

  if item_id == item_ids.angel then
    common.consume_item(player, item_id)
    player.status.deity = {
      type = "angel",
      remaining = constants.deity_duration_turns or 5,
    }
    return { ok = true, effect = "deity_angel" }
  end

  return { ok = false, reason = "unsupported_item" }
end

function item_service.resolve_item_target(state, owner_seat, item_id, target_seat)
  local owner = state.players[owner_seat]
  local target = state.players[target_seat]
  if not owner or not target then
    return { ok = false, reason = "missing_player" }
  end
  if not common.has_item(owner, item_id) then
    return { ok = false, reason = "missing_item" }
  end

  if item_id == item_ids.share_wealth then
    local total = (owner.cash or 0) + (target.cash or 0)
    local half = math.floor(total / 2)
    owner.cash = half
    target.cash = total - half
    common.consume_item(owner, item_id)
    return { ok = true, effect = "share_wealth" }
  end

  if item_id == item_ids.exile then
    common.consume_item(owner, item_id)
    local mountain_index = state.board.index_by_tile_id[state.board.map and state.board.map.market_id] or target.position
    for index, tile_id in ipairs(state.board.path) do
      local def = state.board.tile_defs[tile_id]
      if def and def.type == "mountain" then
        mountain_index = index
        break
      end
    end
    target.position = mountain_index
    target.move_dir = nil
    target.status.stay_turns = state.rules.mountain_stay_turns or 2
    return { ok = true, effect = "exile" }
  end

  if item_id == item_ids.tax then
    common.consume_item(owner, item_id)
    local fee = math.floor((target.cash or 0) * 0.5)
    target.cash = math.max(0, (target.cash or 0) - fee)
    return { ok = true, effect = "tax_target", fee = fee }
  end

  if item_id == item_ids.invite_deity then
    local deity = target.status.deity
    if deity and deity.type ~= "" and (deity.remaining or 0) > 0 then
      owner.status.deity = { type = deity.type, remaining = deity.remaining }
      target.status.deity = { type = "", remaining = 0 }
      common.consume_item(owner, item_id)
      return { ok = true, effect = "invite_deity" }
    end
    return { ok = false, reason = "target_no_deity" }
  end

  if item_id == item_ids.send_poor then
    if not common.has_deity(owner, "poor") then
      return { ok = false, reason = "owner_no_poor" }
    end
    local remain = owner.status.deity.remaining or (constants.deity_duration_turns or 5)
    target.status.deity = { type = "poor", remaining = remain }
    owner.status.deity = { type = "", remaining = 0 }
    common.consume_item(owner, item_id)
    return { ok = true, effect = "send_poor" }
  end

  if item_id == item_ids.poor then
    target.status.deity = { type = "poor", remaining = constants.deity_duration_turns or 5 }
    common.consume_item(owner, item_id)
    return { ok = true, effect = "poor_target" }
  end

  return { ok = false, reason = "unsupported_target_item" }
end

function item_service.resolve_steal(state, owner_seat, target_seat, option_index)
  local owner = state.players[owner_seat]
  local target = state.players[target_seat]
  if not owner or not target then
    return { ok = false, reason = "missing_player" }
  end
  if not common.has_item(owner, item_ids.steal) then
    return { ok = false, reason = "missing_steal" }
  end
  if common.count_item(target) <= 0 then
    return { ok = false, reason = "target_empty" }
  end
  local index = option_index or 1
  local stolen = table.remove(target.inventory.items, index)
  if not stolen then
    stolen = table.remove(target.inventory.items, 1)
  end
  if not stolen then
    return { ok = false, reason = "target_empty" }
  end
  if not common.give_item(owner, stolen.id) then
    return { ok = false, reason = "owner_full" }
  end
  common.consume_item(owner, item_ids.steal)
  return { ok = true, stolen = stolen }
end

function item_service.resolve_remote_dice(state, owner_seat, value)
  local owner = state.players[owner_seat]
  if not owner then
    return { ok = false, reason = "missing_player" }
  end
  if not common.has_item(owner, item_ids.remote_dice) then
    return { ok = false, reason = "missing_item" }
  end
  local target = math.floor(tonumber(value) or 1)
  if target < 1 then
    target = 1
  end
  if target > 6 then
    target = 6
  end
  common.consume_item(owner, item_ids.remote_dice)
  owner.status.pending_remote_dice = {
    values = { target },
  }
  return { ok = true, value = target }
end

function item_service.resolve_roadblock(state, owner_seat, index)
  local owner = state.players[owner_seat]
  if not owner then
    return { ok = false, reason = "missing_player" }
  end
  if not common.has_item(owner, item_ids.roadblock) then
    return { ok = false, reason = "missing_item" }
  end
  local target_index = tonumber(index)
  if not target_index or target_index < 1 or target_index > #state.board.path then
    return { ok = false, reason = "invalid_index" }
  end
  common.consume_item(owner, item_ids.roadblock)
  state.board.overlays.roadblocks[target_index] = true
  return { ok = true, index = target_index }
end

function item_service.resolve_demolish(state, owner_seat, item_id, index)
  local owner = state.players[owner_seat]
  if not owner then
    return { ok = false, reason = "missing_player" }
  end
  if not common.has_item(owner, item_id) then
    return { ok = false, reason = "missing_item" }
  end
  local target_index = tonumber(index)
  if not target_index or target_index < 1 or target_index > #state.board.path then
    return { ok = false, reason = "invalid_index" }
  end
  local tile_id = state.board.path[target_index]
  local tile = state.board.tile_defs[tile_id]
  if not tile or tile.type ~= "land" then
    return { ok = false, reason = "invalid_tile" }
  end
  local tile_state = state.board.tile_states[tile_id]
  if not tile_state or not tile_state.owner_id or tile_state.owner_id == owner_seat then
    return { ok = false, reason = "invalid_owner" }
  end
  common.consume_item(owner, item_id)
  tile_state.level = 0
  state.board.overlays.roadblocks[target_index] = nil
  state.board.overlays.mines[target_index] = nil

  if item_id == item_ids.missile then
    for seat, player in ipairs(state.players) do
      if player.position == target_index and not player.eliminated then
        player.seat_vehicle_id = nil
        local hospital_index = target_index
        for index, path_tile_id in ipairs(state.board.path) do
          local def = state.board.tile_defs[path_tile_id]
          if def and def.type == "hospital" then
            hospital_index = index
            break
          end
        end
        player.position = hospital_index
        player.move_dir = nil
        player.status.stay_turns = state.rules.hospital_stay_turns or 2
      end
    end
  end

  return {
    ok = true,
    index = target_index,
    tile_id = tile_id,
    effect = item_id == item_ids.missile and "missile" or "monster",
  }
end

function item_service.resolve_item_phase_choice(state, owner_seat, option_id, phase)
  local player = state.players[owner_seat]
  if not player then
    return { ok = false, reason = "missing_player" }
  end
  if option_id == "discard_item" then
    local removed = _discard_first(player)
    return { ok = removed ~= nil, discarded = removed }
  end
  local item_id = tonumber(option_id)
  if not item_id then
    return { ok = false, reason = "invalid_item_option" }
  end
  return item_service.apply_manual_item(state, owner_seat, item_id)
end

return item_service
