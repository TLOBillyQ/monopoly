-- crap4lua v0.1.0 的 luacov 覆盖适配器。
--
-- 自研 debug hook 收集器(coverage_collector)与加载期命中回放(load_coverage.lua)
-- 整层退场:spec 在 luacov.runner 下跑,report.out 由 luacov 原生 reporter 产出,
-- crap4lua 只解析标准产物。
--
-- 顶层即装 luacov hook:resolve_suites 加载 spec 的加载期行(模块主块、函数定义)
-- 与用例行同口径入账——晚装会在 spec 加载后才生效,加载期行系统性漏采(旧
-- load_coverage.record/replay 正是为此而造的,随 luacov 早装一并成为多余)。
--
-- 契约见上游 tests/fixtures/basic_project/adapter.lua:
--   resolve_suites(lane, mode) -> suites
--   run(suites, opts) -> { total, failures, failed }
-- opts 由 crap4lua 的 coverage.collect 注入(mode/capture_logs/reporter/
-- raise_on_failure/report_path)。
--
-- require 顺序纪律(修正 #326):luacov hook 必须在任何 src/** 模块首载
-- **之前**装好。harness 顶层 require("src.foundation.number"),若 harness
-- 在 init 之前加载,number.lua 首载即未插桩、进 package.loaded 缓存后整个
-- 模块在 crap 车道永久漏采(behavior lane 下 CRAP 虚高 4 倍,曾误导补测/拆分
-- 决策,与 #318 同源)。init 所需只有纯数据 coverage_config 与工具链
-- luacov_runner,都不依赖 src/,可安全提前。
local bootstrap = require("test.bootstrap")

bootstrap.install_package_paths()

local coverage_config = require("packages.coverage.coverage_config")
local luacov_runner = require("luacov.runner")

local _luacov_initialized = false

-- crap 场景的 luacov 配置与 coverage 车道口径不同:
--   1. analyzer 全量扫 source_roots(src/),luacov include 必须与之一致——coverage
--      车道的 6 tier include 会让 src/host|ui|app|config 整层无覆盖数据,全部
--      落成 N/A(旧链路上游 hook 是「include 空 = 全含」,host/ui 层有真实覆盖)。
--   2. 不需要 reporter 枚举 untested 文件:未出现在 report 里的文件统一按 N/A
--      计分。includeuntestedfiles 反而迫使 luacov reporter 依赖 lfs(C 模块,
--      仅 5.4 tree 有)——crap collect 进程可能跑在任意解释器下,去掉它让报告
--      生成零 C 依赖。
local function _crap_luacov_config()
  local cfg = {}
  for key, value in pairs(coverage_config) do
    cfg[key] = value
  end
  cfg.include = { "src/" }
  local exclude = {}
  for _, pattern in ipairs(coverage_config.exclude or {}) do
    if pattern:match("^src/") == nil then
      exclude[#exclude + 1] = pattern
    end
  end
  cfg.exclude = exclude
  cfg.includeuntestedfiles = nil
  return cfg
end

-- init 幂等:同进程多 adapter 实例(测试 require 场景)只装一次 hook。
local function _ensure_luacov_init()
  if _luacov_initialized then
    return
  end
  luacov_runner.init(_crap_luacov_config())
  _luacov_initialized = true
end

-- 顶层即装(见文件头 require 顺序纪律):必须在加载 harness 之前装好
-- hook,否则其顶层 require 的 src.foundation.number 首载未插桩、永久漏采。
_ensure_luacov_init()

-- catalog / harness 依赖 src.foundation.number(harness 顶层 require),必须
-- 在 luacov init 之后加载。
local catalog = require("test.support.catalog")
local harness = require("test.support.harness")

-- 解析 repo root:通过 package.searchpath 定位 tools/foundation/bootstrap.lua,
-- 取其父目录的父目录(绝对或相对随 package.path 形态,与 luacov key 同源)。
local function _repo_root()
  local found = package.searchpath("tools.foundation.bootstrap", package.path)
  if found == nil then
    return nil
  end
  local normalized = tostring(found):gsub("\\", "/"):gsub("^%./", "")
  return normalized:match("^(.*)/tools/foundation/bootstrap%.lua$")
    or normalized:match("^(.*)/tools/foundation/bootstrap$")
    or normalized
end

-- 归一化 luacov stats key 到 project-root 相对路径,与 crap4lua _remap_paths
-- 的口径一致;合并同一文件分裂出的多个 key(相对/绝对形态)。
-- 注意 repo_root 自身可能带 `./` 片段(如 .../refactorer/./src/...),剥前缀
-- 后可能残留 `./` 开头,需再清一次,保证三种形态(相对 / 绝对 / 绝对带 ./)
-- 归一到同一 key。
local function _merge_duplicate_file_keys()
  local repo_root = _repo_root()
  local prefix = repo_root and (repo_root:gsub("/+$", "") .. "/") or nil
  local merged = {}
  for key, stats in pairs(luacov_runner.data) do
    local normalized = tostring(key):gsub("\\", "/"):gsub("^%./", "")
    if prefix and normalized:sub(1, #prefix) == prefix then
      normalized = normalized:sub(#prefix + 1)
    end
    normalized = normalized:gsub("^%./", "")
    local existing = merged[normalized]
    if existing then
      luacov_runner.update_stats(existing, stats)
    else
      merged[normalized] = stats
    end
  end
  luacov_runner.data = merged
end

local adapter = {}

function adapter.resolve_suites(lane, mode)
  if lane == "behavior" then
    return catalog.load_behavior_suites(), mode or lane
  end
  if lane == "contract" then
    return catalog.load_contract_suites(), mode or lane
  end
  error("unsupported lane for CRAP coverage: " .. tostring(lane), 0)
end

function adapter.run(suites, opts)
  opts = opts or {}
  _ensure_luacov_init()

  -- report_path 由 config.coverage.report 解析而来(绝对路径);stats 用独立临时
  -- 文件,不与 coverage 车道(verify --full 里与 crap_collect 并行)共用
  -- build/luacov.stats.out。report 后 deletestats 清掉 stats。
  -- 默认落 build/(gitignored 生成物区):裸调用/契约测试不传 report_path 时,
  -- 报告若写 cwd 会把 luacov.report.out 泄进 mutate workspace 根目录,被
  -- root_whitelist_guard 判违规、整条 baseline 假红(#283)。
  local report_path = opts.report_path or "build/luacov.crap.report.out"
  local stats_path = tostring(report_path) .. ".stats"
  luacov_runner.configuration.reportfile = report_path
  luacov_runner.configuration.statsfile = stats_path
  luacov_runner.configuration.runreport = true
  luacov_runner.configuration.deletestats = true

  local result = harness.run_all(suites, {
    quiet = true,
    capture_logs = opts.capture_logs,
    reporter = opts.reporter,
    raise_on_failure = false,
  })

  -- 同文件多 key 合并:luacov 以模块加载时的 source 为 key。同一文件若被以
  -- 相对/绝对两种路径形态加载(spec 链 vs with_patches 重新 require),stats
  -- 会分裂成两个 key;crap4lua 的 _remap_paths 是覆盖语义,归一化后同文件
  -- 冲突时后处理者覆盖先处理者,部分行命中系统性丢失(实测 number.lua 的
  -- _parse_integer_string 回退行 cov 92% 而非 100%)。落盘前按 project-root
  -- 相对路径归一化并合并,用 luacov 的 update_stats 累加行命中。
  _merge_duplicate_file_keys()

  -- 显式落盘(save_stats + run_report),不等 os.exit 兜底。
  luacov_runner.shutdown()
  return result
end

return adapter
