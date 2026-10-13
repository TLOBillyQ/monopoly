local events = require("packages.test_runner.events")
local M = {}
function M.tap_handler_factory(options)
  local handler = { successes = {}, failures = {}, errors = {} }
  local counter = 0
  events.subscribe({ "test", "end" }, function(element, _, status, message)
    counter = counter + 1
    if status == "success" then
      handler.successes[#handler.successes + 1] = element
      io.write(("ok %d - %s\n"):format(counter, element.full_name or element.name))
    else
      local bucket = status == "error" and handler.errors or handler.failures
      bucket[#bucket + 1] = element
      io.write(("not ok %d - %s\n"):format(counter, element.full_name or element.name))
      local src = tostring(element.trace and element.trace.source or "?"):gsub("^@", "")
      io.write(("# %s @ %d\n"):format(src, element.trace and element.trace.currentline or 0))
      if message ~= nil then io.write("# Failure message: " .. tostring(message):gsub("\n", "\n# ") .. "\n") end
    end
    return nil, true
  end)
  events.subscribe({ "suite", "end" }, function()
    io.write(("1..%d\n"):format(counter))
    return nil, true
  end)
  return handler
end
return M
