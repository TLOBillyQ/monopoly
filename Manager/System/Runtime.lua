local Entry = require("Manager.GameManager.Entry")

local EggyRuntime = {}

function EggyRuntime.install()
  return Entry.install()
end

return EggyRuntime

