require("tests.bootstrap")

local guard = require("guards.arch_view_guard")

if ... == nil then
  guard.main()
else
  return guard
end
