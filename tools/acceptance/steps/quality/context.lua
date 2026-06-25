local common = require("shared.lib.common")
local number_utils = require("src.foundation.number")

local context = {}

function context.root(world)
  if world.project_root ~= nil then
    return world.project_root
  end
  local root = common.current_dir()
  world.project_root = root
  return root
end

function context.require_path(world, path)
  local full_path = common.join_path(context.root(world), path)
  if not common.path_exists(full_path) then
    return nil, "missing required path: " .. path
  end
  return true
end

function context.require_tool(world, name, relative_path)
  local bootstrap = require("shared.bootstrap")
  local env = bootstrap.install(debug.getinfo(1, "S").source)
  local tool, err = bootstrap.ensure_tool(name, env)
  if tool == nil then
    return nil, err
  end
  if relative_path ~= nil and relative_path ~= "" then
    local full_path = common.join_path(tool.root, relative_path)
    if not common.path_exists(full_path) then
      return nil, "missing required tool path: " .. tostring(name) .. "/" .. tostring(relative_path)
    end
  end
  return true
end

function context.state(world)
  world.quality_state = world.quality_state or {}
  return world.quality_state
end

function context.set_source(world, path)
  local state = context.state(world)
  state.source = tostring(path or "")
  return state
end

function context.to_integer(value)
  return number_utils.to_integer(value)
end

function context.manifest_text(state)
  local version = state.manifest_version or 2
  local status = state.manifest_has_last_status and "\nlastMutationStatus=passed" or ""
  local scope = state.scope_id or "chunk:" .. tostring(state.source or "src/file.lua")
  return "--[[ mutate4lua-manifest\nversion=" .. tostring(version)
    .. "\nscope.0.id=" .. scope
    .. "\nscope.0.semanticHash=" .. tostring(state.semantic_hash or "hash-current")
    .. status
    .. "\n]]"
end

function context.has_marker(text)
  return tostring(text or ""):find("mutate4lua%-manifest") ~= nil
end

function context.prepare_manifest(world, path, opts)
  local state = context.set_source(world, path)
  opts = opts or {}
  state.has_manifest = opts.has_manifest ~= false
  state.manifest_version = opts.version or 2
  state.semantic_hash = opts.semantic_hash or "hash-current"
  state.manifest_has_last_status = opts.last_status == true
  state.scope_id = opts.scope_id
  state.manifest_before = state.has_manifest and context.manifest_text(state) or ""
  state.manifest_after = state.manifest_before
  state.run = {}
  return state
end

function context.mark_manifest_written(state)
  state.has_manifest = true
  state.manifest_version = state.manifest_version or 2
  state.manifest_has_last_status = state.manifest_has_last_status == true
  state.manifest_after = context.manifest_text(state)
end

function context.manifest_data_from_state(state)
  if state.has_manifest == false then
    return nil
  end
  return {
    version = state.manifest_version or 2,
    scopes = {
      {
        id = state.scope_id or "chunk:" .. tostring(state.source or "src/file.lua"),
        semantic_hash = state.semantic_hash or "hash-current",
        last_mutation_status = state.manifest_has_last_status and "passed" or nil,
      },
    },
  }
end

function context.expect(condition, message)
  if condition then
    return true
  end
  return nil, message
end

function context.expect_known_value(value, known, label)
  return context.expect(known[tostring(value or "")] ~= nil,
    "unknown " .. tostring(label) .. " fixture value: " .. tostring(value))
end

function context.expect_manifest_unchanged(world, message)
  local state = context.state(world)
  return context.expect(state.manifest_after == state.manifest_before, message)
end

return context
