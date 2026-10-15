-- APS IR-DRY checker wrapper. Keeps the portable command shape
-- (`<json-ir> <report-output>`; optional `--include-exact`; exit 2 on usage,
-- 1 on failure) and forwards to the pinned acceptance4lua rock, binding the
-- tool to the project luarocks tree through bootstrap.ensure_tool. Same shape
-- as cli/parser.lua; invoked explicitly with Lua and this script's path.
-- 自举三态(#114):网络/下载类装不上是环境不可用——退 3、stderr 打
-- status=unavailable tool=acceptance4lua step=<步>,不冒充检查失败;仓内缺陷照旧退 1。
local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")):match("^(.*)/[^/]+$") .. "/../../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)

local ensure = require("packages.acceptance.cli.ensure")

local cli = {}

-- 跑一次 IR-DRY,不写终端(上游 main 自己写 usage/诊断):返回 { code, stdout, stderr }。
-- options.ensure_tool / options.upstream_main 是注入缝,测试不碰网络、不起上游。
function cli.execute(options)
  options = options or {}
  local ensured = ensure.acceptance4lua(env, {
    ensure_tool = options.ensure_tool,
    tag = "acceptance-ir-dry",
  })
  if ensured ~= true then
    return ensured
  end
  local upstream_main = options.upstream_main or require("acceptance4lua.cli.ir_dry").main
  return { code = upstream_main(options.args or {}), stdout = "", stderr = "" }
end

function cli.main()
  local result = cli.execute({ args = arg or {} })
  io.stdout:write(result.stdout or "")
  io.stderr:write(result.stderr or "")
  os.exit(result.code)
end

if ... == "packages.acceptance.cli.ir_dry" then
  return cli
end

cli.main()
