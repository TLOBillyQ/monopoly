-- SwarmForge config declaration parsing for the launch acceptance steps
-- (features/swarmforge/swarm_launch.feature): locate swarmforge/swarmforge.conf
-- relative to the world project root, parse `window` / `window-invisible` role
-- rows, and resolve a single role row. File-system reads are the only stubbed
-- boundary in the unit tests.
local dsl = require("packages.acceptance.step_dsl")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")

local declaration = {}

function declaration.root(world)
  return world.project_root or "."
end

function declaration.conf_path(world)
  return path_lib.join_path(declaration.root(world), "swarmforge", "swarmforge.conf")
end

-- Parsed rows are cached on the world (`swarm_conf_rows`) so the acceptance
-- pipeline can run several steps without re-reading the config file.
function declaration.parse_conf(world)
  if world.swarm_conf_rows ~= nil then
    return world.swarm_conf_rows, nil
  end
  local content = fs_lib.read_file(declaration.conf_path(world))
  if content == nil then
    return nil, "cannot read " .. declaration.conf_path(world)
  end
  local rows = {}
  for line in tostring(content):gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
      local directive, role, engine, worktree = trimmed:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
      if directive == "window" or directive == "window-invisible" then
        rows[#rows + 1] = { role = role, engine = engine, worktree = worktree }
      end
    end
  end
  world.swarm_conf_rows = rows
  return rows, nil
end

function declaration.role_row(world, role)
  local rows, err = declaration.parse_conf(world)
  if rows == nil then
    return nil, err
  end
  for _, row in ipairs(rows) do
    if row.role == role then
      return row, nil
    end
  end
  return nil, "swarm 配置未声明角色 " .. tostring(role)
end

function declaration.handlers()
  return dsl.steps({
    ["swarm 配置声明角色<角色名>"] = function(world, example)
      local row, err = declaration.role_row(world, example["角色名"])
      if row == nil then
        return nil, err
      end
      world.swarm_role = row
      return true
    end,

    ["解析 swarm 启动配置"] = function(world)
      local rows, err = declaration.parse_conf(world)
      if rows == nil then
        return nil, err
      end
      world.swarm_conf_rows = rows
      return true
    end,
  })
end

return declaration
