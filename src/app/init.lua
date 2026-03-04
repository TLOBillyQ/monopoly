local logger = require("src.core.Logger")
local runtime_install = require("src.app.bootstrap.RuntimeInstall")
local game_startup = require("src.app.bootstrap.GameStartup")
local game_startup_event_bridge = require("src.app.bootstrap.GameStartupEventBridge")
local game_runtime_bootstrap = require("src.app.bootstrap.GameRuntimeBootstrap")
local ui_bootstrap = require("src.app.bootstrap.UIBootstrap")
local startup_policy = require("src.app.bootstrap.StartupPolicy")
local gameplay_rules = require("src.core.config.GameplayRules")

logger.configure_game_time()

-- current_game_ref[1] 由 UIBootstrap 在 GAME_INIT 后赋值
local current_game_ref = { nil }

local startup = startup_policy.resolve(_G)
if startup.release_mode then
  gameplay_rules.debug_log_enabled = false
end

runtime_install.install()
local state = game_startup.build_state(function() return current_game_ref[1] end, {
  profile_name = startup.profile_name,
  release_mode = startup.release_mode,
  force_non_p1_ai = startup.force_non_p1_ai,
  fail_fast_when_roles_empty = startup.fail_fast_when_roles_empty,
})
game_startup_event_bridge.install(state, function() return current_game_ref[1] end)
ui_bootstrap.install(state, current_game_ref, {
  start_runtime = function(ctx_state, game_ref)
    return game_runtime_bootstrap.start(ctx_state, game_ref)
  end,
})
