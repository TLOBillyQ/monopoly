local number_utils = require("src.core.utils.number_utils")
local common = require("crap.common")
local source_names = require("crap.source_names")

local luac_listing = {}

local decision_opcodes = {
  EQ = true,
  LT = true,
  LE = true,
  TEST = true,
  TESTSET = true,
  FORLOOP = true,
  FORPREP = true,
  TFORLOOP = true,
}

local function _parse_header(line)
  local kind, path, start_line, end_line, instruction_count =
    line:match("^([%a_]+)%s+<(.+):(%-?%d+),(%-?%d+)>%s+%((%d+)%s+instructions")
  if kind == nil then
    return nil
  end
  return {
    kind = kind,
    source_path = common.strip_source_prefix(path),
    start_line = number_utils.to_integer(start_line),
    end_line = number_utils.to_integer(end_line),
    instruction_count = number_utils.to_integer(instruction_count) or 0,
    instructions = {},
  }
end

local function _parse_instruction(line)
  local source_line, opcode = line:match("^%s*%d+%s+%[(%-?%d+)%]%s+([A-Z]+)")
  if source_line == nil then
    return nil
  end
  return {
    source_line = number_utils.to_integer(source_line) or 0,
    opcode = opcode,
  }
end

local function _collect_lines(items)
  local seen = {}
  local lines = {}
  for _, item in ipairs(items or {}) do
    local line_no = item.source_line
    if line_no and line_no > 0 and not seen[line_no] then
      seen[line_no] = true
      lines[#lines + 1] = line_no
    end
  end
  table.sort(lines)
  return lines
end

function luac_listing.analyze_module(module_info)
  local command = "luac -p -l " .. common.shell_quote(module_info.source_path) .. " 2>&1"
  local output, err = common.run_command(command)
  if output == nil then
    return nil, err
  end

  local names_by_line = source_names.extract(module_info.source_text)
  local functions = {}
  local current = nil

  for line in (output .. "\n"):gmatch("([^\n]*)\n") do
    local header = _parse_header(line)
    if header then
      if current ~= nil and current.kind == "function" then
        functions[#functions + 1] = current
      end
      current = header
    else
      local instruction = _parse_instruction(line)
      if instruction and current ~= nil and current.kind == "function" then
        current.instructions[#current.instructions + 1] = instruction
      end
    end
  end

  if current ~= nil and current.kind == "function" then
    functions[#functions + 1] = current
  end

  for index, fn in ipairs(functions) do
    local executable_lines = _collect_lines(fn.instructions)
    local decision_candidates = {}
    for _, instruction in ipairs(fn.instructions) do
      if decision_opcodes[instruction.opcode] then
        decision_candidates[#decision_candidates + 1] = instruction
      end
    end
    local decision_lines = _collect_lines(decision_candidates)
    local inferred_name = source_names.consume_name(names_by_line, fn.start_line)
    if inferred_name == nil then
      inferred_name = "anonymous@" .. tostring(fn.start_line or index)
    end
    fn.name = inferred_name
    fn.id = module_info.module_id .. "::" .. inferred_name .. ":" .. tostring(fn.start_line or index)
    fn.executable_lines = executable_lines
    fn.decision_lines = decision_lines
    fn.complexity = 1 + #decision_lines
    fn.module_id = module_info.module_id
    fn.relative_source_path = module_info.relative_source_path
    fn.source_path = module_info.source_path
    fn.source_name = module_info.source_name
    fn.instructions = nil
  end

  return functions
end

return luac_listing
