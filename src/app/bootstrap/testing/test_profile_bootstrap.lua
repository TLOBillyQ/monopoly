local test_profile_resolver = require("src.app.bootstrap.testing.test_profile_resolver")
local startup_bootstrap = require("src.app.bootstrap.startup_bootstrap")

local bootstrap = {}

function bootstrap.apply_bootstrap(game, cfg)
  return startup_bootstrap.apply_bootstrap(game, cfg)
end

function bootstrap.apply(game, profile_name)
  local cfg = test_profile_resolver.resolve_bootstrap(profile_name)
  return startup_bootstrap.apply_bootstrap(game, cfg)
end

return bootstrap
