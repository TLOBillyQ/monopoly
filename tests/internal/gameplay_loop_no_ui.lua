require("tests.bootstrap")

local guard = require("guards.gameplay_loop_no_ui")

if ... == nil then
  guard.main()
else
  return guard
end
