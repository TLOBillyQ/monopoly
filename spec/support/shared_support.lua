-- Shared helpers for regression suites.
local M = {}

require("spec.bootstrap")

local composition_root = require("src.app.compose_game")
local landing_defs = require("src.rules.land.landing_defs")
local effect_pipeline = require("src.rules.effects.pipeline")
local effect = require("src.rules.effects.runner")
local choice_resolver = require("src.rules.choice.resolver")
local choice_contract = require("src.config.choice.contract")
local map_cfg = require("src.config.content.default_map")
local tiles_cfg = require("src.config.content.tiles")
local tile = require("src.rules.board.tile")
local test_env = require("spec.support.test_env")
local presentation_runtime_deps = require("src.ui.coord.deps")
local presentation_ports = require("src.ui.ports")
local logger = require("src.foundation.log")
local tip_queue = require("src.foundation.tips")
local runtime_context = require("src.host.context")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_default_ports = require("src.host.default_ports")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local default_ports = require("src.turn.output.default_ports")
local runtime_state_seam = require("src.ui.state.runtime")
local landing_visual_hold_seam = require("src.ui.visual_hold")
local event_feed_adapter = require("src.turn.output.event_feed_adapter")
local ui_view = require("src.ui.coord.ui_runtime")
local function assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local function assert_player_move_dir(player, expected, msg)
  local status = player and player.status or nil
  assert_eq(status and status.move_dir or nil, expected, msg or "move_dir mismatch")
end

local function assert_tile_id_sequence(entries, expected_ids, msg)
  assert_eq(#entries, #expected_ids, (msg or "tile id sequence length mismatch"))
  for index, expected_id in ipairs(expected_ids) do
    local entry = entries[index]
    local actual_id = entry
    if type(entry) == "table" then
      if entry.tile and entry.tile.id ~= nil then
        actual_id = entry.tile.id
      else
        actual_id = entry.id
      end
    end
    assert_eq(actual_id, expected_id, (msg or "tile id sequence mismatch") .. " at slot " .. tostring(index))
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
  if type(state.board_scene) ~= "table" then
    state.board_scene = {
      tiles = {},
    }
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
  if state.local_actor_role_id ~= nil and ui_runtime.local_actor_role_id == nil then
    ui_runtime.local_actor_role_id = state.local_actor_role_id
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
  camera_helper = true,
  all_roles = true,
  ALLROLES = true,
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
  paid_purchase_port.configure(require("src.host.paid_purchase_gateway"))
  tip_queue.configure_runtime({
    presenter = function(text, duration)
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
    test_mode = logger.is_test_mode(),
  })
  if GameAPI ~= nil
      and type(GameAPI.get_timestamp) == "function"
      and type(GameAPI.get_hour) == "function"
      and type(GameAPI.get_minute) == "function"
      and type(GameAPI.get_second) == "function" then
    logger.configure_game_time(GameAPI)
  else
    logger.reset_time_runtime()
  end
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
    push_popup = function(_, _, _) end,
    show_tip = function(_, intent)
      if type(intent) ~= "table" then
        return false
      end
      if GlobalAPI and type(GlobalAPI.show_tips) == "function" then
        return GlobalAPI.show_tips(intent.text, intent.duration) == true
      end
      return false
    end,
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
  game.tip_output_port = {
    enqueue = function(_, maybe_game, maybe_intent)
      local intent = maybe_intent
      if intent == nil and type(maybe_game) == "table" and maybe_game.text ~= nil then
        intent = maybe_game
      end
      local ui_port = game.ui_port
      if ui_port and type(ui_port.show_tip) == "function" then
        return ui_port:show_tip(intent) == true
      end
      if GlobalAPI and type(GlobalAPI.show_tips) == "function" and type(intent) == "table" then
        return GlobalAPI.show_tips(intent.text, intent.duration) == true
      end
      return false
    end,
  }
  game.event_feed_port = event_feed_adapter.new(game)
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

M.assert_eq = assert_eq
M.assert_player_move_dir = assert_player_move_dir
M.assert_tile_id_sequence = assert_tile_id_sequence
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

local function _wrap_ui_refs(image_refs)
  return {
    images = image_refs or {},
  }
end

M.wrap_ui_refs = _wrap_ui_refs

function M.build_popup_view_state(refs, card_node)
  local function new_node(seed)
    local node = seed or {}
    if not node.listen then
      function node:listen(_, cb)
        self._listener_cb = cb
        return {
          destroy = function()
            self._listener_cb = nil
          end,
        }
      end
    end
    return node
  end
  local state = {
    ui = ui_view.build_ui_state(),
    ui_refs = _wrap_ui_refs(refs or { ["Empty"] = "EMPTY" }),
  }
  state.ui.choice_active = false
  state.ui.market_active = false
  local nodes = {
    ["卡牌展示屏"] = new_node(),
    ["卡牌展示_标题"] = new_node(),
    ["卡牌展示_图片"] = new_node(card_node or {}),
  }
  local function query_nodes_by_name(name)
    local node = nodes[name]
    if not node then
      node = new_node()
      nodes[name] = node
    end
    return { node }
  end
  return state, nodes, query_nodes_by_name
end

function M.build_role_with_events(role_id, events)
  return {
    get_roleid = function() return role_id end,
    send_ui_custom_event = function(event_name)
      events[#events + 1] = event_name
    end,
  }
end

function M.has_event(list, name)
  for _, value in ipairs(list or {}) do
    if value == name then
      return true
    end
  end
  return false
end

function M.build_choice_modal_state()
  local function new_node()
    local node = {}
    function node:listen(_, cb)
      self._listener_cb = cb
      return {
        destroy = function()
          self._listener_cb = nil
        end,
      }
    end
    return node
  end
  local state = {
    pending_choice_id = nil,
    pending_choice_elapsed = 0,
    pending_choice_selected_option_id = nil,
    ui = ui_view.build_ui_state(),
    ui_refs = _wrap_ui_refs({ ["Empty"] = "EMPTY" }),
  }
  bind_ui_runtime(state)
  local names = {
    "玩家选择屏", "玩家选择_标题",
    "玩家选择_槽位1", "玩家选择_槽位2", "玩家选择_槽位3", "玩家选择_槽位4",
    "位置选择屏", "位置_副标题", "位置_放置文本",
    "位置-槽位1按钮", "位置-槽位2按钮", "位置-槽位3按钮", "位置-槽位4按钮", "位置-槽位5按钮", "位置-槽位6按钮", "位置-槽位7按钮",
    "位置-槽位1文本", "位置-槽位2文本", "位置-槽位3文本", "位置-槽位4文本", "位置-槽位5文本", "位置-槽位6文本", "位置-槽位7文本",
    "位置-槽位1投影", "位置-槽位2投影", "位置-槽位3投影", "位置-槽位4投影", "位置-槽位5投影", "位置-槽位6投影", "位置-槽位7投影",
    "遥控骰子屏", "遥控骰子_标题", "遥控骰子_正文",
    "遥控骰子_选项_01", "遥控骰子_选项_02", "遥控骰子_选项_03",
    "遥控骰子_选项_04", "遥控骰子_选项_05", "遥控骰子_选项_06",
    "通用二次确认屏", "通用二次确认_标题", "通用二次确认_文本", "通用二次确认_确定按钮", "通用二次确认_取消",
    "卡牌展示屏", "卡牌展示_标题", "卡牌展示_图片",
    "黑市屏", "黑市_购买按钮", "黑市_关闭", "黑市_售价", "黑市_选中卡牌",
  }
  local nodes = {}
  for _, name in ipairs(names) do
    nodes[name] = new_node()
  end
  local function query_nodes_by_name(name)
    local node = nodes[name]
    if not node then
      node = new_node()
      nodes[name] = node
    end
    return { node }
  end
  return state, nodes, query_nodes_by_name
end

function M.ui_runtime(state)
  return runtime_state_seam.ensure_ui_runtime(state)
end

return M
