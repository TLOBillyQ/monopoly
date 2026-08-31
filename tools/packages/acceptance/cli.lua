-- packages/acceptance/cli.lua —— acceptance 子命令(wayfinder #309 包内实现)
--
-- 统一接口形态(#300 决议):本文件 return 纯接口模块:
--   M.main(args, env) -> 退出码(0 成功 / 1 业务失败 / 2 用法错误)
--   M.usage()         -> 完整 usage 文本(包内单一真源,顶层 <cmd> --help 转发)
--
-- 实现:保持两步语义(先重生成 gitignored 的 generated
-- specs,再逐个 spawn 聚合),顺序转发包内两个入口(regenerate / run_all,
-- acceptance 包的数据面 + 驱动层 + 车道胶水）。
local M = {}

local REGENERATE_ENTRY = "tools/packages/acceptance/regenerate.lua"
local RUN_ALL_ENTRY = "tools/packages/acceptance/run_all.lua"

local function _shell_quote(value)
  local text = tostring(value or "")
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

-- 子进程转发:spawn 现状入口,退出码透传(入口自带 os.exit,语义即本包语义)。
local function _forward(entry, args)
  local parts = { "lua", entry }
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
    "用法: lua tools/cli.lua acceptance [args...]",
    "",
    "验收套件（按需车道）：先从 features/ 中文源重生成 gitignored 的 generated specs，",
    "再由 run_all 逐个 spawn 聚合。引擎核心由自研 acceptance4lua",
    "rock 由 tools/tools.lock 跟随上游主干并从 .toolcache/luarocks 装载，本包是数据面 + 驱动层 + 车道胶水。",
    "详细语义见 tools/packages/acceptance/ 与 `lua tools/cli.lua verify --help`。",
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
  local regenerated = _forward(REGENERATE_ENTRY, {})
  if regenerated ~= 0 then
    return regenerated
  end
  return _forward(RUN_ALL_ENTRY, {})
end

return M
