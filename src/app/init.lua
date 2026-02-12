local runtime_context = require("src.core.RuntimeContext")

local runtime_ctx = runtime_context.new({
  GameAPI = GameAPI,
  LuaAPI = LuaAPI,
})
runtime_context.set_current(runtime_ctx)
runtime_context.install_environment(runtime_ctx)
runtime_context.install_runtime_helpers(runtime_ctx)
runtime_context.install_editor_exports(runtime_ctx)
require "src.game.core.runtime.Bankruptcy"
require "src.game.core.runtime.AgentTargeting"
require "src.game.core.runtime.Agent"
require "src.game.core.runtime.GameState"
require "src.game.core.runtime.GameVictory"
require "src.game.core.runtime.CompositionRoot"

local auto_runner = require("src.game.flow.turn.AutoRunner")
local board_scene = require("src.presentation.BoardScene")
local board_view = require("src.presentation.BoardView")
local game = require("src.game.core.runtime.Game")
local gameplay_loop = require("src.game.flow.turn.GameplayLoop")
local ui_view = require("src.presentation.UIView")
local ui_model = require("src.presentation.UIModel")
local ui_event_router = require("src.presentation.UIEventRouter")
local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")
local gameplay_rules = require("Config.GameplayRules")
local ui_events = require("src.presentation.UIEvents")
local logger = require("src.core.Logger")
local monopoly_event = require("src.game.core.runtime.MonopolyEvents")

logger.configure_game_time()

local max_player_count = 4

local current_game = nil

local function _resolve_roles()
  if type(all_roles) == "table" and #all_roles > 0 then
    return all_roles
  end
  if GameAPI and GameAPI.get_all_valid_roles then
    local ok, roles = pcall(GameAPI.get_all_valid_roles)
    if ok and type(roles) == "table" then
      return roles
    end
  end
  return {}
end

local function _build_role_roster(max_players)
  local roster = {}
  local roles = _resolve_roles()
  for _, role in ipairs(roles) do
    local role_id = nil
    if role and role.get_roleid then
      local ok, id = pcall(role.get_roleid)
      if ok and id ~= nil then
        role_id = id
      end
    end
    if role_id ~= nil then
      local role_name = nil
      if role.get_name then
        local ok, name = pcall(role.get_name)
        if ok and name and name ~= "" then
          role_name = name
        end
      end
      roster[#roster + 1] = { role_id = role_id, name = role_name }
    end
    if max_players and #roster >= max_players then
      break
    end
  end
  if max_players and #roles > max_players then
    logger.warn(
      "[Eggy]",
      "角色数量超过上限，已截断:",
      tostring(#roles),
      "->",
      tostring(max_players)
    )
  end
  return roster
end

local function _build_state()
  local ui = ui_view.build_ui_state()
  local state = {
    ui = ui,
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    wait_move_anim = true,
    move_anim_seq = nil,
    wait_action_anim = true,
    action_anim_seq = nil,
    item_name_by_id = {},
    game_factory = function()
      local role_roster = _build_role_roster(max_player_count)
      if #role_roster > 0 then
        logger.info("[Eggy]", "使用角色驱动初始化，角色数量:", tostring(#role_roster))
        return game:new({
          role_roster = role_roster,
          auto_all = false,
          map = map_cfg,
          tiles = tiles_cfg,
        })
      end
      logger.warn("[Eggy]", "角色列表为空，回退调试玩家初始化")
      return game:new({
        players = { "玩家1", "AI2", "AI3", "AI4" },
        ai = { [2] = true, [3] = true, [4] = true },
        auto_all = false,
        map = map_cfg,
        tiles = tiles_cfg,
      })
    end,
    auto_runner = auto_runner:new({ interval = ui.auto_interval }),
    ai_turn_runner = auto_runner:new({
      interval = gameplay_rules.ai_auto_turn_interval_seconds or 0.4,
    }),
    ai_turn_runner_active = false,
    tile_units = nil,
    tile_positions = nil,
    tile_spacing = nil,
    player_units = nil,
    player_units_missing = false,
    board_last_positions = {},
    board_sync_pending = false,
    board_last_phase = nil,
    next_turn_locked = false,
    next_turn_last_click = nil,
    next_turn_lock_phase = nil,
    role_control_lock_active = false,
    role_control_lock_suppress = 0,
    choice_visible_option_ids = nil,
    pending_choice_selected_option_id = nil,
    _log_once = {},
    tick_started = false,
    ui_dirty = false,
    countdown_last = nil,
    countdown_active_last = nil,
    action_button_elapsed = 0,
    action_button_active = false,
  }

  state.push_popup = function(_, payload)
    local ok = ui_view.push_popup(state, payload)
    if state.ui then
      if ok and current_game and current_game.turn then
        state.ui.popup_owner_index = current_game.turn.current_player_index
      else
        state.ui.popup_owner_index = nil
      end
    end
    return ok
  end
  state.on_tile_upgraded = function(_, tile_id, level)
    board_view.on_tile_upgraded(state, tile_id, level)
  end
  state.on_tile_owner_changed = function(_, tile_id, owner_id)
    board_view.on_tile_owner_changed(state, tile_id, owner_id)
  end

  RegisterCustomEvent(monopoly_event.intent.need_choice, function(_, _, data)
    state.pending_choice = data.choice
    state.pending_choice_elapsed = 0
    state.pending_choice_id = data.choice.id
    assert(current_game ~= nil, "missing current_game")
    local winner = current_game.winner
    local winner_name = current_game.winner_names or (winner and assert(winner.name, "missing winner name"))
    local ui_model = ui_model.build(current_game, {
      game = current_game,
      ui_state = state,
      last_turn = current_game.last_turn,
      finished = current_game.finished,
      winner_name = winner_name,
    })
    state.ui_model = ui_model
    if ui_model.choice then
      ui_view.open_choice_modal(state, ui_model.choice, ui_model.market)
    end
  end)

  return state
end

local function _start_tick_loop(state, interval)
  require "vendor.third_party.Utils"
  local tick_interval = interval or 1
  local tick_seconds = math.tofixed(tick_interval) / 30.0
  SetFrameOut(tick_interval, function()
    gameplay_loop.tick(current_game, state, tick_seconds)
  end, -1)
end

local function _install_game_init(state)
  RegisterTriggerEvent({ EVENT.GAME_INIT }, function()
    require "vendor.third_party.UIManager.Utils"
    UIManager.Builder:new(require "Data.UIManagerNodes")
    state.gameplay_loop_ports = require("src.presentation.api.GameplayLoopPortsAdapter").build(state)
    current_game = gameplay_loop.new_game(state)
    gameplay_loop.set_game(state, current_game)
    ui_event_router.bind(state, function()
      return current_game
    end)

    ui_events.send_to_all(ui_events.show["加载屏"], {})
    board_scene.init(state, map_cfg, current_game)
    ui_view.init_ui_assets(state)

    SetTimeOut(1.0, function()
      ui_events.send_to_all(ui_events.hide["加载屏"], {})
      ui_events.send_to_all(ui_events.show["基础屏"], {})
    end)

    if not state.tick_started then
      state.tick_started = true
      _start_tick_loop(state)
    end
  end)
end

local state = _build_state()
_install_game_init(state)
