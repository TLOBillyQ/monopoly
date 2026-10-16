local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")):match("^(.*)/[^/]+$") .. "/../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
local args = arg or {}
local usage = "usage: gherkin-mutator --feature <path> --runner-worker <command> [--work-dir <path>] [--steps-module <name>] [--workers <count>] [--timeout <duration>] [--status-interval <duration>] [--level full|hard|soft] [--skip-columns <names>] [--implementation-hash <hash>] [--json] [--verbose]\n"
local help = false
for _, value in ipairs(args) do
  if value == "--help" or value == "-h" then help = true end
end
if help or #args == 0 then
  io.write(usage)
  io.write("原生 Windows 支持;工具自举不可用退 3。\n")
  os.exit(help and 0 or 2)
end
local boundary = require("foundation.platform_boundary")
local forwarded = {}
for _, value in ipairs(args) do
  if value ~= boundary.SKIP_FLAG then forwarded[#forwarded + 1] = value end
end
args = forwarded
local ensured = require("packages.acceptance.cli.ensure").acceptance4lua(env, { tag = "acceptance-mutator" })
if ensured ~= true then
  io.stderr:write(ensured.stderr or "")
  os.exit(ensured.code)
end

-- acceptance4lua 的 mutator 生成 entrypoint 时 step 模块默认是中性的 "steps";
-- 本项目的 step handlers 在 packages.acceptance.steps,调用方未显式指定时由
-- 这里补上,与 packages.acceptance.entrypoint 的生成绑定保持一致。
local has_steps_module = false
for _, value in ipairs(args) do
  if value == "--steps-module" or tostring(value):match("^%-%-steps%-module=") ~= nil then
    has_steps_module = true
    break
  end
end
if not has_steps_module then
  local merged = { "--steps-module", "packages.acceptance.steps" }
  for _, value in ipairs(args) do
    merged[#merged + 1] = value
  end
  args = merged
end

-- 经正式适配接口复用项目的原生 Windows Job 车道。
os.exit(require("acceptance4lua.cli.mutator").main(args, {
  parallel_run = function(lanes, options)
    local ok, results = require("foundation.parallel_lanes").run(lanes, options)
    return ok, nil, results
  end,
}))
