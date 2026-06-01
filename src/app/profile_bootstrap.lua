local inventory = require("src.rules.items.inventory")
local constants = require("src.config.content.constants")
local number_utils = require("src.foundation.number")

local bootstrap = {}

local function _assert_integer_like(value, label)
  local resolved = number_utils.to_integer(value)
  assert(resolved ~= nil, tostring(label) .. " must be integer-like, got: " .. tostring(value))
  if number_utils.is_numeric(value) then
    assert(resolved == value, tostring(label) .. " must be integer (no decimals), got: " .. tostring(value))
  end
  return resolved
end

local function _new_render_bootstrap()
  return {
    applied = false,
    tiles_by_id = {},
    overlays = {
      roadblock = {},
      mine = {},
    },
  }
end

local function _ensure_render_bootstrap(game)
  if type(game.test_profile_render_bootstrap) ~= "table" then
    game.test_profile_render_bootstrap = _new_render_bootstrap()
    return game.test_profile_render_bootstrap
  end
  return game.test_profile_render_bootstrap
end

local function _reset_render_bootstrap(game)
  game.test_profile_render_bootstrap = _new_render_bootstrap()
  return game.test_profile_render_bootstrap
end

local function _assert_player_profile_schema(player_cfg, index)
  assert(type(player_cfg) == "table", "invalid profile player config at index: " .. tostring(index))
  assert(player_cfg.inventory_slots == nil,
    "inventory_slots is removed; use item_counts and keep <= " .. tostring(constants.inventory_slots))
  assert(player_cfg.items == nil, "items is removed; use item_counts = { [item_id] = count }")
end

local function _apply_player_resources(game, player, player_cfg)
  if player_cfg.cash ~= nil then
    game:set_player_cash(player, player_cfg.cash)
  end
end

local function _apply_player_position_bootstrap(game, player, player_cfg)
  local tile_id = player_cfg.position_tile_id
  if tile_id == nil then
    return
  end
  local resolved_tile_id = number_utils.to_integer(tile_id)
  assert(resolved_tile_id ~= nil, "invalid position_tile_id: " .. tostring(tile_id))
  local board_index = game.board:index_of_tile_id(resolved_tile_id)
  assert(board_index ~= nil, "position_tile_id not in board path: " .. tostring(resolved_tile_id))
  game:update_player_position(player, board_index)
end

local function _validate_and_parse_item_entry(raw_item_id, raw_count)
  local item_id = number_utils.to_integer(raw_item_id)
  assert(item_id ~= nil, "invalid item_counts item id: " .. tostring(raw_item_id))
  assert(inventory.cfg(item_id) ~= nil, "unknown item id in item_counts: " .. tostring(item_id))
  local count = number_utils.to_integer(raw_count)
  assert(number_utils.is_numeric(raw_count) and count ~= nil and count == raw_count and count > 0,
    "item_counts count must be positive integer, got: " .. tostring(raw_count))
  return item_id, count
end

local function _grant_item_copies(game, player, item_id, count)
  for _ = 1, count do
    local ok = inventory.give(player, item_id, { game = game })
    assert(ok == true, "failed to grant profile item: " .. tostring(item_id))
  end
end

local function _apply_item_count_bootstrap(game, player, player_cfg)
  local item_counts = player_cfg.item_counts
  if item_counts == nil then
    return
  end
  assert(type(item_counts) == "table", "item_counts must be table")

  inventory.clear(player)
  local total = 0
  for raw_item_id, raw_count in pairs(item_counts) do
    local item_id, count = _validate_and_parse_item_entry(raw_item_id, raw_count)
    total = total + count
    assert(total <= constants.inventory_slots,
      "item_counts exceeds inventory limit " .. tostring(constants.inventory_slots))
    _grant_item_copies(game, player, item_id, count)
  end
end

local function _apply_player_status_bootstrap(game, player, player_cfg)
  local statuses = player_cfg.statuses
  if type(statuses) ~= "table" then
    return
  end
  for status_key, status_value in pairs(statuses) do
    assert(type(status_key) == "string" and status_key ~= "", "invalid status key in profile bootstrap")
    game:set_player_status(player, status_key, status_value)
  end
end

local function _apply_player_eliminated(player, player_cfg)
  if player_cfg.eliminated == nil then
    return
  end
  assert(type(player_cfg.eliminated) == "boolean",
    "eliminated must be boolean, got: " .. tostring(player_cfg.eliminated))
  player.eliminated = player_cfg.eliminated
end

local function _apply_player_bootstrap(game, players)
  if type(players) ~= "table" then
    return
  end
  for index, player_cfg in pairs(players) do
    _assert_player_profile_schema(player_cfg, index)
    local player = game.players[index]
    assert(player ~= nil, "invalid profile player index: " .. tostring(index))

    _apply_player_resources(game, player, player_cfg)
    _apply_player_position_bootstrap(game, player, player_cfg)
    _apply_item_count_bootstrap(game, player, player_cfg)
    _apply_player_status_bootstrap(game, player, player_cfg)
    _apply_player_eliminated(player, player_cfg)
  end
end

local function _apply_tile_owner(game, tile, owner_index)
  local resolved = _assert_integer_like(owner_index, "owner_player_index")
  local owner = game.players[resolved]
  assert(owner ~= nil, "invalid owner_player_index: " .. tostring(resolved))
  game:set_tile_owner(tile, owner.id)
  game:set_player_property(owner, tile.id, true)
end

local function _apply_single_tile_cfg(game, raw_tile_id, tile_cfg, render_bootstrap)
  assert(type(tile_cfg) == "table", "invalid profile tile config: " .. tostring(raw_tile_id))
  local tile_id = _assert_integer_like(raw_tile_id, "tile id")
  local tile = game.board:get_tile_by_id(tile_id)
  assert(tile ~= nil, "invalid profile tile id: " .. tostring(tile_id))
  if tile_cfg.owner_player_index ~= nil then
    _apply_tile_owner(game, tile, tile_cfg.owner_player_index)
  end
  if tile_cfg.level ~= nil then
    game:set_tile_level(tile, _assert_integer_like(tile_cfg.level, "tile level"))
  end
  if tile_cfg.render_called == true then
    render_bootstrap.tiles_by_id[tile.id] = true
  end
end

local function _apply_tile_bootstrap(game, tiles)
  if type(tiles) ~= "table" then return end
  local render_bootstrap = _ensure_render_bootstrap(game)
  for raw_tile_id, tile_cfg in pairs(tiles) do
    _apply_single_tile_cfg(game, raw_tile_id, tile_cfg, render_bootstrap)
  end
end

local function _resolve_overlay_entry(raw_entry)
  if raw_entry == nil then
    return nil, false
  end
  if type(raw_entry) == "table" then
    return raw_entry.tile_id, raw_entry.render_called == true
  end
  return raw_entry, false
end

local function _resolve_overlay_index(game, raw_tile_id, overlay_kind)
  local tile_id = number_utils.to_integer(raw_tile_id)
  assert(tile_id ~= nil, "invalid " .. tostring(overlay_kind) .. " tile id: " .. tostring(raw_tile_id))
  local board_index = game.board:index_of_tile_id(tile_id)
  assert(board_index ~= nil, tostring(overlay_kind) .. " tile id not in board path: " .. tostring(tile_id))
  return board_index
end

local function _apply_overlay_list(game, entries, kind, place_fn, render_table)
  for _, entry in ipairs(entries) do
    local raw_tile_id, render_called = _resolve_overlay_entry(entry)
    local board_index = _resolve_overlay_index(game, raw_tile_id, kind)
    place_fn(game, board_index)
    if render_called then
      render_table[board_index] = true
    end
  end
end

local function _apply_overlay_bootstrap(game, overlays)
  if type(overlays) ~= "table" then return end
  local rb = _ensure_render_bootstrap(game)
  if type(overlays.roadblocks) == "table" then
    _apply_overlay_list(game, overlays.roadblocks, "roadblock",
      function(g, idx) g:place_roadblock(idx) end, rb.overlays.roadblock)
  end
  if type(overlays.mines) == "table" then
    _apply_overlay_list(game, overlays.mines, "mine",
      function(g, idx) g:place_mine(idx) end, rb.overlays.mine)
  end
end

local function _apply_turn_bootstrap(game, cfg)
  if cfg.current_turn_player_index == nil then
    return
  end
  local resolved = number_utils.to_integer(cfg.current_turn_player_index)
  assert(resolved ~= nil,
    "invalid current_turn_player_index: " .. tostring(cfg.current_turn_player_index))
  assert(game.players[resolved] ~= nil,
    "current_turn_player_index points to missing player: " .. tostring(resolved))
  assert(game.turn ~= nil,
    "game.turn must exist before setting current_turn_player_index")
  game.turn.current_player_index = resolved
end

local function _apply_market_limits_bootstrap(game, cfg)
  local limits = cfg.market_limits
  if type(limits) ~= "table" then
    return
  end
  for raw_product_id, raw_remaining in pairs(limits) do
    local product_id = number_utils.to_integer(raw_product_id)
    assert(product_id ~= nil, "invalid market_limits product_id: " .. tostring(raw_product_id))
    assert(game.market_limits[product_id] ~= nil,
      "market_limits product_id not in catalog: " .. tostring(product_id))
    local remaining = number_utils.to_integer(raw_remaining)
    assert(remaining ~= nil and remaining >= 0,
      "market_limits remaining must be non-negative integer, got: " .. tostring(raw_remaining))
    game.market_limits[product_id] = remaining
  end
end

function bootstrap.apply_bootstrap(game, cfg)
  assert(game ~= nil, "missing game")
  _reset_render_bootstrap(game)
  if type(cfg) ~= "table" then
    return
  end
  _apply_player_bootstrap(game, cfg.players)
  _apply_tile_bootstrap(game, cfg.tiles)
  _apply_overlay_bootstrap(game, cfg.overlays)
  _apply_turn_bootstrap(game, cfg)
  _apply_market_limits_bootstrap(game, cfg)
end

return bootstrap

--[[ mutate4lua-manifest
version=2
projectHash=801b02b9fc316658
scope.0.id=chunk:src/app/profile_bootstrap.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=249
scope.0.semanticHash=d12cd1696b14c0b3
scope.1.id=function:_assert_integer_like:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=14
scope.1.semanticHash=2d4bb5119916767c
scope.2.id=function:_new_render_bootstrap:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=25
scope.2.semanticHash=afca0a43441e2c19
scope.3.id=function:_ensure_render_bootstrap:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=33
scope.3.semanticHash=b7d556500b96810c
scope.4.id=function:_reset_render_bootstrap:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=38
scope.4.semanticHash=1168f0134a9a4152
scope.5.id=function:_assert_player_profile_schema:40
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=45
scope.5.semanticHash=2389a4b53ca40634
scope.6.id=function:_apply_player_resources:47
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=51
scope.6.semanticHash=1e1bb952c3b94912
scope.7.id=function:_apply_player_position_bootstrap:53
scope.7.kind=function
scope.7.startLine=53
scope.7.endLine=63
scope.7.semanticHash=0462c829973cb498
scope.8.id=function:_apply_player_eliminated:104
scope.8.kind=function
scope.8.startLine=104
scope.8.endLine=111
scope.8.semanticHash=18539b10e56cb2d9
scope.9.id=function:_apply_tile_owner:130
scope.9.kind=function
scope.9.startLine=130
scope.9.endLine=136
scope.9.semanticHash=258ac6bcdde27c64
scope.10.id=function:_apply_single_tile_cfg:138
scope.10.kind=function
scope.10.startLine=138
scope.10.endLine=152
scope.10.semanticHash=cee3c26ca4f291fc
scope.11.id=function:_resolve_overlay_entry:162
scope.11.kind=function
scope.11.startLine=162
scope.11.endLine=170
scope.11.semanticHash=07fc38c2e09bb907
scope.12.id=function:_resolve_overlay_index:172
scope.12.kind=function
scope.12.startLine=172
scope.12.endLine=178
scope.12.semanticHash=4a0d81503891247f
scope.13.id=function:anonymous@196:196
scope.13.kind=function
scope.13.startLine=196
scope.13.endLine=196
scope.13.semanticHash=928bb33b1491de75
scope.14.id=function:anonymous@200:200
scope.14.kind=function
scope.14.startLine=200
scope.14.endLine=200
scope.14.semanticHash=9828212be1ad536b
scope.15.id=function:_apply_overlay_bootstrap:191
scope.15.kind=function
scope.15.startLine=191
scope.15.endLine=202
scope.15.semanticHash=c6076963c232c44f
scope.16.id=function:_apply_turn_bootstrap:204
scope.16.kind=function
scope.16.startLine=204
scope.16.endLine=216
scope.16.semanticHash=c41f711cd60cdcd9
scope.17.id=function:bootstrap.apply_bootstrap:235
scope.17.kind=function
scope.17.startLine=235
scope.17.endLine=246
scope.17.semanticHash=3f6c5499e75576a6
]]
