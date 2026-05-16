local number_utils = require("src.foundation.number")
local normalizer = require("acceptance.chinese_normalizer")
local gherkin_parser = require("acceptance.gherkin_parser")
local mutator = require("acceptance.mutator")
local handoff_message = require("swarmforge.handoff_message")
local common = require("shared.lib.common")

local steps = {}

local function _project_root()
  local source = debug.getinfo(1, "S").source or "@tools/acceptance/steps.lua"
  local normalized = tostring(source):gsub("^@", ""):gsub("\\", "/")
  local tools_dir = normalized:match("^(.*)/acceptance/steps%.lua$")
  if tools_dir == nil then
    return "."
  end
  return tools_dir:match("^(.*)/tools$") or "."
end

local function _read_feature_file(path)
  local root = _project_root()
  local full_path = root .. "/" .. path
  local content, err = common.read_file(full_path)
  if content == nil then
    return nil, "cannot read " .. full_path .. ": " .. tostring(err)
  end
  return content
end

local function _handlers()
  return {
    ["project acceptance step handlers are loaded"] = function(world)
      world.handlers_loaded = true
      return true
    end,

    ["a text value <raw>"] = function(world, example)
      world.raw_text = example.raw
      return true
    end,

    ["the project converts it to an integer"] = function(world)
      world.integer_result = number_utils.to_integer(world.raw_text)
      return true
    end,

    ["the integer result is <result>"] = function(world, example)
      if world.handlers_loaded ~= true then
        return nil, "acceptance step handlers were not loaded"
      end

      local expected = number_utils.to_integer(example.result)
      if expected == nil then
        return nil, "expected result is not an integer: " .. tostring(example.result)
      end
      if world.integer_result ~= expected then
        return nil, "expected " .. tostring(expected) .. ", got " .. tostring(world.integer_result)
      end
      return true
    end,

    ["项目验收步骤已加载"] = function(world)
      world.handlers_loaded = true
      return true
    end,

    ["文本值为<p1>"] = function(world, example)
      world.raw_text = example.p1
      return true
    end,

    ["项目将文本转换为整数"] = function(world)
      world.integer_result = number_utils.to_integer(world.raw_text)
      return true
    end,

    ["整数结果为<p2>"] = function(world, example)
      if world.handlers_loaded ~= true then
        return nil, "acceptance step handlers were not loaded"
      end

      local expected = number_utils.to_integer(example.p2)
      if expected == nil then
        return nil, "expected result is not an integer: " .. tostring(example.p2)
      end
      if world.integer_result ~= expected then
        return nil, "expected " .. tostring(expected) .. ", got " .. tostring(world.integer_result)
      end
      return true
    end,

    -- Background
    ["仓库启用了 SwarmForge 迁移工作流"] = function(world)
      world.swarmforge_enabled = true
      world.project_root = _project_root()
      return true
    end,

    -- Scenario 1: 业务人员只维护中文功能文件
    ["业务功能文件位于<p1>"] = function(world, example)
      world.feature_path = example.p1
      return true
    end,

    ["规格工具读取该文件"] = function(world)
      if world.feature_content == nil and world.feature_path ~= nil then
        local content, err = _read_feature_file(world.feature_path)
        if content == nil then
          return nil, err
        end
        world.feature_content = content
      end
      if world.feature_content == nil then
        return nil, "no feature content available"
      end
      local path = world.feature_path or "features/test.feature"
      local result, norm_err = normalizer.normalize_text(world.feature_content, { path = path })
      if result == nil then
        world.normalize_error = norm_err
        return true
      end
      world.normalized = result
      world.normalize_error = nil
      return true
    end,

    ["工具接受关键字<p2>、<p3>、<p4>、<p5>、<p6>、<p7>和<p8>"] = function(world, example)
      if world.normalize_error ~= nil then
        return nil, "normalization failed: " .. world.normalize_error
      end
      local keywords = { example.p2, example.p3, example.p4, example.p5, example.p6, example.p7, example.p8 }
      for _, kw in ipairs(keywords) do
        if world.feature_content:find(kw, 1, true) == nil then
          return nil, "keyword not found in source: " .. kw
        end
      end
      return true
    end,

    ["工具拒绝业务源文件中的英文结构关键字"] = function()
      local english_feature = "# language: zh-CN\nFeature: Bad\n"
      local _, err = normalizer.normalize_text(english_feature, { path = "features/test.feature" })
      if err == nil then
        return nil, "expected English keyword to be rejected"
      end
      if not tostring(err):find("英文结构关键字", 1, true) then
        return nil, "error should mention English structural keyword: " .. tostring(err)
      end
      return true
    end,

    ["人工编辑源保持为中文"] = function(world)
      if world.feature_content == nil then
        return nil, "no feature content loaded"
      end
      if not world.feature_content:find("# language: zh%-CN") then
        return nil, "source file is not marked as Chinese"
      end
      if world.feature_content:find("^Feature:", 1, true) then
        return nil, "source file contains English Feature keyword"
      end
      return true
    end,

    -- Scenario 2: 不支持的关键字被拒绝并报告位置
    ["中文功能文件第<p9>行使用了<p10>"] = function(world, example)
      local target_line = tonumber(example.p9)
      local keyword = example.p10
      local lines = { "# language: zh-CN" }
      local structure_keywords = { ["剧本"] = true }
      if structure_keywords[keyword] then
        lines[#lines + 1] = "功能: 测试不支持关键字"
        for _ = #lines + 1, target_line - 1 do
          lines[#lines + 1] = ""
        end
        lines[#lines + 1] = keyword .. ": 某个场景"
      else
        lines[#lines + 1] = ""
        lines[#lines + 1] = "功能: 测试不支持关键字"
        lines[#lines + 1] = "场景: 测试"
        for _ = #lines + 1, target_line - 1 do
          lines[#lines + 1] = ""
        end
        lines[#lines + 1] = "  " .. keyword .. " 某个步骤"
      end
      world.feature_content = table.concat(lines, "\n") .. "\n"
      world.feature_path = "features/test.feature"
      return true
    end,

    ["工具拒绝该文件"] = function(world)
      if world.normalize_error == nil then
        return nil, "expected normalization to fail, but it succeeded"
      end
      return true
    end,

    ["错误信息包含第<p9>行"] = function(world, example)
      local line_marker = "第" .. example.p9 .. "行"
      local msg = tostring(world.normalize_error or world.error_message or "")
      if not msg:find(line_marker, 1, true) then
        return nil, "error does not contain line marker: " .. line_marker .. " in: " .. msg
      end
      return true
    end,

    ["错误信息说明<p10>不被接受"] = function(world, example)
      local msg = tostring(world.normalize_error or world.error_message or "")
      if not msg:find(example.p10, 1, true) then
        return nil, "error does not mention keyword: " .. example.p10 .. " in: " .. msg
      end
      return true
    end,

    -- Scenario 3: features 路径下的文件必须声明中文语言标签
    ["文件位于<p11>"] = function(world, example)
      world.feature_path = example.p11
      return true
    end,

    ["文件首行为<p12>"] = function(world, example)
      world.feature_content = example.p12 .. "\n功能: 测试\n场景: 基础\n  假如 步骤一\n"
      return true
    end,

    ["工具<p13>该文件"] = function(world, example)
      if example.p13 == "接受" then
        if world.normalize_error ~= nil then
          return nil, "expected accept but got error: " .. world.normalize_error
        end
        return true
      elseif example.p13 == "拒绝" then
        if world.normalize_error == nil then
          return nil, "expected reject but normalization succeeded"
        end
        return true
      end
      return nil, "unknown accept/reject value: " .. tostring(example.p13)
    end,

    -- Scenario 4: 中文参数名被稳定归一化
    ["步骤文本为<p14>"] = function(world, example)
      world.step_text = example.p14
      return true
    end,

    ["例子表头包含<p15>"] = function(world, example)
      world.example_headers = {}
      for header in tostring(example.p15):gmatch("[^,]+") do
        world.example_headers[#world.example_headers + 1] = header:match("^%s*(.-)%s*$")
      end
      return true
    end,

    ["规格工具生成 APS 兼容产物"] = function(world)
      local feature_text = "# language: zh-CN\n功能: 测试\n场景大纲: 归一化测试\n  假如 "
        .. world.step_text .. "\n例子:\n  | "
        .. table.concat(world.example_headers, " | ") .. " |\n  | "
        .. string.rep("值 | ", #world.example_headers):sub(1, -3) .. " |\n"
      local result, err = normalizer.normalize_text(feature_text, { path = "features/test.feature" })
      if result == nil then
        return nil, "normalization failed: " .. tostring(err)
      end
      world.normalized = result
      return true
    end,

    ["产物中的参数名为<p16>"] = function(world, example)
      local expected_names = {}
      for name in tostring(example.p16):gmatch("[^,]+") do
        expected_names[#expected_names + 1] = name:match("^%s*(.-)%s*$")
      end
      for _, name in ipairs(expected_names) do
        if world.normalized.text:find("<" .. name .. ">", 1, true) == nil
          and world.normalized.text:find("| " .. name .. " |", 1, true) == nil
          and world.normalized.text:find("| " .. name .. " ", 1, true) == nil
          and world.normalized.text:find(" " .. name .. " |", 1, true) == nil then
          return nil, "expected parameter name not in output: " .. name
        end
      end
      return true
    end,

    ["产物保留中文表头到规范参数名的映射"] = function(world)
      if world.normalized.source_map == nil then
        return nil, "no source_map in normalized output"
      end
      if world.normalized.source_map.field_names == nil then
        return nil, "no field_names in source_map"
      end
      for _, header in ipairs(world.example_headers) do
        local found = false
        for _, mapped_name in pairs(world.normalized.source_map.field_names) do
          if mapped_name == header then
            found = true
            break
          end
        end
        if not found then
          return nil, "Chinese header not in field_names mapping: " .. header
        end
      end
      return true
    end,

    ["再次生成得到相同的规范参数名"] = function(world)
      local feature_text = "# language: zh-CN\n功能: 测试\n场景大纲: 归一化测试\n  假如 "
        .. world.step_text .. "\n例子:\n  | "
        .. table.concat(world.example_headers, " | ") .. " |\n  | "
        .. string.rep("值 | ", #world.example_headers):sub(1, -3) .. " |\n"
      local result, err = normalizer.normalize_text(feature_text, { path = "features/test.feature" })
      if result == nil then
        return nil, "second normalization failed: " .. tostring(err)
      end
      if result.text ~= world.normalized.text then
        return nil, "non-deterministic: outputs differ on re-run"
      end
      return true
    end,

    -- Scenario 5: 中文规格被编译为 APS 兼容中间格式
    ["中文功能文件声明<p17>"] = function(world, example)
      world.expected_feature_name = example.p17
      return true
    end,

    ["中文场景声明<p18>"] = function(world, example)
      world.expected_scenario_name = example.p18
      return true
    end,

    ["规格工具生成中间格式"] = function(world)
      local feature_text = "# language: zh-CN\n功能: " .. world.expected_feature_name
        .. "\n场景大纲: " .. world.expected_scenario_name
        .. "\n  假如 步骤一\n例子:\n  | 值 |\n  | 1 |\n"
      local normalized, norm_err = normalizer.normalize_text(feature_text, { path = "features/test.feature" })
      if normalized == nil then
        return nil, "normalization failed: " .. tostring(norm_err)
      end
      local ir, err = gherkin_parser.parse_text(normalized.text, { source_map = normalized.source_map })
      if ir == nil then
        return nil, "parse failed: " .. tostring(err)
      end
      world.ir = ir
      world.normalized_text = normalized
      return true
    end,

    ["中间格式的功能名为<p17>"] = function(world, example)
      if world.ir.name ~= example.p17 then
        return nil, "feature name mismatch: expected " .. example.p17 .. ", got " .. tostring(world.ir.name)
      end
      return true
    end,

    ["中间格式的场景名为<p18>"] = function(world, example)
      local scenario = (world.ir.scenarios or {})[1]
      if scenario == nil then
        return nil, "no scenarios in IR"
      end
      if scenario.name ~= example.p18 then
        return nil, "scenario name mismatch: expected " .. example.p18 .. ", got " .. tostring(scenario.name)
      end
      return true
    end,

    ["中间格式只使用 APS 支持的关键字"] = function(world)
      local aps_keywords = { Given = true, When = true, Then = true, And = true }
      for _, scenario in ipairs(world.ir.scenarios or {}) do
        for _, step in ipairs(scenario.steps or {}) do
          if not aps_keywords[step.keyword] then
            return nil, "non-APS keyword in IR: " .. tostring(step.keyword)
          end
        end
      end
      for _, step in ipairs(world.ir.background or {}) do
        if not aps_keywords[step.keyword] then
          return nil, "non-APS keyword in background: " .. tostring(step.keyword)
        end
      end
      return true
    end,

    ["中间格式不是人工编辑源"] = function(world)
      if world.normalized_text == nil then
        return nil, "no normalized text available"
      end
      local text = world.normalized_text.text
      if text:find("功能:", 1, true) then
        return nil, "IR source still contains Chinese 功能: keyword"
      end
      if not text:find("Feature:", 1, true) then
        return nil, "normalized output should contain APS Feature: keyword"
      end
      return true
    end,

    -- Scenario 6: 诊断信息回指中文源文件
    ["中文功能文件第<p9>行存在<p19>"] = function(world, example)
      world.error_line = tonumber(example.p9)
      world.error_type = example.p19
      return true
    end,

    ["规格工具报告错误"] = function(world, example)
      local file_path = example.p1 or world.feature_path
      local target_line = world.error_line

      local bad_feature
      if world.error_type == "例子列数不匹配" then
        local lines = { "# language: zh-CN" }
        for _ = 2, target_line - 6 do
          lines[#lines + 1] = ""
        end
        lines[#lines + 1] = "功能: 错误测试"
        lines[#lines + 1] = "场景大纲: 表格错误"
        lines[#lines + 1] = "  假如 玩家<玩家>已有<已有道具数>张道具"
        lines[#lines + 1] = "例子:"
        lines[#lines + 1] = "  | 玩家 | 已有道具数 |"
        lines[#lines + 1] = "  | 小明 |"
        bad_feature = table.concat(lines, "\n") .. "\n"
      elseif world.error_type == "缺少参数值" then
        local lines = { "# language: zh-CN" }
        lines[#lines + 1] = ""
        lines[#lines + 1] = "功能: 错误测试"
        for _ = 4, target_line - 2 do
          lines[#lines + 1] = ""
        end
        lines[#lines + 1] = "场景大纲: 缺少值"
        lines[#lines + 1] = "  假如 消息包含分支名<分支名>和提交<提交哈希>"
        lines[#lines + 1] = "例子:"
        lines[#lines + 1] = "  | 分支名 |"
        lines[#lines + 1] = "  | main |"
        bad_feature = table.concat(lines, "\n") .. "\n"
      else
        return nil, "unknown error type: " .. tostring(world.error_type)
      end

      local normalized, norm_err = normalizer.normalize_text(bad_feature, { path = file_path })
      if normalized == nil then
        world.error_message = norm_err
        return true
      end
      local ir, parse_err = gherkin_parser.parse_text(normalized.text, { source_map = normalized.source_map })
      if parse_err ~= nil then
        world.error_message = parse_err
        return true
      end
      if ir == nil then
        return nil, "expected error but got nil IR without error"
      end

      local runtime = require("acceptance.runtime")
      local result = runtime.run_feature(ir, {
        ["消息包含分支名<p1>和提交<p2>"] = function() return true end,
        ["玩家<p1>已有<p2>张道具"] = function() return true end,
      })
      if not result.ok then
        world.error_message = runtime.format_failures(result)
        return true
      end
      return nil, "expected runtime error for: " .. world.error_type
    end,

    ["错误信息包含<p1>"] = function(world, example)
      local root = _project_root()
      local full_path = root .. "/" .. example.p1
      if not common.path_exists(full_path) then
        return nil, "source path does not exist: " .. full_path
      end
      if not tostring(world.error_message):find(example.p1, 1, true) then
        return nil, "error does not contain path: " .. example.p1 .. " in: " .. tostring(world.error_message)
      end
      return true
    end,

    ["错误信息使用中文表头<p15>"] = function(world, example)
      if not tostring(world.error_message):find(example.p15, 1, true) then
        return nil, "error does not contain Chinese header: " .. example.p15 .. " in: " .. tostring(world.error_message)
      end
      return true
    end,

    ["错误信息不只显示规范参数名<p16>"] = function(world, example)
      if not example.p16:match("^p%d+$") then
        return nil, "canonical param name should match pN format: " .. example.p16
      end
      local msg = tostring(world.error_message)
      if not msg:find(example.p15, 1, true) then
        return nil, "error message should contain Chinese header " .. example.p15 .. " in: " .. msg
      end
      return true
    end,

    -- Scenario 7: 变异测试报告显示中文字段名
    ["中文功能文件定义参数<p20>"] = function(world, example)
      world.chinese_param_name = example.p20
      return true
    end,

    ["参数被归一化为<p16>"] = function(world, example)
      world.canonical_param_name = example.p16
      return true
    end,

    ["变异测试生成报告"] = function(world)
      local feature_text = "# language: zh-CN\n功能: 报告测试\n场景大纲: 变异\n  假如 玩家<"
        .. world.chinese_param_name .. ">执行动作\n例子:\n  | "
        .. world.chinese_param_name .. " |\n  | A |\n"
      local normalized, norm_err = normalizer.normalize_text(feature_text, { path = "features/test.feature" })
      if normalized == nil then
        return nil, "normalization failed: " .. tostring(norm_err)
      end
      local ir, parse_err = gherkin_parser.parse_text(normalized.text, { source_map = normalized.source_map })
      if ir == nil then
        return nil, "parse failed: " .. tostring(parse_err)
      end
      local mutations = mutator.build_mutations(ir)
      if #mutations == 0 then
        return nil, "no mutations generated"
      end
      local report = {
        summary = { total = 1, killed = 1, survived = 0, errors = 0 },
        results = {
          { mutation = mutations[1], status = "killed", output = "", error = "", duration = 0 },
        },
      }
      world.mutation_report = mutator.format_text_report(report)
      return true
    end,

    ["报告显示<p20>的变异"] = function(world, example)
      if not world.mutation_report:find(example.p20, 1, true) then
        return nil, "report does not contain Chinese param: " .. example.p20 .. " in: " .. world.mutation_report
      end
      return true
    end,

    ["报告格式为<p21>"] = function(world, example)
      local name_part = example.p21:match("^([^:]+):")
      if name_part and not world.mutation_report:find(name_part .. ":", 1, true) then
        return nil, "report format mismatch, expected '" .. name_part .. ":' in: " .. world.mutation_report
      end
      return true
    end,

    ["报告不只显示<p16>"] = function(world, example)
      if not example.p16:match("^p%d+$") then
        return nil, "canonical param name should match pN format: " .. example.p16
      end
      if world.mutation_report:find(example.p16 .. ":", 1, true)
        and not world.mutation_report:find(world.chinese_param_name, 1, true) then
        return nil, "report only shows canonical name without Chinese"
      end
      return true
    end,

    -- Scenario 8: 交接消息保持 SwarmForge 纪律
    ["<p22>准备交接给<p23>"] = function(world, example)
      local valid_roles = { specifier = true, coder = true, refactorer = true, architect = true }
      if not valid_roles[example.p22] then
        return nil, "unknown source role: " .. tostring(example.p22)
      end
      if not valid_roles[example.p23] then
        return nil, "unknown target role: " .. tostring(example.p23)
      end
      world.handoff_source = example.p22
      world.handoff_target = example.p23
      return true
    end,

    ["交接消息生成"] = function(world, example)
      world.handoff_msg = handoff_message.build({
        source_role = world.handoff_source,
        target_role = world.handoff_target,
        branch = example.p25 or "swarmforge-coder",
        commit = example.p26 or "abc1234",
        summary = example.p27 or "变更",
      })
      world.handoff_cmd = handoff_message.notify_command({
        source_role = world.handoff_source,
        target_role = world.handoff_target,
        branch = example.p25 or "swarmforge-coder",
        commit = example.p26 or "abc1234",
        summary = example.p27 or "变更",
      })
      return true
    end,

    ["消息以<p24>开头"] = function(world, example)
      if world.handoff_msg:sub(1, #example.p24) ~= example.p24 then
        return nil, "message does not start with: " .. example.p24 .. " got: " .. world.handoff_msg:sub(1, 30)
      end
      return true
    end,

    ["消息包含分支名<p25>"] = function(world, example)
      if not world.handoff_msg:find(example.p25, 1, true) then
        return nil, "message missing branch: " .. example.p25
      end
      return true
    end,

    ["消息包含提交哈希<p26>"] = function(world, example)
      if not world.handoff_msg:find(example.p26, 1, true) then
        return nil, "message missing commit: " .. example.p26
      end
      return true
    end,

    ["消息描述变更内容<p27>"] = function(world, example)
      if not world.handoff_msg:find(example.p27, 1, true) then
        return nil, "message missing summary: " .. example.p27
      end
      return true
    end,

    ["消息通过项目内通知脚本发送"] = function(world)
      if not world.handoff_cmd:find("notify%-agent%.sh") then
        return nil, "command does not use notify-agent.sh: " .. world.handoff_cmd
      end
      return true
    end,

    -- Scenario 9: SwarmForge 迁移资产边界清晰
    ["仓库准备提交 SwarmForge 迁移"] = function(world)
      world.project_root = _project_root()
      return true
    end,

    ["开发者查看 git 状态"] = function(world)
      world.git_ready = true
      return true
    end,

    ["<p28>应作为迁移资产提交"] = function(world, example)
      local path = example.p28
      local known_prefixes = { "swarmforge/", "swarmtools/", "features/", "docs/" }
      local valid = false
      for _, prefix in ipairs(known_prefixes) do
        if path:sub(1, #prefix) == prefix then
          valid = true
          break
        end
      end
      if not valid then
        return nil, "path does not match known migration asset prefixes: " .. path
      end
      local result = common.run_command({
        "git", "check-ignore", "--quiet", path,
      }, { cwd = world.project_root })
      if result.ok then
        return nil, "path is gitignored but should be committed: " .. path
      end
      return true
    end,

    ["<p29>应保持为本地运行状态"] = function(world, example)
      local path = example.p29
      local result = common.run_command({
        "git", "check-ignore", "--quiet", path,
      }, { cwd = world.project_root })
      if not result.ok then
        return nil, "path is NOT gitignored but should be local-only: " .. path
      end
      return true
    end,
  }
end

function steps.handlers()
  return _handlers()
end

return steps
