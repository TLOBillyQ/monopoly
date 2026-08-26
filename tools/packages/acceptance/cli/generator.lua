-- APS generator wrapper. Keeps the portable command shape
-- (`<json-ir> <generated-test-output>`; exit 2 on usage, 1 on failure) but binds
-- generated specs to the project runtime through
-- packages.acceptance.entrypoint (#132).
local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
assert(bootstrap.ensure_tool("acceptance4lua", env))

local entrypoint = require("packages.acceptance.entrypoint")

local args = arg or {}
if #args ~= 2 then
  io.stderr:write("usage: acceptance-entrypoint-generator <json-ir> <generated-test-output>\n")
  os.exit(2)
end

local ok, err = entrypoint.generate_file(args[1], args[2])
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  os.exit(1)
end
os.exit(0)
