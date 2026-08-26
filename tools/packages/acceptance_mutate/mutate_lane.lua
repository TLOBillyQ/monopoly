-- packages/acceptance_mutate/mutate_lane.lua —— Gherkin 变异车道(软车道实现,
-- acceptance-mutate 与 mutate 并列为独立软车道；#310 从
-- acceptance 包剥出;mutator 薄壳在 tools/packages/acceptance_mutate/mutator.lua,
-- parser/generator/runner_worker 等引擎件仍住 acceptance 数据面 + 驱动层)。
--
-- 存在理由:soft 是差分档,干净树上会跳过全部变异体、报 total=0 然后退 0。
-- 那条路径一个测试都没真跑,于是 runner adapter 坏掉(典型:Lua 5.4 解释器
-- 没解析到,worker 子进程退回 PATH 上的 lua 5.5)时车道照样报绿。终序里
-- acceptance 软车道每次交接都跑,这个洞能一直藏着。
--
-- 探针先用一个真 job 打通 parser -> generator -> runner_worker。只要 runner 起不来,
-- 这里大声失败,而不是让 mutator 静静地跳过一切然后报成功。全跳过本身是合法的
-- (没动 feature 就没有差分变异体),所以按「跳过数」判失败会天天误报;
-- 该判的是「runner 到底能不能跑」。
local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
assert(bootstrap.ensure_tool("acceptance4lua", env))

local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local shell_lib = require("foundation.shell")
local text_lib = require("foundation.text")
local json = require("acceptance4lua.json")

-- mutator 的 --feature 默认值,保持与 APS 参考实现一致。
local DEFAULT_FEATURE = "features/a-feature.feature"
local PROBE_DIR = "build/acceptance-mutation-probe"

local function _text(zh, en)
  return text_lib.bilingual(zh, en)
end

local function _die(headline, detail)
  io.stderr:write("\n", headline, "\n")
  if detail ~= nil and detail ~= "" then
    io.stderr:write(detail, "\n")
  end
  os.exit(1)
end

-- 探针跑的就是本次真要变异的 feature:不额外钉死某个样例文件。
local function _feature_from_args(args)
  for index, value in ipairs(args) do
    if value == "--feature" then
      return args[index + 1] or DEFAULT_FEATURE
    end
    local inline = tostring(value):match("^%-%-feature=(.+)$")
    if inline ~= nil then
      return inline
    end
  end
  return DEFAULT_FEATURE
end

local function _run(command, options)
  local result = proc_lib.run_command(command, options)
  return result.ok == true, result.output or ""
end

-- runner adapter 健康探针:parser -> generator -> runner_worker 走一遍真 job。
-- 只有 infrastructure_error 算车道失败;test_failure 说明 runner 活着、
-- 只是这个 feature 当前没过,那不归本探针管。
local function _probe_runner(feature_path)
  if fs_lib.path_exists(feature_path) ~= true then
    _die(_text(
      "变异车道中止:找不到 feature " .. feature_path,
      "acceptance-mutate aborted: feature not found: " .. feature_path
    ))
  end

  local probe_root = path_lib.join_path(env.repo_root, PROBE_DIR)
  local generated_dir = path_lib.join_path(probe_root, "generated")
  local ir_path = path_lib.join_path(probe_root, "feature.json")
  local spec_path = path_lib.join_path(generated_dir, "test_feature_acceptance.lua")
  local job_path = path_lib.join_path(probe_root, "job.jsonl")

  local ok, err = fs_lib.ensure_dir(generated_dir)
  if not ok then
    _die(_text("变异车道中止:探针目录建不起来", "acceptance-mutate aborted: cannot create probe dir"), tostring(err))
  end

  ok, err = _run({ "lua", "tools/packages/acceptance/cli/parser.lua", feature_path, ir_path }, { cwd = env.repo_root })
  if not ok then
    _die(_text(
      "变异车道中止:parser 跑不动,变异跑起来只会整批 error。",
      "acceptance-mutate aborted: parser failed; mutants would all error."
    ), err)
  end

  ok, err = _run({ "lua", "tools/packages/acceptance/cli/generator.lua", ir_path, spec_path }, { cwd = env.repo_root })
  if not ok then
    _die(_text(
      "变异车道中止:generator 跑不动,变异跑起来只会整批 error。",
      "acceptance-mutate aborted: generator failed; mutants would all error."
    ), err)
  end

  local job = json.encode_compact({
    id = "runner-probe",
    generated_dir = generated_dir,
    feature_json = ir_path,
  })
  ok, err = fs_lib.write_file(job_path, job .. "\n")
  if not ok then
    _die(_text("变异车道中止:探针 job 写不下去", "acceptance-mutate aborted: cannot write probe job"), tostring(err))
  end

  local result = proc_lib.run_command({ "lua", "tools/packages/acceptance/runner_worker.lua" }, {
    cwd = env.repo_root,
    stdin_path = job_path,
  })

  local response_line = tostring(result.output or ""):match("[^\r\n]+%s*$")
  local decoded_ok, response = pcall(json.decode, response_line or "")
  if not decoded_ok or type(response) ~= "table" then
    _die(_text(
      "变异车道中止:runner_worker 没吐出可解析的 job 响应。",
      "acceptance-mutate aborted: runner_worker returned no parsable response."
    ), tostring(result.output or ""))
  end

  if response.outcome == "infrastructure_error" then
    _die(_text(
      "变异车道中止:runner adapter 起不来(infrastructure_error)。\n"
        .. "变异体全都会 error;soft 档会把这一切伪装成 total=0 通过。\n"
        .. "先看 Lua 5.4 解释器是否解析得到(LUA54_BIN / ACCEPTANCE_LUA_BIN 可覆写)。",
      "acceptance-mutate aborted: runner adapter is broken (infrastructure_error).\n"
        .. "Every mutant would error; soft level would disguise it as a total=0 pass.\n"
        .. "Check the Lua 5.4 launcher resolution (LUA54_BIN / ACCEPTANCE_LUA_BIN override)."
    ), tostring(response.error or result.output or ""))
  end

  io.write(_text(
    "[mutate-lane] runner 探针通过 (" .. tostring(response.outcome) .. "):" .. feature_path,
    "[mutate-lane] runner probe ok (" .. tostring(response.outcome) .. "): " .. feature_path
  ), "\n")
  io.flush()
end

local args = arg or {}
_probe_runner(_feature_from_args(args))

-- 等价变异过滤器(issue #204):角色ID 族列经 Background 身份线程绑定,步骤对标识值
-- 不敏感,值变异必然幸存(APS 第 7 步 project-specific equivalent filter)。验证/选择列
-- (验证*、产品ID 等)不在此列——那些幸存是要抓的信号。调用方可经 ARGS 显式
-- --skip-columns 覆盖本默认清单。
local DEFAULT_SKIP_COLUMNS = "角色ID,观察角色ID,行动角色ID,预期行动角色ID"

local function _has_skip_columns(values)
  for _, value in ipairs(values) do
    if value == "--skip-columns" or tostring(value):match("^%-%-skip%-columns=") ~= nil then
      return true
    end
  end
  return false
end

-- 用 os.execute 而不是 proc_lib.run_command:mutator 的 status 行要实时落到终端。
-- run_command 会把输出重定向进临时文件,长跑期间看不到进度,与「长跑必须periodic
-- 报进度」的约束冲突。
local parts = {
  "lua",
  "tools/packages/acceptance_mutate/mutator.lua",
  "--runner-worker",
  shell_lib.shell_quote("lua tools/packages/acceptance/runner_worker.lua"),
}
if not _has_skip_columns(args) then
  parts[#parts + 1] = "--skip-columns"
  parts[#parts + 1] = shell_lib.shell_quote(DEFAULT_SKIP_COLUMNS)
end
-- acceptance4lua 的 mutator 现在把 --feature 定为必填;车道保留原来的默认
-- feature 行为,调用方没传就由这里补上。
local has_feature = false
for _, value in ipairs(args) do
  if value == "--feature" or tostring(value):match("^%-%-feature=") ~= nil then
    has_feature = true
    break
  end
end
if not has_feature then
  parts[#parts + 1] = "--feature"
  parts[#parts + 1] = shell_lib.shell_quote(DEFAULT_FEATURE)
end
for _, value in ipairs(args) do
  parts[#parts + 1] = shell_lib.shell_quote(value)
end

local ok, _, code = os.execute(table.concat(parts, " "))
os.exit((ok == true or code == 0) and 0 or 1)
