--- LuaUnit 3.5 spec 运行器 CLI 入口；遗留 busted DSL 与自研兼容运行器已退场。
--- 单一执行引擎(LuaUnit 3.5)跑原生 LuaUnit spec(_G 新增 Test* 表 / test*
--- 函数);遗留 busted DSL 已全量改写退场,shim 桥与旧自研兼容层
--- core/assert/runner 一并删除,终态无桥接。
--- 加载后统一登记进 packages.luaunit_runner.registry,组装 listOfNameAndInst
--- 交给一个 LuaUnit 实例一次跑完;事件经 packages.luaunit_runner.events facade
--- 广播,TAP 输出契约与旧兼容层 runner.lua 逐字节一致。
---
--- CLI 面与旧 runner 完全一致:--run / --helper / --output / --pattern /
--- -Xoutput / -c / 裸 root / -- <files>。
---
--- 调用形态:
---   lua5.4 tools/packages/luaunit_runner/runner.lua --run guards
---   lua5.4 tools/packages/luaunit_runner/runner.lua --helper=test/helper.lua \
---     --output=test/log_warns_handler.lua --pattern=test_ -- <file1> <file2> ...
---
--- helper 与 output handler 直接订阅本 runner 的事件面：helper 以
--- events 模块订阅 runner 事件面,output handler 工厂直接引用 events 与
--- tap_outputter——不再经 package.preload 的 busted facade 命名解析(#321)。

-- ------------------------------------------------------- package path 引导
-- 本脚本位于 <repo>/tools/packages/luaunit_runner/runner.lua;据此定位仓根并装
-- 全套 monopoly package.path(与旧 runner 同源),再追加 luarocks 本地 tree 让
-- spec 里的 require("luaunit") 可解析(tree 由 .toolcache/ 按需 bootstrap,
-- gitignored)。

local _self = ((arg and arg[0]) or debug.getinfo(1, "S").source:gsub("^@", "")):gsub("\\", "/")
local _script_dir = _self:match("^(.*)/[^/]+$") or "."
local _repo_root = _script_dir:gsub("/tools/packages/luaunit_runner$", "")
if _repo_root == _script_dir then
  _repo_root = _script_dir .. "/../../.."
end

-- 仓根词法规范化(去 "."、解 ".."):相对调用(lua5.4 tools/.../runner.lua)时
-- 上面的回退会产出带 "../../.." 的仓根,包路径拼出的模块 source 形如
-- "@tools/packages/luaunit_runner/../../../src/rules/x.lua",被 coverage exclude
-- 的 "tools/" 模式误伤,stats 全灭(旧 runner 同源的既有毛病;车道走
-- lua54.lua 的绝对路径从不触发,这里就地修好,相对调用 -c 也能正常采集)。
local function _normalize_repo_root(path)
  local is_abs = path:sub(1, 1) == "/"
  local parts = {}
  for seg in path:gmatch("[^/]+") do
    if seg == ".." then
      if #parts > 0 and parts[#parts] ~= ".." then
        parts[#parts] = nil
      elseif not is_abs then
        parts[#parts + 1] = seg
      end
    elseif seg ~= "." then
      parts[#parts + 1] = seg
    end
  end
  local joined = table.concat(parts, "/")
  if is_abs then
    return "/" .. joined
  end
  return joined == "" and "." or joined
end
_repo_root = _normalize_repo_root(_repo_root)
local _package_path_helper = dofile(_repo_root .. "/tools/foundation/package_path_helper.lua")
_package_path_helper.install_eggy_package_paths({ repo_root = _repo_root })
_package_path_helper.install_luarocks_tree_paths({ repo_root = _repo_root })
local _bootstrap = dofile(_repo_root .. "/tools/foundation/bootstrap.lua")
local _luaunit_ok, _luaunit_err = _bootstrap.ensure_luaunit_tree(_repo_root)
if _luaunit_ok ~= true then
  io.stderr:write("luaunit_runner: cannot ensure luaunit: " .. tostring(_luaunit_err) .. "\n")
  os.exit(1)
end

-- ------------------------------------------------------------------ 覆盖率(最早挂载)
-- 挂载时序与旧 runner 一致:-c 时 require luacov.runner 并 init,配置经 LUACOV_CONFIG
-- 环境变量传入(luacov 自身的默认查找顺序即 LUACOV_CONFIG -> .luacov;未设时回退到
-- 仓内单源配置 tools/packages/coverage/coverage_config.lua)。luacov.init 包装 os.exit,进程
-- 退出时 on_exit 自动落 stats(配置 runreport 时顺带产 report.out)——runner 不再
-- 自行管理收集器生命周期。
--
-- 必须先于 require("foundation.*") —— foundation 顶层 require 会执行 src 模块
-- 加载期行,晚装 hook 会漏采,与 luacov 口径漂移。据 arg 直接判 -c(CLI 解析在后)。
do
  local _want_coverage = false
  for _, a in ipairs(arg) do
    if a == "--" then
      break
    elseif a == "-c" or a == "--coverage" then
      _want_coverage = true
      break
    end
  end
  if _want_coverage then
    local ok_tree, tree_err = _bootstrap.ensure_luacov_tree(_repo_root)
    if ok_tree ~= true then
      io.stderr:write("luaunit_runner: cannot ensure luacov: " .. tostring(tree_err) .. "\n")
      os.exit(1)
    end
    local ok_load, luacov = pcall(require, "luacov.runner")
    if not ok_load then
      io.stderr:write("luaunit_runner: cannot load luacov.runner: " .. tostring(luacov) .. "\n")
      os.exit(1)
    end
    local config_path = os.getenv("LUACOV_CONFIG")
    if config_path == nil or config_path == "" then
      config_path = "tools/packages/coverage/coverage_config.lua"
    end
    local ok_init, init_err = pcall(luacov.init, config_path)
    if not ok_init then
      io.stderr:write("luaunit_runner: luacov init failed: " .. tostring(init_err) .. "\n")
      os.exit(1)
    end
  end
end

-- chunk 缓存(#428):文件级隔离每文件恢复 package.loaded,spec 依赖树被逐文件
-- 整树重加载;按路径缓存 loadfile 原型,重执行语义不变,省掉重复 IO+解析。
-- 装在 helper/spec 加载之前,进程内后续 require 全部受益。
require("packages.luaunit_runner.chunk_cache").install()

local proc_lib = require("foundation.proc")
local fs_lib = require("foundation.fs")
local lu = require("luaunit")
local events = require("packages.luaunit_runner.events")
local registry = require("packages.luaunit_runner.registry")
local tap_outputter = require("packages.luaunit_runner.tap_outputter")

-- helper 与 output handler 经 events / tap_outputter 直接 require(#321 剥
-- facade 面):package.preload["busted"] 等旧命名不再注入。

-- ------------------------------------------------------------------ CLI 解析

local opts = {
  run = nil,
  helper = nil,
  output = nil,
  pattern = nil,
  arguments = {},
  coverage = false,
  files = {},
  roots = {},
}

local i = 1
local after_dashdash = false
while i <= #arg do
  local a = arg[i]
  if after_dashdash then
    opts.files[#opts.files + 1] = a
  elseif a == "--" then
    after_dashdash = true
  elseif a:match("^%-%-run=") then
    opts.run = a:sub(7)
  elseif a == "--run" then
    i = i + 1
    opts.run = arg[i]
  elseif a:match("^%-%-output=") then
    opts.output = a:sub(10)
  elseif a == "--output" or a == "-o" then
    i = i + 1
    opts.output = arg[i]
  elseif a:match("^%-%-helper=") then
    opts.helper = a:sub(10)
  elseif a == "--helper" then
    i = i + 1
    opts.helper = arg[i]
  elseif a:match("^%-%-pattern=") then
    opts.pattern = a:sub(11)
  elseif a == "--pattern" then
    i = i + 1
    opts.pattern = arg[i]
  elseif a == "-Xoutput" then
    i = i + 1
    opts.arguments[#opts.arguments + 1] = arg[i]
  elseif a == "-c" or a == "--coverage" then
    opts.coverage = true
  else
    opts.roots[#opts.roots + 1] = a
  end
  i = i + 1
end

-- -------------------------------------------------- spec_profiles profile

-- 无 --run 时回退 default profile(缺了它会丢 helper,共享 RNG 不播种、
-- runtime ports 不注册,spec 会以与被测代码无关的原因失败)。profile 定义
-- 住 packages/spec_lane/spec_profiles.lua（原 .busted）。
local profile = {}
local cfg_ok, cfg = pcall(dofile, _repo_root .. "/tools/packages/spec_lane/spec_profiles.lua")
if opts.run ~= nil then
  if not cfg_ok or type(cfg) ~= "table" then
    io.stderr:write("luaunit_runner: cannot load spec_profiles config\n")
    os.exit(1)
  end
  profile = cfg[opts.run]
  if profile == nil then
    -- 目录点跑取代 behavior-smoke 手维护子集：--run
    -- 不是命名 profile 时,若是存在的目录则按 behavior 默认(helper/output/
    -- pattern)构造临时 profile,ROOT 即该目录。
    if fs_lib.is_dir(opts.run) then
      local base = type(cfg.behavior) == "table" and cfg.behavior or {}
      profile = {
        ROOT = { opts.run },
        helper = base.helper,
        output = base.output,
        pattern = base.pattern,
      }
    else
      io.stderr:write("luaunit_runner: unknown profile '" .. opts.run .. "'\n")
      os.exit(1)
    end
  end
elseif cfg_ok and type(cfg) == "table" and type(cfg.default) == "table" then
  profile = cfg.default
end

local helper_path = opts.helper or profile.helper
local output_spec = opts.output or profile.output or "TAP"
local pattern = opts.pattern or profile.pattern or "test_"
if profile.Xoutput ~= nil then
  opts.arguments[#opts.arguments + 1] = profile.Xoutput
end

-- -------------------------------------------------------------- spec 发现
-- 与旧 runner 同口径:目标 = 显式文件(-- 后)∪ 裸 root 位置参数;都空则用
-- profile.ROOT。每个目标:.lua 文件直接采纳,目录递归遍历并按 pattern 过滤
-- basename。

local function _is_file(path)
  local fh = io.open(path, "r")
  if fh then
    fh:close()
    return true
  end
  return false
end

local targets = {}
for _, f in ipairs(opts.files) do
  targets[#targets + 1] = f
end
for _, r in ipairs(opts.roots) do
  targets[#targets + 1] = r
end
if #targets == 0 then
  for _, r in ipairs(profile.ROOT or { "test" }) do
    targets[#targets + 1] = r
  end
end

local spec_files = {}
for _, target in ipairs(targets) do
  if target:match("%.lua$") and _is_file(target) then
    spec_files[#spec_files + 1] = target
  else
    local files = proc_lib.collect_files(target, ".lua")
    for _, path in ipairs(files or {}) do
      local base = path:match("([^/\\]+)%.lua$")
      if base ~= nil and base:find(pattern) ~= nil then
        spec_files[#spec_files + 1] = path
      end
    end
  end
end

if #spec_files == 0 then
  io.stderr:write("luaunit_runner: no spec files found (pattern=" .. pattern .. ")\n")
  os.exit(1)
end

-- --------------------------------------------------------- handler + helper

local options = { arguments = opts.arguments }

if output_spec == "TAP" then
  tap_outputter.tap_handler_factory(options)
elseif output_spec:match("%.lua$") then
  local chunk, err = loadfile(output_spec)
  if chunk == nil then
    io.stderr:write("luaunit_runner: cannot load output handler: " .. tostring(err) .. "\n")
    os.exit(1)
  end
  local factory = chunk()
  factory(options) -- handler 直接 require events / tap_outputter 包装内建 TAP
else
  io.stderr:write("luaunit_runner: unsupported output '" .. output_spec
    .. "' (supported: TAP | <path>.lua)\n")
  os.exit(1)
end

-- spec chunk 环境:读写透传 _G(写落真 _G,由文件级隔离快照恢复)。原生 spec
-- 断言走 lu.assertXxx,无需注入 shim assert(兼容层已删);保留这层壳只为
-- 加载路径与旧行为一致。
local spec_env = setmetatable({}, {
  __index = _G,
  __newindex = function(_, k, v)
    rawset(_G, k, v)
  end,
})

if helper_path ~= nil then
  local chunk, err = loadfile(helper_path)
  if chunk == nil then
    io.stderr:write("luaunit_runner: cannot load helper: " .. tostring(err) .. "\n")
    os.exit(1)
  end
  -- helper 加载时直接订阅 runner 事件面，不经过 busted facade：
  -- require package.luaunit_runner.events 订阅事件面,不再被当作 fn(busted)
  -- 调用。返回 function 的旧形态无需兼容——本 runner 不调用它。
  chunk()
end

-- ------------------------------------------------------------------ 加载收集
-- 加载阶段文件级隔离(#428 后收窄为 globals-only,见 file_isolation 头部):
-- 每 spec 文件前后浅快照/恢复 _G,文件顶层引入的全局不跨文件泄漏;
-- package.loaded 不逐文件抹除,按标准 require 缓存语义进程内累积。
-- 与旧 core 的差异:旧 core 加载完立即跑该文件用例再恢复;本 runner 只收集
-- (实例引用 stash 进 registry),恢复后统一交给 LuaUnit 跑 —— 因此每个文件还
-- 要留一份「加载完成后」的环境快照,由 outputter 在该类的 startClass/
-- endClass 装回/恢复,让用例执行环境与旧 core 一致。

local file_isolation = require("packages.luaunit_runner.file_isolation")

--- 加载单个 spec 文件并收集用例进 registry。返回 ok, err(文件级加载错误)。
local function _load_and_collect(path)
  local snap = file_isolation.snapshot_globals()
  local chunk, load_err = loadfile(path, "bt", spec_env)
  if chunk == nil then
    file_isolation.apply_globals(snap)
    return false, load_err
  end
  local ok, err = pcall(chunk) -- 收集阶段:文件顶层代码立即执行
  if not ok then
    file_isolation.apply_globals(snap)
    return false, err
  end

  -- 该文件加载完成后的 _G 快照(fixture 经 spec_env 落 _G 的 fake 等),
  -- 由 outputter 在该类的 startClass/endClass 装回/恢复(见 tap_outputter)。
  local env_snap = file_isolation.snapshot_globals()

  -- 原生形态:_G 新增的 Test* 表 / test* 函数。
  for k, v in pairs(_G) do
    if snap.globals[k] == nil and type(k) == "string" and k:match("^[Tt]est") ~= nil then
      if type(v) == "table" then
        local class_name = registry.unique_class_name(k)
        registry.register_class(class_name, v, path, env_snap)
      elseif type(v) == "function" then
        registry.register_function(k, v, path)
      end
    end
  end

  file_isolation.apply_globals(snap)
  return true
end

for _, file in ipairs(spec_files) do
  local ok, err = _load_and_collect(file)
  if not ok then
    events.results.errors = events.results.errors + 1
    io.write("not ok - failed to load " .. file .. "\n# "
      .. tostring(err):gsub("\n", "\n# ") .. "\n")
  end
end

-- ------------------------------------------------------------------ 执行
-- 全部文件收集完后一次跑完。用 runSuiteByInstancesNoCmdLineParsing 而非
-- runSuiteByInstances(list, {}):后者会把 LUAUNIT_OUTPUT 环境变量当回事,可能
-- 静默覆盖我们的 outputter,且不回传 notSuccessCount;前者跳过命令行解析,
-- 语义更窄更稳。outputType 在 startSuite 时 new(runner) 实例化(见 luaunit.lua
-- startSuite),赋 outputter 类表即可。

local lu_runner = lu.LuaUnit.new()
lu_runner.outputType = tap_outputter.outputter_class
lu_runner:runSuiteByInstancesNoCmdLineParsing(registry.instances())

-- 覆盖率由 luacov 的 os.exit 包装在退出时落盘(on_exit),runner 不额外保存。

local r = events.results
os.exit((r.failures + r.errors) > 0 and 1 or 0)
