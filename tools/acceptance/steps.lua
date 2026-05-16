local number_utils = require("src.foundation.number")
local normalizer = require("acceptance.chinese_normalizer")
local gherkin_parser = require("acceptance.gherkin_parser")
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

    -- Background: SwarmForge workflow enabled
    ["仓库启用了 SwarmForge 迁移工作流"] = function(world)
      world.swarmforge_enabled = true
      world.project_root = _project_root()
      return true
    end,

    -- Scenario 1: Business users maintain only Chinese feature files
    ["业务功能文件位于<p1>"] = function(world, example)
      world.feature_path = example.p1
      return true
    end,

    ["规格工具读取该文件"] = function(world)
      local content, err = _read_feature_file(world.feature_path)
      if content == nil then
        return nil, err
      end
      world.feature_content = content
      local result, norm_err = normalizer.normalize_text(content, { path = world.feature_path })
      if result == nil then
        world.normalize_error = norm_err
        return true
      end
      world.normalized = result
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

    ["工具拒绝业务源文件中的英文结构关键字"] = function(world)
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

    -- Scenario 2: Chinese parameter names are stably normalized
    ["步骤文本为<p9>"] = function(world, example)
      world.step_text = example.p9
      return true
    end,

    ["例子表头包含<p10>"] = function(world, example)
      world.example_headers = {}
      for header in tostring(example.p10):gmatch("[^,]+") do
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

    ["产物中的参数名为<p11>"] = function(world, example)
      local expected_names = {}
      for name in tostring(example.p11):gmatch("[^,]+") do
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

    -- Scenario 3: Chinese spec compiled to APS-compatible IR
    ["中文功能文件声明<p12>"] = function(world, example)
      world.expected_feature_name = example.p12
      return true
    end,

    ["中文场景声明<p13>"] = function(world, example)
      world.expected_scenario_name = example.p13
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

    ["中间格式的功能名为<p12>"] = function(world, example)
      if world.ir.name ~= example.p12 then
        return nil, "feature name mismatch: expected " .. example.p12 .. ", got " .. tostring(world.ir.name)
      end
      return true
    end,

    ["中间格式的场景名为<p13>"] = function(world, example)
      local scenario = (world.ir.scenarios or {})[1]
      if scenario == nil then
        return nil, "no scenarios in IR"
      end
      if scenario.name ~= example.p13 then
        return nil, "scenario name mismatch: expected " .. example.p13 .. ", got " .. tostring(scenario.name)
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
        return nil, "IR source still contains Chinese 功能: keyword (should be normalized)"
      end
      if not text:find("Feature:", 1, true) then
        return nil, "normalized output should contain APS Feature: keyword"
      end
      return true
    end,

    -- Scenario 4: Diagnostics point back to Chinese source
    ["中文功能文件第<p14>行存在<p15>"] = function(world, example)
      world.error_line = tonumber(example.p14)
      world.error_type = example.p15
      return true
    end,

    ["规格工具报告错误"] = function(world, example)
      local file_path = example.p1 or world.feature_path
      local target_line = tonumber(world.error_line)

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
        ["消息包含分支名<p1>和提交<p2>"] = function()
          return true
        end,
        ["玩家<p1>已有<p2>张道具"] = function()
          return true
        end,
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

    ["错误信息包含第<p14>行"] = function(world, example)
      local line_marker = "第" .. example.p14 .. "行"
      if not tostring(world.error_message):find(line_marker, 1, true) then
        return nil, "error does not contain line marker: " .. line_marker .. " in: " .. tostring(world.error_message)
      end
      return true
    end,

    ["错误信息使用中文表头<p10>"] = function(world, example)
      if not tostring(world.error_message):find(example.p10, 1, true) then
        return nil, "error does not contain Chinese header: " .. example.p10 .. " in: " .. tostring(world.error_message)
      end
      return true
    end,

    ["错误信息不只显示规范参数名<p11>"] = function(world, example)
      local msg = tostring(world.error_message)
      if not example.p11:match("^p%d+$") then
        return nil, "canonical param name should match pN format: " .. example.p11
      end
      if not msg:find(example.p10, 1, true) then
        return nil, "error message should contain Chinese header " .. example.p10 .. " in: " .. msg
      end
      if msg:find(example.p11, 1, true) and not msg:find(example.p10, 1, true) then
        return nil, "error only shows canonical name " .. example.p11 .. " without Chinese header"
      end
      return true
    end,

    -- Scenario 5: Handoff messages maintain SwarmForge discipline
    ["<p16>准备交接给<p17>"] = function(world, example)
      local valid_roles = { specifier = true, coder = true, refactorer = true, architect = true }
      if not valid_roles[example.p16] then
        return nil, "unknown source role: " .. tostring(example.p16)
      end
      if not valid_roles[example.p17] then
        return nil, "unknown target role: " .. tostring(example.p17)
      end
      world.handoff_source = example.p16
      world.handoff_target = example.p17
      return true
    end,

    ["交接消息生成"] = function(world, example)
      world.handoff_msg = handoff_message.build({
        source_role = world.handoff_source,
        target_role = world.handoff_target,
        branch = example.p19 or "swarmforge-coder",
        commit = example.p20 or "abc1234",
        summary = example.p21 or "变更",
      })
      world.handoff_cmd = handoff_message.notify_command({
        source_role = world.handoff_source,
        target_role = world.handoff_target,
        branch = example.p19 or "swarmforge-coder",
        commit = example.p20 or "abc1234",
        summary = example.p21 or "变更",
      })
      return true
    end,

    ["消息以<p18>开头"] = function(world, example)
      if world.handoff_msg:sub(1, #example.p18) ~= example.p18 then
        return nil, "message does not start with: " .. example.p18 .. " got: " .. world.handoff_msg:sub(1, 30)
      end
      return true
    end,

    ["消息包含分支名<p19>"] = function(world, example)
      if not world.handoff_msg:find(example.p19, 1, true) then
        return nil, "message missing branch: " .. example.p19
      end
      return true
    end,

    ["消息包含提交哈希<p20>"] = function(world, example)
      if not world.handoff_msg:find(example.p20, 1, true) then
        return nil, "message missing commit: " .. example.p20
      end
      return true
    end,

    ["消息描述变更内容<p21>"] = function(world, example)
      if not world.handoff_msg:find(example.p21, 1, true) then
        return nil, "message missing summary: " .. example.p21
      end
      return true
    end,

    ["消息通过项目内通知脚本发送"] = function(world)
      if not world.handoff_cmd:find("notify%-agent%.sh") then
        return nil, "command does not use notify-agent.sh: " .. world.handoff_cmd
      end
      return true
    end,

    -- Scenario 6: SwarmForge migration asset boundaries
    ["仓库准备提交 SwarmForge 迁移"] = function(world)
      world.project_root = _project_root()
      return true
    end,

    ["开发者查看 git 状态"] = function(world)
      world.git_ready = true
      return true
    end,

    ["<p22>应作为迁移资产提交"] = function(world, example)
      local path = example.p22
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

    ["<p23>应保持为本地运行状态"] = function(world, example)
      local path = example.p23
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
