local M = {}

local function _app_bootstrap()
  return require("src." .. "app")
end

function M.install()
  return _app_bootstrap().init()
end

return M
