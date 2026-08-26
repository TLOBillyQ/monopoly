-- Engine-domain acceptance steps for SwarmForge launch behavior
-- (features/swarmforge/swarm_launch.feature): the swarm config must declare
-- every role, each role's engine must be supported and installed.
--
-- Config parsing lives in the declaration domain module to keep each file's
-- mutation-site count bounded; handlers() merges them back into one step
-- table, mirroring builtin_steps.lua.
local dsl = require("packages.acceptance.step_dsl")
local proc_lib = require("foundation.proc")
local declaration = require("packages.acceptance.steps.swarm_launch.declaration")

local swarm_launch_steps = {}

local _SUPPORTED_ENGINES = {
  claude = true,
  codex = true,
  copilot = true,
  grok = true,
}

function swarm_launch_steps.handlers()
  local handlers = dsl.steps({
    ["角色<角色名>使用受支持的引擎"] = function(world, example)
      local role = example["角色名"]
      local row = world.swarm_role
      if row == nil or row.role ~= role then
        local found, err = declaration.role_row(world, role)
        if found == nil then
          return nil, err
        end
        row = found
      end
      if not _SUPPORTED_ENGINES[row.engine] then
        return nil, "角色 " .. role .. " 的引擎不受支持: " .. tostring(row.engine)
      end
      return true
    end,

    ["角色<角色名>分配唯一会话名"] = function(world, example)
      local role = example["角色名"]
      local rows = world.swarm_conf_rows
      if rows == nil then
        return nil, "swarm 启动配置尚未解析"
      end
      local session_counts = {}
      local role_counts = {}
      for _, row in ipairs(rows) do
        local session = "swarmforge-" .. row.role
        session_counts[session] = (session_counts[session] or 0) + 1
        role_counts[row.role] = (role_counts[row.role] or 0) + 1
      end
      if (role_counts[role] or 0) ~= 1 then
        return nil, "角色 " .. role .. " 在配置中出现 " .. tostring(role_counts[role] or 0) .. " 次"
      end
      local session = "swarmforge-" .. role
      if (session_counts[session] or 0) ~= 1 then
        return nil, "会话 " .. session .. " 被多个角色复用"
      end
      return true
    end,

    ["检查角色<角色名>的引擎是否已安装"] = function(world, example)
      local row, err = declaration.role_row(world, example["角色名"])
      if row == nil then
        return nil, err
      end
      world.engine_available = proc_lib.command_exists(row.engine)
      world.engine_name = row.engine
      return true
    end,

    ["角色<角色名>的引擎可用"] = function(world)
      if world.engine_available ~= true then
        return nil, "引擎 " .. tostring(world.engine_name or "?") .. " 不可用(未安装或不在 PATH)"
      end
      return true
    end,
  })
  dsl.merge(handlers, declaration.handlers(), "swarm_launch.declaration")
  return handlers
end

return swarm_launch_steps
