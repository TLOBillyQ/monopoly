local logger = require("src.foundation.log.logger")
local tip_queue = require("src.foundation.coordination.tip_queue")
local timing = require("src.config.gameplay.timing")
local runtime_install = require("src.app.host_install")
local startup_roster = require("src.app.roster")
local state_factory = require("src.app.state_factory")
local runtime_event_bridge = require("src.app.event_bridge")
local ui_bootstrap = require("src.app.ui_bootstrap")
local gameplay_runtime_bootstrap = require("src.app.gameplay_start")
local gameplay_loop = require("src.turn.loop")
local startup_policy = require("src.app.policy")

local M = {}
local initialized = false
local current_game_ref = { nil }
local state = nil
local _globalapi_missing_warned = false

local function _is_test_mode_enabled()
  if type(logger.is_test_mode) ~= "function" then
    return false
  end
  local ok, enabled = pcall(logger.is_test_mode)
  if not ok then
    return false
  end
  return enabled == true
end

local function _configure_game_time_logger(game_api)
  if game_api ~= nil
      and type(game_api.get_timestamp) == "function"
      and type(game_api.get_hour) == "function"
      and type(game_api.get_minute) == "function"
      and type(game_api.get_second) == "function"
      and type(logger.configure_game_time) == "function" then
    logger.configure_game_time(game_api)
    return
  end
  if type(logger.reset_time_runtime) == "function" then
    logger.reset_time_runtime()
  end
end

local function _has_enabled_debug_role(enabled_by_role)
  for _, enabled in pairs(enabled_by_role or {}) do
    if enabled == true then
      return true
    end
  end
  return false
end

local function _resolve_anim_debug_roles(ctx_state)
  local ui = ctx_state and ctx_state.ui or nil
  local enabled_by_role = ui and ui.anim_debug_enabled_by_role or nil
  if type(enabled_by_role) ~= "table" then
    return nil
  end
  return enabled_by_role
end

local function _is_anim_debug_enabled()
  local enabled_by_role = _resolve_anim_debug_roles(state)
  if enabled_by_role == nil then
    return false
  end
  return _has_enabled_debug_role(enabled_by_role)
end

function M.init()
  if initialized then
    return state
  end

  tip_queue.configure_runtime({
    presenter = function(text, duration)
      if not (GlobalAPI and type(GlobalAPI.show_tips) == "function") then
        if not _globalapi_missing_warned then
          _globalapi_missing_warned = true
          logger.warn("[app]", "GlobalAPI.show_tips not available - tips will be dropped until host is ready")
        end
        return false
      end
      _globalapi_missing_warned = false
      return GlobalAPI.show_tips(text, duration)
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
    test_mode = _is_test_mode_enabled(),
    event_tip_fast_backlog_threshold = timing.event_tip_fast_backlog_threshold,
    event_tip_fast_seconds = timing.event_tip_fast_seconds,
  })

  _configure_game_time_logger(GameAPI)

  local startup = startup_policy.resolve(_G)
  local is_release = startup_policy.is_release
  if type(is_release) ~= "function" then
    is_release = function(resolved)
      return resolved ~= nil and resolved.build_mode == "release"
    end
  end
  if type(logger.set_enabled) == "function" then
    logger.set_enabled(not is_release(startup))
  end
  logger.info(
    "[Eggy]",
    "startup policy:",
    "build_mode=" .. tostring(startup.build_mode),
    "resolved_profile=" .. tostring(startup.profile_name),
    "profile_source=" .. tostring(startup.profile_source),
    "profile_module=" .. tostring(startup.profile_module)
  )

  runtime_install.install()
  local auto_runner = startup_roster.build_auto_runner()
  local function _get_current_game()
    return current_game_ref[1]
  end
  state = state_factory.build_state(_get_current_game, {
    profile_name = startup.profile_name,
    build_game_factory = function(child_state)
      return startup_roster.build_game_factory(child_state, {
        build_mode = startup.build_mode,
        profile_name = startup.profile_name,
        profile_source = startup.profile_source,
        profile_module = startup.profile_module,
      })
    end,
    auto_runner = auto_runner,
  })

  logger.set_anim_debug_enabled_provider(_is_anim_debug_enabled)
  state.on_game_replaced = function(new_game)
    current_game_ref[1] = new_game
    gameplay_loop.set_game(state, new_game)
  end

  runtime_event_bridge.install(state, function() return current_game_ref[1] end)
  ui_bootstrap.install(state, current_game_ref, {
    start_runtime = function(ctx_state, game_ref)
      return gameplay_runtime_bootstrap.start(ctx_state, game_ref)
    end,
  })

  initialized = true
  return state
end

return M
