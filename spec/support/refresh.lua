local env_runtime = require("spec.env_runtime")

local M = {}

function M.before_each_in(env)
  local before_each = assert(env and env.before_each, "missing before_each")
  before_each(function()
    math.randomseed(1)
    env_runtime.refresh()
  end)
end

return M
