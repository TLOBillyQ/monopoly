local logger = require("src.core.utils.logger")
local runtime_install = require("src.app.bootstrap.runtime")
local game_startup = require("src.app.bootstrap.game_startup")
local game_startup_event_bridge = require("src.app.bootstrap.game_startup_event_bridge")
local game_runtime_bootstrap = require("src.app.bootstrap.game_runtime_bootstrap")
local ui_bootstrap = require("src.app.bootstrap.ui_bootstrap")
local startup_policy = require("src.app.bootstrap.startup_policy")
local gameplay_rules = require("src.core.config.gameplay_rules")

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

-- current_game_ref[1] 由 UIBootstrap 在 GAME_INIT 后赋值
local current_game_ref = { nil }

local startup = startup_policy.resolve(_G)
logger.info(
  "[Eggy]",
  "startup policy:",
  "release_mode=" .. tostring(startup.release_mode),
  "release_allow_test_profile=" .. tostring(startup.release_allow_test_profile),
  "resolved_profile=" .. tostring(startup.profile_name),
  "ai_mode=" .. tostring(startup.ai_mode),
  "local_human_role_id=" .. tostring(startup.local_human_role_id)
)
if startup.release_mode then
  gameplay_rules.debug_log_enabled = false
end

runtime_install.install()
local state = game_startup.build_state(function() return current_game_ref[1] end, {
  profile_name = startup.profile_name,
  ai_mode = startup.ai_mode,
  local_human_role_id = startup.local_human_role_id,
  release_mode = startup.release_mode,
  force_non_p1_ai = startup.force_non_p1_ai,
  fail_fast_when_roles_empty = startup.fail_fast_when_roles_empty,
})

local function _is_debug_log_enabled()
  local ui = state and state.ui or nil
  local enabled_by_role = ui and ui.debug_log_enabled_by_role or nil
  if type(enabled_by_role) ~= "table" then
    return false
  end
  for _, enabled in pairs(enabled_by_role) do
    if enabled == true then
      return true
    end
  end
  return false
end

logger.set_event_collection_enabled_provider(_is_debug_log_enabled)
logger.set_anim_debug_enabled_provider(_is_debug_log_enabled)
game_startup_event_bridge.install(state, function() return current_game_ref[1] end)
ui_bootstrap.install(state, current_game_ref, {
  start_runtime = function(ctx_state, game_ref)
    return game_runtime_bootstrap.start(ctx_state, game_ref)
  end,
})
