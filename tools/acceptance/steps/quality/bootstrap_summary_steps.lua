local context = require("acceptance.steps.quality.context")
local bootstrap_runtime = require("acceptance.steps.quality.bootstrap_runtime")

local summary_steps = {}

local function _set_bootstrap_count(field, example_key)
  return function(world, example)
    context.state(world).bootstrap = { [field] = context.to_integer(example[example_key]) or 0 }
    return true
  end
end

function summary_steps.handlers()
  return {
    ["git ls-files src/ 输出<总数>个 Lua 文件"] = _set_bootstrap_count("total", "总数"),

    ["stdout 包含字面量<总数>"] = function(world, example)
      return context.expect(((context.state(world).bootstrap or {}).stdout or ""):find(example["总数"], 1, true) ~= nil,
        "stdout missing total")
    end,

    ["stdout 同时包含 written / migrated / unchanged / skipped 四类计数"] = function(world)
      local stdout = (context.state(world).bootstrap or {}).stdout or ""
      return context.expect(stdout:find("written", 1, true)
          and stdout:find("migrated", 1, true)
          and stdout:find("unchanged", 1, true)
          and stdout:find("skipped", 1, true),
        "stdout missing summary buckets")
    end,

    ["四类计数之和等于<总数>"] = function(world, example)
      local summary = (context.state(world).bootstrap or {}).summary or {}
      local total = (summary.written or 0) + (summary.migrated or 0)
        + (summary.unchanged or 0) + (summary.skipped or 0)
      return context.expect(total == (context.to_integer(example["总数"]) or 0),
        "summary total mismatch")
    end,

    ["工具运行后 summary 显示 skipped 计数为<skipped 计数>"] =
      _set_bootstrap_count("skipped", "skipped 计数"),

    ["mutate_bootstrap.lua 结束"] = function(world)
      return bootstrap_runtime.run_bootstrap(world)
    end,

    ["工具退出码为<退出码>"] = function(world, example)
      return context.expect(((context.state(world).bootstrap or {}).exit_code or 0)
          == (context.to_integer(example["退出码"]) or 0),
        "exit code mismatch")
    end,

    ["工具退出码为 0"] = function(world)
      return context.expect(((context.state(world).bootstrap or {}).exit_code or 0) == 0,
        "exit code mismatch")
    end,

    ["git ls-files 输出不含 src/**/*.lua"] = function(world)
      context.state(world).bootstrap = { no_src = true }
      return true
    end,

    ["stderr 包含\"无 src 文件\"提示字面量"] = function(world)
      return context.expect(((context.state(world).bootstrap or {}).stderr or ""):find("无 src 文件", 1, true) ~= nil,
        "stderr missing no-src hint")
    end,

    ["工具不写任何 manifest 尾块"] = function(world)
      return context.expect((context.state(world).bootstrap or {}).did_write ~= true, "tool wrote manifest")
    end,

    ["git ls-files 输出含<源文件>"] = function(world, example)
      local state = context.prepare_manifest(world, example["源文件"])
      state.bootstrap = { v2 = true }
      return true
    end,

    ["stdout 列出 will-write / will-migrate / will-unchanged / will-skip 计划"] = function(world)
      return context.expect((context.state(world).bootstrap or {}).plan ~= nil, "dry-run plan missing")
    end,
  }
end

return summary_steps
