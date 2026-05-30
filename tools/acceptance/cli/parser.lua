local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../../shared/bootstrap.lua")
bootstrap.install(debug.getinfo(1, "S").source)

os.exit(require("acceptance4lua.cli.parser").main(arg or {}))
