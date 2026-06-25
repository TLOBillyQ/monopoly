local context = require("acceptance.steps.quality.context")
local mutation_runtime = require("acceptance.steps.quality.mutation_runtime")

local result_steps = {}

function result_steps.handlers()
  return {
    ["该次 mutate 运行产生<survived 数>个 survived 与<timeout 数>个 timeout"] = function(world, example)
      local state = context.state(world)
      state.expected_survived = context.to_integer(example["survived 数"]) or 0
      state.expected_timeout = context.to_integer(example["timeout 数"]) or 0
      return true
    end,

    ["mutate 运行结束"] = function(world)
      return mutation_runtime.run_mutate(world)
    end,

    ["survived 与 timeout 信息仅出现在 --json 输出与 CI 产物"] = function(world)
      return context.expect(context.state(world).output_has_failure_info == true,
        "expected failure info to stay in output artifacts")
    end,

    ["manifest 不记录 survived 或 timeout 状态"] = function(world)
      return context.expect(not tostring(context.state(world).manifest_after):find("survived", 1, true)
          and not tostring(context.state(world).manifest_after):find("timeout", 1, true),
        "manifest recorded survived or timeout")
    end,
  }
end

return result_steps
