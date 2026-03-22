local logger = require("src.core.utils.logger")
local runtime_install = require("src.app.bootstrap.runtime_install")
local startup_roster = require("src.app.bootstrap.startup_roster")
local state_factory = require("src.presentation.runtime.state_factory")
local runtime_event_bridge = require("src.presentation.runtime.event_bridge")
local ui_bootstrap = require("src.presentation.runtime.ui_bootstrap")
local gameplay_runtime_bootstrap = require("src.presentation.runtime.gameplay_runtime_bootstrap")
local gameplay_loop = require("src.turn.loop")
local startup_policy = require("src.app.bootstrap.startup_policy")

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

local current_game_ref = { nil }
local startup = startup_policy.resolve(_G)
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
local state = state_factory.build_state(_get_current_game, {
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

local function _has_enabled_debug_role(enabled_by_role)
  for _, enabled in pairs(enabled_by_role or {}) do
    if enabled == true then
      return true
    end
  end
  return false
end

local function _resolve_debug_log_roles(ctx_state)
  local ui = ctx_state and ctx_state.ui or nil
  local enabled_by_role = ui and ui.debug_log_enabled_by_role or nil
  if type(enabled_by_role) ~= "table" then
    return nil
  end
  return enabled_by_role
end

local function _is_debug_log_enabled()
  local enabled_by_role = _resolve_debug_log_roles(state)
  if enabled_by_role == nil then
    return false
  end
  return _has_enabled_debug_role(enabled_by_role)
end

logger.set_event_collection_enabled_provider(_is_debug_log_enabled)
logger.set_anim_debug_enabled_provider(_is_debug_log_enabled)
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
