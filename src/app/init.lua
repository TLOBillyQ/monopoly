local logger = require("src.core.Logger")
local runtime_install = require("src.app.bootstrap.RuntimeInstall")
local game_startup = require("src.app.bootstrap.GameStartup")
local game_startup_event_bridge = require("src.app.bootstrap.GameStartupEventBridge")
local game_runtime_bootstrap = require("src.app.bootstrap.GameRuntimeBootstrap")
local ui_bootstrap = require("src.app.bootstrap.UIBootstrap")

logger.configure_game_time()

-- current_game_ref[1] 由 UIBootstrap 在 GAME_INIT 后赋值
local current_game_ref = { nil }

local function _resolve_startup_profile_name()
  local profile = rawget(_G, "STARTUP_TEST_PROFILE")
  if type(profile) == "string" and profile ~= "" then
    return profile
  end
  return "default"
end

runtime_install.install()
local state = game_startup.build_state(function() return current_game_ref[1] end, {
  profile_name = _resolve_startup_profile_name(),
})
game_startup_event_bridge.install(state, function() return current_game_ref[1] end)
ui_bootstrap.install(state, current_game_ref, {
  start_runtime = function(ctx_state, game_ref)
    return game_runtime_bootstrap.start(ctx_state, game_ref)
  end,
})
