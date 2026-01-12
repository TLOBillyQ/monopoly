local logger = require("src.util.logger")

local Errors = {}

function Errors.missing_service(name)
  logger.warn("缺少 " .. name .. "，跳过处理")
end

return Errors
