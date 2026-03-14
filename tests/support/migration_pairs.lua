local guard_support = require("support.guards.guard_support")

local M = {}

local exact_pairs = {
  { old_path = "Config/runtime_refs.lua", new_path = "src/config/content/runtime_refs.lua" },
  { old_path = "src/core/config/config_sanity.lua", new_path = "src/config/gameplay/config_sanity.lua" },
  { old_path = "src/game/core/runtime/players.lua", new_path = "src/state/player_state.lua" },
  { old_path = "src/game/core/runtime/tiles.lua", new_path = "src/state/board_state.lua" },
  { old_path = "src/game/core/runtime/turn.lua", new_path = "src/state/turn_state.lua" },
  { old_path = "src/game/core/runtime/bootstrap.lua", new_path = "src/rules/bootstrap/registries.lua" },
  { old_path = "src/presentation/runtime/host/sfx_runtime.lua", new_path = "src/host/eggy/sound.lua" },
  { old_path = "src/presentation/runtime/host/unit_lifecycle.lua", new_path = "src/host/eggy/units.lua" },
}

local root_pairs = {
  { old_root = "Config/generated", new_root = "src/config/content" },
  { old_root = "Config/maps", new_root = "src/config/content/maps" },
  { old_root = "Config/testing", new_root = "src/config/testing" },
  { old_root = "src/core/config", new_root = "src/config/gameplay" },
  { old_root = "src/core/state_access", new_root = "src/state/state_access" },
  { old_root = "src/infrastructure/runtime", new_root = "src/host/eggy" },
  { old_root = "src/presentation/runtime/host", new_root = "src/host/eggy" },
  { old_root = "src/game/systems", new_root = "src/rules" },
  { old_root = "src/game/ports", new_root = "src/rules/ports" },
}

local function to_module_id(path)
  return tostring(path):gsub("%.lua$", ""):gsub("/", ".")
end

local function build_pair(old_path, new_path)
  local normalized_old = guard_support.normalize_path(old_path)
  local normalized_new = guard_support.normalize_path(new_path)
  return {
    old_path = normalized_old,
    new_path = normalized_new,
    old_module = to_module_id(normalized_old),
    new_module = to_module_id(normalized_new),
  }
end

function M.file_exists(path)
  local file = io.open(path, "r")
  if not file then
    return false
  end
  file:close()
  return true
end

function M.read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return text
end

function M.iter_pairs()
  local pairs = {}
  local seen_old = {}

  local function add_pair(old_path, new_path)
    local pair = build_pair(old_path, new_path)
    if seen_old[pair.old_path] then
      return
    end
    seen_old[pair.old_path] = true
    pairs[#pairs + 1] = pair
  end

  for _, pair in ipairs(exact_pairs) do
    add_pair(pair.old_path, pair.new_path)
  end

  for _, mapping in ipairs(root_pairs) do
    local files = guard_support.collect_lua_files(mapping.old_root)
    if files then
      table.sort(files)
      for _, path in ipairs(files) do
        local old_path = guard_support.to_repo_relpath(path)
        if not seen_old[old_path] then
          local relpath = old_path:sub(#mapping.old_root + 2)
          add_pair(old_path, mapping.new_root .. "/" .. relpath)
        end
      end
    end
  end

  table.sort(pairs, function(left, right)
    return left.old_path < right.old_path
  end)

  return pairs
end

return M
