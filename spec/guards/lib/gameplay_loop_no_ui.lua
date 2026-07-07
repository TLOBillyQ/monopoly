local composition_root = require("src.app.compose_game")
local gameplay_loop = require("src.turn.loop")
local map_cfg = require("src.config.content.default_map")
local tiles_cfg = require("src.config.content.tiles")
local test_env = require("spec.support.test_env")
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
      -- 无 UI 环境：gate 恒全关，与下方 is_* 存根一致（提供门控查询
      -- override 时必须同时提供 resolve_ui_gate，见 ui_sync_defaults 契约）。
      -- 本 guard 禁 require src.ui.*，故内联字面 gate 而非复用 gate 模块。
      resolve_ui_gate = function()
        return {
          input_blocked = false,
          choice_active = false,
          market_active = false,
          popup_active = false,
        }
      end,
      is_input_blocked = function() return false end,
      is_popup_active = function() return false end,
      is_choice_active = function() return false end,
      is_market_active = function() return false end,
      get_popup_owner_index = function() return nil end,
      set_input_blocked = function() return false end,
    },
    debug = {
      log_status = noop,
      sync_event_log = noop,
      resolve_event_log_enabled = function() return false end,
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
    local game = composition_root.new_game(default_ports.resolve_game_opts({
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

return M
