require("spec.bootstrap").install_package_paths()

local common = require("shared.lib.common")

local M = {}

local function _read_file(path)
  local file = io.open(path, "rb")
  if file == nil then
    return nil
  end
  local content = file:read("*a") or ""
  file:close()
  return content
end

local function _first_line(text)
  return tostring(text or ""):match("([^\n]*)") or ""
end

local function _fail(index, detail)
  return { ok = false, error = "assertion " .. tostring(index) .. " failed: " .. tostring(detail) }
end

function M.run()
  local agents = _read_file("AGENTS.md")
  if agents == nil then
    return _fail(1, "AGENTS.md missing")
  end
  if _first_line(agents) ~= "# 导读" then
    return _fail(1, "AGENTS.md first line mismatch")
  end

  local claude = _read_file("CLAUDE.md")
  if claude == nil then
    return _fail(2, "CLAUDE.md missing")
  end

  local copilot = _read_file(".github/copilot-instructions.md")
  if copilot == nil then
    return _fail(3, ".github/copilot-instructions.md missing")
  end

  if agents ~= claude then
    return _fail(4, "AGENTS.md and CLAUDE.md differ")
  end

  if agents ~= copilot then
    return _fail(5, "AGENTS.md and .github/copilot-instructions.md differ")
  end

  local mixed_case = common.run_command({
    "python3",
    "-c",
    "import os,sys; sys.exit(0 if 'Agents.md' in os.listdir('.') else 1)",
  }, { cwd = "." })
  if mixed_case.ok == true then
    return _fail(6, "mixed-case Agents.md exists")
  end

  local skills_result = common.run_command({ "ls", "-1", ".agents/skills/" }, { cwd = "." })
  if skills_result.ok ~= true then
    return _fail(7, "unable to list .agents/skills: " .. tostring(skills_result.output))
  end
  local skill_count = 0
  for line in (tostring(skills_result.output or "") .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      skill_count = skill_count + 1
    end
  end
  if skill_count ~= 7 then
    return _fail(7, ".agents/skills has " .. tostring(skill_count) .. " entries")
  end

  local claude_skills = common.run_command({ "test", "-d", ".claude/skills" }, { cwd = "." })
  if claude_skills.ok == true then
    return _fail(8, ".claude/skills exists")
  end

  if io.open(".agents/plan.md", "r") ~= nil then
    return _fail(9, ".agents/plan.md exists")
  end
  if io.open(".agents/research.md", "r") ~= nil then
    return _fail(9, ".agents/research.md exists")
  end

  if io.open(".sisyphus/archive/plan.md", "r") == nil then
    return _fail(10, ".sisyphus/archive/plan.md missing")
  end
  if io.open(".sisyphus/archive/research.md", "r") == nil then
    return _fail(10, ".sisyphus/archive/research.md missing")
  end

  local forbidden = "lua tests/(behavior|guard|contract|tooling).lua"
  for _, path in ipairs({ "AGENTS.md", ".agents/skills/verify-fast/SKILL.md", ".agents/skills/verify-full/SKILL.md" }) do
    local text = _read_file(path)
    if text == nil then
      return _fail(11, path .. " missing")
    end
    if text:find(forbidden, 1, true) ~= nil then
      return _fail(11, path .. " contains forbidden tests path pattern")
    end
  end

  return { ok = true, message = "agent_instructions ok" }
end

function M.main()
  local result = M.run()
  if not result.ok then
    io.stderr:write(result.error, "\n")
    os.exit(1)
  end
  print(result.message)
end

if ... == nil then
  M.main()
else
  return M
end
