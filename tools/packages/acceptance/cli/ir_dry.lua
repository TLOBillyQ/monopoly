-- APS IR-DRY checker wrapper. Keeps the portable command shape
-- (`<json-ir> <report-output>`; optional `--include-exact`; exit 2 on usage,
-- 1 on failure) and forwards to the pinned acceptance4lua rock, binding the
-- tool to the project luarocks tree through bootstrap.ensure_tool. Same shape
-- as cli/parser.lua; consumed by the PATH tool `ir-dry-checker` (# APS Lua 迁移).
local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
assert(bootstrap.ensure_tool("acceptance4lua", env))

os.exit(require("acceptance4lua.cli.ir_dry").main(arg or {}))
