local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")
local choice_view = require("src.ui.UIChoice")

local projection = {}

local tiles_by_id = {}
for _, cfg in ipairs(tiles_cfg) do
  tiles_by_id[cfg.id] = cfg
end

local function _build_board_tiles()
  local out = {}
  assert(map_cfg.path ~= nil, "missing map path")
  for i, tile_id in ipairs(map_cfg.path) do
    local cfg = tiles_by_id[tile_id]
    assert(cfg ~= nil, "missing tile cfg: " .. tostring(tile_id))
    out[i] = {
      id = tile_id,
      name = cfg.name,
      type = cfg.type,
      price = cfg.price,
      row = cfg.row,
      col = cfg.col,
    }
  end
  return out
end

local board_tiles = _build_board_tiles()

function projection.board_tiles()
  return board_tiles
end

function projection.resolve_current_player(game)
  local turn = game.turn
  local players = game.players
  assert(turn ~= nil and players ~= nil, "missing turn or players")
  local idx = turn.current_player_index
  if type(idx) ~= "number" then
    return nil, turn,
      string.format("invalid current player index: index=%s, player_count=%d", tostring(idx), #players)
  end
  local current = players[idx]
  if current == nil then
    return nil, turn,
      string.format("current player not found: index=%s, player_count=%d", tostring(idx), #players)
  end
  return current, turn
end

function projection.build_overlays(env)
  assert(env ~= nil and env.game ~= nil and env.game.board ~= nil and env.game.board.get_overlays ~= nil,
    "missing board overlays")
  return env.game.board:get_overlays()
end

function projection.resolve_item_slot_count(ui_runtime)
  local slot_count = 5
  if ui_runtime and type(ui_runtime.item_slots) == "table" and #ui_runtime.item_slots > 0 then
    slot_count = #ui_runtime.item_slots
  end
  return slot_count
end

function projection.build_item_slots_for_player(player, slot_count)
  local current_items = {}
  if player and player.inventory and type(player.inventory.items) == "table" then
    current_items = player.inventory.items
  end
  local item_slots = {}
  for i = 1, slot_count do
    local item = current_items[i]
    item_slots[i] = item and item.id or nil
  end
  return item_slots
end

function projection.build_item_slots_by_player(players, slot_count)
  local out = {}
  for _, player in ipairs(players or {}) do
    local player_id = player and player.id
    if player_id then
      out[player_id] = projection.build_item_slots_for_player(player, slot_count)
    end
  end
  return out
end

function projection.build_auto_enabled_by_player(players)
  local out = {}
  for _, player in ipairs(players or {}) do
    local player_id = player and player.id
    if player_id then
      out[player_id] = player.auto == true
    end
  end
  return out
end

function projection.build_choice_and_market(game, env, ui_state)
  local choice = nil
  local pending = game.turn and game.turn.pending_choice
  if pending then
    choice = choice_view.build_choice_view(pending, { game = env.game })
    choice.id = pending.id
    choice.kind = pending.kind
  end
  local market = nil
  if choice and choice.kind == "market_buy" then
    market = {
      choice_id = choice.id,
      options = choice.options,
      allow_cancel = choice.allow_cancel,
      cancel_label = choice.cancel_label,
      selected_option_id = ui_state and ui_state.pending_choice_selected_option_id or nil,
    }
  end
  return choice, market
end

function projection.build_popup(ui_runtime)
  if ui_runtime and ui_runtime.popup_active and ui_runtime.popup_payload then
    return {
      title = ui_runtime.popup_payload.title,
      body = ui_runtime.popup_payload.body,
      button_text = ui_runtime.popup_payload.button_text,
    }
  end
  return nil
end

function projection.resolve_item_choice_owner_id(game, choice, current_player_id)
  local owner_id = current_player_id
  local pending = game and game.turn and game.turn.pending_choice or nil
  if pending and pending.meta and pending.meta.player_id then
    owner_id = pending.meta.player_id
    return owner_id
  end
  if choice and choice.meta and choice.meta.player_id then
    owner_id = choice.meta.player_id
  end
  return owner_id
end

return projection
