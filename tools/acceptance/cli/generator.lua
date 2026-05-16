local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../../shared/bootstrap.lua")
bootstrap.install(debug.getinfo(1, "S").source)

local generator = require("acceptance.generator")

if #arg ~= 2 then
  io.stderr:write("usage: acceptance-generator <json-ir> <generated-test-output>\n")
  os.exit(2)
end

local ok, err = generator.generate_file(arg[1], arg[2])
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  os.exit(1)
end

os.exit(0)
