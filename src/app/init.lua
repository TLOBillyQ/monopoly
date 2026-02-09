local runtime_context = require("src.core.RuntimeContext")

local runtime_ctx = runtime_context.new({
  GameAPI = GameAPI,
  LuaAPI = LuaAPI,
})
runtime_context.set_current(runtime_ctx)
runtime_context.install_globals(runtime_ctx)
require "src.game.game.Bankruptcy"
require "src.game.game.AgentTargeting"
require "src.game.game.Agent"
require "src.game.game.GameState"
require "src.game.game.GameVictory"
require "src.game.game.CompositionRoot"

local auto_runner = require("src.game.turn.AutoRunner")
local board_scene = require("src.ui.BoardScene")
local board_view = require("src.ui.BoardView")
local game = require("src.game.game.Game")
local gameplay_loop = require("src.game.turn.GameplayLoop")
local ui_view = require("src.ui.UIView")
local ui_model = require("src.ui.UIModel")
local ui_event_router = require("src.ui.UIEventRouter")
local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")
local ui_events = require("src.ui.UIEvents")
local logger = require("src.core.Logger")
local monopoly_event = require("src.game.game.MonopolyEvents")

logger.configure_game_time()

local current_game = nil

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
      return game:new({
        players = { "玩家1", "AI2", "AI3", "AI4" },
        ai = { [2] = true, [3] = true, [4] = true },
        auto_all = false,
        map = map_cfg,
        tiles = tiles_cfg,
      })
    end,
    auto_runner = auto_runner:new({ interval = ui.auto_interval }),
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
    market_choice_option_ids = nil,
    pending_choice_selected_option_id = nil,
    _log_once = {},
    tick_started = false,
    ui_dirty = false,
    countdown_last = nil,
    countdown_active_last = nil,
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
  local tick_seconds = math.tofixed(tick_interval + 1) / 30.0
  SetFrameOut(tick_interval, function()
    gameplay_loop.tick(current_game, state, tick_seconds)
  end, -1)
end

local function _install_game_init(state)
  RegisterTriggerEvent({ EVENT.GAME_INIT }, function()
    require "vendor.third_party.UIManager.Utils"
    UIManager.Builder:new(require "Data.UIManagerNodes")
    current_game = gameplay_loop.new_game(state)
    gameplay_loop.set_game(state, current_game)
    ui_event_router.bind(state, function()
      return current_game
    end, {
      on_game_changed = function(new_game)
        current_game = new_game
      end,
      on_restart = function(_, ctx_state, _, opts)
        gameplay_loop.restart_game(ctx_state, opts)
      end,
    })

    ui_events.send_to_all(ui_events.show["加载屏"], {})
    board_scene.init(state, map_cfg)
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
