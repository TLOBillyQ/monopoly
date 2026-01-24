require('src.bootstrap')()

local Entry = require("src.entry")
local runtime = Entry.run({ platform = "oasis" })
if runtime then
  _G.OasisRuntime = runtime
end
