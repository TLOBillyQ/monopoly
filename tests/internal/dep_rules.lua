require("tests.bootstrap")

local guard = require("guards.dep_rules")

if ... == nil then
  guard.main()
else
  return guard
end
