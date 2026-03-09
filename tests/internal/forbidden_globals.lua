require("tests.bootstrap")

local guard = require("guards.forbidden_globals")

if ... == nil then
  guard.main()
else
  return guard
end
