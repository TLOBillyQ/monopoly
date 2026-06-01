local logger = require("src.foundation.log")
local tip_queue = require("src.foundation.tips")
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

local _GAME_TIME_METHODS = { "get_timestamp", "get_hour", "get_minute", "get_second" }

local function _has_game_time_api(game_api)
  if type(game_api) ~= "table" then return false end
  if type(logger.configure_game_time) ~= "function" then return false end
  for _, name in ipairs(_GAME_TIME_METHODS) do
    if type(game_api[name]) ~= "function" then return false end
  end
  return true
end

local function _configure_game_time_logger(game_api)
  if _has_game_time_api(game_api) then
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

local function _show_warn_in_ui(text)
  if type(GlobalAPI.show_message_marquee) == "function" then
    pcall(GlobalAPI.show_message_marquee, text)
  elseif type(GlobalAPI.show_tips) == "function" then
    pcall(GlobalAPI.show_tips, text, 3.0)
  end
end

local function _ui_warn_sink(entry)
  if entry == nil or entry.level ~= "warn" then return end
  if type(GlobalAPI) ~= "table" then return end
  _show_warn_in_ui("[warn] " .. tostring(entry.text or ""))
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

  if type(logger.set_ui_sink) == "function" then
    logger.set_ui_sink(_ui_warn_sink)
  end

  if not is_release(startup) and type(GlobalAPI) == "table" then
    if type(GlobalAPI.show_tips) == "function" then
      pcall(GlobalAPI.show_tips, "[ping] show_tips 自检", 3.0)
    end
    if type(GlobalAPI.show_message_marquee) == "function" then
      pcall(GlobalAPI.show_message_marquee, "[ping] marquee 自检")
    end
  end

  logger.info(
    "[Eggy]",
    "startup policy:",
    "build_mode=" .. tostring(startup.build_mode),
    "resolved_profile=" .. tostring(startup.profile_name)
  )

  local function _get_current_game()
    return current_game_ref[1]
  end
  -- Sign-in RewardDay events are global host events resolved at fire time, so the
  -- install hands host_install lazy accessors for the (not-yet-built) game and state.
  runtime_install.install({
    get_current_game = _get_current_game,
    get_app_state = function() return state end,
  })
  local auto_runner = startup_roster.build_auto_runner()
  state = state_factory.build_state(_get_current_game, {
    profile_name = startup.profile_name,
    build_game_factory = function(child_state)
      return startup_roster.build_game_factory(child_state, {
        build_mode = startup.build_mode,
        profile_name = startup.profile_name,
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

--[[ mutate4lua-manifest
version=2
projectHash=55bb7934ef8786f1
scope.0.id=chunk:src/app/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=190
scope.0.semanticHash=7e8649b1173c3c91
scope.1.id=function:_is_test_mode_enabled:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=28
scope.1.semanticHash=2b9c9d24465f8d5f
scope.2.id=function:_configure_game_time_logger:41
scope.2.kind=function
scope.2.startLine=41
scope.2.endLine=49
scope.2.semanticHash=5fd377858bffcb0b
scope.3.id=function:_resolve_anim_debug_roles:60
scope.3.kind=function
scope.3.startLine=60
scope.3.endLine=67
scope.3.semanticHash=d7e6b1456de95e99
scope.4.id=function:_is_anim_debug_enabled:69
scope.4.kind=function
scope.4.startLine=69
scope.4.endLine=75
scope.4.semanticHash=2eb4dd158b166ab9
scope.5.id=function:_show_warn_in_ui:77
scope.5.kind=function
scope.5.startLine=77
scope.5.endLine=83
scope.5.semanticHash=bcab47a1d52ddcfb
scope.6.id=function:_ui_warn_sink:85
scope.6.kind=function
scope.6.startLine=85
scope.6.endLine=89
scope.6.semanticHash=fb10f4498fc96f61
scope.7.id=function:anonymous@97:97
scope.7.kind=function
scope.7.startLine=97
scope.7.endLine=107
scope.7.semanticHash=848367feadcedab9
scope.8.id=function:anonymous@108:108
scope.8.kind=function
scope.8.startLine=108
scope.8.endLine=117
scope.8.semanticHash=9e3247301a8ea581
scope.9.id=function:anonymous@128:128
scope.9.kind=function
scope.9.startLine=128
scope.9.endLine=130
scope.9.semanticHash=a259c560c0e2739b
scope.10.id=function:_get_current_game:158
scope.10.kind=function
scope.10.startLine=158
scope.10.endLine=160
scope.10.semanticHash=dbfdcbbc211a026a
scope.11.id=function:anonymous@163:163
scope.11.kind=function
scope.11.startLine=163
scope.11.endLine=168
scope.11.semanticHash=cf6827f40146586d
scope.12.id=function:anonymous@173:173
scope.12.kind=function
scope.12.startLine=173
scope.12.endLine=176
scope.12.semanticHash=47694711620eaab4
scope.13.id=function:anonymous@178:178
scope.13.kind=function
scope.13.startLine=178
scope.13.endLine=178
scope.13.semanticHash=c9f720fc309e2af6
scope.14.id=function:anonymous@180:180
scope.14.kind=function
scope.14.startLine=180
scope.14.endLine=182
scope.14.semanticHash=aa49fbcfe98b268e
scope.15.id=function:M.init:91
scope.15.kind=function
scope.15.startLine=91
scope.15.endLine=187
scope.15.semanticHash=ad73805a99394238
]]
