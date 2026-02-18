local logger = require("src.core.Logger")
local runtime_install = require("src.app.bootstrap.RuntimeInstall")
local game_startup = require("src.app.bootstrap.GameStartup")
local ui_bootstrap = require("src.app.bootstrap.UIBootstrap")

logger.configure_game_time()

-- current_game_ref[1] 由 UIBootstrap 在 GAME_INIT 后赋值
local current_game_ref = { nil }

runtime_install.install()
local state = game_startup.build_state(function() return current_game_ref[1] end)
ui_bootstrap.install(state, current_game_ref)
