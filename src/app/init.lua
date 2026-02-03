require "src.runtime.Globals"
require "src.app.manager_init"

local AutoRunner = require("src.game.turn.AutoRunner")
local BoardScene = require("src.ui.BoardScene")
local Game = require("src.game.game.Game")
local GameplayLoop = require("src.game.turn.GameplayLoop")
local UIView = require("src.ui.UIView")
local UIModel = require("src.ui.UIModel")
local UIEventRouter = require("src.ui.UIEventRouter")
local MapCfg = require("Config.Map")
local TilesCfg = require("Config.Generated.Tiles")
local Logger = require("src.core.Logger")
local MonopolyEvent = require("src.game.MonopolyEvents")

Logger.configure_game_time()

local current_game = nil

local function _BuildState()
  local ui = UIView.BuildUiState()
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
      return Game:new({
        players = { "玩家1", "AI2", "AI3", "AI4" },
        ai = { [2] = true, [3] = true, [4] = true },
        auto_all = true,
        seed = GameAPI.get_timestamp(),
        map = MapCfg,
        tiles = TilesCfg,
      })
    end,
    auto_runner = AutoRunner:New({ interval = ui.auto_interval }),
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
    camera_follow_player_id = nil,
    market_choice_option_ids = nil,
    pending_choice_selected_option_id = nil,
    _log_once = {},
    tick_started = false,
  }

  state.push_popup = function(_, payload)
    return UIView.PushPopup(state, payload)
  end
  state.on_tile_upgraded = function(_, tile_id, level)
    UIView.OnTileUpgraded(state, tile_id, level)
  end
  state.on_tile_owner_changed = function(_, tile_id, owner_id)
    UIView.OnTileOwnerChanged(state, tile_id, owner_id)
  end

  RegisterCustomEvent(MonopolyEvent.intent.need_choice, function(_, _, data)
    state.pending_choice = data.choice
    state.pending_choice_elapsed = 0
    state.pending_choice_id = data.choice.id
    assert(current_game ~= nil, "missing current_game")
    local winner = current_game.winner
    local winner_name = current_game.winner_names or (winner and assert(winner.name, "missing winner name"))
    local ui_model = UIModel.Build(current_game.store.state, {
      game = current_game,
      ui_state = state,
      last_turn = current_game.last_turn,
      finished = current_game.finished,
      winner_name = winner_name,
    })
    state.ui_model = ui_model
    if ui_model.choice then
      UIView.OpenChoiceModal(state, ui_model.choice, ui_model.market)
    end
  end)

  return state
end

local function _InstallGameInit(state)
  RegisterTriggerEvent({ EVENT.GAME_INIT }, function()
    require "vendor.third_party.UIManager.Utils"
    UIManager.Builder:new(require "Data.UIManagerNodes")
    require "src.runtime.ECA"
    current_game = GameplayLoop.NewGame(state)
    GameplayLoop.SetGame(state, current_game)
    UIEventRouter.Bind(state, function()
      return current_game
    end, {
      on_game_changed = function(new_game)
        current_game = new_game
      end,
    })

    local role = GameAPI.get_role(1)
    role.send_ui_custom_event("显示加载屏", {});
    BoardScene.Init(state, MapCfg)
    UIView.InitUiAssets(state)

    SetTimeOut(1.0, function()
      role.send_ui_custom_event("隐藏加载屏", {});
      role.send_ui_custom_event("显示基础屏", {});
    end)

    if not state.tick_started then
      state.tick_started = true
      _StartTickLoop(state)
    end
  end)
end

local function _StartTickLoop(state, interval)
  require "vendor.third_party.Utils"
  local tick_interval = interval or 1
  local tick_seconds = math.tofixed(tick_interval + 1) / 30.0
  SetFrameOut(tick_interval, function()
    GameplayLoop.Tick(current_game, state, tick_seconds)
  end, -1)
end

local state = _BuildState()
_InstallGameInit(state)
