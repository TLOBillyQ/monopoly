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

local function _forward(entry, args)
  require("test.bootstrap").install_package_paths()
  local parts = { require("packages.luaunit_runner.lua54").lua54_bin(), entry }
  for _, value in ipairs(args or {}) do parts[#parts + 1] = value end
  local result = require("foundation.proc").run_command(parts)
  io.write(result.output or "")
  return result.code or (result.ok and 0 or 1)
end

function M.usage()
  return table.concat({
    "用法: lua tools/cli.lua acceptance [--serial|--parallel|--capabilities]",
    "默认串行；--parallel 使用原生 cmd 并行并按注册顺序汇总，空结果失败。",
    "start /b启动Windows PowerShell；内置.NET Add-Type/PInvoke Job Object收容自有子树。",
    "--capabilities: 列出注册/执行/排除集合;Windows 默认排除 capability=acceptance-mutate 的真实 feature,不计为通过。",
    "",
    "验收套件（按需车道）：先从 features/ 中文源重生成 gitignored 的 generated specs，",
    "再由真实 busted 执行场景/例子并以 JSON 汇总；生成物没有独立 harness。解析器来自 acceptance4lua",
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
  for index, value in ipairs(args or {}) do
    if value == "--feature" then
      require("test.bootstrap").install_package_paths()
      local registry = require("packages.acceptance.acceptance_features")
      for _, entry in ipairs(registry.entries) do
        if entry.feature == args[index + 1] and entry.capability then
          local boundary = require("foundation.platform_boundary")
          local verdict = boundary.evaluate(entry.capability, {})
          if verdict.status then
            io.stderr:write("[acceptance] requested feature=" .. entry.feature .. " generated=" .. entry.generated .. "\n")
            return boundary.emit(verdict)
          end
        end
      end
      io.stderr:write("use explicit parser/generator entrypoints for single-feature requests\n")
      return 2
    elseif value == "--capabilities" then
      require("test.bootstrap").install_package_paths()
      require("packages.acceptance.acceptance_features").select(function(line) io.write(line .. "\n") end)
      return 0
    elseif value ~= "--serial" and value ~= "--parallel" then
      io.stderr:write("unknown option: " .. value .. "\n")
      return 2
    end
  end
  local regenerated = _forward(REGENERATE_ENTRY, {})
  if regenerated ~= 0 then
    return regenerated
  end
  return _forward(RUN_ALL_ENTRY, args)
end

return M
