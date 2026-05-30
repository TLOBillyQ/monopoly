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
        ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
      },
      ["parameters"] = {},
      ["text"] = "仓库启用了 SwarmForge 迁移工作流",
    },
  },
  ["metadata"] = {
    ["field_lines"] = {
      ["不支持关键字"] = 22,
      ["中文参数名"] = 86,
      ["中文步骤文本"] = 47,
      ["中文表头"] = 48,
      ["例子关键字"] = 11,
      ["前置关键字"] = 11,
      ["功能关键字"] = 11,
      ["功能名称"] = 60,
      ["动作关键字"] = 11,
      ["场景关键字"] = 11,
      ["场景名称"] = 61,
      ["应提交路径"] = 101,
      ["报告格式示例"] = 90,
      ["接受或拒绝"] = 38,
      ["文件路径"] = 35,
      ["本地路径"] = 102,
      ["源文件路径"] = 9,
      ["结果关键字"] = 11,
      ["行号"] = 22,
      ["规范参数名"] = 50,
      ["连接关键字"] = 11,
      ["错误类型"] = 73,
      ["首行内容"] = 36,
    },
    ["field_names"] = {
      ["不支持关键字"] = "不支持关键字",
      ["中文参数名"] = "中文参数名",
      ["中文步骤文本"] = "中文步骤文本",
      ["中文表头"] = "中文表头",
      ["例子关键字"] = "例子关键字",
      ["前置关键字"] = "前置关键字",
      ["功能关键字"] = "功能关键字",
      ["功能名称"] = "功能名称",
      ["动作关键字"] = "动作关键字",
      ["场景关键字"] = "场景关键字",
      ["场景名称"] = "场景名称",
      ["应提交路径"] = "应提交路径",
      ["报告格式示例"] = "报告格式示例",
      ["接受或拒绝"] = "接受或拒绝",
      ["文件路径"] = "文件路径",
      ["本地路径"] = "本地路径",
      ["源文件路径"] = "源文件路径",
      ["结果关键字"] = "结果关键字",
      ["行号"] = "行号",
      ["规范参数名"] = "规范参数名",
      ["连接关键字"] = "连接关键字",
      ["错误类型"] = "错误类型",
      ["首行内容"] = "首行内容",
    },
    ["language"] = "zh-CN",
    ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
  },
  ["name"] = "中文 Gherkin 验收规格",
  ["scenarios"] = {
    {
      ["examples"] = {
        {
          ["例子关键字"] = "例子",
          ["前置关键字"] = "假如",
          ["功能关键字"] = "功能",
          ["动作关键字"] = "当",
          ["场景关键字"] = "场景大纲",
          ["源文件路径"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          ["结果关键字"] = "那么",
          ["连接关键字"] = "并且",
        },
        {
          ["例子关键字"] = "例子",
          ["前置关键字"] = "假如",
          ["功能关键字"] = "功能",
          ["动作关键字"] = "当",
          ["场景关键字"] = "场景大纲",
          ["源文件路径"] = "features/game/dice_roll.feature",
          ["结果关键字"] = "那么",
          ["连接关键字"] = "但是",
        },
        {
          ["例子关键字"] = "例子",
          ["前置关键字"] = "假如",
          ["功能关键字"] = "功能",
          ["动作关键字"] = "当",
          ["场景关键字"] = "背景",
          ["源文件路径"] = "features/game/bankruptcy.feature",
          ["结果关键字"] = "那么",
          ["连接关键字"] = "并且",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["例子关键字"] = 16,
          ["前置关键字"] = 16,
          ["功能关键字"] = 16,
          ["动作关键字"] = 16,
          ["场景关键字"] = 16,
          ["源文件路径"] = 16,
          ["结果关键字"] = 16,
          ["连接关键字"] = 16,
        },
        ["source_line"] = 8,
        ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
      },
      ["name"] = "业务人员只维护中文功能文件",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "业务功能文件位于<源文件路径>",
            ["source_line"] = 9,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "源文件路径",
          },
          ["text"] = "业务功能文件位于<源文件路径>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "规格工具读取该文件",
            ["source_line"] = 10,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "规格工具读取该文件",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "工具接受关键字<功能关键字>、<场景关键字>、<前置关键字>、<动作关键字>、<结果关键字>、<连接关键字>和<例子关键字>",
            ["source_line"] = 11,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "功能关键字",
            "场景关键字",
            "前置关键字",
            "动作关键字",
            "结果关键字",
            "连接关键字",
            "例子关键字",
          },
          ["text"] = "工具接受关键字<功能关键字>、<场景关键字>、<前置关键字>、<动作关键字>、<结果关键字>、<连接关键字>和<例子关键字>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "工具拒绝业务源文件中的英文结构关键字",
            ["source_line"] = 12,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "工具拒绝业务源文件中的英文结构关键字",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "人工编辑源保持为中文",
            ["source_line"] = 13,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "人工编辑源保持为中文",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["不支持关键字"] = "假设",
          ["行号"] = "5",
        },
        {
          ["不支持关键字"] = "假定",
          ["行号"] = "5",
        },
        {
          ["不支持关键字"] = "剧本",
          ["行号"] = "3",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["不支持关键字"] = 29,
          ["行号"] = 29,
        },
        ["source_line"] = 21,
        ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
      },
      ["name"] = "不支持的关键字被拒绝并报告位置",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "中文功能文件第<行号>行使用了<不支持关键字>",
            ["source_line"] = 22,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "行号",
            "不支持关键字",
          },
          ["text"] = "中文功能文件第<行号>行使用了<不支持关键字>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "规格工具读取该文件",
            ["source_line"] = 23,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "规格工具读取该文件",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "工具拒绝该文件",
            ["source_line"] = 24,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "工具拒绝该文件",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "错误信息包含第<行号>行",
            ["source_line"] = 25,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "行号",
          },
          ["text"] = "错误信息包含第<行号>行",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "错误信息说明<不支持关键字>不被接受",
            ["source_line"] = 26,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "不支持关键字",
          },
          ["text"] = "错误信息说明<不支持关键字>不被接受",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["接受或拒绝"] = "接受",
          ["文件路径"] = "features/game/dice.feature",
          ["首行内容"] = "# language: zh-CN",
        },
        {
          ["接受或拒绝"] = "拒绝",
          ["文件路径"] = "features/game/dice.feature",
          ["首行内容"] = "Feature: dice",
        },
        {
          ["接受或拒绝"] = "接受",
          ["文件路径"] = "tools/test/helper.feature",
          ["首行内容"] = "Feature: helper",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["接受或拒绝"] = 41,
          ["文件路径"] = 41,
          ["首行内容"] = 41,
        },
        ["source_line"] = 34,
        ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
      },
      ["name"] = "features 路径下的文件必须声明中文语言标签",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "文件位于<文件路径>",
            ["source_line"] = 35,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "文件路径",
          },
          ["text"] = "文件位于<文件路径>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "文件首行为<首行内容>",
            ["source_line"] = 36,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "首行内容",
          },
          ["text"] = "文件首行为<首行内容>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "规格工具读取该文件",
            ["source_line"] = 37,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "规格工具读取该文件",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "工具<接受或拒绝>该文件",
            ["source_line"] = 38,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "接受或拒绝",
          },
          ["text"] = "工具<接受或拒绝>该文件",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["中文步骤文本"] = "玩家<玩家>已有<已有道具数>张道具",
          ["中文表头"] = "玩家, 已有道具数",
          ["规范参数名"] = "玩家, 已有道具数",
        },
        {
          ["中文步骤文本"] = "消息包含分支名<分支名>和提交<提交哈希>",
          ["中文表头"] = "分支名, 提交哈希",
          ["规范参数名"] = "分支名, 提交哈希",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["中文步骤文本"] = 55,
          ["中文表头"] = 55,
          ["规范参数名"] = 55,
        },
        ["source_line"] = 46,
        ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
      },
      ["name"] = "中文参数名被稳定归一化",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "步骤文本为<中文步骤文本>",
            ["source_line"] = 47,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "中文步骤文本",
          },
          ["text"] = "步骤文本为<中文步骤文本>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "例子表头包含<中文表头>",
            ["source_line"] = 48,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "中文表头",
          },
          ["text"] = "例子表头包含<中文表头>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "规格工具生成 APS 兼容产物",
            ["source_line"] = 49,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "规格工具生成 APS 兼容产物",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "产物中的参数名为<规范参数名>",
            ["source_line"] = 50,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "规范参数名",
          },
          ["text"] = "产物中的参数名为<规范参数名>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "产物保留中文表头到规范参数名的映射",
            ["source_line"] = 51,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "产物保留中文表头到规范参数名的映射",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "再次生成得到相同的规范参数名",
            ["source_line"] = 52,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "再次生成得到相同的规范参数名",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["功能名称"] = "中文 Gherkin 验收规格",
          ["场景名称"] = "中文规格被编译为 APS 兼容中间格式",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["功能名称"] = 69,
          ["场景名称"] = 69,
        },
        ["source_line"] = 59,
        ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
      },
      ["name"] = "中文规格被编译为 APS 兼容中间格式",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "中文功能文件声明<功能名称>",
            ["source_line"] = 60,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "功能名称",
          },
          ["text"] = "中文功能文件声明<功能名称>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "中文场景声明<场景名称>",
            ["source_line"] = 61,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "场景名称",
          },
          ["text"] = "中文场景声明<场景名称>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "规格工具生成中间格式",
            ["source_line"] = 62,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "规格工具生成中间格式",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "中间格式的功能名为<功能名称>",
            ["source_line"] = 63,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "功能名称",
          },
          ["text"] = "中间格式的功能名为<功能名称>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "中间格式的场景名为<场景名称>",
            ["source_line"] = 64,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "场景名称",
          },
          ["text"] = "中间格式的场景名为<场景名称>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "中间格式只使用 APS 支持的关键字",
            ["source_line"] = 65,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "中间格式只使用 APS 支持的关键字",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "中间格式不是人工编辑源",
            ["source_line"] = 66,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "中间格式不是人工编辑源",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["中文表头"] = "已有道具数",
          ["源文件路径"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          ["行号"] = "18",
          ["规范参数名"] = "p2",
          ["错误类型"] = "例子列数不匹配",
        },
        {
          ["中文表头"] = "提交哈希",
          ["源文件路径"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          ["行号"] = "27",
          ["规范参数名"] = "p2",
          ["错误类型"] = "缺少参数值",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["中文表头"] = 81,
          ["源文件路径"] = 81,
          ["行号"] = 81,
          ["规范参数名"] = 81,
          ["错误类型"] = 81,
        },
        ["source_line"] = 72,
        ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
      },
      ["name"] = "诊断信息回指中文源文件",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "中文功能文件第<行号>行存在<错误类型>",
            ["source_line"] = 73,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "行号",
            "错误类型",
          },
          ["text"] = "中文功能文件第<行号>行存在<错误类型>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "规格工具报告错误",
            ["source_line"] = 74,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "规格工具报告错误",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "错误信息包含<源文件路径>",
            ["source_line"] = 75,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "源文件路径",
          },
          ["text"] = "错误信息包含<源文件路径>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "错误信息包含第<行号>行",
            ["source_line"] = 76,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "行号",
          },
          ["text"] = "错误信息包含第<行号>行",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "错误信息使用中文表头<中文表头>",
            ["source_line"] = 77,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "中文表头",
          },
          ["text"] = "错误信息使用中文表头<中文表头>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "错误信息不只显示规范参数名<规范参数名>",
            ["source_line"] = 78,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "规范参数名",
          },
          ["text"] = "错误信息不只显示规范参数名<规范参数名>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["中文参数名"] = "已有道具数",
          ["报告格式示例"] = "已有道具数: 5 -> 8",
          ["规范参数名"] = "p2",
        },
        {
          ["中文参数名"] = "玩家",
          ["报告格式示例"] = "玩家: A -> B",
          ["规范参数名"] = "p1",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["中文参数名"] = 94,
          ["报告格式示例"] = 94,
          ["规范参数名"] = 94,
        },
        ["source_line"] = 85,
        ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
      },
      ["name"] = "变异测试报告显示中文字段名",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "中文功能文件定义参数<中文参数名>",
            ["source_line"] = 86,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "中文参数名",
          },
          ["text"] = "中文功能文件定义参数<中文参数名>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "参数被归一化为<规范参数名>",
            ["source_line"] = 87,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "规范参数名",
          },
          ["text"] = "参数被归一化为<规范参数名>",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "变异测试生成报告",
            ["source_line"] = 88,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "变异测试生成报告",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "报告显示<中文参数名>的变异",
            ["source_line"] = 89,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "中文参数名",
          },
          ["text"] = "报告显示<中文参数名>的变异",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "报告格式为<报告格式示例>",
            ["source_line"] = 90,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "报告格式示例",
          },
          ["text"] = "报告格式为<报告格式示例>",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "报告不只显示<规范参数名>",
            ["source_line"] = 91,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "规范参数名",
          },
          ["text"] = "报告不只显示<规范参数名>",
        },
      },
    },
    {
      ["examples"] = {
        {
          ["应提交路径"] = "swarmforge/",
          ["本地路径"] = ".swarmforge/",
        },
        {
          ["应提交路径"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          ["本地路径"] = ".worktrees/",
        },
        {
          ["应提交路径"] = "docs/guides/chinese-gherkin.md",
          ["本地路径"] = "agent_context/",
        },
      },
      ["metadata"] = {
        ["example_field_lines"] = {
          ["应提交路径"] = 105,
          ["本地路径"] = 105,
        },
        ["source_line"] = 98,
        ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
      },
      ["name"] = "SwarmForge 迁移资产边界清晰",
      ["steps"] = {
        {
          ["keyword"] = "Given",
          ["metadata"] = {
            ["original_text"] = "仓库准备提交 SwarmForge 迁移",
            ["source_line"] = 99,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "仓库准备提交 SwarmForge 迁移",
        },
        {
          ["keyword"] = "When",
          ["metadata"] = {
            ["original_text"] = "开发者查看 git 状态",
            ["source_line"] = 100,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {},
          ["text"] = "开发者查看 git 状态",
        },
        {
          ["keyword"] = "Then",
          ["metadata"] = {
            ["original_text"] = "<应提交路径>应作为迁移资产提交",
            ["source_line"] = 101,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "应提交路径",
          },
          ["text"] = "<应提交路径>应作为迁移资产提交",
        },
        {
          ["keyword"] = "And",
          ["metadata"] = {
            ["original_text"] = "<本地路径>应保持为本地运行状态",
            ["source_line"] = 102,
            ["source_path"] = "features/swarmforge/chinese_gherkin_acceptance.feature",
          },
          ["parameters"] = {
            "本地路径",
          },
          ["text"] = "<本地路径>应保持为本地运行状态",
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
