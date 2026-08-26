---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/spec_lane/test/test_spec_lane.lua") end
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local spec_lane = require("packages.spec_lane.spec_lane")
local lane_tools = require("packages.spec_lane.spec_lane_tools")

local function _all_pass_tap()
  return table.concat({
    "ok 1 - first thing works",
    "ok 2 - second thing works",
    "ok 3 - third thing works",
    "1..3",
  }, "\n") .. "\n"
end

TestSpecLaneSpec = {}

function TestSpecLaneSpec:test_parse_args_requires_profile()
  local opts, err = spec_lane.parse_args({})
  lu.assertNil(opts)
  lu.assertEvalToTrue(tostring(err):find("missing --profile", 1, true))
end

function TestSpecLaneSpec:test_parse_args_parses_profile()
  local opts = spec_lane.parse_args({ "--profile", "contract" })
  lu.assertIs(opts.profile, "contract")
  lu.assertFalse(opts.verbose)
end

function TestSpecLaneSpec:test_parse_args_parses_verbose_alongside_profile()
  local opts = spec_lane.parse_args({ "--profile", "guards", "--verbose" })
  lu.assertIs(opts.profile, "guards")
  lu.assertTrue(opts.verbose)
end

-- --busted-bin 不再是合法选项。
function TestSpecLaneSpec:test_parse_args_rejects_removed_busted_bin_escape_hatch()
  local opts, err = spec_lane.parse_args({ "--profile", "contract", "--busted-bin", "custom-busted" })
  lu.assertNil(opts)
  lu.assertEvalToTrue(tostring(err):find("unknown option: --busted-bin", 1, true))
end

-- compress_tap 是 foundation.tap_summary.compress 的纯转发(#361 P5):行为面
-- 全在 test_tap_summary.lua,这里只留一个透传冒烟钉住接线没断。
function TestSpecLaneSpec:test_compress_tap_collapses_all_pass_tap_to_single_passed_line()
  local out, passed, failed = spec_lane.compress_tap(_all_pass_tap())
  lu.assertIs(out, "3 passed\n")
  lu.assertIs(passed, 3)
  lu.assertIs(failed, 0)
end

-- 不再支持 busted_bin 单 token 覆写，命令
-- 前缀恒为 argv_prefix 默认值({ lua5.4, runner.lua })。workers=1 强制单进程
-- 串行路径(分片判定要求 worker > 1 且 profile 文件数超过阈值)。
function TestSpecLaneSpec:test_run_defaults_backend_to_luaunit_runner()
  local captured
  local result = spec_lane.run({
    profile = "contract",
    workers = 1,
    run_command = function(command)
      captured = command
      return { ok = true, code = 0, output = _all_pass_tap() }
    end,
  })

  lu.assertEvalToTrue(tostring(captured[2]):find("luaunit_runner/runner%.lua"))
  lu.assertIs(captured[3], "--output=TAP")
  lu.assertIs(captured[4], "--run")
  lu.assertIs(captured[5], "contract")
  lu.assertIs(result.code, 0)
  lu.assertIs(result.stdout, "3 passed\n")
end

-- LPT 分片路径契约:文件数超过阈值(20)的具名 profile 且 worker > 1 时,每
-- worker 一条 runner 进程(helper/output/pattern 取自 profile config,
-- `--` 后显式文件列表),各 lane 输出按 lane 顺序聚合后统一压缩。依赖真实
-- test/contract 文件数 > 20(22 个)触发分片;run_lanes 注入替身避免真 spawn。
function TestSpecLaneSpec:test_sharded_profile_runs_one_runner_lane_per_worker()
  local captured_lanes
  local result = spec_lane.run({
    profile = "contract",
    workers = 3,
    run_command = function()
      error("serial path must not run when sharded")
    end,
    run_lanes = function(lanes)
      captured_lanes = lanes
      local results = {}
      for i, lane in ipairs(lanes) do
        results[i] = { label = lane.label, ok = true, output = _all_pass_tap(), exit_code = 0 }
      end
      return true, results
    end,
  })

  lu.assertTrue(#captured_lanes >= 2,
    "contract should shard into >= 2 lanes, got " .. #captured_lanes)
  for _, lane in ipairs(captured_lanes) do
    lu.assertEvalToTrue(lane.label:match("^contract_w%d+$"), "lane label: " .. lane.label)
    lu.assertEvalToTrue(lane.cmd:find("luaunit_runner/runner%.lua"), "lane cmd: " .. lane.cmd)
    lu.assertEvalToTrue(lane.cmd:find("'%-%-helper=test/helper%.lua'"), "lane cmd: " .. lane.cmd)
    lu.assertEvalToTrue(lane.cmd:find("'%-%-output=TAP'"), "lane cmd: " .. lane.cmd)
    lu.assertEvalToTrue(lane.cmd:find("'%-%-pattern=test_'"), "lane cmd: " .. lane.cmd)
    lu.assertEvalToTrue(lane.cmd:find("'%-%-'"), "lane cmd must pass files after --: " .. lane.cmd)
    lu.assertEvalToTrue(lane.cmd:find("test/contract/"), "lane cmd must carry spec files: " .. lane.cmd)
  end
  -- 3 条 lane × 3 条 ok 行 → 聚合压缩摘要
  lu.assertIs(result.code, 0)
  lu.assertIs(result.passed, #captured_lanes * 3)
  lu.assertIs(result.failed, 0)
  lu.assertIs(result.stdout, tostring(#captured_lanes * 3) .. " passed\n")
end

-- 分片失败聚合:任一 lane 输出带 not ok → failed 计数进摘要、exit code 1。
function TestSpecLaneSpec:test_sharded_failure_aggregates_into_failed_summary()
  local result = spec_lane.run({
    profile = "contract",
    workers = 3,
    run_lanes = function(lanes)
      local results = {}
      for i, lane in ipairs(lanes) do
        if i == 2 then
          results[i] = { label = lane.label, ok = false, exit_code = 1,
            output = "ok 1\nnot ok 2 - failing: shard two broke\n1..2\n" }
        else
          results[i] = { label = lane.label, ok = true, output = _all_pass_tap(), exit_code = 0 }
        end
      end
      return false, results
    end,
  })

  lu.assertIs(result.code, 1)
  lu.assertIs(result.failed, 1)
  lu.assertIs(result.passed, 7)
  lu.assertEvalToTrue(result.stdout:find("not ok 2 - failing: shard two broke", 1, true),
    "failure line must survive aggregation: " .. result.stdout)
  lu.assertEvalToTrue(result.stdout:find("7 passed, 1 failed", 1, true),
    "summary must count the shard failure: " .. result.stdout)
end

-- #298 的发现式包结构：tooling 车道 33 行手维护 ROOT 清单
-- 废除,塌缩为 tools/**/test/ + test/support/**/test/ 双口径自动收养。
function TestSpecLaneSpec:test_discover_test_roots_covers_both_scopes()
  local roots, err = lane_tools.discover_test_roots()
  lu.assertNotNil(roots, tostring(err))
  lu.assertIs(err, nil)
  lu.assertTrue(#roots > 0, "discovery must find at least one test root")
end

function TestSpecLaneSpec:test_discover_test_roots_returns_sorted_unique_test_dirs()
  local roots = lane_tools.discover_test_roots()
  local seen = {}
  local previous = ""
  for _, root in ipairs(roots) do
    lu.assertEvalToTrue(root:find("/test$"), "root must be a test dir: " .. root)
    lu.assertIsNil(seen[root], "duplicate root: " .. root)
    seen[root] = true
    lu.assertEvalToTrue(previous <= root, "roots must be sorted: " .. previous .. " > " .. root)
    previous = root
  end
end

-- 双口径同时匹配新旧布局:同名对时代(foo.lua + foo/test/)与目录即包时代
-- (<pkg>/test/)的测试目录都要被收养。
function TestSpecLaneSpec:test_discover_test_roots_adopts_both_layout_shapes()
  local roots = lane_tools.discover_test_roots()
  local index = {}
  for _, root in ipairs(roots) do
    index[root] = true
  end
  -- 目录即包时代:tools/packages/spec_lane.lua + 同包 test/
  lu.assertTrue(index["tools/packages/spec_lane/test"],
    "package-as-dir root must be adopted")
  -- 同名对时代:test/support/behavior_parallel.lua + behavior_parallel/test/
  lu.assertTrue(index["test/support/behavior_parallel/test"],
    "support same-name-pair root must be adopted")
  -- 目录即包时代:test/support/luaunit_runner_infra/ 无同名 .lua,纯 <pkg>/test/ 形态
  lu.assertTrue(index["test/support/luaunit_runner_infra/test"],
    "package-as-dir root must be adopted")
end


return TestSpecLaneSpec
