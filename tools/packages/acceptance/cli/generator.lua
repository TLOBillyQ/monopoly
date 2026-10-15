-- APS generator wrapper. Keeps the portable command shape
-- (`<json-ir> <generated-test-output>`; exit 2 on usage, 1 on failure) but binds
-- generated specs to the project runtime through
-- packages.acceptance.entrypoint (#132).
-- 自举三态(#114):网络/下载类装不上是环境不可用——退 3、stderr 打
-- status=unavailable tool=acceptance4lua step=<步>,不冒充生成失败;仓内缺陷照旧退 1。
local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")):match("^(.*)/[^/]+$") .. "/../../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)

local ensure = require("packages.acceptance.cli.ensure")

local cli = {}

-- 跑一次生成,不写终端:返回 { code, stdout, stderr }。
-- options.ensure_tool / options.generate_file 是注入缝,测试不碰网络、不起上游。
function cli.execute(options)
  options = options or {}
  local ensured = ensure.acceptance4lua(env, {
    ensure_tool = options.ensure_tool,
    tag = "acceptance-generator",
  })
  if ensured ~= true then
    return ensured
  end
  local args = options.args or {}
  if #args ~= 2 then
    return { code = 2, stdout = "",
      stderr = "usage: acceptance-entrypoint-generator <json-ir> <generated-test-output>\n" }
  end
  local generate_file = options.generate_file or require("packages.acceptance.entrypoint").generate_file
  local ok, err = generate_file(args[1], args[2])
  if not ok then
    return { code = 1, stdout = "", stderr = tostring(err) .. "\n" }
  end
  return { code = 0, stdout = "", stderr = "" }
end

function cli.main()
  local result = cli.execute({ args = arg or {} })
  io.stdout:write(result.stdout or "")
  io.stderr:write(result.stderr or "")
  os.exit(result.code)
end

if ... == "packages.acceptance.cli.generator" then
  return cli
end

cli.main()
