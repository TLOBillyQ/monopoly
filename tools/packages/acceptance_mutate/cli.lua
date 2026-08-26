-- packages/acceptance_mutate/cli.lua —— acceptance-mutate 子命令
-- (wayfinder #310 包内实现)
--
-- 统一接口形态(#300 决议):本文件 return 纯接口模块:
--   M.main(args, env) -> 退出码(0 成功 / 1 业务失败 / 2 用法错误)
--   M.usage()         -> 完整 usage 文本(包内单一真源,顶层 <cmd> --help 转发)
--
-- 实现：转发到包内软车道入口 mutate_lane.lua（与 mutate
-- 并列的独立软车道;mutator 薄壳 mutator.lua 同住本包)。
local M = {}

local ENTRY = "tools/packages/acceptance_mutate/mutate_lane.lua"

local function _shell_quote(value)
  local text = tostring(value or "")
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

-- 子进程转发:spawn 现状入口,退出码透传(入口自带 os.exit,语义即本包语义)。
local function _forward(args)
  local parts = { "lua", ENTRY }
  for _, value in ipairs(args or {}) do
    parts[#parts + 1] = _shell_quote(value)
  end
  local ok, how, code = os.execute(table.concat(parts, " "))
  if how == "exit" then
    return code or (ok and 0 or 1)
  end
  return 1
end

function M.usage()
  return table.concat({
    "用法: lua tools/cli.lua acceptance-mutate [args...]",
    "",
    "验收突变软车道（与 mutate / dry 同级）：对验收数据面跑",
    "变异,选项经 args 直通(如 --level soft / --feature <feature>)。",
    "详细语义见 tools/packages/acceptance_mutate/mutate_lane.lua。",
    "",
  }, "\n") .. "\n"
end

function M.main(args, env)
  for _, value in ipairs(args or {}) do
    if value == "--help" or value == "-h" then
      io.write(M.usage())
      return 0
    end
  end
  return _forward(args)
end

return M
