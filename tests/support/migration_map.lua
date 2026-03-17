local M = {}

local entries = {
  {
    old_path = "src/entry/init.lua",
    new_path = "src/entry.lua",
    old_module = "src.entry.init",
    new_module = "src.entry",
    canonical_module = "src.entry",
    alias_modules = {
      "src.entry",
      "src.entry.init",
    },
    init_kind = "logic_bearing",
    collision_group = "entry",
    keep_shim = true,
  },
  {
    old_path = "src/host/eggy/init.lua",
    new_path = "src/host/eggy.lua",
    old_module = "src.host.eggy.init",
    new_module = "src.host.eggy",
    canonical_module = "src.host.eggy",
    alias_modules = {
      "src.host.eggy",
      "src.host.eggy.init",
    },
    init_kind = "logic_bearing",
    collision_group = "host-eggy",
    keep_shim = true,
  },
  {
    old_path = "src/rules/board/init.lua",
    new_path = "src/rules/board.lua",
    old_module = "src.rules.board.init",
    new_module = "src.rules.board",
    canonical_module = "src.rules.board",
    alias_modules = {
      "src.rules.board",
      "src.rules.board.init",
    },
    init_kind = "logic_bearing",
    collision_group = "rules-board",
    keep_shim = true,
  },
  {
    old_path = "src/rules/movement/init.lua",
    new_path = "src/rules/movement.lua",
    old_module = "src.rules.movement.init",
    new_module = "src.rules.movement",
    canonical_module = "src.rules.movement",
    alias_modules = {
      "src.rules.movement",
      "src.rules.movement.init",
    },
    init_kind = "logic_bearing",
    collision_group = "rules-movement",
    keep_shim = true,
  },
  {
    old_path = "src/rules/market/init.lua",
    new_path = "src/rules/market.lua",
    old_module = "src.rules.market.init",
    new_module = "src.rules.market",
    canonical_module = "src.rules.market",
    alias_modules = {
      "src.rules.market",
      "src.rules.market.init",
    },
    init_kind = "barrel",
    collision_group = "rules-market",
    keep_shim = true,
  },
  {
    old_path = "src/rules/vehicle/init.lua",
    new_path = "src/rules/vehicle.lua",
    old_module = "src.rules.vehicle.init",
    new_module = "src.rules.vehicle",
    canonical_module = "src.rules.vehicle",
    alias_modules = {
      "src.rules.vehicle",
      "src.rules.vehicle.init",
    },
    init_kind = "logic_bearing",
    collision_group = "rules-vehicle",
    keep_shim = true,
  },
  {
    old_path = "src/turn/loop/init.lua",
    new_path = "src/turn/loop.lua",
    old_module = "src.turn.loop.init",
    new_module = "src.turn.loop",
    canonical_module = "src.turn.loop",
    alias_modules = {
      "src.turn.loop",
      "src.turn.loop.init",
    },
    init_kind = "logic_bearing",
    collision_group = "turn-loop",
    keep_shim = true,
  },
  {
    old_path = "src/turn/timing/init.lua",
    new_path = "src/turn/timing.lua",
    old_module = "src.turn.timing.init",
    new_module = "src.turn.timing",
    canonical_module = "src.turn.timing",
    alias_modules = {
      "src.turn.timing",
      "src.turn.timing.init",
    },
    init_kind = "logic_bearing",
    collision_group = "turn-timing",
    keep_shim = true,
  },
  {
    old_path = "src/ui/controllers/ports/init.lua",
    new_path = "src/ui/controllers/ports.lua",
    old_module = "src.ui.controllers.ports.init",
    new_module = "src.ui.controllers.ports",
    canonical_module = "src.ui.controllers.ports",
    alias_modules = {
      "src.ui.controllers.ports",
      "src.ui.controllers.ports.init",
    },
    init_kind = "barrel",
    collision_group = "ui-controllers-ports",
    keep_shim = true,
  },
  {
    old_path = "src/ui/presenters/init.lua",
    new_path = "src/ui/presenters.lua",
    old_module = "src.ui.presenters.init",
    new_module = "src.ui.presenters",
    canonical_module = "src.ui.presenters",
    alias_modules = {
      "src.ui.presenters",
      "src.ui.presenters.init",
    },
    init_kind = "logic_bearing",
    collision_group = "ui-presenters",
    keep_shim = true,
  },
  {
    old_path = "src/ui/render/board/init.lua",
    new_path = "src/ui/render/board.lua",
    old_module = "src.ui.render.board.init",
    new_module = "src.ui.render.board",
    canonical_module = "src.ui.render.board",
    alias_modules = {
      "src.ui.render.board",
      "src.ui.render.board.init",
    },
    init_kind = "logic_bearing",
    collision_group = "ui-render-board",
    keep_shim = true,
  },
  {
    old_path = "src/ui/render/status3d/init.lua",
    new_path = "src/ui/render/status3d.lua",
    old_module = "src.ui.render.status3d.init",
    new_module = "src.ui.render.status3d",
    canonical_module = "src.ui.render.status3d",
    alias_modules = {
      "src.ui.render.status3d",
      "src.ui.render.status3d.init",
    },
    init_kind = "logic_bearing",
    collision_group = "ui-render-status3d",
    keep_shim = true,
  },
  {
    old_path = "src/ui/stores/ui_runtime/init.lua",
    new_path = "src/ui/stores/ui_runtime.lua",
    old_module = "src.ui.stores.ui_runtime.init",
    new_module = "src.ui.stores.ui_runtime",
    canonical_module = "src.ui.stores.ui_runtime",
    alias_modules = {
      "src.ui.stores.ui_runtime",
      "src.ui.stores.ui_runtime.init",
    },
    init_kind = "forward_only",
    collision_group = "ui-stores-ui-runtime",
    keep_shim = true,
  },
}

local VALID_INIT_KINDS = {
  logic_bearing = true,
  barrel = true,
  forward_only = true,
}

local function validate_entries(list)
  assert(#list == 13, "migration map must cover 13 init entry points")
  local seen_groups = {}
  for index, entry in ipairs(list) do
    assert(entry.old_path, ("entry[%d] missing old_path"):format(index))
    assert(entry.new_path, ("entry[%d] missing new_path"):format(index))
    assert(entry.old_module, ("entry[%d] missing old_module"):format(index))
    assert(entry.new_module, ("entry[%d] missing new_module"):format(index))
    assert(entry.canonical_module, ("entry[%d] missing canonical_module"):format(index))
    assert(entry.canonical_module == entry.new_module, ("entry[%d] canonical_module must match new_module"):format(index))
    assert(VALID_INIT_KINDS[entry.init_kind], ("entry[%d] has unknown init_kind: %s"):format(index, tostring(entry.init_kind)))
    assert(entry.collision_group, ("entry[%d] missing collision_group"):format(index))
    assert(not seen_groups[entry.collision_group], ("duplicate collision_group: %s"):format(entry.collision_group))
    seen_groups[entry.collision_group] = true
    assert(type(entry.alias_modules) == "table" and #entry.alias_modules >= 1, ("entry[%d] must expose alias_modules"):format(index))
    local seen_alias = {}
    local canonical_in_alias = false
    for _, alias in ipairs(entry.alias_modules) do
      assert(type(alias) == "string" and alias ~= "", ("entry[%d] has invalid alias_module"):format(index))
      assert(not seen_alias[alias], ("entry[%d] duplicate alias_module: %s"):format(index, alias))
      seen_alias[alias] = true
      if alias == entry.canonical_module then
        canonical_in_alias = true
      end
    end
    assert(canonical_in_alias, ("entry[%d] alias_modules must include canonical module %s"):format(index, entry.canonical_module))
    assert(entry.keep_shim ~= nil, ("entry[%d] missing keep_shim flag"):format(index))
  end
end

validate_entries(entries)

local index_by_canonical = {}
for _, entry in ipairs(entries) do
  index_by_canonical[entry.canonical_module] = entry
end

function M.iter()
  return ipairs(entries)
end

local function clone_entry(entry)
  local copy = {}
  for key, value in pairs(entry or {}) do
    if type(value) == "table" then
      local list = {}
      for index, item in ipairs(value) do
        list[index] = item
      end
      copy[key] = list
    else
      copy[key] = value
    end
  end
  return copy
end

function M.iter_entries()
  local list = {}
  for index, entry in ipairs(entries) do
    list[index] = clone_entry(entry)
  end
  return list
end

function M.iter_pairs()
  local list = {}
  for _, entry in ipairs(entries) do
    if entry.keep_shim ~= false then
      list[#list + 1] = clone_entry(entry)
    end
  end
  return list
end

function M.find_by_old_path(old_path)
  for _, entry in ipairs(entries) do
    if entry.old_path == old_path then
      return entry
    end
  end
  return nil
end

function M.find_by_old_module(old_module)
  for _, entry in ipairs(entries) do
    if entry.old_module == old_module then
      return entry
    end
  end
  return nil
end

function M.find_by_canonical_module(name)
  return index_by_canonical[name]
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

function M.validate_entries()
  validate_entries(entries)
  return true
end

M.entries = entries

return M
