local tool_lockfile = {}

local _TOOL_DEFS = {
  acceptance4lua = { required = "lib/acceptance4lua/init.lua" },
  arch_view = { required = "lib/arch_view/init.lua" },
  crap4lua = { required = "lib/crap4lua/cli.lua" },
  dry4lua = { required = "lib/dry4lua/cli.lua" },
  mutate4lua = { required = "lib/mutate4lua/cli.lua" },
}

local function _trim(text)
  return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function _split_fields(line)
  local fields = {}
  for field in tostring(line or ""):gmatch("%S+") do
    fields[#fields + 1] = field
  end
  return fields
end

function tool_lockfile.definition(name)
  return _TOOL_DEFS[name]
end

function tool_lockfile.parse_contents(content)
  local tools = {}
  local ordered = {}
  local errors = {}

  local line_no = 0
  for raw_line in (tostring(content or "") .. "\n"):gmatch("(.-)\n") do
    line_no = line_no + 1
    local line = _trim(raw_line:gsub("#.*$", ""))
    if line ~= "" then
      local fields = _split_fields(line)
      local name, repo, commit = fields[1], fields[2], fields[3]
      if #fields < 3 then
        errors[#errors + 1] = "line " .. tostring(line_no) .. ": expected <name> <repo> <commit>"
      elseif _TOOL_DEFS[name] == nil then
        errors[#errors + 1] = "line " .. tostring(line_no) .. ": unknown tool " .. tostring(name)
      elseif tools[name] ~= nil then
        errors[#errors + 1] = "line " .. tostring(line_no) .. ": duplicate tool " .. tostring(name)
      elseif not tostring(commit):match("^[0-9a-fA-F]+$") or #tostring(commit) < 10 then
        errors[#errors + 1] = "line " .. tostring(line_no) .. ": invalid commit for " .. tostring(name)
      else
        tools[name] = {
          name = name,
          repo = repo,
          commit = commit,
          checksum = fields[4],
        }
        ordered[#ordered + 1] = name
      end
    end
  end

  if #errors > 0 then
    return nil, table.concat(errors, "\n")
  end
  return { tools = tools, ordered = ordered }
end

return tool_lockfile
