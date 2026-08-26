local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
assert(bootstrap.ensure_tool("acceptance4lua", env))

-- acceptance4lua 的 mutator 生成 entrypoint 时 step 模块默认是中性的 "steps";
-- 本项目的 step handlers 在 packages.acceptance.steps,调用方未显式指定时由
-- 这里补上,与 packages.acceptance.entrypoint 的生成绑定保持一致。
local args = arg or {}
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

os.exit(require("acceptance4lua.cli.mutator").main(args))
