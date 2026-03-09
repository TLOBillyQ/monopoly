require("tests.bootstrap")

local guard = require("guards.legacy_path_guard")

if ... == nil then
  guard.main()
else
  return guard
end
