local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../../shared/bootstrap.lua")
bootstrap.install(debug.getinfo(1, "S").source)

local gherkin_parser = require("acceptance.gherkin_parser")

if #arg ~= 2 then
  io.stderr:write("usage: gherkin-parser <feature-file> <json-output>\n")
  os.exit(2)
end

local ok, err = gherkin_parser.write_json_file(arg[1], arg[2])
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  os.exit(1)
end

os.exit(0)
