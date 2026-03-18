-- Shared helpers for regression suites.
local M = {}

require("tests.bootstrap")

local app = require("src.state.game_state")
local composition_root = require("src.app.bootstrap.compose_game")
local movement = require("src.rules.movement")
local turn_move = require("src.turn.phases.move")
local inventory = require("src.rules.items.inventory")
local executor = require("src.rules.items.executor")
local pricing = require("src.rules.land.pricing")
local land_actions = require("src.rules.land.actions")
local steal = require("src.rules.items.steal")
local chance_effects = require("src.rules.chance.chance_resolver")
local landing_defs = require("src.rules.land.specs.effects")
local effect_pipeline = require("src.rules.effects.effect_pipeline")
local effect = require("src.rules.effects.effect_runner")
local choice_resolver = require("src.player.choices.resolver")
local choice_contract = require("src.core.choice.contract")
local board_utils = require("src.rules.land.board_utils")
local gameplay_loop = require("src.turn.loop")
local turn_anim = require("src.turn.output.anim")
local tick_timeout = require("src.turn.waits.timeout")
local constants = require("src.config.content.constants")
local bankruptcy = require("src.rules.endgame.bankruptcy")
local map_cfg = require("src.config.content.maps.default_map")
local tiles_cfg = require("src.config.content.tiles")
local number_utils = require("src.core.utils.number_utils")
local tile = require("src.rules.board.tile")
local test_env = require("support.test_env")
local presentation_runtime_deps = require("src.ui.ctl.deps")
local presentation_ports = require("src.presentation.runtime.ports")
local logger = require("src.core.utils.logger")
local runtime_context = require("src.host.eggy.context")
local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_default_ports = require("src.host.eggy.default_ports")
local paid_purchase_port = require("src.rules.market.ports.paid_purchase_port")
local default_ports = require("src.turn.output.default_ports")
local runtime_state_seam = require("src.ui.runtime.state")
local landing_visual_hold_seam = require("src.ui.runtime.landing_visual_hold")
local host_runtime_ports = require("src.ui.runtime.host_bridge")

local function assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local function ensure_ui_runtime_for_test(state)
  assert(type(state) == "table", "missing state")
  local ui_runtime = state.ui_runtime
  if type(ui_runtime) ~= "table" then
    ui_runtime = {}
    state.ui_runtime = ui_runtime
  end
  if type(state.presentation_runtime) ~= "table" then
    state.presentation_runtime = presentation_runtime_deps.build()
  end
  if type(state.gameplay_loop_ports) ~= "table" then
    state.gameplay_loop_ports = presentation_ports.build()
  end
  if type(state.board_scene) == "table" and type(state.board_scene.presentation_runtime) ~= "table" then
    state.board_scene.presentation_runtime = state.presentation_runtime
  end
  return state
end

local function bind_ui_runtime(state)
  ensure_ui_runtime_for_test(state)
  local ui_runtime = state.ui_runtime
  if state.ui_model ~= nil and ui_runtime.ui_model == nil then
    ui_runtime.ui_model = state.ui_model
  end
  if state.pending_choice ~= nil and ui_runtime.pending_choice == nil then
    ui_runtime.pending_choice = state.pending_choice
  end
  if state.pending_choice_id ~= nil and ui_runtime.pending_choice_id == nil then
    ui_runtime.pending_choice_id = state.pending_choice_id
  end
  if state.pending_choice_elapsed ~= nil and ui_runtime.pending_choice_elapsed == nil then
    ui_runtime.pending_choice_elapsed = state.pending_choice_elapsed
  end
  if state.ui_modal_elapsed ~= nil and ui_runtime.ui_modal_elapsed == nil then
    ui_runtime.ui_modal_elapsed = state.ui_modal_elapsed
  end
  if state.ui_modal_ref ~= nil and ui_runtime.ui_modal_ref == nil then
    ui_runtime.ui_modal_ref = state.ui_modal_ref
  end
  if state.choice_visible_option_ids ~= nil and ui_runtime.choice_visible_option_ids == nil then
    ui_runtime.choice_visible_option_ids = state.choice_visible_option_ids
  end
  if state.pending_choice_selected_option_id ~= nil and ui_runtime.pending_choice_selected_option_id == nil then
    ui_runtime.pending_choice_selected_option_id = state.pending_choice_selected_option_id
  end
  if state.ui_dirty ~= nil and ui_runtime.ui_dirty == nil then
    ui_runtime.ui_dirty = state.ui_dirty == true
  end
  return state
end

local function _refresh_runtime_context_for_tests()
  return test_env.refresh_runtime_context_for_tests({
    GameAPI = GameAPI,
    LuaAPI = LuaAPI,
    GlobalAPI = GlobalAPI,
    SetTimeOut = SetTimeOut,
    RegisterCustomEvent = RegisterCustomEvent,
    TriggerCustomEvent = TriggerCustomEvent,
    all_roles = all_roles,
    ALLROLES = ALLROLES,
    vehicle_helper = vehicle_helper,
    camera_helper = camera_helper,
  })
end

local _RUNTIME_CONTEXT_KEYS = {
  GameAPI = true,
  LuaAPI = true,
  SetTimeOut = true,
  RegisterCustomEvent = true,
  RegisterTriggerEvent = true,
  TriggerCustomEvent = true,
  vehicle_helper = true,
  camera_helper = true,
  change_skin_helper = true,
  all_roles = true,
  ALLROLES = true,
  get_vehicle_player = true,
  get_vehicle_move_direction = true,
  get_vehicle_move_time = true,
  get_spawn_vehicle_id = true,
  get_camera_target = true,
  get_skin_id = true,
  get_change_skin_role = true,
}

local function _patches_need_context_refresh(patches)
  for _, patch in ipairs(patches) do
    local target = patch.target
    if (target == nil or target == _G) and _RUNTIME_CONTEXT_KEYS[patch.key] then
      return true
    end
  end
  return false
end

local function _refresh_runtime_services_for_tests()
  local ctx = runtime_context.current()
  if ctx == nil or ctx.env == nil then
    return _refresh_runtime_context_for_tests()
  end

  runtime_ports.reset_for_tests()
  runtime_ports.configure(runtime_default_ports.build(runtime_context))
  paid_purchase_port.reset_for_tests()
  paid_purchase_port.configure(require("src.host.eggy.paid_purchase_gateway"))
  logger.configure_host_runtime({
    game_api = GameAPI,
    tip_presenter = function(text, duration)
      if GlobalAPI and type(GlobalAPI.show_tips) == "function" then
        return GlobalAPI.show_tips(text, duration)
      end
      return false
    end,
    scheduler = function(delay, fn)
      if type(SetTimeOut) == "function" then
        return SetTimeOut(delay, fn)
      end
      if fn then
        fn()
        return true
      end
      return false
    end,
  })
  return ctx
end

local function with_patches(patches, fn, opts)
  local patch_opts = opts or {}
  local originals = {}
  for i, patch in ipairs(patches) do
    local target = patch.target or _G
    originals[i] = { target = target, key = patch.key, value = target[patch.key] }
    target[patch.key] = patch.value
  end
  local need_refresh = not patch_opts.skip_runtime_context_refresh
      and _patches_need_context_refresh(patches)
  if need_refresh then
    _refresh_runtime_context_for_tests()
  elseif not patch_opts.skip_runtime_context_refresh then
    _refresh_runtime_services_for_tests()
  end
  local handler = debug and debug.traceback or function(err) return err end
  local ok, err = xpcall(fn, handler)
  for i = #originals, 1, -1 do
    local patch = originals[i]
    patch.target[patch.key] = patch.value
  end
  if need_refresh then
    _refresh_runtime_context_for_tests()
  elseif not patch_opts.skip_runtime_context_refresh then
    _refresh_runtime_services_for_tests()
  end
  if not ok then
    error(err)
  end
end

test_env.install_defaults()
_refresh_runtime_context_for_tests()

local function build_ui_port(overrides)
  local ui_view = require("src.ui.ctl.ui_runtime")
  local ui_state = ui_view.build_ui_state()
  local refs = {
    images = {
      ["Empty"] = "EMPTY",
    },
  }
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
  choice_contract.copy_explicit_fields(payload, entry)
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

local function new_game(opts)
  opts = opts or {}
  local game = composition_root.new_game(default_ports.resolve_game_opts({
    players = opts.players or { "P1", "P2" },
    ai = opts.ai or { [2] = true },
    auto_all = opts.auto_all == true,
    map = opts.map or map_cfg,
    tiles = opts.tiles or tiles_cfg,
  }))
  if opts.install_ui_port ~= false then
    game.ui_port = build_ui_port(opts.ui_port)
  end
  game.popup_port = {
    push_popup = function(_, payload, popup_opts)
      local ui_port = game.ui_port
      if ui_port and type(ui_port.push_popup) == "function" then
        return ui_port:push_popup(payload, popup_opts)
      end
      return false
    end,
  }
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
M.bind_ui_runtime = bind_ui_runtime
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
M.runtime_state = runtime_state_seam
M.landing_visual_hold = landing_visual_hold_seam
M.host_runtime_ports = host_runtime_ports

return M
