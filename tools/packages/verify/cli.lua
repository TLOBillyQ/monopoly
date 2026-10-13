-- packages/verify/cli.lua —— verify 子命令(wayfinder #307 包内实现)
--
-- 统一接口形态(#300 决议):本文件 return 纯接口模块:
--   M.main(args, env) -> 退出码(0 成功 / 1 业务失败 / 2 用法错误)
--   M.usage()         -> 完整 usage 文本(包内单一真源,顶层 <cmd> --help 转发)
--
-- 实现:子进程转发包内编排入口 main.lua(原 tools/quality/verify_full.lua,
-- #307 包迁后入口随包),flag 解析与 os.exit 语义原样住入口,退出码透传。
local M = {}

local ENTRY = "tools/packages/verify/main.lua"

-- 原生 argv 转发，与 foundation 的 cmd quoting 保持单一真源。
local function _forward(args)
  require("test.bootstrap").install_package_paths()
  local proc = require("foundation.proc")
  local lua54 = require("packages.luaunit_runner.lua54")
  local command = { lua54.lua54_bin(), ENTRY }
  for _, value in ipairs(args or {}) do
    command[#command + 1] = value
  end
  local result = proc.run_command(command)
  io.write(result.output or "")
  return result.code or (result.ok and 0 or 1)
end

function M.usage()
  return table.concat({
    "用法: lua tools/cli.lua verify [--serial|--parallel|--full|--coverage|--crap|--tooling|--verbose|--no-coverage]",
    "",
    "质量门禁编排器:默认 slim 车道(contract + guards + arch + behavior 七层 + foundation",
    "+ lint-src/lint-test/lint-tools + encoding),是迭代默认与 push 前唯一硬地板。",
    "",
    "flag 映射:",
    "  --serial       所有车道及其测试子进程按序执行(原生 Windows 默认)",
    "  --parallel     原生 start /b 后台并行；Job Object超时停止自有进程树",
    "                 首次会话用gcc编译项目原生helper；空输出按失败计",
    "  (默认)         slim:七层 + foundation 行为 spec 全跑",
    "  --full         slim + coverage + crap(完整报告,按需)",
    "  --coverage     显式加 coverage 并行 lane(只看覆盖率)",
    "  --crap         显式补 crap_collect → crap → crap_gate 两步(只看 CRAP)",
    "  --tooling      正交叠加 tooling 并行 lane(改 tools/** 时)",
    "  --no-coverage  silent no-op(向后兼容;coverage 默认 opt-out)",
    "  --verbose      展开各 lane 明细",
    "",
    "挑选提示:",
    "  - 默认 verify 已剥离 coverage + crap;需要完整报告时显式 --full,",
    "    或分别 --coverage / --crap。",
    "  - property 独立车道已退场(#190):两个道具时机 fuzz 探针",
    "    (test/behavior/rules/items/test_item_timing_fuzz.lua、",
    "    test/behavior/turn/test_item_timing_loop_fuzz.lua)随默认 verify 跑",
    "    (400 seeds;MONOPOLY_FUZZ_SEEDS 可放大做 soak,FUZZ_ONLY_SEED=<n> 单 seed 复放)。",
    "  - 红车道 → 看 `[verify] FAIL <lane>` 行,按 lane 名下钻",
    "    (spec-lane --profile <目录> 或单文件)。",
    "",
    "pipeline 不包含(按需走单工具):mutate / dry / arch-view / crap report / acceptance;",
    "acceptance 需单独 `lua tools/cli.lua acceptance`,dry 与 acceptance-mutate 是软车道,",
    "且当前按 POSIX 专用能力声明:原生 Windows 上请求退 3(status=unavailable),",
    "不在 slim / --tooling / acceptance 这些最低保证面内(#96 / ADR 0066)。",
    "真源:tools/packages/verify/(main.lua / lane_builders.lua / lanes.lua)。",
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
