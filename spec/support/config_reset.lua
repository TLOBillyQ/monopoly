local M = {}

local _mutable_singleton_configs = {
  require("src.config.content.constants"),
  require("src.config.gameplay.debug_flags"),
}

function M.reset_all()
  for _, config in ipairs(_mutable_singleton_configs) do
    if type(config) == "table" and type(config.reset) == "function" then
      config.reset()
    end
  end
end

return M
