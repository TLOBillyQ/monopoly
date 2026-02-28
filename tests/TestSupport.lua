-- Shared helpers for regression suites.
local M = {}

local app = require("src.game.core.runtime.Game")
local movement = require("src.game.systems.movement.Movement")
local turn_flow = require("src.game.flow.turn.TurnFlow")
local turn_move = require("src.game.flow.turn.TurnMove")
local inventory = require("src.game.systems.items.ItemInventory")
local executor = require("src.game.systems.items.ItemExecutor")
local pricing = require("src.game.systems.land.LandPricing")
local land_actions = require("src.game.systems.land.LandActions")
local steal = require("src.game.systems.items.ItemSteal")
local chance_effects = require("src.game.systems.chance.ChanceResolver")
local landing_defs = require("Config.LandingEffects")
local effect_pipeline = require("src.game.systems.effects.EffectPipeline")
local effect = require("src.game.systems.effects.EffectRunner")
local choice_resolver = require("src.game.systems.choices.ChoiceResolver")
local board_utils = require("src.game.systems.land.LandBoardUtils")
local gameplay_loop = require("src.game.flow.turn.GameplayLoop")
local turn_anim = require("src.game.flow.turn.TurnAnim")
local tick_timeout = require("src.game.flow.turn.TickTimeout")
local constants = require("Config.Generated.Constants")
local bankruptcy = require("src.game.core.runtime.Bankruptcy")
local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")
local number_utils = require("src.core.NumberUtils")
local tile = require("src.game.systems.board.Tile")

if not math.tofixed then
  function math.tofixed(value)
    return value
  end
end

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

if not math.Quaternion then
  function math.Quaternion(x, y, z)
    return { x = x, y = y, z = z }
  end
end

local function assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local function with_patches(patches, fn)
  local originals = {}
  for i, patch in ipairs(patches) do
    local target = patch.target or _G
    originals[i] = { target = target, key = patch.key, value = target[patch.key] }
    target[patch.key] = patch.value
  end
  local handler = debug and debug.traceback or function(err) return err end
  local ok, err = xpcall(fn, handler)
  for i = #originals, 1, -1 do
    local patch = originals[i]
    patch.target[patch.key] = patch.value
  end
  if not ok then
    error(err)
  end
end

LuaAPI = LuaAPI or {}
LuaAPI.rand = LuaAPI.rand or function()
  return math.random()
end

GameAPI = GameAPI or {}
UIManager = UIManager or {}
if not UIManager.query_nodes_by_name then
  UIManager.query_nodes_by_name = function(name)
    local node = {
      name = name,
      set_texture_keep_size = function() end,
      set_texture_native_size = function() end,
    }
    return { node }
  end
end
if not GameAPI.random_int then
  math.randomseed(1)
  GameAPI.random_int = function(min, max)
    return math.random(min, max)
  end
end

TriggerCustomEvent = TriggerCustomEvent or function() end

local function build_ui_port(overrides)
  local ui_view = require("src.presentation.api.UIViewService")
  local ui_state = ui_view.build_ui_state()
  local refs = { ["Empty"] = "EMPTY" }
  local port = {
    ui = ui_state,
    ui_refs = refs,
    ui_model = nil,
    set_label = ui_state.set_label,
    set_visible = ui_state.set_visible,
    set_touch_enabled = ui_state.set_touch_enabled,
    query_node = ui_state.query_node,
    wait_move_anim = false,
    wait_action_anim = false,
    push_popup = function() end,
    on_tile_owner_changed = function() end,
    on_tile_upgraded = function() end,
    build_model = function(state, game)
      return ui_view.build_model(state, game)
    end,
    refresh_from_dirty = function(game, state, dirty)
      return ui_view.refresh_from_dirty(game, state, dirty)
    end,
  }
  if overrides then
    for key, value in pairs(overrides) do
      port[key] = value
    end
  end
  return port
end

local function visited_tile_ids(board, visited)
  local list = {}
  for _, idx in ipairs(visited or {}) do
    local tile_ref = board:get_tile(idx)
    table.insert(list, tile_ref and tile_ref.id or idx)
  end
  return list
end

local function list_contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

local function next_choice_id(game)
  local seq = game.turn.choice_seq or 0
  seq = seq + 1
  game.turn.choice_seq = seq
  return seq
end

local function open_choice(game, payload)
  assert(game and game.turn, "Choice.open requires game.turn")
  payload = payload or {}
  local id = next_choice_id(game)
  local entry = {
    id = id,
    kind = payload.kind,
    title = payload.title or "请选择",
    body_lines = payload.body_lines or {},
    options = payload.options or {},
    allow_cancel = payload.allow_cancel ~= false,
    cancel_label = payload.cancel_label or "取消",
    meta = payload.meta,
  }
  game.turn.pending_choice = entry
  game.dirty.turn = true
  game.dirty.any = true
  return entry
end

local function get_choice(game)
  if not (game and game.turn) then
    return nil
  end
  return game.turn.pending_choice
end

local function resolve_choice_first(game, pending)
  if pending.options and #pending.options > 0 then
    local first = pending.options[1]
    choice_resolver.resolve(game, pending, { option_id = first.id or first })
    return true
  end
  if pending.allow_cancel then
    choice_resolver.resolve(game, pending, { type = "choice_cancel", choice_id = pending.id })
    return true
  end
  return false
end

local max_landing_depth = 10

local function build_landing_ctx(game, move_result)
  return effect.build_game_ctx(game, move_result, {
    phase_default = "landing",
    on_landing = true,
  })
end

local function resolve_landing(game, player, tile_ref, move_result, depth)
  depth = depth or 0
  local ctx = build_landing_ctx(game, move_result)

  local function handle_need_landing(out)
    if depth >= max_landing_depth then
      return out
    end
    local target_player = (out.player_id and game and game.players and game.players[out.player_id]) or player
    local next_tile = nil
    if target_player then
      local idx = out.board_index or target_player.position
      next_tile = idx and game and game.board and game.board:get_tile(idx) or nil
    end
    if next_tile then
      return resolve_landing(game, target_player, next_tile, out.move_result, depth + 1)
    end
    return out
  end

  return effect_pipeline.run(landing_defs, player, tile_ref, ctx, {
    next_state = "post_action",
    next_args = { player = player },
    optional_choice_kind = "landing_optional_effect",
    optional_reason = "landing_optional",
    optional_allow_cancel = true,
    optional_cancel_label = "跳过",
    on_need_landing = handle_need_landing,
  })
end

local function resolve_landing_with_choices(game, player, tile_ref, move_result, max_iterations)
  local res = resolve_landing(game, player, tile_ref, move_result, 0)
  local iteration = 0
  local limit = max_iterations or 10
  while res and res.waiting and iteration < limit do
    iteration = iteration + 1
    local pending = get_choice(game)
    if not pending then
      break
    end
    if not resolve_choice_first(game, pending) then
      break
    end
    if iteration < limit then
      local current_tile = game.board:get_tile(player.position)
      res = resolve_landing(game, player, current_tile, move_result, iteration)
    end
  end
  return res
end

local function new_game()
  local game = app:new({
    players = { "P1", "P2" },
    ai = { [2] = true },
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  })
  game.ui_port = build_ui_port()
  return game
end

local function first_land_tile(board)
  for idx, tile_ref in ipairs(board.path) do
    if tile_ref.type == "land" then
      return idx, tile_ref
    end
  end
  error("no land tile found")
end

local function first_tile_by_type(board, t)
  for idx, tile_ref in ipairs(board.path) do
    if tile_ref.type == t then
      return idx, tile_ref
    end
  end
  error("no tile found for type=" .. tostring(t))
end

local function first_adjacent_land_pair(board)
  for idx = 1, #board.path - 1 do
    local a = board.path[idx]
    local b = board.path[idx + 1]
    if a.type == "land" and b.type == "land" then
      return idx, a, idx + 1, b
    end
  end
  error("no adjacent land tiles")
end

local function tile_state(game, tile_ref)
  local state = tile.get_state(game, tile_ref)
  return state or { owner_id = nil, level = 0 }
end

M.app = app
M.movement = movement
M.turn_flow = turn_flow
M.turn_move = turn_move
M.inventory = inventory
M.executor = executor
M.pricing = pricing
M.land_actions = land_actions
M.steal = steal
M.chance_effects = chance_effects
M.choice_resolver = choice_resolver
M.board_utils = board_utils
M.gameplay_loop = gameplay_loop
M.turn_anim = turn_anim
M.tick_timeout = tick_timeout
M.constants = constants
M.bankruptcy = bankruptcy
M.map_cfg = map_cfg
M.tiles_cfg = tiles_cfg
M.number_utils = number_utils
M.assert_eq = assert_eq
M.with_patches = with_patches
M.build_ui_port = build_ui_port
M.visited_tile_ids = visited_tile_ids
M.list_contains = list_contains
M.open_choice = open_choice
M.get_choice = get_choice
M.resolve_choice_first = resolve_choice_first
M.resolve_landing = resolve_landing
M.resolve_landing_with_choices = resolve_landing_with_choices
M.new_game = new_game
M.first_land_tile = first_land_tile
M.first_tile_by_type = first_tile_by_type
M.first_adjacent_land_pair = first_adjacent_land_pair
M.tile_state = tile_state

return M
