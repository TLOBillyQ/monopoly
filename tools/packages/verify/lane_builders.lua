-- verify 的车道表:default(七层 + foundation 全跑,coverage / crap 按需挂载)。
-- 选哪张由 lanes.resolve 决定,这里只负责造表。
local shell_lib = require("foundation.shell")

local builders = {}

-- spec-lane 车道默认后端 = LuaUnit 运行器
-- (packages.luaunit_runner.lua54.argv_prefix)。--busted-bin / BUSTED_BIN
-- 逃生舱已删,verify_full 不注入任何覆写。
local function _spec_lane_cmd(profile)
  return shell_lib.build_command({
    "lua",
    "tools/packages/spec_lane/spec_lane.lua",
    "--profile",
    profile,
  })
end

-- lint 要 luacheck + lua5.4 两者俱在,缺任一就跳过而不是让车道变红。
-- #449: lint 按目录拆三条并行子车道(lint-src / lint-test / lint-tools),
-- 每条独立报 PASS/FAIL、可按 lane 名下钻;即便 luacheck 单进程回退
-- (LuaLanes 缺失),车道级并行也能把 wall 压进 slim 预算。
local LINT_TARGETS = { "src", "test", "tools" }

local function _add_lint_or_skip(lanes, skipped, env)
  if env.luacheck_available == true and env.lua54_bin then
    for _, target in ipairs(LINT_TARGETS) do
      lanes[#lanes + 1] = {
        label = "lint-" .. target,
        cmd = shell_lib.build_command({ env.lua54_bin, "tools/packages/lint/runner.lua", target }),
      }
    end
  else
    for _, target in ipairs(LINT_TARGETS) do
      skipped[#skipped + 1] = "lint-" .. target
    end
  end
end

-- behavior 与 crap_collect 并行编排：两者
-- in parallel. behavior keeps test/log_warns_handler.lua's warn-summary
-- diagnostic in verify_full output; crap_collect produces the coverage data
-- the post-parallel analyze step turns into crap_report.json without
-- re-running the 2305 tests sequentially.
function builders.default(env, include_tooling, include_coverage, include_crap)
  local lanes, skipped = {}, {}
  lanes[#lanes + 1] = { label = "contract", cmd = _spec_lane_cmd("contract") }
  lanes[#lanes + 1] = { label = "guards", cmd = _spec_lane_cmd("guards") }
  lanes[#lanes + 1] = { label = "arch", cmd = "lua tools/packages/arch_view/runner.lua check" }
  lanes[#lanes + 1] = { label = "behavior", cmd = "lua test/support/behavior_parallel.lua" }
  _add_lint_or_skip(lanes, skipped, env)
  lanes[#lanes + 1] = { label = "encoding", cmd = "lua tools/packages/encoding/encoding.lua check" }
  -- property 车道已退场(测试极简化决策/monopoly#190):道具时机 fuzz 探针分片并入
  -- behavior 车道并行吸收,默认 verify 就跑得到,不再需要独立入口。
  if include_tooling then
    lanes[#lanes + 1] = {
      label = "tooling",
      cmd = "lua test/support/behavior_parallel.lua --profile tooling",
    }
  end
  -- coverage 与 crap 默认 opt-out（cleaner/architect owns the
  -- long-running lanes). Default verify stays slim.
  -- collect 进程内 adapter 顶层 require("cluacov.hook")（5.4 ABI 的
  -- .so),PATH 上的 lua 可能是 5.5,加载即崩(实测 exit 139)。与 coverage 车道
  -- 同口径钉 env.lua54_bin;探不到时整条跳过(analyze/gate 步骤随之不跑)。
  if include_crap then
    if env.lua54_bin then
      lanes[#lanes + 1] = {
        label = "crap_collect",
        cmd = shell_lib.build_command({
          env.lua54_bin,
          "tools/packages/crap/runner.lua",
          "collect",
          "--lane", "behavior",
          "--out", "tmp/crap_collect.json",
        }),
      }
    else
      skipped[#skipped + 1] = "crap_collect"
    end
  end
  -- Coverage runs alongside the other lanes: it re-runs the spec lanes under
  -- luacov in a separate lua5.4 process with its own stats files (luacov.<profile>.stats.out),
  -- so it shares no mutable state with the non-coverage lanes. Wall time is
  -- bounded by the slower of (parallel lanes, coverage), not their sum.
  if include_coverage then
    if env.lua54_bin and env.coverage_available ~= false then
      lanes[#lanes + 1] = {
        label = "coverage",
        cmd = shell_lib.build_command({
          env.lua54_bin,
          "tools/packages/coverage/coverage.lua",
          "--quiet",
          "--out",
          "tmp/coverage.md",
        }),
      }
    else
      skipped[#skipped + 1] = "coverage"
    end
  end
  return lanes, skipped
end

return builders
