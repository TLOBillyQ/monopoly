-- luacheck: globals describe it
local runtime = require("acceptance4lua.runtime")
local steps = require("acceptance.steps")
local json = require("acceptance4lua.json")

local embedded_ir = {
  ["background"] = {
    {
      ["keyword"] = "Given",
      ["metadata"] = {
        ["original_text"] = "仓库启用了 SwarmForge 迁移工作流",
        ["source_line"] = 6,
        ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
      },
      ["parameters"] = {},
      ["text"] = "仓库启用了 SwarmForge 迁移工作流",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["变异总数"] = 9,
      ["报告格式"] = 10,
      ["期望状态间隔"] = 14,
      ["状态间隔"] = 10,
      ["跳过变异数"] = 27,
      ["跳过场景数"] = 27,
    },
    ["field_names"] = {
      ["变异总数"] = "变异总数",
      ["报告格式"] = "报告格式",
      ["期望状态间隔"] = "期望状态间隔",
      ["状态间隔"] = "状态间隔",
      ["跳过变异数"] = "跳过变异数",
      ["跳过场景数"] = "跳过场景数",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
  },
  ["name"] = "Gherkin 变异状态输出",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["变异总数"] = "2",
          ["报告格式"] = "JSON",
          ["期望状态间隔"] = "30s",
          ["状态间隔"] = "30s",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["变异总数"] = 19,
          ["报告格式"] = 19,
          ["期望状态间隔"] = 19,
          ["状态间隔"] = 19,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
      },
      ["name"] = "状态输出不污染最终报告",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "验收变异样例包含<变异总数>个可执行变异",
            ["source_line"] = 9,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {
            "变异总数",
          },
          ["text"] = "验收变异样例包含<变异总数>个可执行变异",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "执行 Gherkin mutator 时启用<状态间隔>状态间隔并请求<报告格式>报告",
            ["source_line"] = 10,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {
            "状态间隔",
            "报告格式",
          },
          ["text"] = "执行 Gherkin mutator 时启用<状态间隔>状态间隔并请求<报告格式>报告",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "mutator 命令成功完成",
            ["source_line"] = 11,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {},
          ["text"] = "mutator 命令成功完成",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "标准错误输出包含状态行",
            ["source_line"] = 12,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {},
          ["text"] = "标准错误输出包含状态行",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "状态行包含总数<变异总数>和完成数<变异总数>",
            ["source_line"] = 13,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {
            "变异总数",
            "变异总数",
          },
          ["text"] = "状态行包含总数<变异总数>和完成数<变异总数>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "状态行包含状态间隔<期望状态间隔>",
            ["source_line"] = 14,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {
            "期望状态间隔",
          },
          ["text"] = "状态行包含状态间隔<期望状态间隔>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "标准输出保持为<报告格式>报告",
            ["source_line"] = 15,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {
            "报告格式",
          },
          ["text"] = "标准输出保持为<报告格式>报告",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "标准输出不包含状态行",
            ["source_line"] = 16,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {},
          ["text"] = "标准输出不包含状态行",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["报告格式"] = "JSON",
          ["期望状态间隔"] = "30s",
          ["状态间隔"] = "30s",
          ["跳过变异数"] = "2",
          ["跳过场景数"] = "1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["报告格式"] = 33,
          ["期望状态间隔"] = 33,
          ["状态间隔"] = 33,
          ["跳过变异数"] = 33,
          ["跳过场景数"] = 33,
        },
        ["source_line"] = 22,
        ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
      },
      ["name"] = "差分跳过数量进入状态输出",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "验收变异样例已经有成功差分基线",
            ["source_line"] = 23,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {},
          ["text"] = "验收变异样例已经有成功差分基线",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "执行 Gherkin mutator 时启用<状态间隔>状态间隔并请求<报告格式>报告",
            ["source_line"] = 24,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {
            "状态间隔",
            "报告格式",
          },
          ["text"] = "执行 Gherkin mutator 时启用<状态间隔>状态间隔并请求<报告格式>报告",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "mutator 命令成功完成",
            ["source_line"] = 25,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {},
          ["text"] = "mutator 命令成功完成",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "标准错误输出包含状态行",
            ["source_line"] = 26,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {},
          ["text"] = "标准错误输出包含状态行",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "状态行包含跳过场景数<跳过场景数>和跳过变异数<跳过变异数>",
            ["source_line"] = 27,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {
            "跳过场景数",
            "跳过变异数",
          },
          ["text"] = "状态行包含跳过场景数<跳过场景数>和跳过变异数<跳过变异数>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "状态行包含状态间隔<期望状态间隔>",
            ["source_line"] = 28,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {
            "期望状态间隔",
          },
          ["text"] = "状态行包含状态间隔<期望状态间隔>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "标准输出保持为<报告格式>报告",
            ["source_line"] = 29,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {
            "报告格式",
          },
          ["text"] = "标准输出保持为<报告格式>报告",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "标准输出不包含状态行",
            ["source_line"] = 30,
            ["source_path"] = "features/swarmforge/acceptance_mutator_status.feature",
          },
          ["parameters"] = {},
          ["text"] = "标准输出不包含状态行",
        },
      },
    },
  },
}

local function load_ir()
  local override_path = os.getenv("ACCEPTANCE_FEATURE_JSON")
  if override_path ~= nil and override_path ~= "" then
    local file = assert(io.open(override_path, "rb"))
    local content = file:read("*a")
    file:close()
    return json.decode(content)
  end
  return embedded_ir
end

local ir = load_ir()

describe("Acceptance: " .. tostring(ir.name), function()
  runtime.define_busted_specs(ir, steps.handlers(), it)
end)
