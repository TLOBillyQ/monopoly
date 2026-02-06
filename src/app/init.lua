local app = require("src.v2.bootstrap.App")

local instance = app.new()
instance:start()

return instance
