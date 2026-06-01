local number_utils = require("src.foundation.number")
local json = require("acceptance4lua.json")
local common = require("shared.lib.common")

local mutator_status_steps = {}

local function _root(world)
  return world.project_root or "."
end

local function _acceptance_status_tmp_dir(world)
  local root = _root(world)
  local token = tostring(os.time()) .. "_" .. tostring({}):gsub("[^%w]+", "")
  local dir = common.join_path(root, "tmp/acceptance_mutator_status_" .. token)
  common.remove_path(dir)
  common.ensure_dir(dir)
  return dir
end

local function _write_status_sample_feature(path)
  return common.write_file(path, table.concat({
    "Feature: mutator status sample",
    "",
    "Scenario Outline: integer conversion",
    "  Given project acceptance step handlers are loaded",
    "  And a text value <raw>",
    "  When the project converts it to an integer",
    "  Then the integer result is <result>",
    "",
    "Examples:",
    "  | raw | result |",
    "  | 1   | 1      |",
    "",
  }, "\n"))
end

local function _prepare_mutator_status_world(world)
  local tmp_dir = _acceptance_status_tmp_dir(world)
  world.mutator_status_tmp_dir = tmp_dir
  world.mutator_status_feature = common.join_path(tmp_dir, "status.feature")
  world.mutator_status_work_dir = common.join_path(tmp_dir, "work")
  world.mutator_status_stdout = common.join_path(tmp_dir, "stdout.txt")
  world.mutator_status_stderr = common.join_path(tmp_dir, "stderr.txt")
  local ok, err = _write_status_sample_feature(world.mutator_status_feature)
  if not ok then
    return nil, err
  end
  return true
end

local function _run_gherkin_mutator(world, options)
  local root = _root(world)
  local args = {
    common.shell_quote(common.join_path(root, "gherkin-mutator")),
    "--feature", common.shell_quote(world.mutator_status_feature),
    "--work-dir", common.shell_quote(world.mutator_status_work_dir),
    "--runner-worker", common.shell_quote("lua " .. common.join_path(root, "tools/acceptance/runner_worker.lua")),
  }
  if options and options.status_interval ~= nil then
    args[#args + 1] = "--status-interval"
    args[#args + 1] = common.shell_quote(options.status_interval)
  end
  if options and options.report_format == "JSON" then
    args[#args + 1] = "--json"
  end

  local command = table.concat(args, " ")
    .. " > " .. common.shell_quote(world.mutator_status_stdout)
    .. " 2> " .. common.shell_quote(world.mutator_status_stderr)
  local result = common.run_command(command, { cwd = root })
  world.mutator_status_result = result
  world.mutator_status_stdout_text = common.read_file(world.mutator_status_stdout) or ""
  world.mutator_status_stderr_text = common.read_file(world.mutator_status_stderr) or ""
  return true
end

local function _last_status_line(text)
  local found = nil
  for line in (tostring(text or "") .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^status%s+") then
      found = line
    end
  end
  return found
end

local function _status_line(world)
  return world.last_status_line or _last_status_line(world.mutator_status_stderr_text) or ""
end

local function _assert_status_tokens(line, tokens)
  for _, token in ipairs(tokens) do
    local expected = token[1] .. "=" .. tostring(token[2])
    if not line:find(expected, 1, true) then
      return nil, "status line missing " .. expected .. ": " .. line
    end
  end
  return true
end

local function _status_tokens_handler(specs)
  return function(world, example)
    local tokens = {}
    for index, spec in ipairs(specs) do
      local value = spec.value
      if spec.example_key ~= nil then
        value = example[spec.example_key]
      end
      tokens[index] = { spec.name, value }
    end
    return _assert_status_tokens(_status_line(world), tokens)
  end
end

function mutator_status_steps.handlers()
  return {
    ["验收变异样例包含<变异总数>个可执行变异"] = function(world, example)
      local ok, err = _prepare_mutator_status_world(world)
      if not ok then
        return nil, err
      end
      world.expected_mutation_total = number_utils.to_integer(example["变异总数"])
      return true
    end,

    ["验收变异样例已经有成功差分基线"] = function(world)
      local ok, err = _prepare_mutator_status_world(world)
      if not ok then
        return nil, err
      end
      ok = _run_gherkin_mutator(world, { report_format = "JSON" })
      if not ok then
        return nil, "failed to run baseline mutator"
      end
      if not world.mutator_status_result.ok then
        return nil, "baseline mutator failed: " .. tostring(world.mutator_status_stdout_text)
          .. tostring(world.mutator_status_stderr_text)
      end
      return true
    end,

    ["执行 Gherkin mutator 时启用30s状态间隔并请求<报告格式>报告"] = function(world, example)
      world.requested_report_format = example["报告格式"]
      return _run_gherkin_mutator(world, {
        status_interval = "30s",
        report_format = example["报告格式"],
      })
    end,

    ["mutator 命令成功完成"] = function(world)
      local result = world.mutator_status_result
      if result == nil then
        return nil, "mutator command was not run"
      end
      if result.ok ~= true then
        return nil, "mutator command failed with code " .. tostring(result.code)
          .. "\nstdout:\n" .. tostring(world.mutator_status_stdout_text)
          .. "\nstderr:\n" .. tostring(world.mutator_status_stderr_text)
      end
      return true
    end,

    ["标准错误输出包含状态行"] = function(world)
      local line = _last_status_line(world.mutator_status_stderr_text)
      if line == nil then
        return nil, "stderr does not contain a status line: " .. tostring(world.mutator_status_stderr_text)
      end
      world.last_status_line = line
      return true
    end,

    ["状态行包含总数<变异总数>和完成数<变异总数>"] = _status_tokens_handler({
      { name = "total", example_key = "变异总数" },
      { name = "completed", example_key = "变异总数" },
      { name = "running", value = 0 },
    }),

    ["状态行包含跳过场景数<跳过场景数>和跳过变异数<跳过变异数>"] = _status_tokens_handler({
      { name = "skipped_scenarios", example_key = "跳过场景数" },
      { name = "skipped_mutations", example_key = "跳过变异数" },
    }),

    ["状态行包含已耗时"] = function(world)
      local line = _status_line(world)
      if not line:find("elapsed=%d+s")
        and not line:find("elapsed=%d+%.%d+s")
      then
        return nil, "status line missing elapsed duration: " .. line
      end
      return true
    end,

    ["标准输出保持为<报告格式>报告"] = function(world, example)
      if example["报告格式"] == "JSON" then
        local decoded = json.decode(world.mutator_status_stdout_text)
        if decoded == nil or decoded.summary == nil then
          return nil, "stdout is not a JSON mutation report: " .. tostring(world.mutator_status_stdout_text)
        end
        return true
      end
      return nil, "unsupported report format in status spec: " .. tostring(example["报告格式"])
    end,

    ["标准输出不包含状态行"] = function(world)
      if tostring(world.mutator_status_stdout_text):find("^status%s+") then
        return nil, "stdout contains status line: " .. tostring(world.mutator_status_stdout_text)
      end
      if tostring(world.mutator_status_stdout_text):find("\nstatus%s+") then
        return nil, "stdout contains status line: " .. tostring(world.mutator_status_stdout_text)
      end
      return true
    end,
  }
end

return mutator_status_steps
