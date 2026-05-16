local handoff_message = {}

local GREETING = "Review your rules."

local function _project_root()
  local source = debug.getinfo(1, "S").source or "@tools/swarmforge/handoff_message.lua"
  local normalized = tostring(source):gsub("^@", ""):gsub("\\", "/")
  local tools_dir = normalized:match("^(.*)/swarmforge/handoff_message%.lua$")
  if tools_dir == nil then
    return "."
  end
  return tools_dir:match("^(.*)/tools$") or "."
end

function handoff_message.notify_script_path()
  return _project_root() .. "/swarmtools/notify-agent.sh"
end

function handoff_message.build(opts)
  opts = opts or {}
  return GREETING
    .. " Branch: " .. tostring(opts.branch)
    .. " Commit: " .. tostring(opts.commit)
    .. " Changed: " .. tostring(opts.summary)
end

function handoff_message.notify_command(opts)
  opts = opts or {}
  local script = handoff_message.notify_script_path()
  local message = handoff_message.build(opts)
  return script .. " " .. tostring(opts.target_role) .. ' "' .. message .. '"'
end

return handoff_message
