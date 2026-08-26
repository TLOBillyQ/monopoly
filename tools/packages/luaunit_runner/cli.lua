-- packages/luaunit_runner/cli.lua —— luaunit_runner 包内接口形态(#305 包迁)
--
-- 统一接口形态(#300 决议):本文件 return 纯接口模块:
--   M.main(args, env) -> 退出码(0 成功 / 1 业务失败 / 2 用法错误)
--   M.usage()         -> 完整 usage 文本(包内单一真源)
--
-- 顶层 tools/cli.lua 的封闭命令表**无** luaunit_runner 命令：
-- luaunit_runner 是底层运行器,不是用户子命令。本 cli 是接口形态,供
-- verify/coverage/spec_lane 等包内消费(require("packages.luaunit_runner.cli")
-- 后调用 main/usage),不接顶层路由。
--
-- 实现:转发到本包 runner.lua(经 lua54.lua 的 argv_prefix 拿
-- { lua5.4 解释器, runner.lua 绝对路径 }),退出码透传。
local M = {}

local lua54 = require("packages.luaunit_runner.lua54")

local function _shell_quote(value)
  local text = tostring(value or "")
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

-- 子进程转发:spawn lua5.4 runner.lua <args>,退出码透传。
local function _forward(args)
  local parts = {}
  for _, token in ipairs(lua54.argv_prefix()) do
    parts[#parts + 1] = _shell_quote(token)
  end
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
    "用法: lua tools/packages/luaunit_runner/runner.lua [--run <profile>|--helper=<path>|--output=<TAP|path>|--pattern=<pat>|-- <files...>]",
    "",
    "LuaUnit 3.5 spec 运行器：加载并收集 Test* 类 / test* 函数，",
    "一次跑完并输出 TAP。无 --run 时回退 spec_profiles default profile。",
    "本 cli 不接顶层 tools/cli.lua 路由(封闭命令集无 luaunit_runner 命令),",
    "是 verify/coverage/spec_lane 内部消费的接口形态。",
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
