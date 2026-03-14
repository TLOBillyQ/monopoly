local app = require("src.game.core.runtime.game")
local gameplay_loop = require("src.turn.loop")
local map_cfg = require("src.config.content.maps.default_map")
local tiles_cfg = require("src.config.content.tiles")
local test_env = require("tests.support.test_env")
local default_ports = require("src.turn.output.default_ports")

local M = {}

local function noop()
end

local function build_ports()
  return {
    modal = {
      close_choice_modal = noop,
      open_choice_modal = noop,
      close_popup = noop,
    },
    anim = {
      play_move_anim = noop,
      play_action_anim = noop,
      reset_status_3d = noop,
      sync_status_3d = noop,
    },
    ui_sync = {
      apply_input_lock = noop,
      step_choice_timeout = noop,
      step_modal_timeout = noop,
      update_countdown = noop,
      build_model = function() return {} end,
      refresh_from_dirty = function() return false end,
      get_ui_state = function(state) return state and state.ui or nil end,
      is_input_blocked = function() return false end,
      is_popup_active = function() return false end,
      is_choice_active = function() return false end,
      is_market_active = function() return false end,
      get_popup_owner_index = function() return nil end,
      set_input_blocked = function() return false end,
    },
    debug = {
      log_status = noop,
      sync_debug_log = noop,
      resolve_debug_enabled = function() return false end,
    },
    state = {
      apply_role_control_lock = noop,
      install_event_handlers = noop,
      on_bankruptcy_tiles_cleared = noop,
    },
  }
end

function M.run()
  test_env.install_defaults()

  if not math.tofixed then
    function math.tofixed(value)
      return value
    end
  end

  if not SetFrameOut then
    function SetFrameOut(_, fn)
      if fn then
        fn()
      end
    end
  end

  GameAPI = GameAPI or {}
  if not GameAPI.random_int then
    math.randomseed(1)
    GameAPI.random_int = function(min, max)
      return math.random(min, max)
    end
  end

  test_env.refresh_runtime_context_for_tests({
    GameAPI = GameAPI,
    LuaAPI = LuaAPI,
    GlobalAPI = GlobalAPI,
    SetTimeOut = SetTimeOut,
    RegisterCustomEvent = RegisterCustomEvent,
    TriggerCustomEvent = TriggerCustomEvent,
  })

  local state = {
    ui = nil,
    ui_dirty = false,
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    board_last_phase = nil,
    next_turn_locked = false,
    next_turn_last_click = nil,
    next_turn_lock_phase = nil,
    role_control_lock_active = false,
    role_control_lock_suppress = 0,
    _log_once = {},
    gameplay_loop_ports = build_ports(),
    auto_runner = { set_enabled = noop, reset_timer = noop, next_action = function() end },
  }

  local ok, err = xpcall(function()
    local game = app:new(default_ports.resolve_game_opts({
      players = { "玩家1", "玩家2", "玩家3", "玩家4" },
      ai = {},
      auto_all = false,
      map = map_cfg,
      tiles = tiles_cfg,
    }))

    gameplay_loop.set_game(state, game)
    gameplay_loop.tick(game, state, 0.1)
  end, debug.traceback)

  if not ok then
    return { ok = false, error = err }
  end

  return { ok = true, message = "tick ok" }
end

function M.main()
  local result = M.run()
  if not result.ok then
    io.stderr:write("gameplay_loop_no_ui error: ", tostring(result.error), "\n")
    os.exit(1)
  end
  print(result.message)
end

if ... == nil then
  M.main()
else
  return M
end
